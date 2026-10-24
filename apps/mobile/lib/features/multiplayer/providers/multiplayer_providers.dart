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

  void _persistGroups(String gameId, String uid, List<CardGroup> groups) {
    try {
      final jsonList = groups.map((g) => g.toJson()).toList();
      _storage.setString('saved_groups_${gameId}_$uid', jsonEncode(jsonList));
      _storage.setBool('dealt_${gameId}_$uid', true);
    } catch (e) {
      debugPrint('[MultiplayerNotifier] Persisting groups error: $e');
    }
  }

  List<CardGroup>? _loadSavedGroups(String gameId, String uid) {
    try {
      final raw = _storage.getString('saved_groups_${gameId}_$uid');
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
        _storage.setString('saved_groups_${gameId}_${user.uid}', '');
        _storage.setBool('dealt_${gameId}_${user.uid}', false);
        _hasTriggeredInitialDeal = false;
        groups = [];
      }

      final effectiveJoker = g.effectiveJokerForPlayer(user.uid);

      // Section 7: Authoritative Hand State Synchronization (localHand = serverHand)
      // When 13 cards first arrive on initial deal or on page reload / tab shift:
      if (groups.isEmpty && g.myHand.isNotEmpty) {
        final saved = isNewRound ? null : _loadSavedGroups(gameId, user.uid);
        if (saved != null && saved.isNotEmpty) {
          _hasTriggeredInitialDeal = true;
          _storage.setBool('dealt_${gameId}_${user.uid}', true);
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
          final alreadyDealt = _storage.getBool('dealt_${gameId}_${user.uid}') ?? false;
          if (!_hasTriggeredInitialDeal && !alreadyDealt) {
            _hasTriggeredInitialDeal = true;
            _storage.setBool('dealt_${gameId}_${user.uid}', true);
            _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.dealing);
          } else {
            _hasTriggeredInitialDeal = true;
          }
        }
        _persistGroups(gameId, user.uid, groups);
      } else if (groups.isNotEmpty && g.myHand.isNotEmpty) {
        groups = _syncGroupsWithHand(groups, g.myHand, effectiveJoker);
        _persistGroups(gameId, user.uid, groups);
      }

      _revalidateGroups(groups, effectiveJoker);
      final score = _recalculateScore(groups, effectiveJoker);

      state = state.copyWith(
        gameState: g,
        cardGroups: groups,
        currentScore: score,
        hasDrawnThisTurn: g.isDiscardPhase && g.isMyTurn(user.uid),
      );
    });
  }

  // Card selection (matches Maya Bot single-card exclusive selection for clean, deterministic discard)
  void selectCard(Card card) {
    if (state.isHandLocked) return;
    if (state.selectedCard == card) {
      state = state.copyWith(clearSelectedCard: true, selectedCards: const {});
    } else {
      state = state.copyWith(
        selectedCard: card,
        selectedCards: {card},
      );
    }
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

    state = state.copyWith(isSubmitting: true);
    try {
      await _service.openClosedJoker(gameId: game.gameId, myUid: user.uid);
      final updatedOpened = [...game.openedJokerPlayerUids, user.uid];
      final updatedGame = game.copyWith(openedJokerPlayerUids: updatedOpened);
      final updatedGroups = List<CardGroup>.from(state.cardGroups);
      _revalidateGroups(updatedGroups, updatedGame.openJoker);
      final score = _recalculateScore(updatedGroups, updatedGame.openJoker);

      state = state.copyWith(
        gameState: updatedGame,
        cardGroups: updatedGroups,
        currentScore: score,
        isSubmitting: false,
      );
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
      final drawn = await _service.drawFromClosed(gameId: game.gameId, myUid: user.uid);
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
        cardGroups: updatedGroups,
        currentScore: score,
        hasDrawnThisTurn: true,
        isSubmitting: false,
        clearSelectedCard: true,
      );

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
      final drawn = await _service.drawFromOpen(gameId: game.gameId, myUid: user.uid);
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
        cardGroups: updatedGroups,
        currentScore: score,
        hasDrawnThisTurn: true,
        isSubmitting: false,
        clearSelectedCard: true,
      );

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

    // Check Indian Rummy Rule: cannot discard open-drawn card
    if (game.cardDrawnFromOpenThisTurn != null && game.cardDrawnFromOpenThisTurn == cardToDiscard) {
      state = state.copyWith(
        statusMessage: 'Indian Rummy Rule: You cannot discard the card drawn from the open pile in the same turn!',
      );
      return;
    }

    state = state.copyWith(isSubmitting: true, clearStatusMessage: true);
    try {
      await _service.discardCard(
        gameId: game.gameId,
        myUid: user.uid,
        card: cardToDiscard,
      );

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
    } catch (e) {
      state = state.copyWith(isSubmitting: false, statusMessage: e.toString());
    }
  }

  // Drop Hand / Round
  Future<void> dropGame() async {
    final user = _ref.read(authProvider);
    final game = state.gameState;
    if (user == null || game == null) return;
    if (!game.isMyTurn(user.uid) || !game.isDrawPhase || game.isDeclaring) return;

    state = state.copyWith(isSubmitting: true, isHandLocked: true);
    try {
      await _service.dropGame(gameId: game.gameId, myUid: user.uid);
      state = state.copyWith(
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
  Future<Map<String, dynamic>?> declareHand() async {
    final allCards = _allCards();
    if (allCards.length < 13) {
      state = state.copyWith(statusMessage: 'Invalid card count: you only have ${allCards.length} cards.');
      return null;
    }

    Card discardCard;
    List<CardGroup> remainingGroups;

    if (allCards.length >= 14) {
      if (state.selectedCard == null) {
        state = state.copyWith(statusMessage: 'Please select exactly 1 card to discard for your declaration.');
        return null;
      }
      discardCard = state.selectedCard!;
      remainingGroups = _removeCardFromGroups(state.cardGroups, discardCard);
    } else {
      discardCard = state.selectedCard ?? allCards.last;
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

    state = state.copyWith(isSubmitting: true, isHandLocked: true);
    try {
      final res = await _service.declareGame(
        gameId: game.gameId,
        myUid: user.uid,
        discardCard: discardCard,
        groups: groupCards,
      );
      state = state.copyWith(isSubmitting: false, isHandLocked: false, statusMessage: res['message']);
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
      state = state.copyWith(
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
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    cards.insert(adjustedNew.clamp(0, cards.length), card);
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

  Future<void> recordHeartbeat() async {
    final game = state.gameState;
    final user = _ref.read(authProvider);
    if (game == null || user == null) return;
    await _service.recordPlayerHeartbeat(gameId: game.gameId, uid: user.uid);
  }

  Future<void> markDisconnected() async {
    final game = state.gameState;
    final user = _ref.read(authProvider);
    if (game == null || user == null) return;
    await _service.markPlayerDisconnected(gameId: game.gameId, uid: user.uid);
  }

  Future<void> checkDisconnections() async {
    final game = state.gameState;
    if (game == null || game.isCompleted) return;
    await _service.checkDisconnections(game.gameId);
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

  void groupSelectedCards(List<Card> cardsToGroup) {
    if (cardsToGroup.isEmpty) return;
    final currentCards = _allCards();
    final validCardsToGroup = <Card>[];
    for (final c in cardsToGroup) {
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

    // Newly drawn cards that arrived from server are appended as a separate group
    for (final missingCard in serverCardsRemaining) {
      updatedGroups.add(CardGroup(
        id: 'grp_${_groupIdCounter++}',
        type: CardGroupType.deadwood,
        cards: [missingCard],
        isValid: false,
        customLabel: 'DRAWN',
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
