import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/competency_management/competency_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class CompetencyLevelBadge extends StatelessWidget {
  const CompetencyLevelBadge({
    super.key,
    required this.level,
    this.overridden = false,
    this.compact = false,
  });

  final CompetencyLevel level;
  final bool overridden;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: level.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            level.label,
            style: TextStyle(fontSize: compact ? 10 : 11, fontWeight: FontWeight.w700, color: level.color),
          ),
          if (overridden) ...[
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: compact ? 10 : 11, color: level.color),
          ],
        ],
      ),
    );
  }
}

class EventRecommendationBadge extends StatelessWidget {
  const EventRecommendationBadge({super.key, required this.recommendation});

  final EventScaleRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminTheme.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.accentBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_outlined, size: 14, color: AdminTheme.accentBlue),
          const SizedBox(width: 6),
          Text(
            'Recommended for: ${recommendation.label}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminTheme.accentBlue),
          ),
        ],
      ),
    );
  }
}

class CompetencyProgressBar extends StatelessWidget {
  const CompetencyProgressBar({
    super.key,
    required this.label,
    required this.value,
    this.max = 100,
    this.suffix = '%',
  });

  final String label;
  final double value;
  final double max;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final pct = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary))),
            Text('${value.round()}$suffix', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: AdminTheme.border,
            color: AdminTheme.accentBlue,
          ),
        ),
      ],
    );
  }
}
