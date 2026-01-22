import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/models/distance_state.dart';
import 'package:twain/providers/location_providers.dart';

class DirectionalDots extends ConsumerWidget {
  const DirectionalDots({super.key, required this.isLeftSide});

  final bool isLeftSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(distanceStateProvider);

    switch (state.status) {
      case DistanceStatus.hidden:
        return const SizedBox.shrink();
      case DistanceStatus.acquiring:
        return const _RippleDot();
      case DistanceStatus.waitingForPartner:
        return const _StatusDot(
          color: Color(0xFFD32F2F),
          icon: Icons.close,
        );
      case DistanceStatus.ready:
        return _DirectionalArrowDot(
          trend: state.trend,
          isLeftSide: isLeftSide,
        );
    }
  }
}

class _RippleDot extends StatefulWidget {
  const _RippleDot();

  @override
  State<_RippleDot> createState() => _RippleDotState();
}

class _RippleDotState extends State<_RippleDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final size = 14.0 + (progress * 12.0);
          final opacity = (1 - progress).clamp(0.0, 1.0);
          const color = Color(0xFF7E57C2);

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.25 * opacity),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.color,
    this.icon,
    this.iconSize = 14,
  });

  final Color color;
  final IconData? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: icon != null
            ? Icon(
                icon,
                size: iconSize,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}

class _DirectionalArrowDot extends StatelessWidget {
  const _DirectionalArrowDot({
    required this.trend,
    required this.isLeftSide,
  });

  final DistanceTrend trend;
  final bool isLeftSide;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForTrend();
    final color = _trendColor(trend, context);

    if (iconData == null) {
      return _StatusDot(color: color);
    }

    return _StatusDot(
      color: color,
      icon: iconData,
      iconSize: 16,
    );
  }

  IconData? _iconForTrend() {
    if (trend == DistanceTrend.closer) {
      return isLeftSide ? Icons.chevron_right : Icons.chevron_left;
    }
    return isLeftSide ? Icons.chevron_left : Icons.chevron_right;
  }

  Color _trendColor(DistanceTrend trend, BuildContext context) {
    if (trend == DistanceTrend.closer) {
      return const Color(0xFF2E7D32);
    }
    return const Color(0xFFD81B60);
  }
}
