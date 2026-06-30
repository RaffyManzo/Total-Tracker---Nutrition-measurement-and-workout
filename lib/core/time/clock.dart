class Clock {
  const Clock({DateTime Function()? now}) : _now = now;

  final DateTime Function()? _now;

  DateTime nowUtc() {
    return (_now?.call() ?? DateTime.now()).toUtc();
  }

  int nowEpochMs() {
    return nowUtc().millisecondsSinceEpoch;
  }
}
