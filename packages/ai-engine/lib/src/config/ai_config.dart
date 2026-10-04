enum AILevel { beginner, intermediate, advanced, expert }

class AIConfig {
  final AILevel level;
  final double mistakeRate;
  final int monteCarloRollouts;
  final bool useOpponentModel;
  final bool useProbability;
  final bool useStrategySwitching;
  final Duration thinkingDelay;

  const AIConfig({
    this.level = AILevel.advanced,
    this.mistakeRate = 0.02,
    this.monteCarloRollouts = 50,
    this.useOpponentModel = true,
    this.useProbability = true,
    this.useStrategySwitching = true,
    this.thinkingDelay = const Duration(milliseconds: 1000),
  });

  factory AIConfig.beginner() => const AIConfig(
    level: AILevel.beginner,
    mistakeRate: 0.25,
    monteCarloRollouts: 0,
    useOpponentModel: false,
    useProbability: false,
    useStrategySwitching: false,
    thinkingDelay: Duration(milliseconds: 1500),
  );

  factory AIConfig.intermediate() => const AIConfig(
    level: AILevel.intermediate,
    mistakeRate: 0.10,
    monteCarloRollouts: 0,
    useOpponentModel: true,
    useProbability: false,
    useStrategySwitching: true,
    thinkingDelay: Duration(milliseconds: 2500),
  );

  factory AIConfig.advanced() => const AIConfig(
    level: AILevel.advanced,
    mistakeRate: 0.02,
    monteCarloRollouts: 100,
    useOpponentModel: true,
    useProbability: true,
    useStrategySwitching: true,
    thinkingDelay: Duration(milliseconds: 3500),
  );

  factory AIConfig.expert() => const AIConfig(
    level: AILevel.expert,
    mistakeRate: 0.0,
    monteCarloRollouts: 1000,
    useOpponentModel: true,
    useProbability: true,
    useStrategySwitching: true,
    thinkingDelay: Duration(milliseconds: 4500),
  );
}
