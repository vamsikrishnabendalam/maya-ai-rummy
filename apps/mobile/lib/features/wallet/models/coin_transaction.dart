class CoinTransaction {
  final String transactionId;
  final String uid;
  final String type; // INITIAL_ACCOUNT_REWARD | DAILY_LOGIN_REWARD | ACHIEVEMENT_REWARD | TABLE_ENTRY_FEE | TABLE_CREATION_FEE | GAME_REFUND | GAME_WIN_PRIZE | ADMIN_CREDIT | ADMIN_DEBIT | OTHER_REWARD
  final int amount; // positive for credit, negative for debit
  final int balanceBefore;
  final int balanceAfter;
  final String referenceId; // tableId, gameId, achievementId, or reason
  final String reason;
  final DateTime createdAt;
  final String createdBy; // user uid, admin uid, or 'system'

  const CoinTransaction({
    required this.transactionId,
    required this.uid,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.referenceId,
    required this.reason,
    required this.createdAt,
    required this.createdBy,
  });

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;

  String get formattedAmount => amount > 0 ? '+$amount' : '$amount';

  String get typeLabel {
    switch (type) {
      case 'INITIAL_ACCOUNT_REWARD':
        return 'Welcome Bonus';
      case 'DAILY_LOGIN_REWARD':
        return 'Daily Login Reward';
      case 'ACHIEVEMENT_REWARD':
        return 'Achievement Reward';
      case 'TABLE_ENTRY_FEE':
        return 'Table Entry Fee';
      case 'TABLE_CREATION_FEE':
        return 'Table Creation Fee';
      case 'GAME_REFUND':
        return 'Table Refund';
      case 'GAME_WIN_PRIZE':
        return 'Match Victory Pot';
      case 'ADMIN_CREDIT':
        return 'Admin Grant';
      case 'ADMIN_DEBIT':
        return 'Admin Adjustment';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  Map<String, dynamic> toJson() => {
    'transactionId': transactionId,
    'uid': uid,
    'type': type,
    'amount': amount,
    'balanceBefore': balanceBefore,
    'balanceAfter': balanceAfter,
    'referenceId': referenceId,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
  };

  factory CoinTransaction.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      try {
        final toDate = (d as dynamic).toDate;
        if (toDate != null) return toDate() as DateTime;
      } catch (_) {}
      return DateTime.now();
    }

    return CoinTransaction(
      transactionId: json['transactionId'] ?? '',
      uid: json['uid'] ?? '',
      type: json['type'] ?? 'OTHER_REWARD',
      amount: json['amount'] ?? 0,
      balanceBefore: json['balanceBefore'] ?? 0,
      balanceAfter: json['balanceAfter'] ?? 0,
      referenceId: json['referenceId'] ?? '',
      reason: json['reason'] ?? '',
      createdAt: parseDate(json['createdAt']),
      createdBy: json['createdBy'] ?? 'system',
    );
  }
}
