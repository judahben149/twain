import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/models/distance_state.dart';
import 'package:twain/providers/location_providers.dart';

class DistanceMeterWidget extends ConsumerWidget {
  const DistanceMeterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(distanceStateProvider);

    if (state.status == DistanceStatus.hidden) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final color = _colorForState(state, theme);
    final text = _textForState(state);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _textForState(DistanceState state) {
    switch (state.status) {
      case DistanceStatus.ready:
        return state.formatDistance();
      case DistanceStatus.waitingForPartner:
        if (state.distanceMeters != null) {
          return state.formatDistance();
        }
        return '--';
      case DistanceStatus.acquiring:
        return '--';
      case DistanceStatus.hidden:
        return '';
    }
  }

  Color _colorForState(DistanceState state, ThemeData theme) {
    switch (state.status) {
      case DistanceStatus.ready:
        return _trendColor(state.trend, theme);
      case DistanceStatus.waitingForPartner:
        return const Color(0xFFD32F2F);
      case DistanceStatus.acquiring:
        return const Color(0xFF7E57C2);
      case DistanceStatus.hidden:
        return theme.colorScheme.onSurface.withOpacity(0.4);
    }
  }

  Color _trendColor(DistanceTrend trend, ThemeData theme) {
    switch (trend) {
      case DistanceTrend.closer:
        return const Color(0xFF2E7D32);
      case DistanceTrend.apart:
        return const Color(0xFFD81B60);
    }
  }
}
