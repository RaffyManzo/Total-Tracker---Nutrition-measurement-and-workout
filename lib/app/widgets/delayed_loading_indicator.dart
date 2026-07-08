import 'dart:async';

import 'package:flutter/material.dart';

class DelayedLoadingIndicator extends StatefulWidget {
  const DelayedLoadingIndicator({
    this.delay = const Duration(milliseconds: 200),
    this.minimumVisible = const Duration(milliseconds: 280),
    this.child,
    this.indicator,
    super.key,
  });

  final Duration delay;
  final Duration minimumVisible;
  final Widget? child;
  final Widget? indicator;

  @override
  State<DelayedLoadingIndicator> createState() =>
      _DelayedLoadingIndicatorState();
}

class _DelayedLoadingIndicatorState extends State<DelayedLoadingIndicator> {
  Timer? _delayTimer;
  bool _visible = false;
  DateTime? _visibleSince;

  @override
  void initState() {
    super.initState();
    _delayTimer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() {
        _visible = true;
        _visibleSince = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return widget.child ?? const SizedBox.shrink();
    }
    final DateTime? since = _visibleSince;
    if (since != null &&
        DateTime.now().difference(since) < widget.minimumVisible) {
      return widget.indicator ??
          const Center(child: CircularProgressIndicator());
    }
    return widget.indicator ?? const Center(child: CircularProgressIndicator());
  }
}
