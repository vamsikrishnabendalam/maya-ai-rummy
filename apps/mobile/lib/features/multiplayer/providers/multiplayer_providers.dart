import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import '../models/table_models.dart';
import '../services/multiplayer_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../game/models/card_group.dart';
import '../../game/providers/game_ui_provider.dart';
import '../../home/services/player_preferences_storage.dart';

final multiplayerServiceProvider = Provider<MultiplayerService>((ref) => MultiplayerService());

// --------------- Network Resilience & Status Provider ---------------

class NetworkStatus {
  final int pingMs;
  final bool isOffline;
  final int pendingActions;

  const NetworkStatus({
    this.pingMs = 32,
    this.isOffline = false,
    this.pendingActions = 0,
  });

  bool get isDegraded => !isOffline && (pingMs >= 150 || pendingActions > 0);
  bool get isDisconnected => isOffline || pingMs >= 600;
}

final networkStatusProvider = StreamProvider.autoDispose<NetworkStatus>((ref) {
  final service = ref.watch(multiplayerServiceProvider);
  final controller = StreamController<NetworkStatus>();

  void emit() {
    if (!controller.isClosed) {
      controller.add(NetworkStatus(
        pingMs: service.lastPingMs,
        isOffline: service.isOffline,
        pendingActions: service.actionQueue.pendingCount,
      ));
    }
  }

  final timer = Timer.periodic(const Duration(seconds: 1), (_) => emit());
  service.pingNotifier.addListener(emit);
  service.offlineNotifier.addListener(emit);
  emit();

  ref.onDispose(() {
    timer.cancel();
    service.pingNotifier.removeListener(emit);
    service.offlineNotifier.removeListener(emit);
    controller.close();
  });

  return controller.stream;
});

// --------------- Lobby State Notifier ---------------

class MultiplayerLobbyNotifier extends StateNotifier<AsyncValue<TableLobby?>> {
  final MultiplayerService _service;
  final Ref _ref;
  StreamSubscription<TableLobby>? _sub;

  MultiplayerLobbyNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<Map<String, String>> createTable({
    required String tableName,
    required int maxPlayers,
    String? password,
    String gameMode = 'Points Rummy',
    int turnTimerSeconds = 30,
    int firstDropPenalty = 20,
    int middleDropPenalty = 40,
    int maxPenalty = 80,
    String entryType = 'FREE',
    int entryCoins = 0,
    String jokerMode = 'OPEN',
  }) async {
    final user = _ref.read(authProvider);
    if (user == null) throw Exception('Must be signed in to create a table.');

    state = const AsyncValue.loading();
    try {
      final res = await _service.createTable(
        user: user,
        tableName: tableName,
        maxPlayers: maxPlayers,
        password: password,
        gameMode: gameMode,
        turnTimerSeconds: turnTimerSeconds,
        firstDropPenalty: firstDropPenalty,
        middleDropPenalty: middleDropPenalty,
        maxPenalty: maxPenalty,
        entryType: entryType,
        entryCoins: entryCoins,
        jokerMode: jokerMode,
      );
      watchTable(res['tableId']!);
      return res;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinTable({
    required String roomCode,
    String? password,
  }) async {
    final user = _ref.read(authProvider);
    if (user == null) throw Exception('Must be signed in to join a table.');

    state = const AsyncValue.loading();
    try {
      final res = await _service.joinTable(
        user: user,
        roomCode: roomCode,
        password: password,
      );
      watchTable(res['tableId'] as String);
      return res;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void watchTable(String tableId) {
    _sub?.cancel();
    _sub = _service.watchTable(tableId).listen(
      (lobby) {
        state = AsyncValue.data(lobby);
      },
      onError: (err, st) {
        state = AsyncValue.error(err, st);
      },
    );
  }

  Future<void> leaveTable() async {
    final lobby = state.value;
    final user = _ref.read(authProvider);
    if (lobby != null && user != null) {
      await _service.leaveTable(lobby.tableId, user.uid);
    }
    _sub?.cancel();
    _sub = null;
    state = const AsyncValue.data(null);
  }

  Future<String> startGame() async {
    final lobby = state.value;
    if (lobby == null) throw Exception('No active table lobby');
    final gameId = await _service.startGame(lobby.tableId);
    return gameId;
  }

  Future<void> kickPlayer(String targetUid) async {
    final lobby = state.value;
    final user = _ref.read(authProvider);
    if (lobby != null && user != null) {
      await _service.kickPlayerFromTable(
        tableId: lobby.tableId,
        hostUid: user.uid,
        targetUid: targetUid,
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final multiplayerLobbyProvider = StateNotifierProvider<MultiplayerLobbyNotifier, AsyncValue<TableLobby?>>((ref) {
  return MultiplayerLobbyNotifier(ref.watch(multiplayerServiceProvider), ref);
});

// --------------- Game Table State Notifier ---------------

class MultiplayerGameTableState {
  final MultiplayerGameState? gameState;
  final List<CardGroup> cardGroups;
  final Card? selectedCard;
  final Set<Card> selectedCards;
  final bool hasDrawnThisTurn;
  final bool isSubmitting;
  final bool isHandLocked;
  final int currentScore;
  final String? statusMessage;
  final Card? finishCard;

  const MultiplayerGameTableState({
    this.gameState,
    this.cardGroups = const [],
    this.selectedCard,
    this.selectedCards = const {},
    this.hasDrawnThisTurn = false,
    this.isSubmitting = false,
    this.isHandLocked = false,
    this.currentScore = 0,
    this.statusMessage,
    this.finishCard,
  });

  MultiplayerGameTableState copyWith({
    MultiplayerGameState? gameState,
    List<CardGroup>? cardGroups,
    Card? selectedCard,
    bool clearSelectedCard = false,
    Set<Card>? selectedCards,
    bool? hasDrawnThisTurn,
    bool? isSubmitting,
    bool? isHandLocked,
    int? currentScore,
    String? statusMessage,
    bool clearStatusMessage = false,
    Card? finishCard,
    bool clearFinishCard = false,
  }) {
    return MultiplayerGameTableState(
      gameState: gameState ?? this.gameState,
      cardGroups: cardGroups ?? this.cardGroups,
      selectedCard: clearSelectedCard ? null : (selectedCard ?? this.selectedCard),
      selectedCards: clearSelectedCard ? const {} : (selectedCards ?? this.selectedCards),
      hasDrawnThisTurn: hasDrawnThisTurn ?? this.hasDrawnThisTurn,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isHandLocked: isHandLocked ?? this.isHandLocked,
      currentScore: currentScore ?? this.currentScore,
      statusMessage: clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
      finishCard: clearFinishCard ? null : (finishCard ?? this.finishCard),
    );
  }
}

class MultiplayerGameNotifier extends StateNotifier<MultiplayerGameTableState> {
  final MultiplayerService _service;
  final Ref _ref;
  final PreferencesStorage _storage = createPreferencesStorage();
  StreamSubscription<MultiplayerGameState>? _sub;
  int _groupIdCounter = 0;
  bool _hasTriggeredInitialDeal = false;

  MultiplayerGameNotifier(this._service, this._ref) : super(const MultiplayerGameTableState());

  bool get hasFirstLife {
    final allCards = state.cardGroups.expand((g) => g.cards).toList();
    return state.cardGroups.any((g) => g.type == CardGroupType.pureSequence) ||
        SequenceValidator.hasPureSequenceInHand(allCards);
  }

  bool get hasSecondLife {
    final pureCount = state.cardGroups.where((g) => g.type == CardGroupType.pureSequence).length;
    final impureCount = state.cardGroups.where((g) => g.type == CardGroupType.impureSequence).length;
    return pureCount >= 1 && (pureCount + impureCount) >= 2;
  }

  void _persistGroups(String gameId, String uid, List<CardGroup> groups, [int? round]) {
    try {
      final r = round ?? state.gameState?.currentRound ?? 1;
      final jsonList = groups.map((g) => g.toJson()).toList();
      _storage.setString('saved_groups_${gameId}_${uid}_r$r', jsonEncode(jsonList));
      _storage.setBool('dealt_${gameId}_${uid}_r$r', true);
    } catch (e) {
      debugPrint('[MultiplayerNotifier] Persisting groups error: $e');
    }
  }

  List<CardGroup>? _loadSavedGroups(String gameId, String uid, [int? round]) {
    try {
      final r = round ?? state.gameState?.currentRound ?? 1;
      final raw = _storage.getString('saved_groups_${gameId}_${uid}_r$r');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .map((item) => CardGroup.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[MultiplayerNotifier] Loading saved groups error: $e');
    }
    return null;
  }

  void watchGame(String gameId) {
    final user = _ref.read(authProvider);
    if (user == null) return;

    _sub?.cancel();

    // Only reset state if switching to a DIFFERENT game to preserve cards when returning to tab
    if (state.gameState?.gameId != gameId) {
      final alreadyDealt = _storage.getBool('dealt_${gameId}_${user.uid}') ?? false;
      _hasTriggeredInitialDeal = alreadyDealt;
      state = const MultiplayerGameTableState();
    }

    _sub = _service.watchGame(gameId, user.uid).listen((g) {
      final prevGame = state.gameState;
      final isNewRound = prevGame != null && g.currentRound > prevGame.currentRound;

      List<CardGroup> groups = state.cardGroups;
      if (isNewRound) {
        // Clear cached groups from previous round so fresh 13 cards are clean-dealt
        _storage.setString('saved_groups_${gameId}_${user.uid}_r${prevGame.currentRound}', '');
        _storage.setBool('dealt_${gameId}_${user.uid}_r${prevGame.currentRound}', false);
        _storage.setString('saved_groups_${gameId}_${user.uid}_r${g.currentRound}', '');
        _storage.setBool('dealt_${gameId}_${user.uid}_r${g.currentRound}', false);
        _hasTriggeredInitialDeal = false;
        groups = [];
      }

      final effectiveJoker = g.effectiveJokerForPlayer(user.uid);

      // Section 7: Authoritative Hand State Synchronization (localHand = serverHand)
      // When 13 cards first arrive on initial deal or on page reload / tab shift:
      if (groups.isEmpty && g.myHand.isNotEmpty) {
        final saved = isNewRound ? null : _loadSavedGroups(gameId, user.uid, g.currentRound);
        if (saved != null && saved.isNotEmpty) {
          _hasTriggeredInitialDeal = true;
          _storage.setBool('dealt_${gameId}_${user.uid}_r${g.currentRound}', true);
          groups = _syncGroupsWithHand(saved, g.myHand, effectiveJoker);
        } else {
          final partition = HandPartitioner.findBestPartition(g.myHand, effectiveJoker);
          groups = [];
          for (final grp in partition.groups) {
            if (grp.cards.isNotEmpty) {
              final type = _detectGroupType(grp.cards, effectiveJoker);
              groups.add(CardGroup(
                id: 'grp_${_groupIdCounter++}',
                type: type,
                cards: List<Card>.from(grp.cards),
                isValid: type != CardGroupType.deadwood,
              ));
            }
          }
          final alreadyDealt = _storage.getBool('dealt_${gameId}_${user.uid}_r${g.currentRound}') ?? false;
          if (!_hasTriggeredInitialDeal && !alreadyDealt) {
            _hasTriggeredInitialDeal = true;
            _storage.setBool('dealt_${gameId}_${user.uid}_r${g.currentRound}', true);
            _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.dealing);
          } else {
            _hasTriggeredInitialDeal = true;
          }
        }
        _persistGroups(gameId, user.uid, groups, g.currentRound);
      } else if (groups.isNotEmpty && g.myHand.isNotEmpty) {
        groups = _syncGroupsWithHand(groups, g.myHand, effectiveJoker);
        _persistGroups(gameId, user.uid, groups, g.currentRound);
      }

      _revalidateGroups(groups, effectiveJoker);
      final score = _recalculateScore(groups, effectiveJoker);

      final totalCardsCount = groups.expand((grp) => grp.cards).length;
      final has14Cards = totalCardsCount >= 14 || g.myHand.length >= 14;

      // Invariant Reconciliation: if player holds >= 14 cards, but game is in DRAW_PHASE or not player's turn,
      // auto-trim excess card(s) from local groups to resolve 14-card deadlock upon reconnect.
      if (has14Cards && (g.phase == 'DRAW_PHASE' || !g.isMyTurn(user.uid))) {
        final all = groups.expand((g) => g.cards).toList();
        if (all.length > 13) {
          final surplus = all.sublist(13);
          for (final extraCard in surplus) {
            groups = _removeCardFromGroups(groups, extraCard);
          }
          _revalidateGroups(groups, effectiveJoker);
          _persistGroups(gameId, user.uid, groups, g.currentRound);
        }
      }

      final effectivePhase = (has14Cards && g.isMyTurn(user.uid) && g.phase != 'DRAW_PHASE') ? 'DISCARD_PHASE' : g.phase;
      final normalizedGame = g.copyWith(phase: effectivePhase);

      state = state.copyWith(
        gameState: normalizedGame,
        cardGroups: groups,
        currentScore: score,
        hasDrawnThisTurn: (has14Cards || normalizedGame.isDiscardPhase) && normalizedGame.isMyTurn(user.uid),
      );

      // Auto-unlock Closed Joker ONLY if dealt hand already contains a Pure Sequence (Life) on deal (13 cards, before any draw)
      if (g.isClosedJoker && !g.openedJokerPlayerUids.contains(user.uid) && groups.isNotEmpty) {
        final allCards = groups.expand((grp) => grp.cards).toList();
        if (allCards.length == 13 &&
            g.myHand.length == 13 &&
            !has14Cards &&
            !state.hasDrawnThisTurn &&
            !normalizedGame.isDiscardPhase &&
            !g.isRoundOver &&
            !g.isDeclaring &&
            g.status == 'IN_PROGRESS') {
          if (SequenceValidator.hasPureSequenceInHand(allCards)) {
            openClosedJoker();
          }
        }
      }
    });
  }

  // Card selection: toggles selectedCards for grouping, single card active for discard
  void selectCard(Card card) {
    if (state.isHandLocked) return;

    final updated = Set<Card>.from(state.selectedCards);
    if (updated.contains(card)) {
      updated.remove(card);
    } else {
      updated.add(card);
    }
    final single = updated.isNotEmpty ? updated.last : null;
    state = state.copyWith(
      selectedCards: updated,
      selectedCard: single,
      clearSelectedCard: single == null,
    );
  }

  // Toggle multi-selection (for grouping multiple cards)
  void toggleCardSelection(Card card) {
    if (state.isHandLocked) return;
    final updated = Set<Card>.from(state.selectedCards);
    if (updated.contains(card)) {
      updated.remove(card);
    } else {
      updated.add(card);
    }
    final single = updated.isNotEmpty ? updated.last : null;
    state = state.copyWith(
      selectedCards: updated,
      selectedCard: single,
      clearSelectedCard: single == null,
    );
  }

  void clearSelection() {
    state = state.copyWith(clearSelectedCard: true, selectedCards: const {});
  }

  Card? get _effectiveWildJoker {
    final game = state.gameState;
    final user = _ref.read(authProvider);
    if (game == null || user == null) return null;
    return game.effectiveJokerForPlayer(user.uid);
  }

  /// Reveals closed joker to current player when they form Life (Pure Sequence)
  Future<void> openClosedJoker() async {
    final game = state.gameState;
    final user = _ref.read(authProvider);
    if (game == null || user == null) return;
    if (!game.isClosedJoker) return;
    if (game.openedJokerPlayerUids.contains(user.uid)) return;

    // Rummy Rule: Closed Joker cannot be viewed during turn while holding 14 cards before discard
    final totalCards = _allCards().length;
    if (totalCards > 13 || state.hasDrawnThisTurn) {
      debugPrint('[openClosedJoker] Blocked: Cannot unlock Closed Joker while holding 14 cards before discarding.');
      return;
    }

    state = state.copyWith(isSubmitting: true);
    try {
      await _service.openClosedJoker(gameId: game.gameId, myUid: user.uid);
      final updatedOpened = [...game.openedJokerPlayerUids, user.uid];
      final currentCardsCount = _allCards().length;
      final effectivePhase = (currentCardsCount >= 14 || state.hasDrawnThisTurn)
          ? 'DISCARD_PHASE'
          : game.phase;
      final updatedGame = game.copyWith(
        openedJokerPlayerUids: updatedOpened,
        phase: effectivePhase,
      );
      final updatedGroups = List<CardGroup>.from(state.cardGroups);
      _revalidateGroups(updatedGroups, updatedGame.openJoker);
      final score = _recalculateScore(updatedGroups, updatedGame.openJoker);

      state = state.copyWith(
        gameState: updatedGame,
        cardGroups: updatedGroups,
        currentScore: score,
        hasDrawnThisTurn: (currentCardsCount >= 14 || effectivePhase == 'DISCARD_PHASE') && game.isMyTurn(user.uid),
        isSubmitting: false,
      );

      // Trigger royal reveal animation (matches Maya AI single player)
      if (updatedGame.openJoker != null) {
        _ref.read(gameUIProvider.notifier).triggerSecretJokerReveal(updatedGame.openJoker!);
      }
    } catch (e) {
      state = state.copyWith(isSubmitting: false, statusMessage: e.toString());
    }
  }

  // Draw Closed
  Future<void> drawFromClosed() async {
    final user = _ref.read(authProvider);
    final game = state.gameState;
    if (user == null || game == null) return;
    if (!game.isMyTurn(user.uid) || !game.isDrawPhase) return;
    if (_allCards().length >= 14) return;

    state = state.copyWith(isSubmitting: true);
    try {
      final drawn = await _service.drawFromClosed(
        gameId: game.gameId,
        myUid: user.uid,
        expectedTurnNumber: game.turnNumber,
      );

      // Check if the realtime watchGame stream already incorporated the drawn card
      final currentCards = _allCards();
      if (!currentCards.contains(drawn) && currentCards.length < 14) {
        final updatedGroups = List<CardGroup>.from(state.cardGroups);
        updatedGroups.add(CardGroup(
          id: 'grp_${_groupIdCounter++}',
          type: CardGroupType.deadwood,
          cards: [drawn],
          isValid: false,
          customLabel: 'DRAWN',
        ));
        _revalidateGroups(updatedGroups, game.openJoker);
        final score = _recalculateScore(updatedGroups, game.openJoker);
        _persistGroups(game.gameId, user.uid, updatedGroups);

        state = state.copyWith(
          gameState: game.copyWith(phase: 'DISCARD_PHASE'),
          cardGroups: updatedGroups,
          currentScore: score,
          hasDrawnThisTurn: true,
          isSubmitting: false,
          clearSelectedCard: true,
        );
      } else {
        state = state.copyWith(
          gameState: game.copyWith(phase: 'DISCARD_PHASE'),
          hasDrawnThisTurn: true,
          isSubmitting: false,
          clearSelectedCard: true,
        );
      }

      _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.drewFromClosed, card: drawn);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, statusMessage: e.toString());
    }
  }

  // Draw Open
  Future<void> drawFromOpen() async {
    final user = _ref.read(authProvider);
    final game = state.gameState;
    if (user == null || game == null || game.openPile.isEmpty) return;
    if (!game.isMyTurn(user.uid) || !game.isDrawPhase) return;
    if (_allCards().length >= 14) return;

    state = state.copyWith(isSubmitting: true);
    try {
      final drawn = await _service.drawFromOpen(
        gameId: game.gameId,
        myUid: user.uid,
        expectedTurnNumber: game.turnNumber,
      );

      // Check if the realtime watchGame stream already incorporated the drawn card
      final currentCards = _allCards();
      if (!currentCards.contains(drawn) && currentCards.length < 14) {
        final updatedGroups = List<CardGroup>.from(state.cardGroups);
        updatedGroups.add(CardGroup(
          id: 'grp_${_groupIdCounter++}',
          type: CardGroupType.deadwood,
          cards: [drawn],
          isValid: false,
          customLabel: 'DRAWN',
        ));
        _revalidateGroups(updatedGroups, _effectiveWildJoker);
        final score = _recalculateScore(updatedGroups, _effectiveWildJoker);
        _persistGroups(game.gameId, user.uid, updatedGroups);

        state = state.copyWith(
          gameState: game.copyWith(phase: 'DISCARD_PHASE'),
          cardGroups: updatedGroups,
          currentScore: score,
          hasDrawnThisTurn: true,
          isSubmitting: false,
          clearSelectedCard: true,
        );
      } else {
        state = state.copyWith(
          gameState: game.copyWith(phase: 'DISCARD_PHASE'),
          hasDrawnThisTurn: true,
          isSubmitting: false,
          clearSelectedCard: true,
        );
      }

      _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.drewFromOpen, card: drawn);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, statusMessage: e.toString());
    }
  }

  // Discard Card
  Future<void> discardSelectedCard() async {
    if (state.selectedCard == null) return;
    final cardToDiscard = state.selectedCard!;
    final user = _ref.read(authProvider);
    final game = state.gameState;
    if (user == null || game == null) return;
    if (state.isHandLocked || game.isCompleted || game.isGameOver || game.isDeclaring || game.isRoundOver) return;

    // Check Indian Rummy Rule: cannot discard open-drawn card
    if (game.cardDrawnFromOpenThisTurn != null && game.cardDrawnFromOpenThisTurn == cardToDiscard) {
      state = state.copyWith(
        statusMessage: 'Indian Rummy Rule: You cannot discard the card drawn from the open pile in the same turn!',
      );
      return;
    }

    state = state.copyWith(isSubmitting: true, clearStatusMessage: true);
    final previousGroups = state.cardGroups;
    final previousScore = state.currentScore;
    try {
      final updated = _removeCardFromGroups(state.cardGroups, cardToDiscard);
      _clearDrawnTags(updated);
      _revalidateGroups(updated, _effectiveWildJoker);
      final score = _recalculateScore(updated, _effectiveWildJoker);
      _persistGroups(game.gameId, user.uid, updated);

      state = state.copyWith(
        cardGroups: updated,
        currentScore: score,
        hasDrawnThisTurn: false,
        clearSelectedCard: true,
        isSubmitting: false,
      );

      _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.discarded, card: cardToDiscard);

      await _service.discardCard(
        gameId: game.gameId,
        myUid: user.uid,
        card: cardToDiscard,
        expectedTurnNumber: game.turnNumber,
      );

      // Auto-unlock Closed Joker if pure sequence (Life) is formed after discarding
      if (game.isClosedJoker && !game.openedJokerPlayerUids.contains(user.uid)) {
        final remainingHand = updated.expand((g) => g.cards).toList();
        if (SequenceValidator.hasPureSequenceInHand(remainingHand)) {
          await openClosedJoker();
        }
      }
    } catch (e) {
      state = state.copyWith(
        cardGroups: previousGroups,
        currentScore: previousScore,
        isSubmitting: false,
        statusMessage: e.toString(),
      );
    }
  }

  // Discard specific card (supports direct drag & drop or tap)
  Future<void> discardCard(Card card) async {
    state = state.copyWith(selectedCard: card);
    await discardSelectedCard();
  }

  // Declare with specific finish card
  Future<Map<String, dynamic>?> declareWithCard(Card card) async {
    state = state.copyWith(selectedCard: card, selectedCards: {card}, finishCard: card);
    return await declareHand(finishCard: card);
  }

  // Sort Hand ascending alias
  void sortHandAscending() => autoSortHand();

  // Drop Hand / Round
  Future<void> dropGame() async {
    final user = _ref.read(authProvider);
    final game = state.gameState;
    if (user == null || game == null) return;
    if (!game.isMyTurn(user.uid) || !game.isDrawPhase || game.isDeclaring) return;

    state = state.copyWith(isSubmitting: true, isHandLocked: true);
    try {
      await _service.dropGame(gameId: game.gameId, myUid: user.uid);
      final updatedGame = _service.getMockGame(game.gameId);
      state = state.copyWith(
        gameState: updatedGame ?? state.gameState,
        isSubmitting: false,
        isHandLocked: false,
        statusMessage: 'You have dropped from this round.',
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        isHandLocked: false,
        statusMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // Declare Hand
  Future<Map<String, dynamic>?> declareHand({Card? finishCard}) async {
    final currentGame = state.gameState;
    if (state.isSubmitting || (currentGame != null && (currentGame.isDeclaring || currentGame.status == 'DECLARING' || currentGame.status == 'COMPLETED'))) {
      return {'isValid': true, 'message': 'Declaration already in progress'};
    }
    final allCards = _allCards();
    if (allCards.length < 13) {
      state = state.copyWith(statusMessage: 'Invalid card count: you only have ${allCards.length} cards.');
      return null;
    }

    Card discardCard;
    List<CardGroup> remainingGroups;

    final effectiveCard = finishCard ?? state.selectedCard;

    if (allCards.length >= 14) {
      if (effectiveCard == null) {
        state = state.copyWith(statusMessage: 'Please select exactly 1 card to discard for your declaration.');
        return null;
      }
      discardCard = effectiveCard;
      remainingGroups = _removeCardFromGroups(state.cardGroups, discardCard);
    } else {
      discardCard = effectiveCard ?? allCards.last;
      remainingGroups = state.cardGroups;
    }

    final groupCards = remainingGroups.map((g) => g.cards).toList();
    final remainingCount = groupCards.fold<int>(0, (sum, g) => sum + g.length);
    if (remainingCount != 13) {
      state = state.copyWith(
        statusMessage: 'Declared hand must have exactly 13 cards (currently has $remainingCount).',
      );
      return null;
    }

    final user = _ref.read(authProvider);
    final game = state.gameState;
    if (user == null || game == null) return null;

    state = state.copyWith(isSubmitting: true, isHandLocked: true, finishCard: discardCard);
    try {
      final res = await _service.declareGame(
        gameId: game.gameId,
        myUid: user.uid,
        discardCard: discardCard,
        groups: groupCards,
        expectedTurnNumber: game.turnNumber,
      );
      final updatedGame = _service.getMockGame(game.gameId);
      state = state.copyWith(
        gameState: updatedGame ?? state.gameState?.copyWith(status: 'DECLARING', finishCard: discardCard),
        cardGroups: remainingGroups,
        isSubmitting: false,
        isHandLocked: true,
        statusMessage: res['message'],
      );
      return res;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, isHandLocked: false, statusMessage: e.toString());
      return null;
    }
  }

  // Opponent submits final hand during DECLARING phase to reduce penalty score
  Future<void> submitFinalHand() async {
    final user = _ref.read(authProvider);
    final game = state.gameState;
    if (user == null || game == null) return;

    state = state.copyWith(isSubmitting: true);
    try {
      final groupCards = state.cardGroups.map((g) => g.cards).toList();
      await _service.submitFinalHand(
        gameId: game.gameId,
        myUid: user.uid,
        groups: groupCards,
      );
      final updatedSubmitted = [...game.submittedPlayerUids, user.uid];
      state = state.copyWith(
        gameState: game.copyWith(submittedPlayerUids: updatedSubmitted),
        isSubmitting: false,
        isHandLocked: true,
        statusMessage: 'Final hand submitted! Waiting for other players...',
      );
    } catch (e) {
      state = state.copyWith(isSubmitting: false, statusMessage: e.toString());
    }
  }

  // Checks if declaration timeout occurred and triggers finalization
  Future<void> checkDeclarationTimeout() async {
    final game = state.gameState;
    if (game == null) return;
    try {
      await _service.checkDeclarationTimeout(game.gameId);
    } catch (_) {}
  }

  // --------------- Drag & Drop Hand Group Management ---------------

  void moveCardBetweenGroups(Card card, String fromGroupId, String toGroupId, int insertIndex) {
    if (state.isHandLocked) return;
    final groups = List<CardGroup>.from(state.cardGroups);

    // Remove from source group
    final fromIdx = groups.indexWhere((g) => g.id == fromGroupId);
    if (fromIdx < 0) return;
    final fromCards = List<Card>.from(groups[fromIdx].cards);
    fromCards.remove(card);
    groups[fromIdx] = groups[fromIdx].copyWith(cards: fromCards);

    // Add to target group
    final toIdx = groups.indexWhere((g) => g.id == toGroupId);
    if (toIdx < 0) return;
    final toCards = List<Card>.from(groups[toIdx].cards);
    final safeIndex = insertIndex.clamp(0, toCards.length);
    toCards.insert(safeIndex, card);
    groups[toIdx] = groups[toIdx].copyWith(cards: toCards);

    _cleanupEmptyGroups(groups);
    _revalidateGroups(groups, _effectiveWildJoker);
    final score = _recalculateScore(groups, _effectiveWildJoker);

    final user = _ref.read(authProvider);
    if (state.gameState != null && user != null) {
      _persistGroups(state.gameState!.gameId, user.uid, groups);
    }

    state = state.copyWith(cardGroups: groups, currentScore: score);
  }

  void moveCardWithinGroup(String groupId, int oldIndex, int newIndex) {
    if (state.isHandLocked) return;
    final groups = List<CardGroup>.from(state.cardGroups);
    final idx = groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;

    final cards = List<Card>.from(groups[idx].cards);
    if (oldIndex < 0 || oldIndex >= cards.length) return;

    final card = cards.removeAt(oldIndex);
    cards.insert(newIndex.clamp(0, cards.length), card);
    groups[idx] = groups[idx].copyWith(cards: cards);

    _revalidateGroups(groups, _effectiveWildJoker);
    final score = _recalculateScore(groups, _effectiveWildJoker);

    final user = _ref.read(authProvider);
    if (state.gameState != null && user != null) {
      _persistGroups(state.gameState!.gameId, user.uid, groups);
    }

    state = state.copyWith(cardGroups: groups, currentScore: score);
  }

  void moveCardToNewGroup(Card card, String fromGroupId) {
    if (state.isHandLocked) return;
    final groups = List<CardGroup>.from(state.cardGroups);
    final fromIdx = groups.indexWhere((g) => g.id == fromGroupId);
    if (fromIdx >= 0) {
      final fromCards = List<Card>.from(groups[fromIdx].cards);
      fromCards.remove(card);
      groups[fromIdx] = groups[fromIdx].copyWith(cards: fromCards);
    }
    groups.add(CardGroup(
      id: 'grp_${_groupIdCounter++}',
      type: CardGroupType.deadwood,
      cards: [card],
      isValid: false,
    ));
    _cleanupEmptyGroups(groups);
    _revalidateGroups(groups, _effectiveWildJoker);
    final score = _recalculateScore(groups, _effectiveWildJoker);

    final user = _ref.read(authProvider);
    if (state.gameState != null && user != null) {
      _persistGroups(state.gameState!.gameId, user.uid, groups);
    }

    state = state.copyWith(cardGroups: groups, currentScore: score);
  }

  void addNewGroup() {
    if (state.isHandLocked) return;
    final groups = List<CardGroup>.from(state.cardGroups);
    groups.add(CardGroup(
      id: 'grp_${_groupIdCounter++}',
      type: CardGroupType.deadwood,
      cards: [],
      isValid: false,
    ));
    final user = _ref.read(authProvider);
    if (state.gameState != null && user != null) {
      _persistGroups(state.gameState!.gameId, user.uid, groups);
    }
    state = state.copyWith(cardGroups: groups);
  }

  void autoSortHand() {
    if (state.isHandLocked) return;
    final allCards = _allCards();
    final sorted = List<Card>.from(allCards)
      ..sort((a, b) {
        if (a.isPrintedJoker) return 1;
        if (b.isPrintedJoker) return -1;
        int suitComp = (a.suit?.index ?? 0).compareTo(b.suit?.index ?? 0);
        if (suitComp != 0) return suitComp;
        return SequenceValidator.rankToLowValue(a.rank!).compareTo(SequenceValidator.rankToLowValue(b.rank!));
      });

    final newGroups = [
      CardGroup(
        id: 'grp_${_groupIdCounter++}',
        type: CardGroupType.deadwood,
        cards: sorted,
        isValid: false,
      ),
    ];

    _revalidateGroups(newGroups, _effectiveWildJoker);
    final score = _recalculateScore(newGroups, _effectiveWildJoker);

    final user = _ref.read(authProvider);
    if (state.gameState != null && user != null) {
      _persistGroups(state.gameState!.gameId, user.uid, newGroups);
    }

    state = state.copyWith(cardGroups: newGroups, currentScore: score);
    _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.sorted);
  }

  void autoGroupHand() {
    if (state.isHandLocked) return;
    final allCards = _allCards();
    if (allCards.isEmpty) return;

    final openJoker = _effectiveWildJoker;
    if (allCards.length >= 14) {
      // 14+ cards: Partition all cards to find melds and best discard card
      final partition14 = HandPartitioner.findBestPartition(allCards, openJoker);
      Card? bestDiscardCard;

      final deadwoodCards = <Card>[];
      for (final grp in partition14.groups) {
        if (!grp.isValid || grp.type == HandGroupType.invalid) {
          deadwoodCards.addAll(grp.cards);
        }
      }

      if (deadwoodCards.isNotEmpty) {
        // Discard highest point non-joker card
        deadwoodCards.sort((a, b) {
          final isAJoker = a.isPrintedJoker || (openJoker != null && a.rank == openJoker.rank);
          final isBJoker = b.isPrintedJoker || (openJoker != null && b.rank == openJoker.rank);
          if (isAJoker && !isBJoker) return 1;
          if (!isAJoker && isBJoker) return -1;
          return Scoring.getCardValue(b, openJoker).compareTo(Scoring.getCardValue(a, openJoker));
        });
        bestDiscardCard = deadwoodCards.first;
      } else {
        // All 14 cards are part of valid groups: pick surplus card from a 4+ card group
        for (final grp in partition14.groups.reversed) {
          if (grp.cards.length >= 4) {
            bestDiscardCard = grp.cards.last;
            break;
          }
        }
        bestDiscardCard ??= allCards.last;
      }

      final remaining13 = List<Card>.from(allCards)..remove(bestDiscardCard);
      final best13Partition = HandPartitioner.findBestPartition(remaining13, openJoker);

      final newGroups = <CardGroup>[];
      for (final grp in best13Partition.groups) {
        if (grp.cards.isEmpty) continue;
        final type = _detectGroupType(grp.cards, openJoker);
        newGroups.add(CardGroup(
          id: 'grp_${_groupIdCounter++}',
          type: type,
          cards: List<Card>.from(grp.cards),
          isValid: type != CardGroupType.deadwood,
        ));
      }

      // Add the 14th card as the discard group
      newGroups.add(CardGroup(
        id: 'grp_${_groupIdCounter++}',
        type: CardGroupType.deadwood,
        cards: [bestDiscardCard],
        isValid: false,
        customLabel: 'DISCARD',
      ));

      _revalidateGroups(newGroups, openJoker);
      final score = _recalculateScore(newGroups, openJoker);

      final user = _ref.read(authProvider);
      if (state.gameState != null && user != null) {
        _persistGroups(state.gameState!.gameId, user.uid, newGroups);
      }

      state = state.copyWith(
        cardGroups: newGroups,
        currentScore: score,
        selectedCard: bestDiscardCard,
        selectedCards: {bestDiscardCard},
      );
      _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.grouped);
      return;
    }

    final partition = HandPartitioner.findBestPartition(allCards, openJoker);
    final newGroups = <CardGroup>[];

    for (final grp in partition.groups) {
      if (grp.cards.isEmpty) continue;
      final type = _detectGroupType(grp.cards, openJoker);
      newGroups.add(CardGroup(
        id: 'grp_${_groupIdCounter++}',
        type: type,
        cards: List<Card>.from(grp.cards),
        isValid: type != CardGroupType.deadwood,
      ));
    }

    _revalidateGroups(newGroups, openJoker);
    final score = _recalculateScore(newGroups, openJoker);

    final user = _ref.read(authProvider);
    if (state.gameState != null && user != null) {
      _persistGroups(state.gameState!.gameId, user.uid, newGroups);
    }

    state = state.copyWith(cardGroups: newGroups, currentScore: score);
    _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.grouped);
  }

  bool _isHandlingTimeout = false;

  Future<void> handleTurnTimeout() async {
    if (_isHandlingTimeout) return;
    final game = state.gameState;
    final user = _ref.read(authProvider);
    if (game == null || user == null || game.status != 'IN_PROGRESS') return;
    if (game.currentTurnPlayerId != user.uid) return;

    _isHandlingTimeout = true;
    try {
      // 1 miss timeout elimination: server picks & drops card, eliminates player, and advances/concludes game
      await _service.forceAdvanceTurnOnTimeout(game.gameId);
    } catch (e) {
      debugPrint('[MultiplayerGameNotifier] handleTurnTimeout notice: $e');
    } finally {
      _isHandlingTimeout = false;
    }
  }

  bool _isHeartbeatInProgress = false;
  Future<void> recordHeartbeat() async {
    final game = state.gameState;
    final user = _ref.read(authProvider);
    if (game == null || user == null || _isHeartbeatInProgress) return;
    _isHeartbeatInProgress = true;
    try {
      await _service.recordPlayerHeartbeat(gameId: game.gameId, uid: user.uid);
    } finally {
      _isHeartbeatInProgress = false;
    }
  }

  Future<void> markDisconnected() async {
    final game = state.gameState;
    final user = _ref.read(authProvider);
    if (game == null || user == null) return;
    await _service.markPlayerDisconnected(gameId: game.gameId, uid: user.uid);
  }

  bool _isCheckingDisconnections = false;
  Future<void> checkDisconnections() async {
    final game = state.gameState;
    if (game == null || game.isCompleted || _isCheckingDisconnections) return;
    final now = _service.syncedServerNow;
    final hasCandidate = game.players.any((p) =>
      p.status == 'ACTIVE' && !p.connected && p.disconnectedAt != null &&
      now.difference(p.disconnectedAt!).inSeconds >= 180
    );
    if (!hasCandidate) return;

    _isCheckingDisconnections = true;
    try {
      await _service.checkDisconnections(game.gameId);
    } finally {
      _isCheckingDisconnections = false;
    }
  }

  Future<void> forceAdvanceTurnOnTimeout() async {
    final game = state.gameState;
    if (game == null || game.status != 'IN_PROGRESS') return;
    await _service.forceAdvanceTurnOnTimeout(game.gameId);
  }

  /// Start next round immediately (e.g. host clicks 'Deal Now' during ROUND_OVER)
  Future<void> startNextRound() async {
    final game = state.gameState;
    if (game == null || game.status != 'ROUND_OVER') return;
    await _service.startNextRound(game.gameId);
  }

  /// Host table owner action to conclude game at any moment
  Future<void> endGameByHost() async {
    final game = state.gameState;
    final user = _ref.read(authProvider);
    if (game == null || user == null || game.isCompleted) return;

    state = state.copyWith(isSubmitting: true);
    try {
      await _service.endGameByHost(gameId: game.gameId, myUid: user.uid);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, statusMessage: e.toString());
      rethrow;
    }
  }

  /// Host table owner action to remove/kick a player during the game
  Future<void> removePlayerByHost(String targetUid) async {
    final game = state.gameState;
    final user = _ref.read(authProvider);
    if (game == null || user == null || game.isCompleted) return;

    state = state.copyWith(isSubmitting: true);
    try {
      await _service.removePlayerByHost(
        gameId: game.gameId,
        hostUid: user.uid,
        targetUid: targetUid,
      );
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, statusMessage: e.toString());
      rethrow;
    }
  }

  void groupSelectedCards([List<Card>? cardsToGroup]) {
    final targets = cardsToGroup ??
        (state.selectedCards.isNotEmpty
            ? state.selectedCards.toList()
            : (state.selectedCard != null ? [state.selectedCard!] : <Card>[]));
    if (targets.isEmpty) return;
    final currentCards = _allCards();
    final validCardsToGroup = <Card>[];
    for (final c in targets) {
      if (currentCards.any((card) => card.cardId == c.cardId || card == c)) {
        validCardsToGroup.add(c);
      }
    }
    if (validCardsToGroup.isEmpty) return;

    final updated = List<CardGroup>.from(state.cardGroups);
    for (final c in validCardsToGroup) {
      for (int i = 0; i < updated.length; i++) {
        final cards = List<Card>.from(updated[i].cards);
        final idx = cards.indexWhere((card) => card.cardId == c.cardId || card == c);
        if (idx >= 0) {
          cards.removeAt(idx);
          updated[i] = updated[i].copyWith(cards: cards);
          break; // Stop after removing 1 instance!
        }
      }
    }
    _cleanupEmptyGroups(updated);
    final type = _detectGroupType(validCardsToGroup, _effectiveWildJoker);
    updated.add(CardGroup(
      id: 'grp_${_groupIdCounter++}',
      type: type,
      cards: List<Card>.from(validCardsToGroup),
      isValid: type != CardGroupType.deadwood,
    ));

    _revalidateGroups(updated, _effectiveWildJoker);
    final score = _recalculateScore(updated, _effectiveWildJoker);

    final user = _ref.read(authProvider);
    if (state.gameState != null && user != null) {
      _persistGroups(state.gameState!.gameId, user.uid, updated);
    }

    state = state.copyWith(
      cardGroups: updated,
      currentScore: score,
      clearSelectedCard: true,
      selectedCards: const {},
    );
  }

  List<CardGroup> _syncGroupsWithHand(List<CardGroup> currentGroups, List<Card> serverHand, Card? openJoker) {
    final serverCardsRemaining = List<Card>.from(serverHand);
    final updatedGroups = <CardGroup>[];

    for (final group in currentGroups) {
      final keptCards = <Card>[];
      for (final card in group.cards) {
        // Step 1: Look for exact card match (including deck index and printed joker)
        int idx = serverCardsRemaining.indexWhere((c) =>
            c.cardId == card.cardId || c.toInt() == card.toInt() || c == card);
        // Step 2: If no exact match (due to deckIndex difference across shoe in Indian Rummy),
        // match by rank + suit + isPrintedJoker so card remains in its exact group!
        if (idx < 0) {
          idx = serverCardsRemaining.indexWhere((c) =>
              c.isPrintedJoker == card.isPrintedJoker &&
              (c.isPrintedJoker || (c.suit == card.suit && c.rank == card.rank)));
        }
        if (idx >= 0) {
          keptCards.add(serverCardsRemaining.removeAt(idx));
        }
      }
      if (keptCards.isNotEmpty) {
        updatedGroups.add(group.copyWith(cards: keptCards));
      }
    }

    int totalKept = updatedGroups.fold<int>(0, (sum, g) => sum + g.cards.length);
    // If fewer than 10 cards matched out of a full 13+ card hand, currentGroups is stale (e.g. from a prior round).
    // Discard stale grouping and partition the entire fresh hand cleanly!
    if (serverHand.length >= 13 && totalKept < 10) {
      final partition = HandPartitioner.findBestPartition(serverHand, openJoker);
      final cleanGroups = <CardGroup>[];
      for (final grp in partition.groups) {
        if (grp.cards.isNotEmpty) {
          final type = _detectGroupType(grp.cards, openJoker);
          cleanGroups.add(CardGroup(
            id: 'grp_${_groupIdCounter++}',
            type: type,
            cards: List<Card>.from(grp.cards),
            isValid: type != CardGroupType.deadwood,
          ));
        }
      }
      return cleanGroups;
    }

    // Newly arrived cards from server:
    if (updatedGroups.isEmpty && serverCardsRemaining.isNotEmpty) {
      // Entire hand arrived clean without matching stale saved groups -> find optimal partition!
      final partition = HandPartitioner.findBestPartition(serverCardsRemaining, openJoker);
      for (final grp in partition.groups) {
        if (grp.cards.isNotEmpty) {
          final type = _detectGroupType(grp.cards, openJoker);
          updatedGroups.add(CardGroup(
            id: 'grp_${_groupIdCounter++}',
            type: type,
            cards: List<Card>.from(grp.cards),
            isValid: type != CardGroupType.deadwood,
          ));
        }
      }
    } else if (serverCardsRemaining.length == 1) {
      // Exactly 1 newly drawn card arrived from server
      updatedGroups.add(CardGroup(
        id: 'grp_${_groupIdCounter++}',
        type: CardGroupType.deadwood,
        cards: [serverCardsRemaining.first],
        isValid: false,
        customLabel: 'DRAWN',
      ));
    } else if (serverCardsRemaining.length > 1) {
      // Multiple surplus cards -> bundle together into 1 deadwood group rather than splitting into 1-card groups!
      updatedGroups.add(CardGroup(
        id: 'grp_${_groupIdCounter++}',
        type: CardGroupType.deadwood,
        cards: List<Card>.from(serverCardsRemaining),
        isValid: false,
      ));
    }

    _cleanupEmptyGroups(updatedGroups);
    return updatedGroups;
  }

  List<Card> _allCards() {
    return state.cardGroups.expand((g) => g.cards).toList();
  }

  CardGroupType _detectGroupType(List<Card> cards, Card? wildJoker) {
    if (cards.length < 3) return CardGroupType.deadwood;

    final seqRes = SequenceValidator.validate(cards, wildJoker);
    if (seqRes.isValid) {
      return seqRes.type == SequenceType.pure
          ? CardGroupType.pureSequence
          : CardGroupType.impureSequence;
    }

    final setRes = SetValidator.validate(cards, wildJoker);
    if (setRes.isValid) {
      return CardGroupType.set;
    }

    return CardGroupType.deadwood;
  }

  void _revalidateGroups(List<CardGroup> groups, Card? wildJoker) {
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      if (group.cards.length < 3) {
        groups[i] = group.copyWith(
          type: CardGroupType.deadwood,
          isValid: false,
          customLabel: group.customLabel == 'DRAWN' ? 'DRAWN' : (group.customLabel == 'DISCARD' ? 'DISCARD' : null),
          clearCustomLabel: group.customLabel != 'DRAWN' && group.customLabel != 'DISCARD',
        );
        continue;
      }

      final type = _detectGroupType(group.cards, wildJoker);
      final isValid = type != CardGroupType.deadwood;
      groups[i] = group.copyWith(
        type: type,
        isValid: isValid,
        clearCustomLabel: true,
      );
    }
  }

  int _recalculateScore(List<CardGroup> groups, Card? wildJoker) {
    return Scoring.calculateHandDeadwood(
      groups: groups.map((g) => g.cards).toList(),
      wildJoker: wildJoker,
      maxPenalty: 80,
    );
  }

  void _cleanupEmptyGroups(List<CardGroup> groups) {
    groups.removeWhere((g) => g.isEmpty);
    if (groups.isEmpty) {
      groups.add(CardGroup(
        id: 'grp_${_groupIdCounter++}',
        type: CardGroupType.deadwood,
        cards: [],
        isValid: false,
      ));
    }
  }

  void _clearDrawnTags(List<CardGroup> groups) {
    for (var i = 0; i < groups.length; i++) {
      if (groups[i].customLabel == 'DRAWN') {
        groups[i] = groups[i].copyWith(clearCustomLabel: true);
      }
    }
  }

  List<CardGroup> _removeCardFromGroups(List<CardGroup> groups, Card card) {
    final result = <CardGroup>[];
    bool removed = false;
    for (final g in groups) {
      final cards = List<Card>.from(g.cards);
      if (!removed) {
        int idx = cards.indexWhere((c) => c.cardId == card.cardId || c.toInt() == card.toInt() || c == card);
        if (idx < 0) {
          idx = cards.indexWhere((c) =>
              c.isPrintedJoker == card.isPrintedJoker &&
              (c.isPrintedJoker || (c.suit == card.suit && c.rank == card.rank)));
        }
        if (idx >= 0) {
          cards.removeAt(idx);
          removed = true;
        }
      }
      if (cards.isNotEmpty) {
        result.add(g.copyWith(cards: cards));
      }
    }
    return result;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final multiplayerGameProvider = StateNotifierProvider<MultiplayerGameNotifier, MultiplayerGameTableState>((ref) {
  return MultiplayerGameNotifier(ref.watch(multiplayerServiceProvider), ref);
});
