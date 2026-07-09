import 'package:flutter/widgets.dart';

class LifecycleTransitionDecision {
  const LifecycleTransitionDecision({
    required this.state,
    required this.duplicate,
    required this.shouldReconcile,
    required this.generation,
    this.backgroundDurationMs,
  });

  final AppLifecycleState state;
  final bool duplicate;
  final bool shouldReconcile;
  final int generation;
  final int? backgroundDurationMs;
}

/// Pure state machine used by Android lifecycle observers.
///
/// `inactive` never overwrites the background timestamp. `hidden`/`paused`
/// record it once. Repeated states are coalesced. A resume produces at most one
/// reconcile until [completeResume] is called.
class AppLifecycleTransitionCoordinator {
  AppLifecycleState? _lastState;
  DateTime? _backgroundedAt;
  bool _resumeInFlight = false;
  int _generation = 0;
  bool _detached = false;

  AppLifecycleState? get lastState => _lastState;
  DateTime? get backgroundedAt => _backgroundedAt;
  bool get resumeInFlight => _resumeInFlight;
  bool get detached => _detached;

  LifecycleTransitionDecision transition(
    AppLifecycleState state, {
    required DateTime now,
  }) {
    if (_lastState == state) {
      return LifecycleTransitionDecision(
        state: state,
        duplicate: true,
        shouldReconcile: false,
        generation: _generation,
      );
    }

    _lastState = state;

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundedAt ??= now;
    }

    if (state == AppLifecycleState.detached) {
      _detached = true;
      _resumeInFlight = false;
      return LifecycleTransitionDecision(
        state: state,
        duplicate: false,
        shouldReconcile: false,
        generation: _generation,
      );
    }

    if (state != AppLifecycleState.resumed || _resumeInFlight) {
      return LifecycleTransitionDecision(
        state: state,
        duplicate: false,
        shouldReconcile: false,
        generation: _generation,
      );
    }

    _detached = false;
    _resumeInFlight = true;
    _generation += 1;
    return LifecycleTransitionDecision(
      state: state,
      duplicate: false,
      shouldReconcile: true,
      generation: _generation,
      backgroundDurationMs: _backgroundedAt == null
          ? null
          : now.difference(_backgroundedAt!).inMilliseconds,
    );
  }

  void completeResume(int generation) {
    if (!_resumeInFlight || generation != _generation) {
      return;
    }
    _resumeInFlight = false;
    _backgroundedAt = null;
  }

  void cancel() {
    _resumeInFlight = false;
    _detached = true;
  }
}
