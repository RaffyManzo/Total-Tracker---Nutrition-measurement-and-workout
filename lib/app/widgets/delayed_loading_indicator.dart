import 'dart:async';

import 'package:flutter/material.dart';

/// Shows [indicator] only when loading lasts longer than [delay].
///
/// Once visible, the indicator remains mounted for at least [minimumVisible].
/// Completion, error, cancellation and disposal cancel all pending callbacks.
class DelayedLoadingIndicator extends StatefulWidget {
  const DelayedLoadingIndicator({
    this.isLoading = true,
    this.delay = const Duration(milliseconds: 200),
    this.minimumVisible = const Duration(milliseconds: 280),
    this.child,
    this.indicator,
    super.key,
  });

  final bool isLoading;
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
  Timer? _minimumTimer;
  bool _visible = false;
  bool _minimumElapsed = false;

  @override
  void initState() {
    super.initState();
    _synchronize();
  }

  @override
  void didUpdateWidget(DelayedLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_visible && oldWidget.minimumVisible != widget.minimumVisible) {
      _startMinimumTimer();
    }
    if (oldWidget.isLoading != widget.isLoading ||
        oldWidget.delay != widget.delay) {
      _synchronize();
    }
  }

  void _synchronize() {
    if (widget.isLoading) {
      if (_visible || _delayTimer?.isActive == true) {
        return;
      }
      _delayTimer?.cancel();
      _delayTimer = Timer(widget.delay, () {
        _delayTimer = null;
        if (!mounted || !widget.isLoading) {
          return;
        }
        setState(() => _visible = true);
        _startMinimumTimer();
      });
      return;
    }

    _delayTimer?.cancel();
    _delayTimer = null;
    if (_visible && _minimumElapsed) {
      _hide();
    }
  }

  void _startMinimumTimer() {
    _minimumTimer?.cancel();
    _minimumElapsed = widget.minimumVisible <= Duration.zero;
    if (_minimumElapsed) {
      if (!widget.isLoading) {
        _hide();
      }
      return;
    }
    _minimumTimer = Timer(widget.minimumVisible, () {
      _minimumTimer = null;
      if (!mounted) {
        return;
      }
      _minimumElapsed = true;
      if (!widget.isLoading) {
        _hide();
      }
    });
  }

  void _hide() {
    if (!mounted || !_visible) {
      return;
    }
    _minimumTimer?.cancel();
    _minimumTimer = null;
    setState(() {
      _visible = false;
      _minimumElapsed = false;
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _minimumTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return widget.child ?? const SizedBox.shrink();
    }
    return widget.indicator ?? const Center(child: CircularProgressIndicator());
  }
}
