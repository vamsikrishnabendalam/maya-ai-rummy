import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:ai_engine/ai_engine.dart' hide CardGroup;
import '../models/card_group.dart';
import '../models/game_settings.dart';
import '../models/round_score.dart';
import '../services/spectator_sync_service.dart';
import 'game_ui_provider.dart';

/// Combined game + hand organization + UI selection + scorecard state.
class GameTableState {
  final GameState gameState;
  final List<CardGroup> cardGroups;
  final bool hasDrawnThisTurn;
  final Card? selectedCard;
  final int currentScore;
  final HandPartitionResult? declarationResult;
  final bool isHandLocked;
  final GameSettings gameSettings;
  final List<RoundScore> roundScores;
  final bool isRoundOver;
  final bool isAwaitingHumanDeclarationShow;
  final HandPartitionResult? botDeclarationResult;
  final Card? botDiscardCard;
  final AILevel aiLevel;
  final String dealerId; // 'ai_bot_1' or 'human_player'
  final bool hasHumanOpenedJoker;
  final bool hasBotOpenedJoker;

  const GameTableState({
    required this.gameState,
    required this.cardGroups,
    this.hasDrawnThisTurn = false,
    this.selectedCard,
    this.currentScore = 0,
    this.declarationResult,
    this.isHandLocked = false,
    this.gameSettings = const GameSettings(),
    this.roundScores = const [],
    this.isRoundOver = false,
    this.isAwaitingHumanDeclarationShow = false,
    this.botDeclarationResult,
    this.botDiscardCard,
    this.aiLevel = AILevel.intermediate,
    this.dealerId = 'ai_bot_1',
    this.hasHumanOpenedJoker = true,
    this.hasBotOpenedJoker = true,
  });

  int get totalHumanScore => roundScores.fold(0, (sum, r) => sum + r.humanScore);
  int get totalAiScore => roundScores.fold(0, (sum, r) => sum + r.aiScore);
  int get currentRoundNumber => roundScores.length + 1;
  bool get isHumanEliminated => totalHumanScore >= gameSettings.eliminationScore;
  bool get isAiEliminated => totalAiScore >= gameSettings.eliminationScore;
  bool get isHumanDealer => dealerId == 'human_player';
  bool get isAiDealer => dealerId == 'ai_bot_1';
  String get dealerName => isHumanDealer ? 'Human Player' : 'Maya Bot';

  String get aiDifficultyLabel {
    switch (aiLevel) {
      case AILevel.beginner:
        return 'Easy';
      case AILevel.advanced:
      case AILevel.expert:
        return 'Hard';
      case AILevel.intermediate:
        return 'Medium';
    }
  }

  GameTableState copyWith({
    GameState? gameState,
    List<CardGroup>? cardGroups,
    bool? hasDrawnThisTurn,
    Card? selectedCard,
    bool clearSelectedCard = false,
    int? currentScore,
    HandPartitionResult? declarationResult,
    bool? isHandLocked,
    GameSettings? gameSettings,
    List<RoundScore>? roundScores,
    bool? isRoundOver,
    bool? isAwaitingHumanDeclarationShow,
    HandPartitionResult? botDeclarationResult,
    Card? botDiscardCard,
    AILevel? aiLevel,
    String? dealerId,
    bool? hasHumanOpenedJoker,
    bool? hasBotOpenedJoker,
  }) {
    return GameTableState(
      gameState: gameState ?? this.gameState,
      cardGroups: cardGroups ?? this.cardGroups,
      hasDrawnThisTurn: hasDrawnThisTurn ?? this.hasDrawnThisTurn,
      selectedCard: clearSelectedCard ? null : (selectedCard ?? this.selectedCard),
      currentScore: currentScore ?? this.currentScore,
      declarationResult: declarationResult ?? this.declarationResult,
      isHandLocked: isHandLocked ?? this.isHandLocked,
      gameSettings: gameSettings ?? this.gameSettings,
      roundScores: roundScores ?? this.roundScores,
      isRoundOver: isRoundOver ?? this.isRoundOver,
      isAwaitingHumanDeclarationShow:
          isAwaitingHumanDeclarationShow ?? this.isAwaitingHumanDeclarationShow,
      botDeclarationResult: botDeclarationResult ?? this.botDeclarationResult,
      botDiscardCard: botDiscardCard ?? this.botDiscardCard,
      aiLevel: aiLevel ?? this.aiLevel,
      dealerId: dealerId ?? this.dealerId,
      hasHumanOpenedJoker: hasHumanOpenedJoker ?? this.hasHumanOpenedJoker,
      hasBotOpenedJoker: hasBotOpenedJoker ?? this.hasBotOpenedJoker,
    );
  }
}

/// Main game state notifier — manages engine state, card grouping, selection, discard, declaration, settings, and scorecards.
class GameTableNotifier extends StateNotifier<GameTableState> {
  late GameEngine _engine;
  final Ref _ref;
  int _groupIdCounter = 0;
  final BotStrategyEngine _botStrategy = BotStrategyEngine();
  OpponentThreatTracker _opponentThreatTracker = OpponentThreatTracker();

  GameTableNotifier(this._ref)
      : super(GameTableState(
          gameState: GameState(
            gameId: '',
            players: [],
            openPile: [],
            closedDeck: [],
            wildJoker: null,
            currentPlayerIndex: 0,
            phase: GamePhase.WAITING,
          ),
          cardGroups: [],
        )) {
    Future.microtask(() {
      startNewGame();
    });
  }

  // --------------- Getters ---------------

  String get currentPlayerId {
    if (state.gameState.players.isEmpty) return 'human_player';
    return state.gameState.players[state.gameState.currentPlayerIndex].id;
  }

  bool get isHumanTurn => currentPlayerId == 'human_player';

  bool get isDrawPhase => state.gameState.phase == GamePhase.DRAW_PHASE;

  bool get isDiscardPhase => state.gameState.phase == GamePhase.DISCARD_PHASE;

  bool get isGameComplete => state.gameState.phase == GamePhase.COMPLETE || state.isRoundOver;

  bool get canDiscard =>
      isHumanTurn &&
      isDiscardPhase &&
      state.selectedCard != null &&
      !state.isRoundOver &&
      !state.isAwaitingHumanDeclarationShow &&
      (state.gameState.cardDrawnFromOpenThisTurn == null ||
          state.selectedCard != state.gameState.cardDrawnFromOpenThisTurn);

  bool get canDiscardAndDeclare =>
      isHumanTurn &&
      isDiscardPhase &&
      state.selectedCard != null &&
      !state.isRoundOver &&
      !state.isAwaitingHumanDeclarationShow;

  Player get humanPlayer {
    return state.gameState.players.firstWhere(
      (p) => p.id == 'human_player',
      orElse: () => Player(id: 'human_player', hand: []),
    );
  }

  Player get aiPlayer {
    return state.gameState.players.firstWhere(
      (p) => p.id == 'ai_bot_1',
      orElse: () => Player(id: 'ai_bot_1', hand: []),
    );
  }

  Card get wildJokerCard {
    return state.gameState.wildJoker ??
        Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0);
  }

  Card? get effectiveHumanWildJoker =>
      (state.gameSettings.jokerMode == 'OPEN' || state.hasHumanOpenedJoker)
          ? state.gameState.wildJoker
          : null;

  Card? get effectiveBotWildJoker =>
      (state.gameSettings.jokerMode == 'OPEN' || state.hasBotOpenedJoker)
          ? state.gameState.wildJoker
          : null;

  bool get hasHumanLife => SequenceValidator.hasPureSequenceInHand(humanPlayer.hand);

  bool get hasHumanSecondLife {
    final pureCount = state.cardGroups.where((g) => g.type == CardGroupType.pureSequence).length;
    final impureCount = state.cardGroups.where((g) => g.type == CardGroupType.impureSequence).length;
    return pureCount >= 1 && (pureCount + impureCount) >= 2;
  }

  bool get canHumanOpenJoker =>
      state.gameSettings.isClosedJoker && !state.hasHumanOpenedJoker && hasHumanLife;

  void openClosedJoker() {
    if (!state.gameSettings.isClosedJoker || state.hasHumanOpenedJoker) return;
    if (!hasHumanLife) return;
    state = state.copyWith(hasHumanOpenedJoker: true);
    _revalidateGroups(state.cardGroups);
    final score = _recalculateScore(state.cardGroups);
    state = state.copyWith(currentScore: score);
    _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.grouped);
  }

  void setJokerMode(String mode) {
    final newSettings = state.gameSettings.copyWith(jokerMode: mode);
    final bool isOpen = mode == 'OPEN';
    state = state.copyWith(
      gameSettings: newSettings,
      hasHumanOpenedJoker: isOpen,
      hasBotOpenedJoker: isOpen,
    );
    final newScore = Scoring.calculateHandDeadwood(
      groups: state.cardGroups.map((g) => g.cards).toList(),
      wildJoker: isOpen ? state.gameState.wildJoker : null,
      maxPenalty: newSettings.fullCountPenalty,
    );
    state = state.copyWith(currentScore: newScore);
  }

  /// Whether the remaining 13 cards (after discarding selectedCard) form a valid declaration
  bool get remainingCardsFormValidDeclaration {
    if (state.selectedCard == null || !isDiscardPhase) return false;
    final cardToDiscard = state.selectedCard!;
    final remainingGroups = _removeCardFromGroups(state.cardGroups, cardToDiscard);
    final declaredCards = remainingGroups.map((g) => g.cards).toList();
    final validator = DeclarationValidator();
    final result = validator.validate(declaredCards, effectiveHumanWildJoker);
    return result.isValid;
  }

  // --------------- Card Selection ---------------

  void selectCard(Card card) {
    if (state.isHandLocked || state.isRoundOver) return;

    if (state.selectedCard == card) {
      state = state.copyWith(clearSelectedCard: true);
    } else {
      state = state.copyWith(selectedCard: card);
    }
  }

  void deselectCard() {
    state = state.copyWith(clearSelectedCard: true);
  }

  // --------------- Game Setup & Actions ---------------

  void startNewGame() {
    _engine = GameEngine();
    _groupIdCounter = 0;
    _opponentThreatTracker = OpponentThreatTracker();
    final config = GameConfig(
      gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
      mode: GameMode.POOL_201,
      maxPlayers: 2,
      deckCount: 1, // 2 players: 1 deck = 54 cards (52 suited + 2 jokers)
      firstDropPenalty: state.gameSettings.firstDropPenalty,
      middleDropPenalty: state.gameSettings.middleDropPenalty,
      fullCountPenalty: state.gameSettings.fullCountPenalty,
      eliminationScore: state.gameSettings.eliminationScore,
    );

    int seed = DateTime.now().millisecondsSinceEpoch;
    var initialState = _engine.createGame(config, seed);

    final humanHand = initialState.players[0].hand;
    final botHand = initialState.players[1].hand;

    final players = [
      Player(id: 'human_player', hand: humanHand),
      Player(id: 'ai_bot_1', hand: botHand),
    ];

    final newGameState = initialState.copyWith(
      players: players,
      currentPlayerIndex: 0,
      phase: GamePhase.DRAW_PHASE,
    );

    final initialGroups = [
      CardGroup(
        id: _nextGroupId(),
        type: CardGroupType.deadwood,
        cards: List.from(humanHand),
        isValid: false,
      ),
    ];

    final bool isOpen = state.gameSettings.jokerMode == 'OPEN';
    final initialScore = Scoring.calculateHandDeadwood(
      groups: [humanHand],
      wildJoker: isOpen ? newGameState.wildJoker : null,
      maxPenalty: state.gameSettings.fullCountPenalty,
    );

    state = GameTableState(
      gameState: newGameState,
      cardGroups: initialGroups,
      hasDrawnThisTurn: false,
      currentScore: initialScore,
      isHandLocked: false,
      gameSettings: state.gameSettings,
      roundScores: state.roundScores,
      isRoundOver: false,
      dealerId: 'ai_bot_1',
      hasHumanOpenedJoker: isOpen,
      hasBotOpenedJoker: isOpen,
    );

    _ref.read(gameUIProvider.notifier).resetUI();
    _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.dealing);

    SpectatorSyncService.syncState(
      gameState: newGameState,
      humanGroups: initialGroups,
      wildJoker: newGameState.wildJoker,
      gameSettings: state.gameSettings,
      roundScores: state.roundScores,
      isRoundOver: false,
      dealerId: 'ai_bot_1',
      event: {
        'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'DEAL',
        'actor': 'Dealer (Maya Bot)',
        'title': 'Tournament Started — Deal 1 Dealt',
        'details': 'Deal 1 dealt. Maya Bot is Dealer. Human Player gets first turn to pick the first open card or draw closed deck.',
        'telemetry': {
          'roundNumber': 1,
          'dealer': 'Maya Bot',
          'firstTurn': 'Human Player',
          'wildJoker': newGameState.wildJoker.toString(),
          'firstOpenCard': newGameState.openPile.isNotEmpty ? newGameState.openPile.first.toString() : 'None',
        },
      },
    );
  }

  void startNextRound() {
    _groupIdCounter = 0;
    _opponentThreatTracker = OpponentThreatTracker();
    final config = GameConfig(
      gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
      mode: GameMode.POOL_201,
      maxPlayers: 2,
      deckCount: 1, // 2 players: 1 deck = 54 cards (52 suited + 2 jokers)
      firstDropPenalty: state.gameSettings.firstDropPenalty,
      middleDropPenalty: state.gameSettings.middleDropPenalty,
      fullCountPenalty: state.gameSettings.fullCountPenalty,
      eliminationScore: state.gameSettings.eliminationScore,
    );

    int seed = DateTime.now().millisecondsSinceEpoch;
    var initialState = _engine.createGame(config, seed);

    final humanHand = initialState.players[0].hand;
    final botHand = initialState.players[1].hand;

    final players = [
      Player(id: 'human_player', hand: humanHand),
      Player(id: 'ai_bot_1', hand: botHand),
    ];

    // In a tournament: dealer changes every game.
    // Round 1 (roundScores.length == 0): Bot was dealer, Human got first turn & open card.
    // Round 2 (roundScores.length == 1): Human is dealer, Bot gets first turn & open card.
    // Round 3 (roundScores.length == 2): Bot is dealer, Human gets first turn & open card.
    // Alternates predictably based on rounds played.
    final nextDealerId = (state.roundScores.length % 2 == 0) ? 'ai_bot_1' : 'human_player';
    final firstPlayerIndex = (nextDealerId == 'ai_bot_1') ? 0 : 1;
    final dealerName = (nextDealerId == 'human_player') ? 'Human Player' : 'Maya Bot';
    final firstPlayerName = (firstPlayerIndex == 0) ? 'Human Player' : 'Maya Bot';

    final newGameState = initialState.copyWith(
      players: players,
      currentPlayerIndex: firstPlayerIndex,
      phase: GamePhase.DRAW_PHASE,
    );

    final initialGroups = [
      CardGroup(
        id: _nextGroupId(),
        type: CardGroupType.deadwood,
        cards: List.from(humanHand),
        isValid: false,
      ),
    ];

    final bool isOpen = state.gameSettings.jokerMode == 'OPEN';
    final initialScore = Scoring.calculateHandDeadwood(
      groups: [humanHand],
      wildJoker: isOpen ? newGameState.wildJoker : null,
      maxPenalty: state.gameSettings.fullCountPenalty,
    );

    state = state.copyWith(
      gameState: newGameState,
      cardGroups: initialGroups,
      hasDrawnThisTurn: false,
      currentScore: initialScore,
      isHandLocked: false,
      declarationResult: null,
      clearSelectedCard: true,
      isRoundOver: false,
      isAwaitingHumanDeclarationShow: false,
      botDeclarationResult: null,
      botDiscardCard: null,
      dealerId: nextDealerId,
      hasHumanOpenedJoker: isOpen,
      hasBotOpenedJoker: isOpen,
    );

    _ref.read(gameUIProvider.notifier).resetUI();
    _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.dealing);

    SpectatorSyncService.syncState(
      gameState: newGameState,
      humanGroups: initialGroups,
      wildJoker: newGameState.wildJoker,
      gameSettings: state.gameSettings,
      roundScores: state.roundScores,
      isRoundOver: false,
      dealerId: nextDealerId,
      event: {
        'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'ROUND_START',
        'actor': 'Dealer ($dealerName)',
        'title': 'Deal ${state.currentRoundNumber} Started — 13 Cards Dealt',
        'details': 'New deal started. Dealer: $dealerName. First turn & open card given to: $firstPlayerName.',
        'telemetry': {
          'roundNumber': state.currentRoundNumber,
          'dealer': dealerName,
          'firstTurn': firstPlayerName,
          'wildJoker': newGameState.wildJoker.toString(),
          'firstOpenCard': newGameState.openPile.isNotEmpty ? newGameState.openPile.first.toString() : 'None',
        },
      },
    );

    // If non-dealer is Maya Bot (firstPlayerIndex == 1), automatically trigger its first turn
    if (firstPlayerIndex == 1) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && !state.isRoundOver) {
          _triggerAITurn();
        }
      });
    }
  }

  void resetTournament() {
    state = state.copyWith(roundScores: []);
    startNewGame();
  }

  void updateSettings(GameSettings newSettings) {
    final bool isHumanRevealed = newSettings.jokerMode == 'OPEN' || state.hasHumanOpenedJoker;
    final newScore = Scoring.calculateHandDeadwood(
      groups: state.cardGroups.map((g) => g.cards).toList(),
      wildJoker: isHumanRevealed ? state.gameState.wildJoker : null,
      maxPenalty: newSettings.fullCountPenalty,
    );
    state = state.copyWith(
      gameSettings: newSettings,
      currentScore: newScore,
      hasHumanOpenedJoker: newSettings.jokerMode == 'OPEN' ? true : state.hasHumanOpenedJoker,
      hasBotOpenedJoker: newSettings.jokerMode == 'OPEN' ? true : state.hasBotOpenedJoker,
    );
  }

  // --------------- Draw Flow (Places drawn card separately at end) ---------------

  void drawFromClosedDeck() {
    if (!isHumanTurn || !isDrawPhase || state.isHandLocked || state.isRoundOver) return;

    final action = DrawFromClosedDeck(
      playerId: 'human_player',
      gameId: state.gameState.gameId,
      sequenceNumber: state.gameState.turnNumber + 1,
      timestamp: DateTime.now(),
    );

    final newGameState = _engine.processAction(state.gameState, action);

    final newHand = newGameState.players
        .firstWhere((p) => p.id == 'human_player')
        .hand;
    final drawnCard = newHand.isNotEmpty ? newHand.last : null;

    final updatedGroups = List<CardGroup>.from(state.cardGroups);
    if (drawnCard != null) {
      // Place newly drawn card in a dedicated separate group at the end!
      updatedGroups.add(CardGroup(
        id: _nextGroupId(),
        type: CardGroupType.deadwood,
        cards: [drawnCard],
        isValid: false,
        customLabel: 'DRAWN',
      ));
    }

    _revalidateGroups(updatedGroups);
    final score = _recalculateScore(updatedGroups);

    state = state.copyWith(
      gameState: newGameState,
      cardGroups: updatedGroups,
      hasDrawnThisTurn: true,
      currentScore: score,
      clearSelectedCard: true,
    );

    _ref
        .read(gameUIProvider.notifier)
        .triggerAction(GameActionType.drewFromClosed, card: drawnCard);

    SpectatorSyncService.syncState(
      gameState: newGameState,
      humanGroups: updatedGroups,
      wildJoker: wildJokerCard,
      gameSettings: state.gameSettings,
      roundScores: state.roundScores,
      isRoundOver: false,
      dealerId: state.dealerId,
      event: {
        'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'PLAYER_DRAW_CLOSED',
        'actor': 'Human Player',
        'title': 'Player Drew from Closed Deck',
        'details': 'Drew card ($drawnCard). Placed in DRAWN group.',
        'telemetry': {
          'drawnCard': drawnCard.toString(),
          'closedDeckRemaining': newGameState.closedDeck.length,
        },
      },
    );
  }

  void drawFromOpenDeck() {
    if (!isHumanTurn || !isDrawPhase || state.isHandLocked || state.isRoundOver) return;
    if (state.gameState.openPile.isEmpty) return;

    final drawnCard = state.gameState.openPile.last;

    final action = DrawFromOpenDeck(
      playerId: 'human_player',
      gameId: state.gameState.gameId,
      sequenceNumber: state.gameState.turnNumber + 1,
      timestamp: DateTime.now(),
    );

    final newGameState = _engine.processAction(state.gameState, action);
    _opponentThreatTracker.recordPickFromOpen(drawnCard);

    final updatedGroups = List<CardGroup>.from(state.cardGroups);
    // Place newly drawn card in a dedicated separate group at the end!
    updatedGroups.add(CardGroup(
      id: _nextGroupId(),
      type: CardGroupType.deadwood,
      cards: [drawnCard],
      isValid: false,
      customLabel: 'DRAWN',
    ));

    _revalidateGroups(updatedGroups);
    final score = _recalculateScore(updatedGroups);

    state = state.copyWith(
      gameState: newGameState,
      cardGroups: updatedGroups,
      hasDrawnThisTurn: true,
      currentScore: score,
      clearSelectedCard: true,
    );

    _ref
        .read(gameUIProvider.notifier)
        .triggerAction(GameActionType.drewFromOpen, card: drawnCard);

    SpectatorSyncService.syncState(
      gameState: newGameState,
      humanGroups: updatedGroups,
      wildJoker: wildJokerCard,
      gameSettings: state.gameSettings,
      roundScores: state.roundScores,
      isRoundOver: false,
      dealerId: state.dealerId,
      event: {
        'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'PLAYER_DRAW_OPEN',
        'actor': 'Human Player',
        'title': 'Player Drew from Open Pile ($drawnCard)',
        'details': 'Picked up $drawnCard from top of discard pile.',
        'telemetry': {
          'drawnCard': drawnCard.toString(),
        },
      },
    );
  }

  // --------------- Discard Flow ---------------

  void discardSelectedCard() {
    if (state.selectedCard == null) return;
    discardCard(state.selectedCard!);
  }

  void discardCard(Card card) {
    if (!isHumanTurn || !isDiscardPhase || state.isHandLocked || state.isRoundOver) return;
    if (state.gameState.cardDrawnFromOpenThisTurn != null &&
        state.gameState.cardDrawnFromOpenThisTurn == card) {
      return;
    }

    final action = DiscardCard(
      card,
      playerId: 'human_player',
      gameId: state.gameState.gameId,
      sequenceNumber: state.gameState.turnNumber + 1,
      timestamp: DateTime.now(),
    );

    final newGameState = _engine.processAction(state.gameState, action);
    _opponentThreatTracker.recordDiscard(card);

    final updatedGroups = _removeCardFromGroups(state.cardGroups, card);
    _clearDrawnTags(updatedGroups);
    _revalidateGroups(updatedGroups);
    final score = _recalculateScore(updatedGroups);

    state = state.copyWith(
      gameState: newGameState,
      cardGroups: updatedGroups,
      hasDrawnThisTurn: false,
      currentScore: score,
      clearSelectedCard: true,
    );

    _ref
        .read(gameUIProvider.notifier)
        .triggerAction(GameActionType.discarded, card: card);

    SpectatorSyncService.syncState(
      gameState: newGameState,
      humanGroups: updatedGroups,
      wildJoker: wildJokerCard,
      gameSettings: state.gameSettings,
      roundScores: state.roundScores,
      isRoundOver: false,
      dealerId: state.dealerId,
      event: {
        'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'PLAYER_DISCARD',
        'actor': 'Human Player',
        'title': 'Player Discarded $card',
        'details': 'Discarded $card to open pile. Current hand deadwood: $score pts.',
        'telemetry': {
          'discardedCard': card.toString(),
          'remainingDeadwood': score,
        },
      },
    );

    if (currentPlayerId == 'ai_bot_1' &&
        state.gameState.phase != GamePhase.COMPLETE &&
        !state.isRoundOver) {
      _triggerAITurn();
    }
  }

  // --------------- Discard & Declare Flow ---------------

  HandPartitionResult discardAndDeclareSelectedCard() {
    state = state.copyWith(isHandLocked: true);

    Card? cardToDiscard = state.selectedCard;
    List<CardGroup> remainingGroups = state.cardGroups;

    if (cardToDiscard != null) {
      remainingGroups = _removeCardFromGroups(state.cardGroups, cardToDiscard);
    }

    final declaredCards = remainingGroups.map((g) => g.cards).toList();
    final validator = DeclarationValidator();
    final result = validator.validate(declaredCards, effectiveHumanWildJoker);
    final partitionResult = result.partitionResult ??
        HandPartitioner.evaluateGroups(declaredCards, effectiveHumanWildJoker);

    final updatedOpenPile = List<Card>.from(state.gameState.openPile);
    if (cardToDiscard != null) {
      updatedOpenPile.add(cardToDiscard);
    }

    final humanHand = remainingGroups.expand((g) => g.cards).toList();
    final bool isHumanValid = partitionResult.isValidDeclaration;
    final int humanRoundScore = isHumanValid
        ? 0
        : state.gameSettings.fullCountPenalty;

    final aiHand = aiPlayer.hand;
    // Optimally partition AI hand using HandPartitioner to find minimum count with best joker arrangement
    final aiOptimalPartition = HandPartitioner.findBestPartition(
      aiHand,
      effectiveBotWildJoker,
    );
    // On opponent wrong show, the winner gets 0 points!
    final int aiRoundScore = isHumanValid
        ? aiOptimalPartition.penaltyScore
        : 0;

    final newHumanPlayer = Player(
      id: 'human_player',
      hand: humanHand,
      score: humanRoundScore,
      status: isHumanValid ? PlayerStatus.DECLARED : PlayerStatus.ACTIVE,
    );
    final newAiPlayer = Player(
      id: 'ai_bot_1',
      hand: aiHand,
      score: aiRoundScore,
      status: PlayerStatus.ACTIVE,
    );

    final updatedGameState = state.gameState.copyWith(
      openPile: updatedOpenPile,
      phase: GamePhase.COMPLETE,
      players: [newHumanPlayer, newAiPlayer],
    );

    final newRoundScore = RoundScore(
      roundNumber: state.currentRoundNumber,
      humanScore: humanRoundScore,
      aiScore: aiRoundScore,
      cumulativeHumanScore: state.totalHumanScore + humanRoundScore,
      cumulativeAiScore: state.totalAiScore + aiRoundScore,
      humanOutcome: isHumanValid
          ? 'Declared (0 pts)'
          : 'Wrong Show (${state.gameSettings.fullCountPenalty} pts)',
      aiOutcome: isHumanValid
          ? 'Lost ($aiRoundScore pts)'
          : 'Won by Default (0 pts)',
      timestamp: DateTime.now(),
    );

    final newRoundScores = List<RoundScore>.from(state.roundScores)..add(newRoundScore);

    state = state.copyWith(
      gameState: updatedGameState,
      cardGroups: remainingGroups,
      clearSelectedCard: true,
      currentScore: humanRoundScore,
      declarationResult: partitionResult,
      isHandLocked: false,
      roundScores: newRoundScores,
      isRoundOver: true,
    );

    // Final cards & count breakdown for logs and telemetry
    final humanHandGroups = remainingGroups.map((g) {
      final grpScore = Scoring.calculateHandDeadwood(groups: [g.cards], wildJoker: wildJokerCard);
      return {
        'label': g.label,
        'cards': g.cards.map((c) => c.toString()).join(' '),
        'count': g.cards.length,
        'deadwood': grpScore,
      };
    }).toList();

    final botHandGroups = aiOptimalPartition.groups.map((g) {
      final grpScore = Scoring.calculateHandDeadwood(groups: [g.cards], wildJoker: wildJokerCard);
      return {
        'label': g.label,
        'cards': g.cards.map((c) => c.toString()).join(' '),
        'count': g.cards.length,
        'deadwood': grpScore,
      };
    }).toList();

    final String humanSummaryStr = remainingGroups.map((g) => '${g.label}: [${g.cards.join(" ")}]').join(' | ');
    final String botSummaryStr = aiOptimalPartition.groups.map((g) => '${g.label}: [${g.cards.join(" ")}]').join(' | ');

    final String eventDetails = isHumanValid
        ? 'Valid declaration verified (${partitionResult.pureSequenceCount} pure seq, ${partitionResult.totalSequenceCount} total seq).\n'
          'Final Cards & Counts upon Declaration:\n'
          '• Human (Winner: 0 pts): $humanSummaryStr\n'
          '• Maya Bot (Rearranged to least count: $aiRoundScore pts): $botSummaryStr'
        : 'Invalid declaration (Wrong Show): ${partitionResult.errorMessage}. Human penalized ${state.gameSettings.fullCountPenalty} pts.\n'
          'Final Cards & Counts upon Declaration:\n'
          '• Human (Wrong Show: ${state.gameSettings.fullCountPenalty} pts): $humanSummaryStr\n'
          '• Maya Bot (Winner by Default: 0 pts): $botSummaryStr';

    SpectatorSyncService.syncState(
      gameState: updatedGameState,
      humanGroups: remainingGroups,
      wildJoker: wildJokerCard,
      gameSettings: state.gameSettings,
      roundScores: newRoundScores,
      isRoundOver: true,
      dealerId: state.dealerId,
      event: {
        'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'HUMAN_DECLARATION',
        'actor': 'Human Player',
        'title': isHumanValid
            ? 'Player Declared Valid Show (0 pts)!'
            : 'Player Invalid Declaration / Wrong Show (${state.gameSettings.fullCountPenalty} pts)!',
        'details': eventDetails,
        'telemetry': {
          'isValid': isHumanValid,
          'winner': isHumanValid ? 'Human Player' : 'Maya AI Bot',
          'pureSeqCount': partitionResult.pureSequenceCount,
          'totalSeqCount': partitionResult.totalSequenceCount,
          'humanScore': humanRoundScore,
          'aiScore': aiRoundScore,
          'humanTotalCards': humanHand.length,
          'botTotalCards': aiHand.length,
          'humanFinalCards': humanHandGroups,
          'botFinalCards': botHandGroups,
        },
      },
    );

    return partitionResult;
  }

  // --------------- Drop Hand Flow ---------------

  void dropCurrentHand() {
    if (!isHumanTurn || state.isRoundOver) return;

    final isFirstDrop = state.gameState.turnNumber <= 1 && !state.hasDrawnThisTurn;
    final int dropPenalty = isFirstDrop
        ? state.gameSettings.firstDropPenalty
        : state.gameSettings.middleDropPenalty;

    final updatedPlayers = [
      Player(
        id: 'human_player',
        hand: humanPlayer.hand,
        score: dropPenalty,
        status: PlayerStatus.DROPPED,
      ),
      Player(
        id: 'ai_bot_1',
        hand: aiPlayer.hand,
        score: 0,
        status: PlayerStatus.ACTIVE,
      ),
    ];

    final updatedGameState = state.gameState.copyWith(
      phase: GamePhase.COMPLETE,
      players: updatedPlayers,
    );

    final newRoundScore = RoundScore(
      roundNumber: state.currentRoundNumber,
      humanScore: dropPenalty,
      aiScore: 0,
      cumulativeHumanScore: state.totalHumanScore + dropPenalty,
      cumulativeAiScore: state.totalAiScore,
      humanOutcome: isFirstDrop
          ? 'First Drop ($dropPenalty pts)'
          : 'Middle Drop ($dropPenalty pts)',
      aiOutcome: 'Opponent Dropped (0 pts)',
      timestamp: DateTime.now(),
    );

    final newRoundScores = List<RoundScore>.from(state.roundScores)..add(newRoundScore);

    state = state.copyWith(
      gameState: updatedGameState,
      currentScore: dropPenalty,
      roundScores: newRoundScores,
      isRoundOver: true,
      clearSelectedCard: true,
    );

    SpectatorSyncService.syncState(
      gameState: updatedGameState,
      humanGroups: state.cardGroups,
      wildJoker: wildJokerCard,
      gameSettings: state.gameSettings,
      roundScores: newRoundScores,
      isRoundOver: true,
      dealerId: state.dealerId,
      event: {
        'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'HUMAN_DROP',
        'actor': 'Human Player',
        'title': isFirstDrop
            ? 'Player First Drop ($dropPenalty pts)'
            : 'Player Middle Drop ($dropPenalty pts)',
        'details': 'Player dropped hand without declaring. Round ended.',
        'telemetry': {
          'dropType': isFirstDrop ? 'FIRST_DROP' : 'MIDDLE_DROP',
          'dropPenalty': dropPenalty,
        },
      },
    );
  }

  // --------------- Card Group Management ---------------

  void moveCardBetweenGroups(
      Card card, String fromGroupId, String toGroupId, int insertIndex) {
    if (state.isHandLocked || state.isRoundOver) return;
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
    _revalidateGroups(groups);
    final score = _recalculateScore(groups);

    state = state.copyWith(cardGroups: groups, currentScore: score);
  }

  void moveCardWithinGroup(String groupId, int oldIndex, int newIndex) {
    if (state.isHandLocked || state.isRoundOver) return;
    final groups = List<CardGroup>.from(state.cardGroups);
    final idx = groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;

    final cards = List<Card>.from(groups[idx].cards);
    if (oldIndex < 0 || oldIndex >= cards.length) return;

    final card = cards.removeAt(oldIndex);
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    cards.insert(adjustedNew.clamp(0, cards.length), card);
    groups[idx] = groups[idx].copyWith(cards: cards);

    _revalidateGroups(groups);
    final score = _recalculateScore(groups);

    state = state.copyWith(cardGroups: groups, currentScore: score);
  }

  void addNewGroup() {
    if (state.isHandLocked || state.isRoundOver) return;
    final groups = List<CardGroup>.from(state.cardGroups);
    groups.add(CardGroup(
      id: _nextGroupId(),
      type: CardGroupType.deadwood,
      cards: [],
      isValid: false,
    ));
    state = state.copyWith(cardGroups: groups);
  }

  void moveCardToNewGroup(Card card, String fromGroupId) {
    if (state.isHandLocked || state.isRoundOver) return;
    final groups = List<CardGroup>.from(state.cardGroups);
    final fromIdx = groups.indexWhere((g) => g.id == fromGroupId);
    if (fromIdx >= 0) {
      final fromCards = List<Card>.from(groups[fromIdx].cards);
      fromCards.remove(card);
      groups[fromIdx] = groups[fromIdx].copyWith(cards: fromCards);
    }
    groups.add(CardGroup(
      id: _nextGroupId(),
      type: CardGroupType.deadwood,
      cards: [card],
      isValid: false,
    ));
    _cleanupEmptyGroups(groups);
    _revalidateGroups(groups);
    final score = _recalculateScore(groups);

    state = state.copyWith(cardGroups: groups, currentScore: score);
  }

  void autoSortHand() {
    if (state.isHandLocked || state.isRoundOver) return;
    final allCards = _allGroupedCards();
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
        id: _nextGroupId(),
        type: CardGroupType.deadwood,
        cards: sorted,
        isValid: false,
      ),
    ];

    _revalidateGroups(newGroups);
    final score = _recalculateScore(newGroups);

    state = state.copyWith(cardGroups: newGroups, currentScore: score);
    _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.sorted);
  }

  /// Returns non-cheating probability and meld suggestions for current hand
  List<GroupSuggestion> getGroupSuggestions() {
    return ProbabilityEngine.analyzeHand(
      playerHand: humanPlayer.hand,
      openPile: state.gameState.openPile,
      openJoker: effectiveHumanWildJoker,
      closedDeckCount: state.gameState.closedDeck.length,
    );
  }

  /// Applies recommended grouping to player's hand.
  void applyRecommendedGrouping(List<List<Card>> recommendedGroups) {
    if (state.isHandLocked || state.isRoundOver) return;
    final newGroups = <CardGroup>[];

    for (final groupCards in recommendedGroups) {
      if (groupCards.isEmpty) continue;
      final type = _detectGroupType(groupCards);
      newGroups.add(CardGroup(
        id: _nextGroupId(),
        type: type,
        cards: List.from(groupCards),
        isValid: type != CardGroupType.deadwood,
      ));
    }

    _revalidateGroups(newGroups);
    final score = _recalculateScore(newGroups);

    state = state.copyWith(cardGroups: newGroups, currentScore: score);
    _ref.read(gameUIProvider.notifier).triggerAction(GameActionType.grouped);
  }

  void autoGroupHand() {
    if (state.isHandLocked || state.isRoundOver) return;
    final allCards = _allGroupedCards();
    final partition = HandPartitioner.findBestPartition(allCards, effectiveHumanWildJoker);
    final groupsToApply = partition.groups.map((g) => g.cards).toList();
    applyRecommendedGrouping(groupsToApply);
  }

  void setAILevel(AILevel level) {
    state = state.copyWith(aiLevel: level);
  }

  // --------------- AI Turn ---------------

  void _triggerAITurn() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted || state.isRoundOver) return;

      final aiPlayerState =
          state.gameState.players.firstWhere((p) => p.id == 'ai_bot_1');
      if (state.gameSettings.isClosedJoker && !state.hasBotOpenedJoker) {
        if (SequenceValidator.hasPureSequenceInHand(aiPlayerState.hand)) {
          state = state.copyWith(hasBotOpenedJoker: true);
        }
      }
      final wildJoker = effectiveBotWildJoker;

      final knowledge = BotKnowledgeState(
        ownHand: aiPlayerState.hand,
        openJoker: wildJoker,
        openPile: state.gameState.openPile,
        visibleDiscardHistory: state.gameState.openPile,
        closedDeckRemaining: state.gameState.closedDeck.length,
        turnNumber: state.gameState.turnNumber,
        opponentPicksFromOpen: _opponentThreatTracker.picksFromOpen,
        opponentDiscards: _opponentThreatTracker.discards,
        opponentCardCount: humanPlayer.hand.length,
        humanScore: state.totalHumanScore,
        botScore: state.totalAiScore,
      );

      final aiConfig = AIConfig(
        level: state.aiLevel,
        monteCarloRollouts: state.aiLevel == AILevel.advanced ? 40 : 0,
        mistakeRate: state.aiLevel == AILevel.beginner
            ? 0.25
            : (state.aiLevel == AILevel.intermediate ? 0.10 : 0.02),
        useOpponentModel: state.aiLevel != AILevel.beginner,
        useProbability: state.aiLevel == AILevel.advanced,
        useStrategySwitching: state.aiLevel != AILevel.beginner,
      );
      final drawResult = _botStrategy.decideDraw(knowledge, aiConfig, _opponentThreatTracker);
      final bool chooseOpen = drawResult.choice == DrawChoice.openPile && state.gameState.openPile.isNotEmpty;
      final Card? openCard = state.gameState.openPile.isNotEmpty ? state.gameState.openPile.last : null;

      GameState stateAfterDraw;
      Card? botDrawnCard;

      if (chooseOpen) {
        botDrawnCard = state.gameState.openPile.last;
        stateAfterDraw = _engine.processAction(
          state.gameState,
          DrawFromOpenDeck(
            playerId: 'ai_bot_1',
            gameId: state.gameState.gameId,
            sequenceNumber: state.gameState.turnNumber + 1,
            timestamp: DateTime.now(),
          ),
        );
      } else {
        stateAfterDraw = _engine.processAction(
          state.gameState,
          DrawFromClosedDeck(
            playerId: 'ai_bot_1',
            gameId: state.gameState.gameId,
            sequenceNumber: state.gameState.turnNumber + 1,
            timestamp: DateTime.now(),
          ),
        );
        final newAIHand = stateAfterDraw.players.firstWhere((p) => p.id == 'ai_bot_1').hand;
        botDrawnCard = newAIHand.isNotEmpty ? newAIHand.last : null;
      }

      state = state.copyWith(gameState: stateAfterDraw);
      _ref
          .read(gameUIProvider.notifier)
          .triggerAction(GameActionType.botDrew);

      // Sync bot draw event to Spectator Dashboard
      SpectatorSyncService.syncState(
        gameState: stateAfterDraw,
        humanGroups: state.cardGroups,
        wildJoker: wildJokerCard,
        gameSettings: state.gameSettings,
        roundScores: state.roundScores,
        isRoundOver: false,
        dealerId: state.dealerId,
        event: {
          'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'BOT_DRAW',
          'actor': 'Maya AI Bot',
          'title': chooseOpen ? 'Maya Drew from Open Pile ($openCard)' : 'Maya Drew from Closed Deck',
          'details': drawResult.reasoning,
          'telemetry': {
            'decision': chooseOpen ? 'OPEN_PILE' : 'CLOSED_DECK',
            'utility': drawResult.openCardUtility,
            'currentDeadwood': drawResult.currentDeadwood,
            'hypoDeadwoodWithOpen': drawResult.hypoDeadwoodWithOpen,
            'topOpenCard': openCard?.toString(),
            'botDrawnCard': botDrawnCard?.toString(),
          },
        },
      );

      // Discard decision after 1100ms
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (!mounted || state.isRoundOver) return;

        final handWith14 = state.gameState.players
            .firstWhere((p) => p.id == 'ai_bot_1')
            .hand;

        final discardResult = _botStrategy.decideDiscard(
          handWith14,
          wildJoker,
          aiConfig,
          _opponentThreatTracker,
          state.gameState.turnNumber,
          cardDrawnFromOpenPile: chooseOpen ? botDrawnCard : null,
        );

        final bestDiscardCard = discardResult.bestDiscard;

        // If Maya bot achieved valid declaration, notify and await human card show submission!
        if (discardResult.canDeclare) {
          final rem13 = List<Card>.from(handWith14)..remove(bestDiscardCard);
          final winningPartition = HandPartitioner.findValidPartition(rem13, wildJoker);
          _notifyBotDeclaration(bestDiscardCard, winningPartition);
          return;
        }

        // Otherwise normal discard
        final discardState = _engine.processAction(
          state.gameState,
          DiscardCard(
            bestDiscardCard,
            playerId: 'ai_bot_1',
            gameId: state.gameState.gameId,
            sequenceNumber: state.gameState.turnNumber + 1,
            timestamp: DateTime.now(),
          ),
        );

        state = state.copyWith(
          gameState: discardState,
          hasDrawnThisTurn: false,
        );
        _ref
            .read(gameUIProvider.notifier)
            .triggerAction(GameActionType.botDiscarded, card: bestDiscardCard);

        final topCandidatesTelemetry = discardResult.allCandidates.take(5).map((c) => {
          'card': c.card.toString(),
          'resultingDeadwood': c.resultingDeadwood,
          'isValidDeclaration': c.isValidDeclaration,
          'score': c.totalScore,
          'breaksPure': c.breaksPureSequence,
          'breaksMeld': c.breaksCompletedMeld,
          'opponentDanger': c.opponentDanger,
        }).toList();

        final bestCandidate = discardResult.allCandidates.firstWhere(
          (c) => c.card == bestDiscardCard,
          orElse: () => discardResult.allCandidates.first,
        );

        // Sync bot discard event to Spectator Dashboard
        SpectatorSyncService.syncState(
          gameState: discardState,
          humanGroups: state.cardGroups,
          wildJoker: wildJokerCard,
          gameSettings: state.gameSettings,
          roundScores: state.roundScores,
          isRoundOver: false,
          dealerId: state.dealerId,
          event: {
            'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'BOT_DISCARD',
            'actor': 'Maya AI Bot',
            'title': 'Maya Discarded $bestDiscardCard',
            'details': discardResult.reasoning,
            'telemetry': {
              'discardedCard': bestDiscardCard.toString(),
              'resultingDeadwood': bestCandidate.resultingDeadwood,
              'candidateEvaluations': topCandidatesTelemetry,
            },
          },
        );
      });
    });
  }

  void _notifyBotDeclaration(Card discardCard, HandPartitionResult botPartition) {
    final updatedOpenPile = List<Card>.from(state.gameState.openPile)..add(discardCard);

    final currentAIHand = List<Card>.from(
      state.gameState.players.firstWhere((p) => p.id == 'ai_bot_1').hand,
    )..remove(discardCard);

    final updatedPlayers = [
      Player(
        id: 'human_player',
        hand: humanPlayer.hand,
        score: state.currentScore,
        status: PlayerStatus.ACTIVE,
      ),
      Player(
        id: 'ai_bot_1',
        hand: currentAIHand,
        score: 0,
        status: botPartition.isValidDeclaration ? PlayerStatus.DECLARED : PlayerStatus.ACTIVE,
      ),
    ];

    final updatedGameState = state.gameState.copyWith(
      openPile: updatedOpenPile,
      players: updatedPlayers,
    );

    final currentHumanScore = _recalculateScore(state.cardGroups);

    state = state.copyWith(
      gameState: updatedGameState,
      isAwaitingHumanDeclarationShow: true,
      botDeclarationResult: botPartition,
      botDiscardCard: discardCard,
      currentScore: currentHumanScore,
      isRoundOver: false,
      isHandLocked: false,
      clearSelectedCard: true,
    );

    _ref
        .read(gameUIProvider.notifier)
        .triggerAction(GameActionType.botDiscarded, card: discardCard);

    SpectatorSyncService.syncState(
      gameState: updatedGameState,
      humanGroups: state.cardGroups,
      wildJoker: wildJokerCard,
      gameSettings: state.gameSettings,
      roundScores: state.roundScores,
      isRoundOver: false,
      isAwaitingHumanDeclarationShow: true,
      dealerId: state.dealerId,
      event: {
        'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'BOT_DECLARATION_PENDING_SHOW',
        'actor': 'Maya AI Bot',
        'title': 'Maya Bot Declared Show (Awaiting Human Cards)',
        'details': 'Maya Bot declared with discard $discardCard. Human player can rearrange cards to minimize deadwood score before submission.',
        'telemetry': {
          'discardCard': discardCard.toString(),
          'botPureSeqCount': botPartition.pureSequenceCount,
          'botTotalSeqCount': botPartition.totalSequenceCount,
        },
      },
    );
  }

  /// Called when the human player finishes rearranging their cards and submits their show
  /// in response to Maya Bot's declaration.
  void submitHumanDeclarationShow() {
    if (!state.isAwaitingHumanDeclarationShow) return;

    final botPartition = state.botDeclarationResult;
    final discardCard = state.botDiscardCard;
    if (botPartition == null || discardCard == null) return;

    final bool isBotValid = botPartition.isValidDeclaration;
    final int botScore = isBotValid ? 0 : state.gameSettings.fullCountPenalty;

    // Calculate human deadwood penalty from player's final rearranged groups
    final int humanScore = isBotValid
        ? Scoring.calculateHandDeadwood(
            groups: state.cardGroups.map((g) => g.cards).toList(),
            wildJoker: effectiveHumanWildJoker,
            maxPenalty: state.gameSettings.fullCountPenalty,
          )
        : 0;

    final currentAIHand = List<Card>.from(
      state.gameState.players.firstWhere((p) => p.id == 'ai_bot_1').hand,
    );

    final updatedPlayers = [
      Player(
        id: 'human_player',
        hand: humanPlayer.hand,
        score: humanScore,
        status: PlayerStatus.ACTIVE,
      ),
      Player(
        id: 'ai_bot_1',
        hand: currentAIHand,
        score: botScore,
        status: isBotValid ? PlayerStatus.DECLARED : PlayerStatus.ACTIVE,
      ),
    ];

    final updatedGameState = state.gameState.copyWith(
      phase: GamePhase.COMPLETE,
      players: updatedPlayers,
    );

    final newRoundScore = RoundScore(
      roundNumber: state.currentRoundNumber,
      humanScore: humanScore,
      aiScore: botScore,
      cumulativeHumanScore: state.totalHumanScore + humanScore,
      cumulativeAiScore: state.totalAiScore + botScore,
      humanOutcome: isBotValid
          ? 'Lost ($humanScore pts)'
          : 'Won by Default (0 pts)',
      aiOutcome: isBotValid
          ? 'Declared (0 pts)'
          : 'Wrong Show (${state.gameSettings.fullCountPenalty} pts)',
      timestamp: DateTime.now(),
    );

    final newRoundScores = List<RoundScore>.from(state.roundScores)..add(newRoundScore);

    state = state.copyWith(
      gameState: updatedGameState,
      roundScores: newRoundScores,
      isRoundOver: true,
      currentScore: humanScore,
      isAwaitingHumanDeclarationShow: false,
      botDeclarationResult: null,
      botDiscardCard: null,
      isHandLocked: true,
    );

    final humanHandGroups = state.cardGroups.map((g) {
      final grpScore = Scoring.calculateHandDeadwood(groups: [g.cards], wildJoker: wildJokerCard);
      return {
        'label': g.label,
        'cards': g.cards.map((c) => c.toString()).join(' '),
        'count': g.cards.length,
        'deadwood': grpScore,
      };
    }).toList();

    final botHandGroups = botPartition.groups.map((g) {
      final grpScore = Scoring.calculateHandDeadwood(groups: [g.cards], wildJoker: wildJokerCard);
      return {
        'label': g.label,
        'cards': g.cards.map((c) => c.toString()).join(' '),
        'count': g.cards.length,
        'deadwood': grpScore,
      };
    }).toList();

    final String humanSummaryStr = state.cardGroups.map((g) => '${g.label}: [${g.cards.join(" ")}]').join(' | ');
    final String botSummaryStr = botPartition.groups.map((g) => '${g.label}: [${g.cards.join(" ")}]').join(' | ');

    final String eventDetails = isBotValid
        ? 'Maya Bot declared valid show (${botPartition.pureSequenceCount} pure seq, ${botPartition.totalSequenceCount} total seq).\n'
          'Final Cards & Counts upon Declaration:\n'
          '• Maya Bot (Winner: 0 pts): $botSummaryStr\n'
          '• Human Player (Rearranged Count: $humanScore pts): $humanSummaryStr'
        : 'Maya Bot Wrong Show (${state.gameSettings.fullCountPenalty} pts). Human wins round with 0 pts.\n'
          'Final Cards & Counts upon Declaration:\n'
          '• Maya Bot (Wrong Show: ${state.gameSettings.fullCountPenalty} pts): $botSummaryStr\n'
          '• Human Player (Winner by Default: 0 pts): $humanSummaryStr';

    SpectatorSyncService.syncState(
      gameState: updatedGameState,
      humanGroups: state.cardGroups,
      wildJoker: wildJokerCard,
      gameSettings: state.gameSettings,
      roundScores: newRoundScores,
      isRoundOver: true,
      dealerId: state.dealerId,
      event: {
        'id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'BOT_DECLARATION',
        'actor': 'Maya AI Bot',
        'title': isBotValid
            ? 'Maya Bot Declared Valid Show (0 pts)!'
            : 'Maya Bot Wrong Show (${state.gameSettings.fullCountPenalty} pts)!',
        'details': eventDetails,
        'telemetry': {
          'isValid': isBotValid,
          'winner': isBotValid ? 'Maya AI Bot' : 'Human Player',
          'pureSeqCount': botPartition.pureSequenceCount,
          'totalSeqCount': botPartition.totalSequenceCount,
          'humanScore': humanScore,
          'botScore': botScore,
          'humanTotalCards': humanPlayer.hand.length,
          'botTotalCards': currentAIHand.length,
          'humanFinalCards': humanHandGroups,
          'botFinalCards': botHandGroups,
        },
      },
    );
  }

  List<Card> allGroupedCards() => _allGroupedCards();

  String _nextGroupId() => 'group_${_groupIdCounter++}';

  List<Card> _allGroupedCards() {
    return state.cardGroups.expand((g) => g.cards).toList();
  }

  int _recalculateScore(List<CardGroup> groups) {
    return Scoring.calculateHandDeadwood(
      groups: groups.map((g) => g.cards).toList(),
      wildJoker: effectiveHumanWildJoker,
      maxPenalty: state.gameSettings.fullCountPenalty,
    );
  }

  List<CardGroup> _removeCardFromGroups(List<CardGroup> groups, Card card) {
    final updated = <CardGroup>[];
    for (final group in groups) {
      final cards = List<Card>.from(group.cards)..remove(card);
      if (cards.isNotEmpty) {
        updated.add(group.copyWith(cards: cards));
      }
    }
    if (updated.isEmpty) {
      updated.add(CardGroup(
        id: _nextGroupId(),
        type: CardGroupType.deadwood,
        cards: [],
        isValid: false,
      ));
    }
    return updated;
  }

  void _cleanupEmptyGroups(List<CardGroup> groups) {
    groups.removeWhere((g) => g.isEmpty);
    if (groups.isEmpty) {
      groups.add(CardGroup(
        id: _nextGroupId(),
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

  void _revalidateGroups(List<CardGroup> groups) {
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      if (group.cards.length < 3) {
        groups[i] = group.copyWith(
          type: CardGroupType.deadwood,
          isValid: false,
          customLabel: group.customLabel == 'DRAWN' ? 'DRAWN' : null,
          clearCustomLabel: group.customLabel != 'DRAWN',
        );
        continue;
      }

      final type = _detectGroupType(group.cards);
      final isValid = type != CardGroupType.deadwood;
      groups[i] = group.copyWith(
        type: type,
        isValid: isValid,
        clearCustomLabel: true,
      );
    }
  }

  CardGroupType _detectGroupType(List<Card> cards) {
    if (cards.length < 3) return CardGroupType.deadwood;

    final seqRes = SequenceValidator.validate(cards, effectiveHumanWildJoker);
    if (seqRes.isValid) {
      return seqRes.type == SequenceType.pure
          ? CardGroupType.pureSequence
          : CardGroupType.impureSequence;
    }

    final setRes = SetValidator.validate(cards, effectiveHumanWildJoker);
    if (setRes.isValid) {
      return CardGroupType.set;
    }

    return CardGroupType.deadwood;
  }
}

final gameTableProvider =
    StateNotifierProvider<GameTableNotifier, GameTableState>((ref) {
  return GameTableNotifier(ref);
});
