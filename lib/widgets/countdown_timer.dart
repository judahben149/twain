import 'dart:async';
import 'package:flutter/material.dart';

/// A widget that displays a countdown to a target time and automatically refreshes.
class CountdownTimer extends StatefulWidget {
  final DateTime? targetTime;
  final TextStyle? style;
  final String Function(Duration remaining)? formatDuration;
  final VoidCallback? onComplete;

  const CountdownTimer({
    super.key,
    required this.targetTime,
    this.style,
    this.formatDuration,
    this.onComplete,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetTime != widget.targetTime) {
      _calculateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    if (widget.targetTime == null) {
      _remaining = Duration.zero;
      return;
    }

    final now = DateTime.now();
    if (widget.targetTime!.isBefore(now)) {
      _remaining = Duration.zero;
    } else {
      _remaining = widget.targetTime!.difference(now);
    }
  }

  void _startTimer() {
    // Update every second if remaining time is less than an hour,
    // otherwise update every minute
    _timer?.cancel();

    final interval = _remaining.inMinutes < 60
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);

    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;

      setState(() {
        _calculateRemaining();
      });

      if (_remaining == Duration.zero) {
        _timer?.cancel();
        widget.onComplete?.call();
      }
    });
  }

  String _defaultFormatDuration(Duration duration) {
    if (duration == Duration.zero) return 'Now';

    if (duration.inDays > 0) {
      final hours = duration.inHours % 24;
      return 'Next in ${duration.inDays}d ${hours}h';
    } else if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      return 'Next in ${duration.inHours}h ${minutes}m';
    } else if (duration.inMinutes > 0) {
      final seconds = duration.inSeconds % 60;
      return 'Next in ${duration.inMinutes}m ${seconds}s';
    } else {
      return 'Next in ${duration.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.targetTime == null) {
      return const SizedBox.shrink();
    }

    final format = widget.formatDuration ?? _defaultFormatDuration;
    return Text(
      format(_remaining),
      style: widget.style,
    );
  }
}
