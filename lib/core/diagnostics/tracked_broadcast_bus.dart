import 'dart:async';

/// Immutable runtime counters for a broadcast bus.
///
/// `pendingDeliveries` counts event/listener deliveries that were published
/// but whose callback has not started yet. It is therefore a queue depth, not
/// a publication counter.
class TrackedBroadcastMetrics {
  const TrackedBroadcastMetrics({
    required this.registeredSubscribers,
    required this.publishedEvents,
    required this.pendingDeliveries,
    required this.callbacksInFlight,
    required this.callbacksCompleted,
    required this.callbacksSkipped,
    required this.coalescedEvents,
  });

  final int registeredSubscribers;
  final int publishedEvents;
  final int pendingDeliveries;
  final int callbacksInFlight;
  final int callbacksCompleted;
  final int callbacksSkipped;
  final int coalescedEvents;

  Map<String, Object?> toJson() => <String, Object?>{
        'subscriberCount': registeredSubscribers,
        'publishedEvents': publishedEvents,
        'queueDepth': pendingDeliveries,
        'callbacksInFlight': callbacksInFlight,
        'callbacksCompleted': callbacksCompleted,
        'callbacksSkipped': callbacksSkipped,
        'coalescedEventCount': coalescedEvents,
      };
}

/// Broadcast stream with per-listener accounting.
///
/// The wrapper deliberately counts subscriptions individually. A normal
/// [StreamController.broadcast] only exposes `hasListener`, which cannot
/// distinguish one subscriber from many.
class TrackedBroadcastBus<T> {
  TrackedBroadcastBus({bool sync = false})
      : _controller = StreamController<T>.broadcast(sync: sync);

  final StreamController<T> _controller;
  final Set<_TrackedSubscription<T>> _subscriptions =
      <_TrackedSubscription<T>>{};

  int _publishedEvents = 0;
  int _pendingDeliveries = 0;
  int _callbacksInFlight = 0;
  int _callbacksCompleted = 0;
  int _callbacksSkipped = 0;
  int _coalescedEvents = 0;

  late final Stream<T> stream = _TrackedStream<T>(this);

  TrackedBroadcastMetrics get metrics => TrackedBroadcastMetrics(
        registeredSubscribers: _subscriptions.length,
        publishedEvents: _publishedEvents,
        pendingDeliveries: _pendingDeliveries,
        callbacksInFlight: _callbacksInFlight,
        callbacksCompleted: _callbacksCompleted,
        callbacksSkipped: _callbacksSkipped,
        coalescedEvents: _coalescedEvents,
      );

  void publish(T event) {
    if (_controller.isClosed) {
      return;
    }
    _publishedEvents += 1;
    for (final _TrackedSubscription<T> subscription
        in _subscriptions.toList(growable: false)) {
      if (!subscription._cancelled) {
        subscription._pending += 1;
        _pendingDeliveries += 1;
      }
    }
    _controller.add(event);
  }

  void recordSkipped([int count = 1]) {
    if (count > 0) {
      _callbacksSkipped += count;
    }
  }

  void recordCoalesced([int count = 1]) {
    if (count > 0) {
      _coalescedEvents += count;
    }
  }

  void resetMetricsForTests() {
    _publishedEvents = 0;
    _pendingDeliveries = 0;
    _callbacksInFlight = 0;
    _callbacksCompleted = 0;
    _callbacksSkipped = 0;
    _coalescedEvents = 0;
    for (final _TrackedSubscription<T> subscription in _subscriptions) {
      subscription._pending = 0;
    }
  }

  StreamSubscription<T> _listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    late final _TrackedSubscription<T> tracked;
    late final StreamSubscription<T> inner;

    inner = _controller.stream.listen(
      (T event) => tracked._dispatch(event),
      onError: (Object error, StackTrace stackTrace) {
        tracked._dispatchError(error, stackTrace);
        if (cancelOnError == true) {
          tracked._markCancelled();
        }
      },
      onDone: () {
        tracked._markCancelled();
        tracked._onDone?.call();
      },
      cancelOnError: cancelOnError,
    );

    tracked = _TrackedSubscription<T>(
      owner: this,
      inner: inner,
      onData: onData,
      onError: onError,
      onDone: onDone,
    );
    _subscriptions.add(tracked);
    return tracked;
  }

  void _beginDelivery(_TrackedSubscription<T> subscription) {
    if (subscription._pending > 0) {
      subscription._pending -= 1;
      if (_pendingDeliveries > 0) {
        _pendingDeliveries -= 1;
      }
    }
    _callbacksInFlight += 1;
  }

  void _completeDelivery() {
    if (_callbacksInFlight > 0) {
      _callbacksInFlight -= 1;
    }
    _callbacksCompleted += 1;
  }

  void _remove(_TrackedSubscription<T> subscription) {
    if (!_subscriptions.remove(subscription)) {
      return;
    }
    if (subscription._pending > 0) {
      _pendingDeliveries -= subscription._pending;
      if (_pendingDeliveries < 0) {
        _pendingDeliveries = 0;
      }
      subscription._pending = 0;
    }
  }
}

class _TrackedStream<T> extends Stream<T> {
  const _TrackedStream(this.owner);

  final TrackedBroadcastBus<T> owner;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return owner._listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TrackedSubscription<T> implements StreamSubscription<T> {
  _TrackedSubscription({
    required TrackedBroadcastBus<T> owner,
    required StreamSubscription<T> inner,
    required void Function(T event)? onData,
    required Function? onError,
    required void Function()? onDone,
  })  : _owner = owner,
        _inner = inner,
        _onData = onData,
        _onError = onError,
        _onDone = onDone;

  final TrackedBroadcastBus<T> _owner;
  final StreamSubscription<T> _inner;
  void Function(T event)? _onData;
  Function? _onError;
  void Function()? _onDone;
  int _pending = 0;
  bool _cancelled = false;

  void _dispatch(T event) {
    if (_cancelled) {
      return;
    }
    _owner._beginDelivery(this);
    try {
      _onData?.call(event);
    } finally {
      _owner._completeDelivery();
    }
  }

  void _dispatchError(Object error, StackTrace stackTrace) {
    final Function? handler = _onError;
    if (handler == null) {
      Zone.current.handleUncaughtError(error, stackTrace);
    } else if (handler is void Function(Object, StackTrace)) {
      handler(error, stackTrace);
    } else if (handler is void Function(Object)) {
      handler(error);
    } else {
      Function.apply(handler, <Object>[error, stackTrace]);
    }
  }

  void _markCancelled() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    _owner._remove(this);
  }

  @override
  Future<void> cancel() {
    _markCancelled();
    return _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) {
    _onData = handleData;
  }

  @override
  void onError(Function? handleError) {
    _onError = handleError;
  }

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
}
