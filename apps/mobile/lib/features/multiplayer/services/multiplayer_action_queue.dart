import 'dart:async';
import 'package:flutter/foundation.dart';

/// Serialized FIFO Action Queue for multiplayer rummy transactions.
/// Prevents concurrent transaction contention storms, race conditions, and deadlocks.
/// Automatically detects and drops stale turn actions if the turn has already advanced.
class MultiplayerActionQueue {
  final List<_QueuedAction> _queue = [];
  bool _isProcessing = false;

  int get pendingCount => _queue.length;
  bool get isProcessing => _isProcessing;

  /// Enqueue an asynchronous action to run sequentially.
  /// If [expectedTurnNumber] is provided and [currentTurnNumberGetter] reports
  /// that the server has already moved to a higher turn, the action is aborted
  /// without hitting Firestore.
  Future<T> enqueue<T>({
    required String actionType,
    int? expectedTurnNumber,
    int Function()? currentTurnNumberGetter,
    required Future<T> Function() task,
  }) {
    final completer = Completer<T>();
    final queued = _QueuedAction<T>(
      actionType: actionType,
      expectedTurnNumber: expectedTurnNumber,
      currentTurnNumberGetter: currentTurnNumberGetter,
      task: task,
      completer: completer,
    );

    _queue.add(queued);
    _processNext();
    return completer.future;
  }

  void _processNext() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final action = _queue.removeAt(0);

      // Check for turn staleness
      if (action.expectedTurnNumber != null && action.currentTurnNumberGetter != null) {
        final currentTurn = action.currentTurnNumberGetter!();
        if (currentTurn > action.expectedTurnNumber!) {
          debugPrint(
            '[MultiplayerActionQueue] Dropping stale action ${action.actionType} '
            '(expected turn ${action.expectedTurnNumber}, current turn $currentTurn)',
          );
          action.completeError(
            StateError('Stale action: Turn has already progressed from ${action.expectedTurnNumber} to $currentTurn'),
          );
          continue;
        }
      }

      try {
        await action.execute();
      } catch (e, st) {
        debugPrint('[MultiplayerActionQueue] Error executing ${action.actionType}: $e');
        action.completeError(e, st);
      }
    }

    _isProcessing = false;
  }

  void clear() {
    for (final action in _queue) {
      action.completeError(StateError('Action queue cleared'));
    }
    _queue.clear();
    _isProcessing = false;
  }
}

abstract class _QueuedAction<T> {
  String get actionType;
  int? get expectedTurnNumber;
  int Function()? get currentTurnNumberGetter;
  Future<void> execute();
  void completeError(Object error, [StackTrace? stackTrace]);

  factory _QueuedAction({
    required String actionType,
    int? expectedTurnNumber,
    int Function()? currentTurnNumberGetter,
    required Future<T> Function() task,
    required Completer<T> completer,
  }) = _TypedQueuedAction<T>;
}

class _TypedQueuedAction<T> implements _QueuedAction<T> {
  @override
  final String actionType;
  @override
  final int? expectedTurnNumber;
  @override
  final int Function()? currentTurnNumberGetter;
  final Future<T> Function() task;
  final Completer<T> completer;

  _TypedQueuedAction({
    required this.actionType,
    this.expectedTurnNumber,
    this.currentTurnNumberGetter,
    required this.task,
    required this.completer,
  });

  @override
  Future<void> execute() async {
    try {
      final res = await task();
      if (!completer.isCompleted) completer.complete(res);
    } catch (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    }
  }

  @override
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) completer.completeError(error, stackTrace);
  }
}

