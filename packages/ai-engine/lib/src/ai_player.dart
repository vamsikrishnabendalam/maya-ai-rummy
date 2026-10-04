import 'package:game_engine/game_engine.dart';
import 'observation.dart';
import 'config/ai_config.dart';
import 'models/bot_knowledge_state.dart';
import 'analysis/opponent_threat_tracker.dart';
import 'simulation/action_simulator.dart';
import 'strategy/bot_strategy_engine.dart';

enum DrawDecision { closedDeck, openPile }

class AIDecision {
  final DrawDecision drawDecision;
  final Card discardCard;
  final bool declare;
  final String? drawReasoning;
  final String? discardReasoning;
  final List<Map<String, dynamic>>? candidateEvaluations;
  final int? resultingDeadwood;

  AIDecision({
    required this.drawDecision,
    required this.discardCard,
    this.declare = false,
    this.drawReasoning,
    this.discardReasoning,
    this.candidateEvaluations,
    this.resultingDeadwood,
  });
}

abstract class AIEngine {
  AIDecision calculateNextMove(AIObservation observation, AIConfig config);
}

class AIPlayer implements AIEngine {
  final BotStrategyEngine strategyEngine = BotStrategyEngine();
  final OpponentThreatTracker threatTracker = OpponentThreatTracker();

  DrawEvaluationResult decideDraw(
    BotKnowledgeState knowledge,
    AIConfig config,
  ) {
    return strategyEngine.decideDraw(knowledge, config, threatTracker);
  }

  DiscardEvaluationResult decideDiscard(
    List<Card> hand,
    Card? openJoker,
    AIConfig config,
    int turnNumber, {
    Card? cardDrawnFromOpenPile,
  }) {
    return strategyEngine.decideDiscard(
      hand,
      openJoker,
      config,
      threatTracker,
      turnNumber,
      cardDrawnFromOpenPile: cardDrawnFromOpenPile,
    );
  }

  @override
  AIDecision calculateNextMove(AIObservation observation, AIConfig config) {
    final knowledge = BotKnowledgeState(
      ownHand: observation.hand,
      openJoker: observation.wildJoker,
      openPile: observation.discardPile,
      visibleDiscardHistory: observation.knownDeadCards,
      closedDeckRemaining: observation.closedDeckRemaining,
      turnNumber: observation.turnNumber,
    );

    final drawResult = strategyEngine.decideDraw(knowledge, config, threatTracker);
    final drawDecision = drawResult.choice == DrawChoice.openPile
        ? DrawDecision.openPile
        : DrawDecision.closedDeck;

    final simulatedHand = List<Card>.from(observation.hand);
    if (drawDecision == DrawDecision.openPile && observation.topOfOpenPile != null) {
      simulatedHand.add(observation.topOfOpenPile!);
    }

    final discardResult = strategyEngine.decideDiscard(
      simulatedHand,
      observation.wildJoker,
      config,
      threatTracker,
      observation.turnNumber,
      cardDrawnFromOpenPile: drawDecision == DrawDecision.openPile ? observation.topOfOpenPile : null,
    );

    return AIDecision(
      drawDecision: drawDecision,
      discardCard: discardResult.bestDiscard,
      declare: discardResult.canDeclare,
      drawReasoning: drawResult.reasoning,
      discardReasoning: discardResult.reasoning,
      candidateEvaluations: discardResult.allCandidates.map((c) => {
        'card': c.card.toString(),
        'resultingDeadwood': c.resultingDeadwood,
        'isValidDeclaration': c.isValidDeclaration,
        'score': c.totalScore,
        'breaksPure': c.breaksPureSequence,
        'breaksMeld': c.breaksCompletedMeld,
      }).toList(),
      resultingDeadwood: discardResult.allCandidates.isNotEmpty
          ? discardResult.allCandidates.first.resultingDeadwood
          : 0,
    );
  }
}
