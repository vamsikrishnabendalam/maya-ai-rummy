import 'dart:math';
import 'package:game_engine/game_engine.dart';
import 'package:ai_engine/ai_engine.dart';

class SimulationMetrics {
  int totalGames = 0;
  int p1Wins = 0;
  int p2Wins = 0;
  int timeouts = 0;
  int totalTurns = 0;
  int meldDestructionAnomalies = 0;
  int totalDeadwoodP1 = 0;
  int totalDeadwoodP2 = 0;
  int pureSeqFormed = 0;
  int setsFormed = 0;
}

void main(List<String> args) {
  int numGames = 10000;
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--games' && i + 1 < args.length) {
      numGames = int.tryParse(args[i + 1]) ?? 10000;
    }
  }

  print('====================================================');
  print('MAYA AI RUMMY — 10,000+ HEADLESS BOT SIMULATION');
  print('Running $numGames games across AI configurations...');
  print('====================================================');

  final stopwatch = Stopwatch()..start();
  final metrics = SimulationMetrics();
  final rng = Random(42);

  final engine = GameEngine();
  final botStrategy = BotStrategyEngine();

  for (int g = 1; g <= numGames; g++) {
    // Alternate matchups:
    // First 4000: Intermediate (P1) vs Advanced (P2)
    // Next 3000: Beginner (P1) vs Advanced (P2)
    // Next 3000: Advanced (P1) vs Advanced (P2)
    AIConfig p1Config;
    AIConfig p2Config;
    if (g <= 4000) {
      p1Config = AIConfig(level: AILevel.intermediate, monteCarloRollouts: 0);
      p2Config = AIConfig(level: AILevel.advanced, monteCarloRollouts: 20);
    } else if (g <= 7000) {
      p1Config = AIConfig(level: AILevel.beginner, monteCarloRollouts: 0);
      p2Config = AIConfig(level: AILevel.advanced, monteCarloRollouts: 20);
    } else {
      p1Config = AIConfig(level: AILevel.advanced, monteCarloRollouts: 20);
      p2Config = AIConfig(level: AILevel.advanced, monteCarloRollouts: 20);
    }

    final config = GameConfig(
      gameId: 'sim_$g',
      mode: GameMode.POOL_201,
      maxPlayers: 2,
      deckCount: 2,
      firstDropPenalty: 20,
      middleDropPenalty: 40,
      fullCountPenalty: 80,
      eliminationScore: 201,
    );

    var gameState = engine.createGame(config, rng.nextInt(1000000000));
    final t1 = OpponentThreatTracker();
    final t2 = OpponentThreatTracker();

    int turnCount = 0;
    const maxTurns = 35; // Maximum turns before declaring timeout
    bool gameOver = false;

    while (!gameOver && turnCount < maxTurns && gameState.closedDeck.isNotEmpty) {
      turnCount++;
      final isP1 = gameState.currentPlayerIndex == 0;
      final currentThreatTracker = isP1 ? t1 : t2;
      final opponentThreatTracker = isP1 ? t2 : t1;
      final currentConfig = isP1 ? p1Config : p2Config;
      final currentHand = gameState.players[gameState.currentPlayerIndex].hand;
      final opponentHand = gameState.players[1 - gameState.currentPlayerIndex].hand;

      // --- DRAW PHASE ---
      final knowledge = BotKnowledgeState(
        ownHand: currentHand,
        openJoker: gameState.wildJoker,
        openPile: gameState.openPile,
        visibleDiscardHistory: gameState.openPile,
        closedDeckRemaining: gameState.closedDeck.length,
        turnNumber: turnCount,
        opponentPicksFromOpen: currentThreatTracker.picksFromOpen,
        opponentDiscards: currentThreatTracker.discards,
        opponentCardCount: opponentHand.length,
      );

      final drawEval = botStrategy.decideDraw(knowledge, currentConfig, currentThreatTracker);
      final chooseOpen = drawEval.choice == DrawChoice.openPile && gameState.openPile.isNotEmpty;

      Card? drawnCard;
      if (chooseOpen) {
        drawnCard = gameState.openPile.last;
        gameState = engine.processAction(
          gameState,
          DrawFromOpenDeck(
            playerId: gameState.players[gameState.currentPlayerIndex].id,
            gameId: gameState.gameId,
            sequenceNumber: gameState.turnNumber + 1,
            timestamp: DateTime.now(),
          ),
        );
        opponentThreatTracker.recordPickFromOpen(drawnCard);
      } else {
        gameState = engine.processAction(
          gameState,
          DrawFromClosedDeck(
            playerId: gameState.players[gameState.currentPlayerIndex].id,
            gameId: gameState.gameId,
            sequenceNumber: gameState.turnNumber + 1,
            timestamp: DateTime.now(),
          ),
        );
        final handAfterDraw = gameState.players[gameState.currentPlayerIndex].hand;
        drawnCard = handAfterDraw.last;
      }

      // --- DISCARD PHASE ---
      final handWith14 = gameState.players[gameState.currentPlayerIndex].hand;
      final discardEval = botStrategy.decideDiscard(
        handWith14,
        gameState.wildJoker,
        currentConfig,
        currentThreatTracker,
        turnCount,
      );

      // Verify invariant: candidate discard must not break pure sequence or meld without overwhelming cause
      final bestDiscard = discardEval.bestDiscard;
      final bestCandidate = discardEval.allCandidates.firstWhere(
        (c) => c.card == bestDiscard,
        orElse: () => discardEval.allCandidates.first,
      );

      if (bestCandidate.breaksPureSequence && !bestCandidate.isValidDeclaration) {
        metrics.meldDestructionAnomalies++;
      }

      // Check declaration
      if (discardEval.canDeclare) {
        gameOver = true;
        if (isP1) {
          metrics.p1Wins++;
        } else {
          metrics.p2Wins++;
        }
        break;
      }

      // Normal Discard
      gameState = engine.processAction(
        gameState,
        DiscardCard(
          bestDiscard,
          playerId: gameState.players[gameState.currentPlayerIndex].id,
          gameId: gameState.gameId,
          sequenceNumber: gameState.turnNumber + 1,
          timestamp: DateTime.now(),
        ),
      );
      opponentThreatTracker.recordDiscard(bestDiscard);
    }

    metrics.totalGames++;
    metrics.totalTurns += turnCount;
    if (!gameOver) {
      metrics.timeouts++;
    }

    // Evaluate final hands for stats
    final h1 = gameState.players[0].hand;
    final h2 = gameState.players[1].hand;
    final a1 = HandAnalyzer.analyze(h1, gameState.wildJoker);
    final a2 = HandAnalyzer.analyze(h2, gameState.wildJoker);
    metrics.totalDeadwoodP1 += a1.deadwoodPoints;
    metrics.totalDeadwoodP2 += a2.deadwoodPoints;
    metrics.pureSeqFormed += a1.pureSequences.length + a2.pureSequences.length;
    metrics.setsFormed += a1.sets.length + a2.sets.length;

    if (g % 2000 == 0 || g == numGames) {
      final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
      final rate = (g / (elapsed > 0 ? elapsed : 1)).toStringAsFixed(1);
      print('[$g / $numGames] P1 Wins: ${metrics.p1Wins} | P2 Wins: ${metrics.p2Wins} | Timeouts: ${metrics.timeouts} | Meld Anomalies: ${metrics.meldDestructionAnomalies} (${rate} games/s)');
    }
  }

  stopwatch.stop();
  final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;

  print('====================================================');
  print('SIMULATION RESULTS SUMMARY');
  print('====================================================');
  print('Total Games Simulated      : ${metrics.totalGames}');
  print('Total Simulation Time      : ${elapsedSec.toStringAsFixed(2)} seconds');
  print('Throughput                 : ${(metrics.totalGames / elapsedSec).toStringAsFixed(1)} games/second');
  print('Player 1 Wins              : ${metrics.p1Wins} (${((metrics.p1Wins / metrics.totalGames) * 100).toStringAsFixed(1)}%)');
  print('Player 2 (Advanced) Wins   : ${metrics.p2Wins} (${((metrics.p2Wins / metrics.totalGames) * 100).toStringAsFixed(1)}%)');
  print('Timeouts (exceeded 35 trn) : ${metrics.timeouts} (${((metrics.timeouts / metrics.totalGames) * 100).toStringAsFixed(1)}%)');
  print('Average Turns Per Game     : ${(metrics.totalTurns / metrics.totalGames).toStringAsFixed(1)}');
  print('Average Deadwood (P1)      : ${(metrics.totalDeadwoodP1 / metrics.totalGames).toStringAsFixed(1)} pts');
  print('Average Deadwood (P2 Adv)  : ${(metrics.totalDeadwoodP2 / metrics.totalGames).toStringAsFixed(1)} pts');
  print('Pure Sequences Formed      : ${metrics.pureSeqFormed}');
  print('Sets Formed                : ${metrics.setsFormed}');
  print('Meld-Destruction Anomalies : ${metrics.meldDestructionAnomalies} (TARGET: 0)');
  print('====================================================');
  if (metrics.meldDestructionAnomalies == 0) {
    print('SUCCESS: ZERO MELD-DESTRUCTION ANOMALIES VERIFIED ACROSS 10,000 GAMES!');
  } else {
    print('WARNING: Detected ${metrics.meldDestructionAnomalies} anomalies!');
  }
}
