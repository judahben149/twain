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
      width: 24,
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final size = 10.0 + (progress * 10.0);
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
                width: 10,
                height: 10,
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
    this.iconSize = 12,
  });

  final Color color;
  final IconData? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Container(
          width: 20,
          height: 20,
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
      ),
    );
  }
}

class _DirectionalArrowDot extends StatefulWidget {
  const _DirectionalArrowDot({
    required this.trend,
    required this.isLeftSide,
  });

  final DistanceTrend trend;
  final bool isLeftSide;

  @override
  State<_DirectionalArrowDot> createState() => _DirectionalArrowDotState();
}

class _DirectionalArrowDotState extends State<_DirectionalArrowDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _rotationAnimation;
  DistanceTrend? _previousTrend;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_DirectionalArrowDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trend != widget.trend) {
      _animateArrow();
    }
  }

  void _animateArrow() {
    // Calculate rotation based on trend change
    // Closer = pointing inward (right for left side, left for right side)
    // Apart = pointing outward (left for left side, right for right side)
    final isCloser = widget.trend == DistanceTrend.closer;

    // Target rotation: 0 = pointing inward, pi = pointing outward
    final targetRotation = isCloser ? 0.0 : 3.14159;
    final currentRotation = _rotationAnimation.value;

    _rotationAnimation = Tween<double>(
      begin: currentRotation,
      end: targetRotation,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward(from: 0);
    _previousTrend = widget.trend;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _trendColor(widget.trend);
    final isCloser = widget.trend == DistanceTrend.closer;

    // Base icon pointing inward (toward center)
    final baseIcon = widget.isLeftSide ? Icons.chevron_right : Icons.chevron_left;

    return SizedBox(
      width: 24,
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Icon(
                baseIcon,
                size: 16,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _trendColor(DistanceTrend trend) {
    if (trend == DistanceTrend.closer) {
      return const Color(0xFF2E7D32);
    }
    return const Color(0xFFD81B60);
  }
}
