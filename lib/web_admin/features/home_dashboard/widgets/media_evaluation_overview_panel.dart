import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/dashboard_card.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef HomeNavigate = void Function(AdminRoute route, {Map<String, dynamic>? params});

class MediaEvaluationOverviewPanel extends StatelessWidget {
  const MediaEvaluationOverviewPanel({
    super.key,
    required this.stats,
    required this.onNavigate,
  });

  final EvalOverviewStats stats;
  final HomeNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionHeader(
            title: 'Media Evaluation Overview',
            subtitle: 'Evaluation results for recent uploads.',
            icon: Icons.analytics_outlined,
            iconColor: AdminTheme.accentBlue,
            trailing: HomeTextButton(
              label: 'Last 7 days',
              icon: Icons.expand_more_rounded,
              onPressed: () => onNavigate(AdminRoute.mediaEvaluation),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (ctx, c) {
              final cols = c.maxWidth >= 500 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: cols == 4 ? 1.4 : 1.6,
                children: [
                  _EvalStatTile(
                    icon: Icons.photo_library_outlined,
                    iconColor: AdminTheme.accentBlue,
                    label: 'Evaluated',
                    value: stats.evaluated,
                    trend: stats.evaluatedTrend,
                  ),
                  _EvalStatTile(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AdminTheme.success,
                    label: 'Good Quality',
                    value: stats.goodQuality,
                    trend: stats.goodQualityTrend,
                  ),
                  _EvalStatTile(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AdminTheme.warning,
                    label: 'Needs Improvement',
                    value: stats.needsImprovement,
                    trend: stats.needsImprovementTrend,
                    invertTrend: true,
                  ),
                  _EvalStatTile(
                    icon: Icons.smart_toy_outlined,
                    iconColor: AdminTheme.danger,
                    label: 'AI Risk Flagged',
                    value: stats.aiFlagged,
                    trend: stats.aiFlaggedTrend,
                    invertTrend: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EvalStatTile extends StatelessWidget {
  const _EvalStatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.trend,
    this.invertTrend = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final int value;
  final double trend;
  final bool invertTrend;

  bool get _isPositive => invertTrend ? trend < 0 : trend >= 0;
  bool get _isNeutral => trend == 0;

  Color get _trendColor {
    if (_isNeutral) return AdminTheme.textSecondary;
    return _isPositive ? AdminTheme.success : AdminTheme.danger;
  }

  IconData get _trendIcon {
    if (_isNeutral) return Icons.remove;
    return (invertTrend ? trend < 0 : trend > 0)
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
  }

  String get _trendLabel {
    if (_isNeutral) return '0%';
    final abs = trend.abs();
    return '${abs.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AdminTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AdminTheme.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(_trendIcon, size: 12, color: _trendColor),
              const SizedBox(width: 2),
              Text(
                _trendLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _trendColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
