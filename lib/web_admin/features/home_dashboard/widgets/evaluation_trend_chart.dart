import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/dashboard_card.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef HomeNavigate = void Function(AdminRoute route, {Map<String, dynamic>? params});

class EvaluationTrendChart extends StatelessWidget {
  const EvaluationTrendChart({
    super.key,
    required this.points,
    required this.onNavigate,
  });

  final List<EvaluationTrendPoint> points;
  final HomeNavigate onNavigate;

  static const _colorEvaluated = Color(0xFF0052D4);
  static const _colorGood = Color(0xFF16A34A);
  static const _colorNeeds = Color(0xFFF59E0B);
  static const _colorAi = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionHeader(
            title: 'Evaluation Trend',
            subtitle: 'Media evaluation count (last 7 days).',
            icon: Icons.show_chart_rounded,
            iconColor: AdminTheme.accentBlue,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'No evaluation data yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AdminTheme.textSecondary,
                      ),
                    ),
                  )
                : _TrendLineChart(points: points),
          ),
          const SizedBox(height: 14),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _LegendDot(color: _colorEvaluated, label: 'Evaluated'),
              _LegendDot(color: _colorGood, label: 'Good Quality'),
              _LegendDot(color: _colorNeeds, label: 'Needs Improvement'),
              _LegendDot(color: _colorAi, label: 'AI Flagged'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendLineChart extends StatefulWidget {
  const _TrendLineChart({required this.points});

  final List<EvaluationTrendPoint> points;

  @override
  State<_TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<_TrendLineChart> {
  int? _touchedIndex;

  double get _maxY {
    double max = 10;
    for (final p in widget.points) {
      final vals = [p.evaluated, p.goodQuality, p.needsImprovement, p.aiFlagged];
      for (final v in vals) {
        if (v > max) max = v.toDouble();
      }
    }
    return (max * 1.25).ceilToDouble();
  }

  List<FlSpot> _spots(int Function(EvaluationTrendPoint) selector) {
    return widget.points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), selector(e.value).toDouble()))
        .toList();
  }

  LineChartBarData _line(
    List<FlSpot> spots,
    Color color, {
    bool dashed = false,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: _touchedIndex == index ? 5 : 3,
          color: color,
          strokeWidth: 2,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.06),
      ),
      dashArray: dashed ? [4, 4] : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    final maxY = _maxY;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (event is FlPointerHoverEvent && response?.lineBarSpots != null) {
              setState(() => _touchedIndex = response!.lineBarSpots!.first.spotIndex);
            } else if (event is FlPointerExitEvent) {
              setState(() => _touchedIndex = null);
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E293B),
            getTooltipItems: (spots) => spots.map((s) {
              const labels = ['Evaluated', 'Good', 'Needs', 'AI'];
              const colors = [
                Color(0xFF0052D4),
                Color(0xFF16A34A),
                Color(0xFFF59E0B),
                Color(0xFFDC2626),
              ];
              final i = s.barIndex.clamp(0, 3);
              return LineTooltipItem(
                '${labels[i]}: ${s.y.toInt()}',
                TextStyle(
                  color: colors[i],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AdminTheme.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AdminTheme.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= pts.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    pts[idx].dateLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          _line(_spots((p) => p.evaluated), const Color(0xFF0052D4)),
          _line(_spots((p) => p.goodQuality), const Color(0xFF16A34A)),
          _line(_spots((p) => p.needsImprovement), const Color(0xFFF59E0B)),
          _line(_spots((p) => p.aiFlagged), const Color(0xFFDC2626), dashed: true),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AdminTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
