import 'dart:math';
import 'package:game_engine/game_engine.dart';
import '../models/bot_knowledge_state.dart';
import '../config/ai_config.dart';
import '../analysis/opponent_threat_tracker.dart';
import '../simulation/action_simulator.dart';

class BotTurnDecision {
  final DrawChoice drawChoice;
  final Card discardCard;
  final bool declare;
  final String drawReasoning;
  final String discardReasoning;
  final List<Map<String, dynamic>> candidateEvaluations;
  final int resultingDeadwood;

  const BotTurnDecision({
    required this.drawChoice,
    required this.discardCard,
    required this.declare,
    required this.drawReasoning,
    required this.discardReasoning,
    required this.candidateEvaluations,
    required this.resultingDeadwood,
  });
}

/// Central Strategy Engine orchestrating Easy, Medium, and Hard Bot behaviors.
class BotStrategyEngine {
  final Random _rng = Random();

  /// Step 1: Computes the Draw Phase Decision (Open Pile vs Closed Deck).
  DrawEvaluationResult decideDraw(
    BotKnowledgeState knowledge,
    AIConfig config,
    OpponentThreatTracker threatTracker,
  ) {
    double leakPenalty = 30.0;
    if (config.level == AILevel.advanced || config.level == AILevel.expert) {
      leakPenalty = 45.0; // Hard bot is more cautious about leaking information
    } else if (config.level == AILevel.beginner) {
      leakPenalty = 15.0; // Easy bot takes open card more readily
    }

    return ActionSimulator.evaluateDraw(
      knowledge,
      threatTracker,
      infoLeakPenalty: leakPenalty,
    );
  }

  /// Step 2: Post-Draw Discard & Declare Decision from the 14-card hand.
  DiscardEvaluationResult decideDiscard(
    List<Card> handWith14,
    Card? openJoker,
    AIConfig config,
    OpponentThreatTracker threatTracker,
    int turnNumber, {
    Card? cardDrawnFromOpenPile,
  }) {
    double defensiveWeight = 1.0;
    if (config.level == AILevel.expert || config.level == AILevel.advanced) {
      defensiveWeight = 1.6; // Hard bot plays tight defense
    } else if (config.level == AILevel.beginner) {
      defensiveWeight = 0.3; // Easy bot focuses mainly on own hand
    }

    final eval = ActionSimulator.evaluateDiscard(
      handWith14,
      openJoker,
      threatTracker,
      turnNumber,
      defensiveWeight: defensiveWeight,
      cardDrawnFromOpenPile: cardDrawnFromOpenPile,
    );

    // If candidate enables winning declaration, ALWAYS declare!
    if (eval.canDeclare) {
      return eval;
    }

    // Easy Bot: Adds controlled randomness among TOP safe candidates only
    if (config.level == AILevel.beginner && eval.allCandidates.length >= 2) {
      // Filter out self-destructive candidates (never pick cards that break melds, jokers, or card drawn from open)
      final safeCandidates = eval.allCandidates
          .where((c) =>
              !c.breaksPureSequence &&
              !c.breaksCompletedMeld &&
              !c.isJoker &&
              (cardDrawnFromOpenPile == null || c.card != cardDrawnFromOpenPile))
          .toList();

      if (safeCandidates.length >= 2 && _rng.nextDouble() < 0.30) {
        // Occasionally pick second best safe candidate to simulate beginner play
        final picked = safeCandidates[1];
        return DiscardEvaluationResult(
          bestDiscard: picked.card,
          canDeclare: false,
          allCandidates: eval.allCandidates,
          reasoning: 'Beginner heuristic selected ${picked.card} (Deadwood: ${picked.resultingDeadwood} pts)',
        );
      }
    }

    // Hard Bot: Deep Monte Carlo rollout lookahead across top safe candidates
    if ((config.level == AILevel.expert || config.level == AILevel.advanced) &&
        eval.allCandidates.length >= 2) {
      final refinedCandidate = _monteCarloRefinement(
        handWith14,
        openJoker,
        eval.allCandidates,
        threatTracker,
        rollouts: config.monteCarloRollouts > 0 ? config.monteCarloRollouts : 60,
      );
      if (refinedCandidate != null) {
        return DiscardEvaluationResult(
          bestDiscard: refinedCandidate.card,
          canDeclare: refinedCandidate.isValidDeclaration,
          allCandidates: eval.allCandidates,
          reasoning: 'Hard AI Deep Rollout selected ${refinedCandidate.card} (Score: ${refinedCandidate.totalScore.toInt()})',
        );
      }
    }

    return eval;
  }

  /// Monte Carlo rollout lookahead for Hard Bot:
  /// Evaluates expected hand potential after simulated future draws.
  DiscardCandidateScore? _monteCarloRefinement(
    List<Card> handWith14,
    Card? openJoker,
    List<DiscardCandidateScore> candidates,
    OpponentThreatTracker threatTracker, {
    int rollouts = 50,
  }) {
    // Only compare top 3 non-destructive candidates
    final topCandidates = candidates
        .where((c) => !c.breaksPureSequence && !c.breaksCompletedMeld && !c.isJoker)
        .take(3)
        .toList();

    if (topCandidates.length <= 1) return null;
    // If top candidate is overwhelmingly superior, skip rollout
    if (topCandidates[0].totalScore - topCandidates[1].totalScore > 250.0) {
      return topCandidates[0];
    }

    double bestExpectedValue = -999999.0;
    DiscardCandidateScore bestCandidate = topCandidates.first;

    for (final cand in topCandidates) {
      final rem13 = List<Card>.from(handWith14)..remove(cand.card);
      double rolloutTotal = cand.totalScore;

      final sampleCount = min(rollouts, 12);
      for (int i = 0; i < sampleCount; i++) {
        final randomSuit = Suit.values[_rng.nextInt(Suit.values.length)];
        final randomRank = Rank.values[_rng.nextInt(Rank.values.length)];
        final testCard = Card(suit: randomSuit, rank: randomRank, deckIndex: 0);

        final hypo14 = List<Card>.from(rem13)..add(testCard);
        final partition = HandPartitioner.findBestPartition(hypo14, openJoker);
        final deadwood = partition.isValidDeclaration ? 0 : partition.penaltyScore;
        rolloutTotal += (80 - deadwood) * 0.5;
      }

      if (rolloutTotal > bestExpectedValue) {
        bestExpectedValue = rolloutTotal;
        bestCandidate = cand;
      }
    }

    return bestCandidate;
  }
}
