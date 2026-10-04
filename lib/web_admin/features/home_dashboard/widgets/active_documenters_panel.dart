import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/home_dashboard_models.dart';
import 'package:access_mobile/web_admin/features/home_dashboard/widgets/dashboard_card.dart';
import 'package:access_mobile/web_admin/navigation/admin_routes.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef HomeNavigate = void Function(AdminRoute route, {Map<String, dynamic>? params});

// Competency tier colors
const _colorAdvanced = Color(0xFF16A34A);   // green
const _colorDeveloping = Color(0xFF0052D4); // blue
const _colorAmateur = Color(0xFFF59E0B);    // amber

class ActiveDocumentersPanel extends StatefulWidget {
  const ActiveDocumentersPanel({
    super.key,
    required this.snapshot,
    required this.onNavigate,
  });

  final ActiveDocumenterSnapshot snapshot;
  final HomeNavigate onNavigate;

  @override
  State<ActiveDocumentersPanel> createState() => _ActiveDocumentersPanelState();
}

class _ActiveDocumentersPanelState extends State<ActiveDocumentersPanel> {
  int _touchedIndex = -1;

  static const _colors = [_colorAdvanced, _colorDeveloping, _colorAmateur];

  List<PieChartSectionData> _sections() {
    final snap = widget.snapshot;
    if (snap.breakdown.isEmpty) {
      return [
        PieChartSectionData(
          value: 1,
          color: AdminTheme.border,
          radius: _touchedIndex == 0 ? 38 : 32,
          title: '',
        ),
      ];
    }

    return snap.breakdown.asMap().entries.map((e) {
      final i = e.key;
      final b = e.value;
      final isTouched = i == _touchedIndex;
      return PieChartSectionData(
        value: b.count > 0 ? b.count.toDouble() : 0.001,
        color: _colors[i % _colors.length],
        radius: isTouched ? 40 : 32,
        title: '',
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: AdminTheme.cardShadow,
                ),
                child: Text(
                  '${b.percent.toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _colors[i % _colors.length],
                  ),
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot;

    return HomeDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionHeader(
            title: 'Active Documenters',
            subtitle: 'Member activity and competency levels.',
            icon: Icons.groups_outlined,
            iconColor: AdminTheme.accentBlue,
            trailing: HomeTextButton(
              label: 'View all',
              icon: Icons.chevron_right_rounded,
              onPressed: () => widget.onNavigate(AdminRoute.rankings),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Donut chart
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: _sections(),
                        centerSpaceRadius: 34,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (response?.touchedSection != null) {
                              setState(() {
                                _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                              });
                            } else {
                              setState(() => _touchedIndex = -1);
                            }
                          },
                        ),
                      ),
                    ),
                    // Center label
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${snap.totalActive}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AdminTheme.textPrimary,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Active\nMembers',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: AdminTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Breakdown list
              Expanded(
                child: snap.breakdown.isEmpty
                    ? const Text(
                        'No members yet.',
                        style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: snap.breakdown.asMap().entries.map((e) {                          final i = e.key;
                          final b = e.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _BreakdownRow(
                              label: b.label,
                              count: b.count,
                              percent: b.percent,
                              color: _colors[i % _colors.length],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });

  final String label;
  final int count;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AdminTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AdminTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${percent.toInt()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: AdminTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
