import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/coin_transaction.dart';
import '../../../../core/config/firebase_config.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  FirebaseFirestore? get _firestore =>
      FirebaseConfig.isInitialized ? FirebaseFirestore.instance : null;

  /// Deduct coins atomically via Firestore transaction
  /// Returns the new balance on success
  Future<int> deductCoins({
    required String uid,
    required int amount,
    required String type,
    required String reason,
    required String referenceId,
    String? createdBy,
  }) async {
    if (amount <= 0) throw Exception('Deduction amount must be strictly greater than 0');
    final fs = _firestore;
    if (fs == null) {
      debugPrint('[WalletService] Offline / local mode deduction ($amount coins)');
      return 5000;
    }

    final userRef = fs.collection('users').doc(uid);
    final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}_${uid.substring(0, uid.length.clamp(0, 6))}';
    final txRef = fs.collection('coinTransactions').doc(txId);

    return await fs.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw Exception('User account does not exist.');
      }

      final data = userSnap.data()!;
      final status = data['accountStatus'] ?? 'ACTIVE';
      if (status == 'BLOCKED' || status == 'SUSPENDED') {
        throw Exception('Account is $status. Coin transactions are disabled.');
      }

      final currentBalance = (data['coins'] as num?)?.toInt() ?? 0;
      if (currentBalance < amount) {
        throw Exception('Insufficient virtual coins ($currentBalance available, $amount required).');
      }

      final newBalance = currentBalance - amount;
      final currentSpent = (data['lifetimeCoinsSpent'] as num?)?.toInt() ?? 0;

      // 1. Update user balance
      transaction.update(userRef, {
        'coins': newBalance,
        'lifetimeCoinsSpent': currentSpent + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Append-only ledger entry
      final ledger = CoinTransaction(
        transactionId: txId,
        uid: uid,
        type: type,
        amount: -amount,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        referenceId: referenceId,
        reason: reason,
        createdAt: DateTime.now(),
        createdBy: createdBy ?? uid,
      );

      transaction.set(txRef, ledger.toJson());
      return newBalance;
    });
  }

  /// Credit coins atomically via Firestore transaction
  /// Returns the new balance on success
  Future<int> creditCoins({
    required String uid,
    required int amount,
    required String type,
    required String reason,
    required String referenceId,
    String? createdBy,
  }) async {
    if (amount <= 0) throw Exception('Credit amount must be strictly greater than 0');
    final fs = _firestore;
    if (fs == null) {
      debugPrint('[WalletService] Offline / local mode credit ($amount coins)');
      return 5000;
    }

    final userRef = fs.collection('users').doc(uid);
    final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}_${uid.substring(0, uid.length.clamp(0, 6))}';
    final txRef = fs.collection('coinTransactions').doc(txId);

    return await fs.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw Exception('User account does not exist.');
      }

      final data = userSnap.data()!;
      final currentBalance = (data['coins'] as num?)?.toInt() ?? 0;
      final currentEarned = (data['lifetimeCoinsEarned'] as num?)?.toInt() ?? 0;
      final newBalance = currentBalance + amount;

      // 1. Update user balance
      transaction.update(userRef, {
        'coins': newBalance,
        'lifetimeCoinsEarned': currentEarned + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Append-only ledger entry
      final ledger = CoinTransaction(
        transactionId: txId,
        uid: uid,
        type: type,
        amount: amount,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        referenceId: referenceId,
        reason: reason,
        createdAt: DateTime.now(),
        createdBy: createdBy ?? 'system',
      );

      transaction.set(txRef, ledger.toJson());
      return newBalance;
    });
  }

  /// Admin coin adjustment (Credit or Debit)
  Future<void> adminAdjustCoins({
    required String adminUid,
    required String targetUid,
    required int amount,
    required String reason,
  }) async {
    if (amount == 0) throw Exception('Adjustment amount cannot be zero');
    final fs = _firestore;
    if (fs == null) return;

    final userRef = fs.collection('users').doc(targetUid);
    final txId = 'tx_admin_${DateTime.now().millisecondsSinceEpoch}_${targetUid.substring(0, targetUid.length.clamp(0, 6))}';
    final txRef = fs.collection('coinTransactions').doc(txId);
    final auditId = 'audit_${DateTime.now().millisecondsSinceEpoch}';
    final auditRef = fs.collection('adminAuditLogs').doc(auditId);

    await fs.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) throw Exception('Target user not found.');

      final data = userSnap.data()!;
      final currentBalance = (data['coins'] as num?)?.toInt() ?? 0;
      final newBalance = currentBalance + amount;
      if (newBalance < 0) {
        throw Exception('Adjustment would result in negative balance ($newBalance). Operation rejected.');
      }

      final type = amount > 0 ? 'ADMIN_CREDIT' : 'ADMIN_DEBIT';
      final currentEarned = (data['lifetimeCoinsEarned'] as num?)?.toInt() ?? 0;
      final currentSpent = (data['lifetimeCoinsSpent'] as num?)?.toInt() ?? 0;

      transaction.update(userRef, {
        'coins': newBalance,
        if (amount > 0) 'lifetimeCoinsEarned': currentEarned + amount,
        if (amount < 0) 'lifetimeCoinsSpent': currentSpent + (-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(txRef, {
        'transactionId': txId,
        'uid': targetUid,
        'type': type,
        'amount': amount,
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
        'referenceId': 'admin_manual_adjustment',
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminUid,
      });

      transaction.set(auditRef, {
        'auditId': auditId,
        'adminUid': adminUid,
        'targetUid': targetUid,
        'action': type,
        'amount': amount,
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Stream user transaction history from the append-only ledger
  Stream<List<CoinTransaction>> streamUserTransactions(String uid) {
    final fs = _firestore;
    if (fs == null) return Stream.value([]);

    return fs
        .collection('coinTransactions')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CoinTransaction.fromJson(d.data())).toList());
  }

  /// Stream all system transactions for Admin Audit
  Stream<List<CoinTransaction>> streamAllTransactions({int limit = 100}) {
    final fs = _firestore;
    if (fs == null) return Stream.value([]);

    return fs
        .collection('coinTransactions')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CoinTransaction.fromJson(d.data())).toList());
  }
}
