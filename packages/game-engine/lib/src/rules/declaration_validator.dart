import '../models/card.dart';
import 'hand_partitioner.dart';

class ValidationResult {
  final bool isValid;
  final int penaltyScore;
  final String? errorMessage;
  final HandPartitionResult? partitionResult;

  ValidationResult(
    this.isValid,
    this.penaltyScore, {
    this.errorMessage,
    this.partitionResult,
  });
}

/// Authoritative Rummy Declaration Validator.
class DeclarationValidator {
  /// Validates a list of card groups.
  /// If groups are supplied, validates them. If the groups are invalid,
  /// also searches for any valid 13-card partition in the combined hand.
  ValidationResult validate(List<List<Card>> groups, Card? wildJoker) {
    // 1. Evaluate explicit groups
    final explicitResult = HandPartitioner.evaluateGroups(groups, wildJoker);
    if (explicitResult.isValidDeclaration) {
      return ValidationResult(
        true,
        0,
        partitionResult: explicitResult,
      );
    }

    // 2. If visual groups fail, check if the cards can form any valid partition
    final allCards = groups.expand((g) => g).toList();
    if (allCards.length == 13) {
      final autoPartition = HandPartitioner.findValidPartition(allCards, wildJoker);
      if (autoPartition.isValidDeclaration) {
        return ValidationResult(
          true,
          0,
          partitionResult: autoPartition,
        );
      }
    }

    return ValidationResult(
      false,
      explicitResult.penaltyScore,
      errorMessage: explicitResult.errorMessage,
      partitionResult: explicitResult,
    );
  }
}
