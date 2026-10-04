import 'dart:math';
import 'package:game_engine/game_engine.dart';
import '../models/bot_knowledge_state.dart';
import '../analysis/hand_analyzer.dart';
import '../analysis/opponent_threat_tracker.dart';

enum DrawChoice { closedDeck, openPile }

class DrawEvaluationResult {
  final DrawChoice choice;
  final String reasoning;
  final double openCardUtility;
  final int currentDeadwood;
  final int hypoDeadwoodWithOpen;

  const DrawEvaluationResult({
    required this.choice,
    required this.reasoning,
    required this.openCardUtility,
    required this.currentDeadwood,
    required this.hypoDeadwoodWithOpen,
  });
}

class DiscardCandidateScore {
  final Card card;
  final double totalScore;
  final int resultingDeadwood;
  final bool isValidDeclaration;
  final bool breaksPureSequence;
  final bool breaksCompletedMeld;
  final bool isJoker;
  final double opponentDanger;
  final String reasoning;

  const DiscardCandidateScore({
    required this.card,
    required this.totalScore,
    required this.resultingDeadwood,
    required this.isValidDeclaration,
    required this.breaksPureSequence,
    required this.breaksCompletedMeld,
    required this.isJoker,
    required this.opponentDanger,
    required this.reasoning,
  });
}

class DiscardEvaluationResult {
  final Card bestDiscard;
  final bool canDeclare;
  final List<DiscardCandidateScore> allCandidates;
  final String reasoning;

  const DiscardEvaluationResult({
    required this.bestDiscard,
    required this.canDeclare,
    required this.allCandidates,
    required this.reasoning,
  });
}

/// Action Simulator: Simulates actions and resulting hands to select optimal moves.
class ActionSimulator {
  /// Evaluates whether to draw from the Open Discard Pile or the Closed Deck.
  static DrawEvaluationResult evaluateDraw(
    BotKnowledgeState knowledge,
    OpponentThreatTracker threatTracker, {
    double infoLeakPenalty = 35.0,
  }) {
    final hand = knowledge.ownHand;
    final openCard = knowledge.topOfOpenPile;
    final openJoker = knowledge.openJoker;

    final currentAnalysis = HandAnalyzer.analyze(hand, openJoker);

    if (openCard == null) {
      return DrawEvaluationResult(
        choice: DrawChoice.closedDeck,
        reasoning: 'Open pile is empty. Drawing from Closed Deck.',
        openCardUtility: 0.0,
        currentDeadwood: currentAnalysis.deadwoodPoints,
        hypoDeadwoodWithOpen: currentAnalysis.deadwoodPoints,
      );
    }

    // Never pick an open card if it is a discard made by ourselves (or rule restriction)
    // Simulate picking up openCard into hand (creates 14-card hand)
    final hypoHand = List<Card>.from(hand)..add(openCard);
    final hypoAnalysis = HandAnalyzer.analyze(hypoHand, openJoker);

    // Verify whether openCard is ACTUALLY part of any completed meld
    final isInPure = hypoAnalysis.isCardInPureSequence(openCard);
    final isInMeld = hypoAnalysis.isCardInCompletedMeld(openCard);
    final completesPure = isInPure && hypoAnalysis.pureSequences.length > currentAnalysis.pureSequences.length;
    final completesMeld = isInMeld && hypoAnalysis.cardsInCompletedMelds.length > currentAnalysis.cardsInCompletedMelds.length;

    // Simulate discarding the best OTHER card (since openCard cannot be discarded in the same turn)
    double bestOtherScore = -999999.0;
    Card? bestOtherDiscard;
    HandAnalysisResult? bestSimAnalysis;

    for (final c in hand) {
      final rem13 = List<Card>.from(hypoHand)..remove(c);
      final a = HandAnalyzer.analyze(rem13, openJoker);
      if (a.strategicHandValue > bestOtherScore) {
        bestOtherScore = a.strategicHandValue;
        bestOtherDiscard = c;
        bestSimAnalysis = a;
      }
    }

    double openUtility = 0.0;

    if (bestSimAnalysis != null) {
      // 1. Winning declaration
      if (bestSimAnalysis.canDeclare) {
        openUtility += 10000.0;
      }

      // 2. Completes Pure Sequence
      if (completesPure) {
        openUtility += 450.0;
      }

      // 3. Completes Impure Sequence or Set
      if (completesMeld) {
        openUtility += 300.0;
      }

      // 4. Joker
      if (JokerUtils.isJoker(openCard, openJoker)) {
        openUtility += 500.0;
      }

      // 5. Deadwood reduction: Only relevant if the card is part of a meld, pure sequence, or joker!
      final deadwoodDiff = currentAnalysis.deadwoodPoints - bestSimAnalysis.deadwoodPoints;
      if (isInMeld || isInPure || JokerUtils.isJoker(openCard, openJoker)) {
        if (deadwoodDiff > 0) {
          openUtility += deadwoodDiff * 15.0;
        } else if (deadwoodDiff < 0) {
          openUtility += deadwoodDiff * 10.0; // Penalty if drawing openCard worsens deadwood
        }
      }

      // 6. 2-card potential melds with high probability (e.g. 5-6 suited)
      if (!completesMeld && hypoAnalysis.isCardInPotentialMeld(openCard)) {
        if (bestSimAnalysis.deadwoodPoints <= currentAnalysis.deadwoodPoints) {
          openUtility += 35.0;
        }
      }

      // Critical Safety: If openCard is not in any meld, not in pure, and not a joker:
      if (!isInMeld && !isInPure && !JokerUtils.isJoker(openCard, openJoker)) {
        if (!hypoAnalysis.isCardInPotentialMeld(openCard)) {
          openUtility = 0.0;
        } else {
          openUtility = min(openUtility, 35.0);
        }
      }
    }

    // Subtract information leak penalty
    final netOpenValue = openUtility - infoLeakPenalty;
    final bool chooseOpen = openUtility > 0.0 && netOpenValue > 60.0;

    final String reason = chooseOpen
        ? 'Open card $openCard improves hand (utility: ${openUtility.toStringAsFixed(0)} vs leak penalty ${infoLeakPenalty.toStringAsFixed(0)}). Picking from Open Pile.'
        : 'Open card $openCard does not sufficiently improve hand (net utility: ${netOpenValue.toStringAsFixed(0)}). Drawing from Closed Deck.';

    return DrawEvaluationResult(
      choice: chooseOpen ? DrawChoice.openPile : DrawChoice.closedDeck,
      reasoning: reason,
      openCardUtility: openUtility,
      currentDeadwood: currentAnalysis.deadwoodPoints,
      hypoDeadwoodWithOpen: bestSimAnalysis?.deadwoodPoints ?? hypoAnalysis.deadwoodPoints,
    );
  }

  /// Evaluates all candidate discard cards from a 14-card hand.
  /// Strictly protects completed pure sequences, sets, and card drawn from open pile.
  static DiscardEvaluationResult evaluateDiscard(
    List<Card> handWith14,
    Card? openJoker,
    OpponentThreatTracker threatTracker,
    int turnNumber, {
    double defensiveWeight = 1.0,
    Card? cardDrawnFromOpenPile,
  }) {
    // Current analysis of 14 cards before discard
    final preAnalysis = HandAnalyzer.analyze(handWith14, openJoker);
    final candidateScores = <DiscardCandidateScore>[];

    final threatLevel = threatTracker.evaluateThreatLevel(turnNumber);
    final threatMultiplier = threatLevel == ThreatLevel.critical
        ? 2.2
        : threatLevel == ThreatLevel.high
            ? 1.6
            : threatLevel == ThreatLevel.medium
                ? 1.1
                : 0.7;

    for (final candidate in handWith14) {
      // 1. Simulate remaining 13-card hand after discarding this candidate
      final rem13 = List<Card>.from(handWith14)..remove(candidate);
      final remAnalysis = HandAnalyzer.analyze(rem13, openJoker);

      double score = remAnalysis.strategicHandValue;

      // 2. Check: Did discarding this candidate break a completed pure sequence?
      bool breaksPure = false;
      for (final seq in preAnalysis.pureSequences) {
        if (seq.contains(candidate)) {
          final remSeq = seq.where((c) => c != candidate).toList();
          final stillPure = remSeq.length >= 3 &&
              SequenceValidator.validate(remSeq, openJoker).type == SequenceType.pure;
          if (!stillPure) {
            breaksPure = true;
          }
          break;
        }
      }
      if (breaksPure) {
        score -= 2500.0; // MASSIVE PENALTY: Never break a pure sequence!
      }

      // 3. Check: Did discarding this candidate break an impure sequence or set?
      bool breaksMeld = false;
      if (!breaksPure) {
        for (final seq in preAnalysis.impureSequences) {
          if (seq.contains(candidate)) {
            final remSeq = seq.where((c) => c != candidate).toList();
            final stillValid = remSeq.length >= 3 &&
                SequenceValidator.validate(remSeq, openJoker).isValid;
            if (!stillValid) {
              breaksMeld = true;
            }
            break;
          }
        }
        if (!breaksMeld) {
          for (final set in preAnalysis.sets) {
            if (set.contains(candidate)) {
              final remSet = set.where((c) => c != candidate).toList();
              final stillValid = remSet.length >= 3 &&
                  SetValidator.validate(remSet, openJoker).isValid;
              if (!stillValid) {
                breaksMeld = true;
              }
              break;
            }
          }
        }
      }
      if (breaksMeld) {
        score -= 1500.0; // HUGE PENALTY: Never break completed sets or impure sequences!
      }

      // 4. Check: Did discarding this card break a 2-card candidate straight?
      if (!breaksPure && !breaksMeld) {
        if (remAnalysis.potentialSequences.length < preAnalysis.potentialSequences.length) {
          score -= 200.0;
        }
      }

      // 5. Joker Protection: NEVER discard wild or printed jokers unless hand is 100% jokers
      final isJoker = JokerUtils.isJoker(candidate, openJoker);
      if (isJoker) {
        score -= 8000.0; // MAXIMUM PENALTY
      }

      // 6. Defensive Discard Consideration
      final danger = threatTracker.getDiscardDanger(candidate, openJoker, turnNumber);
      final dangerPenalty = danger * 350.0 * threatMultiplier * defensiveWeight;
      score -= dangerPenalty;

      // 7. Deadwood point reduction incentive:
      // If card is an isolated dead card, reward discarding high-face cards (10, J, Q, K) to minimize penalty
      if (remAnalysis.unmatchedCards.contains(candidate) ||
          (!remAnalysis.isCardInCompletedMeld(candidate) && !remAnalysis.isCardInPotentialMeld(candidate))) {
        final val = Scoring.getCardValue(candidate, openJoker);
        score += val * 4.0; // Favor discarding higher deadwood cards
      }

      // 0. Card drawn from open pile prohibition: Cannot discard the card picked from open pile in the same turn!
      final bool isCardDrawnFromOpen = cardDrawnFromOpenPile != null && candidate == cardDrawnFromOpenPile;
      if (isCardDrawnFromOpen) {
        score -= 9999999.0;
      }

      // 8. Winning Declaration:
      if (remAnalysis.canDeclare && !isCardDrawnFromOpen) {
        score += 20000.0; // HIGHEST PRIORITY: Declare and win!
      }

      String reason = 'Standard discard candidate';
      if (isCardDrawnFromOpen) {
        reason = 'PROHIBITED: Cannot discard the card picked from open pile in the same turn.';
      } else if (remAnalysis.canDeclare) {
        reason = 'Winning declaration achieved! Discard $candidate to Declare.';
      } else if (breaksPure) {
        reason = 'CRITICAL: Breaks completed pure sequence (Heavy Penalty).';
      } else if (breaksMeld) {
        reason = 'WARNING: Breaks completed sequence or set (Heavy Penalty).';
      } else if (isJoker) {
        reason = 'CRITICAL: Card is a Joker (Protected).';
      } else if (danger > 0.6) {
        reason = 'Dangerous discard: likely wanted by opponent (${(danger * 100).toInt()}% danger).';
      } else {
        reason = 'Safe deadwood discard. Minimizes deadwood to ${remAnalysis.deadwoodPoints} pts.';
      }

      candidateScores.add(DiscardCandidateScore(
        card: candidate,
        totalScore: score,
        resultingDeadwood: remAnalysis.deadwoodPoints,
        isValidDeclaration: remAnalysis.canDeclare,
        breaksPureSequence: breaksPure,
        breaksCompletedMeld: breaksMeld,
        isJoker: isJoker,
        opponentDanger: danger,
        reasoning: reason,
      ));
    }

    // Sort descending by total score
    candidateScores.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final best = candidateScores.first;

    return DiscardEvaluationResult(
      bestDiscard: best.card,
      canDeclare: best.isValidDeclaration,
      allCandidates: candidateScores,
      reasoning: 'Selected ${best.card}: ${best.reasoning} (Deadwood: ${best.resultingDeadwood} pts, Score: ${best.totalScore.toInt()})',
    );
  }
}
