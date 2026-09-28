import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/analytics/analytics_compute.dart';
import 'package:access_mobile/web_admin/features/analytics/widgets/analytics_layout.dart';

/// Screenshot-matched palette (#3b82f6 family).
abstract final class AnalyticsChartColors {
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const purple = Color(0xFF8B5CF6);
  static const orange = Color(0xFFF59E0B);
  static const insightsBg = Color(0xFFF5F3FF);
}

class FlRequestsLineChart extends StatelessWidget {
  const FlRequestsLineChart({
    super.key,
    required this.requests,
    required this.completions,
  });

  final List<(DateTime, int)> requests;
  final List<(DateTime, int)> completions;

  @override
  Widget build(BuildContext context) {
    final len = math.max(requests.length, completions.length);
    if (len == 0) {
      return const Center(child: Text('No data', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))));
    }

    final maxY = _niceMax([
      ...requests.map((e) => e.$2),
      ...completions.map((e) => e.$2),
    ]);

    final reqSpots = _spots(requests);
    final compSpots = _spots(completions);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxY / 4,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= requests.length) return const SizedBox.shrink();
                if (!_showTick(i, requests.length)) return const SizedBox.shrink();
                final d = requests[i].$1;
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${months[d.month - 1]} ${d.day}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: reqSpots,
            isCurved: false,
            color: AnalyticsChartColors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: compSpots,
            isCurved: false,
            color: AnalyticsChartColors.green,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
      duration: Duration.zero,
    );
  }

  List<FlSpot> _spots(List<(DateTime, int)> series) {
    return List.generate(series.length, (i) => FlSpot(i.toDouble(), series[i].$2.toDouble()));
  }

  bool _showTick(int i, int len) {
    if (len <= 6) return true;
    final step = (len / 5).ceil();
    return i % step == 0 || i == len - 1;
  }

  double _niceMax(List<int> values) {
    if (values.isEmpty) return 4;
    final m = values.reduce(math.max).toDouble();
    if (m <= 4) return 4;
    if (m <= 10) return 10;
    if (m <= 20) return 20;
    if (m <= 40) return 40;
    return (m / 10).ceil() * 10;
  }
}

class FlDonutChart extends StatelessWidget {
  const FlDonutChart({
    super.key,
    required this.segments,
    required this.centerValue,
    required this.centerLabel,
    this.size = 120,
    this.compactCenter = false,
  });

  final List<ChartSegment> segments;
  final String centerValue;
  final String centerLabel;
  final double size;

  /// Smaller center text — used by request-status card (unchanged layout).
  final bool compactCenter;

  @override
  Widget build(BuildContext context) {
    final sections = segments
        .where((s) => s.value > 0)
        .map(
          (s) => PieChartSectionData(
            value: s.value,
            color: Color(s.color),
            radius: size * 0.38,
            showTitle: false,
          ),
        )
        .toList();

    if (sections.isEmpty) {
      sections.add(PieChartSectionData(value: 1, color: const Color(0xFFE2E8F0), radius: size * 0.38, showTitle: false));
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: size * 0.32,
              sections: sections,
              startDegreeOffset: -90,
            ),
            duration: Duration.zero,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: compactCenter ? 20 : 22,
                  color: const Color(0xFF0F172A),
                  height: 1,
                ),
              ),
              Text(
                centerLabel,
                style: TextStyle(fontSize: compactCenter ? 10 : 11, color: const Color(0xFF64748B), height: 1.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

(String, String) _splitQualityLabel(String label) {
  final open = label.indexOf('(');
  if (open < 0) return (label, '');
  final title = label.substring(0, open).trim();
  final subtitle = label.substring(open).trim().replaceAll('>=', '≥');
  return (title, subtitle);
}

List<PieChartSectionData> _donutSections(
  List<ChartSegment> segments,
  double chartSize, {
  bool pctOneDecimal = false,
}) {
  final outerR = chartSize * 0.46;
  final total = segments.fold<double>(0, (s, e) => s + e.value);
  final sections = segments
      .where((s) => s.value > 0)
      .map((s) {
        final pct = total > 0 ? (s.value / total) * 100 : 0.0;
        final title = pctOneDecimal ? '${pct.toStringAsFixed(1)}%' : '${pct.round()}%';
        return PieChartSectionData(
          value: s.value,
          color: Color(s.color),
          radius: outerR,
          title: title,
          titleStyle: TextStyle(fontSize: chartSize * 0.095, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
          titlePositionPercentageOffset: 0.55,
          borderSide: const BorderSide(color: Colors.white, width: 2),
        );
      })
      .toList();
  if (sections.isEmpty) {
    sections.add(PieChartSectionData(value: 1, color: const Color(0xFFE2E8F0), radius: outerR, showTitle: false));
  }
  return sections;
}

Widget _donutCenter(String value, String label, {required double chartSize}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: chartSize * 0.2, color: const Color(0xFF0F172A), height: 1),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(fontSize: chartSize * 0.105, color: const Color(0xFF64748B), height: 1.2),
      ),
    ],
  );
}

Widget _compactDonut({
  required double chartSize,
  required List<PieChartSectionData> sections,
  required String centerValue,
  required String centerLabel,
}) {
  return SizedBox(
    width: chartSize,
    height: chartSize,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.hardEdge,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 0,
            centerSpaceRadius: chartSize * 0.30,
            sections: sections,
            startDegreeOffset: -90,
          ),
          duration: Duration.zero,
        ),
        _donutCenter(centerValue, centerLabel, chartSize: chartSize),
      ],
    ),
  );
}

Widget _legendSwatch(int color) {
  return Container(
    width: 10,
    height: 10,
    margin: const EdgeInsets.only(top: 2),
    decoration: BoxDecoration(color: Color(color), borderRadius: BorderRadius.circular(2)),
  );
}

/// Donut + two-line square legend — Media Quality card only.
class FlMediaQualityPanel extends StatelessWidget {
  const FlMediaQualityPanel({super.key, required this.segments, required this.centerValue});

  final List<ChartSegment> segments;
  final String centerValue;

  static const _chartSize = 92.0;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    final sections = _donutSections(segments, _chartSize);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _compactDonut(
          chartSize: _chartSize,
          sections: sections,
          centerValue: centerValue,
          centerLabel: 'Total Media',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _mediaLegendRow(segments[i], total),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _mediaLegendRow(ChartSegment seg, double total) {
    final pct = total > 0 ? ((seg.value / total) * 100).round() : 0;
    final count = seg.value.round();
    final (title, subtitle) = _splitQualityLabel(seg.label);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legendSwatch(seg.color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.25)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.25)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), height: 1.25)),
            Text('$count', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.25)),
          ],
        ),
      ],
    );
  }
}

/// Donut left + legend right — Skill Level card only.
class FlSkillLevelPanel extends StatelessWidget {
  const FlSkillLevelPanel({super.key, required this.segments, required this.centerValue});

  final List<ChartSegment> segments;
  final String centerValue;

  static const _chartSize = 92.0;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    final sections = _donutSections(segments, _chartSize, pctOneDecimal: true);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _compactDonut(
          chartSize: _chartSize,
          sections: sections,
          centerValue: centerValue,
          centerLabel: 'Members',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _skillLegendRow(segments[i], total),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _skillLegendRow(ChartSegment seg, double total) {
    final pct = total > 0 ? (seg.value / total) * 100 : 0.0;
    final count = seg.value.round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legendSwatch(seg.color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(seg.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.25)),
            Text(
              '$count (${pct.toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.25),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryGridPainter extends CustomPainter {
  const _CategoryGridPainter({required this.divisions});

  final int divisions;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (var i = 1; i <= divisions; i++) {
      final x = size.width * i / divisions;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryGridPainter old) => old.divisions != divisions;
}

class FlCategoryBarChartWithLabels extends StatelessWidget {
  const FlCategoryBarChartWithLabels({super.key, required this.bars});

  final List<(String, int)> bars;

  static const _labelWidth = 108.0;
  static const _valueWidth = 76.0;
  static const _barHeight = 12.0;
  static const _rowGap = 16.0;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const Center(child: Text('No requests', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))));
    }
    final total = bars.fold<int>(0, (s, e) => s + e.$2);
    final maxVal = bars.map((e) => e.$2).reduce(math.max).toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, count) in bars)
          Padding(
            padding: const EdgeInsets.only(bottom: _rowGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Text(
                    label,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155), height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final fillW = maxVal > 0 ? (count / maxVal) * c.maxWidth : 0.0;
                      return SizedBox(
                        height: _barHeight,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            CustomPaint(
                              size: Size(c.maxWidth, _barHeight),
                              painter: const _CategoryGridPainter(divisions: 4),
                            ),
                            Container(
                              height: _barHeight,
                              width: fillW,
                              decoration: const BoxDecoration(
                                color: AnalyticsChartColors.blue,
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: _valueWidth,
                  child: Text(
                    total > 0 ? '$count (${(count / total * 100).toStringAsFixed(1)}%)' : '$count',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class FlQualityAreaChart extends StatelessWidget {
  const FlQualityAreaChart({super.key, required this.points});

  final List<(DateTime, double)> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const Center(child: Text('Not enough evaluations', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))));
    }

    final minY = points.map((e) => e.$2).reduce(math.min) - 2;
    final maxY = points.map((e) => e.$2).reduce(math.max) + 2;
    final spots = List.generate(points.length, (i) => FlSpot(i.toDouble(), points[i].$2));

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: AnalyticsChartColors.blue,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 4, color: AnalyticsChartColors.blue, strokeWidth: 2, strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AnalyticsChartColors.blue.withValues(alpha: 0.25), AnalyticsChartColors.blue.withValues(alpha: 0.02)],
              ),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          extraLinesOnTop: true,
          horizontalLines: [],
        ),
      ),
      duration: Duration.zero,
    );
  }
}

/// Legend with colored square + label + pct + count (media quality style).
class FlChartLegend extends StatelessWidget {
  const FlChartLegend({
    super.key,
    required this.segments,
    this.showCounts = false,
    this.useSquare = false,
  });

  final List<ChartSegment> segments;
  final bool showCounts;
  final bool useSquare;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: segments.map((seg) {
        final pct = total > 0 ? ((seg.value / total) * 100).toStringAsFixed(0) : '0';
        final count = seg.value.round();
        final text = showCounts ? '${seg.label}\n$pct% ($count)' : '${seg.label} ($pct%)';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: Color(seg.color),
                  shape: useSquare ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: useSquare ? BorderRadius.circular(2) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.3))),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class AnalyticsLegendDot extends StatelessWidget {
  const AnalyticsLegendDot({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }
}

class AnalyticsChartCard extends StatelessWidget {
  const AnalyticsChartCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.expand = true,
    this.backgroundColor = Colors.white,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool expand;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AnalyticsLayout.cardPadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AnalyticsLayout.cardRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: AnalyticsLayout.cardTitleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: AnalyticsLayout.headerGap),
          if (expand) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class AnalyticsKpiCard extends StatelessWidget {
  const AnalyticsKpiCard({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.trend,
    this.suffix = '',
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final double trend;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final up = trend >= 0;
    return Container(
      height: AnalyticsLayout.kpiHeight,
      padding: AnalyticsLayout.cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AnalyticsLayout.cardRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '$value$suffix',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF0F172A), height: 1),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: AnalyticsChartColors.green),
              const SizedBox(width: 3),
              Text(
                '${up ? '+' : ''}${trend.abs().toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AnalyticsChartColors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
