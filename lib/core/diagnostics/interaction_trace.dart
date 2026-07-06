import 'dart:async';

import 'app_diagnostics.dart';

/// Lightweight, privacy-safe instrumentation for user flows.
///
/// Events are queued asynchronously by [AppDiagnostics]. Callers must only
/// provide structural metadata (durations, counts, state flags and route
/// names); typed text, food names, quantities and identifiers are excluded.
class InteractionTrace {
  InteractionTrace._();

  static final Map<String, int> _sampleCounters = <String, int>{};

  static void event(
    String name, {
    Map<String, Object?> data = const <String, Object?>{},
    int sampleEvery = 1,
  }) {
    final int normalizedSample = sampleEvery < 1 ? 1 : sampleEvery;
    final int count = (_sampleCounters[name] ?? 0) + 1;
    _sampleCounters[name] = count;
    if (normalizedSample > 1 && count % normalizedSample != 1) return;
    unawaited(
      AppDiagnostics.instance.info(
        name,
        data: <String, Object?>{
          ...data,
          if (normalizedSample > 1) 'sampleEvery': normalizedSample,
          if (normalizedSample > 1) 'sampleOrdinal': count,
        },
      ),
    );
  }

  static InteractionTraceSpan start(
    String name, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return InteractionTraceSpan._(name, data);
  }
}

class InteractionTraceSpan {
  InteractionTraceSpan._(this.name, this.initialData)
      : _watch = Stopwatch()..start();

  final String name;
  final Map<String, Object?> initialData;
  final Stopwatch _watch;
  bool _finished = false;

  void complete({Map<String, Object?> data = const <String, Object?>{}}) {
    if (_finished) return;
    _finished = true;
    _watch.stop();
    InteractionTrace.event(
      '$name.completed',
      data: <String, Object?>{
        ...initialData,
        ...data,
        'elapsedMs': _watch.elapsedMilliseconds,
      },
    );
  }

  void fail(
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    if (_finished) return;
    _finished = true;
    _watch.stop();
    unawaited(
      AppDiagnostics.instance.error(
        '$name.failed',
        error: error,
        stackTrace: stackTrace,
        data: <String, Object?>{
          ...initialData,
          ...data,
          'elapsedMs': _watch.elapsedMilliseconds,
        },
      ),
    );
  }
}
