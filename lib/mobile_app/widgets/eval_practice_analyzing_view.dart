import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Pipeline stages shown during practice evaluation (UI only).
enum EvalAnalysisPipelineStage {
  uploading,
  qualityAnalysis,
  authenticityCheck,
  generatingFeedback,
}

/// Full-screen analyzing UI. [activeStage] null = indeterminate stage highlight (no fake %).
class EvalPracticeAnalyzingView extends StatefulWidget {
  const EvalPracticeAnalyzingView({
    super.key,
    required this.isVideo,
    this.activeStage,
  });

  final bool isVideo;

  /// When set (e.g. Gemini feedback), that stage stays active and prior stages show complete.
  final EvalAnalysisPipelineStage? activeStage;

  @override
  State<EvalPracticeAnalyzingView> createState() => _EvalPracticeAnalyzingViewState();
}

class _EvalPracticeAnalyzingViewState extends State<EvalPracticeAnalyzingView>
    with TickerProviderStateMixin {
  static const _stages = [
    (EvalAnalysisPipelineStage.uploading, 'Uploading', Icons.cloud_upload_outlined),
    (EvalAnalysisPipelineStage.qualityAnalysis, 'Quality Analysis', Icons.high_quality_outlined),
    (EvalAnalysisPipelineStage.authenticityCheck, 'Authenticity Check', Icons.verified_user_outlined),
    (EvalAnalysisPipelineStage.generatingFeedback, 'Generating Feedback', Icons.auto_awesome_outlined),
  ];

  late final AnimationController _pulse;
  late final AnimationController _orbit;
  AnimationController? _cycle;
  int _cycleIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _orbit = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))
      ..repeat();
    if (widget.activeStage == null) {
      _cycle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _cycleIndex = (_cycleIndex + 1) % _stages.length);
            _cycle!.forward(from: 0);
          }
        })
        ..forward();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _orbit.dispose();
    _cycle?.dispose();
    super.dispose();
  }

  int _indexForStage(EvalAnalysisPipelineStage stage) {
    return _stages.indexWhere((s) => s.$1 == stage).clamp(0, _stages.length - 1);
  }

  int get _activeIndex {
    final locked = widget.activeStage;
    if (locked != null) return _indexForStage(locked);
    return _cycleIndex;
  }

  bool _isComplete(int index) {
    final locked = widget.activeStage;
    if (locked == null) return false;
    return index < _activeIndex;
  }

  bool _isActive(int index) => index == _activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 28),
              Text(
                'Analyzing your media',
                textAlign: TextAlign.center,
                style: dashText(const TextStyle(
                  color: kTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                )),
              ),
              if (widget.isVideo) ...[
                const SizedBox(height: 8),
                Text(
                  'Video analysis may take a few minutes.',
                  textAlign: TextAlign.center,
                  style: memberDashboardMetaStyle.copyWith(fontSize: 13),
                ),
              ],
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: Listenable.merge([_pulse, _orbit]),
                builder: (_, __) {
                  final pulse = 0.85 + _pulse.value * 0.15;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kBorder),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withValues(alpha: 0.08 * pulse),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.06 * pulse),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kSurface,
                          kCyan.withValues(alpha: 0.04 + _pulse.value * 0.03),
                          kAccent.withValues(alpha: 0.03),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 88,
                          width: 88,
                          child: CustomPaint(
                            painter: _AnalysisOrbitPainter(spin: _orbit.value),
                            child: Center(
                              child: Icon(
                                Icons.insights_rounded,
                                size: 36,
                                color: Color.lerp(kAccent, kCyan, _pulse.value)!,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(_stages.length, (i) {
                          final stage = _stages[i];
                          final complete = _isComplete(i);
                          final active = _isActive(i);
                          return Padding(
                            padding: EdgeInsets.only(bottom: i < _stages.length - 1 ? 0 : 0),
                            child: _PipelineStageRow(
                              label: stage.$2,
                              icon: stage.$3,
                              complete: complete,
                              active: active,
                              pulse: active ? pulse : 1,
                              showConnector: i < _stages.length - 1,
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(flex: 3),
              Text(
                'Please keep the app open until analysis finishes.',
                textAlign: TextAlign.center,
                style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipelineStageRow extends StatelessWidget {
  const _PipelineStageRow({
    required this.label,
    required this.icon,
    required this.complete,
    required this.active,
    required this.pulse,
    required this.showConnector,
  });

  final String label;
  final IconData icon;
  final bool complete;
  final bool active;
  final double pulse;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final Color textColor;
    if (complete) {
      dotColor = kGreen;
      textColor = kTextSecondary;
    } else if (active) {
      dotColor = kAccent;
      textColor = kTextPrimary;
    } else {
      dotColor = kBorder;
      textColor = kTextSecondary.withValues(alpha: 0.85);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: active ? 32 : 28,
                  height: active ? 32 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: complete
                        ? kGreen.withValues(alpha: 0.12)
                        : active
                            ? kAccent.withValues(alpha: 0.12 * pulse)
                            : kBg,
                    border: Border.all(
                      color: complete
                          ? kGreen.withValues(alpha: 0.45)
                          : active
                              ? Color.lerp(kAccent, kCyan, 0.35)!.withValues(alpha: 0.55 * pulse)
                              : kBorder,
                      width: active ? 1.5 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: kCyan.withValues(alpha: 0.2 * pulse),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    complete ? Icons.check_rounded : icon,
                    size: complete ? 16 : (active ? 17 : 15),
                    color: dotColor,
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: complete ? kGreen.withValues(alpha: 0.35) : kBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: active ? 4 : 5, bottom: showConnector ? 14 : 4),
              child: Text(
                label,
                style: dashText(TextStyle(
                  color: textColor,
                  fontSize: active ? 15 : 14,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  height: 1.2,
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisOrbitPainter extends CustomPainter {
  _AnalysisOrbitPainter({required this.spin});

  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = kAccent.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    const dotCount = 3;
    for (var i = 0; i < dotCount; i++) {
      final angle = spin * 2 * math.pi + (i * 2 * math.pi / dotCount);
      final dotCenter = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      final color = i == 0
          ? kAccent
          : i == 1
              ? kCyan
              : const Color(0xFF7C3AED);
      canvas.drawCircle(dotCenter, 4.5, Paint()..color = color.withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(covariant _AnalysisOrbitPainter oldDelegate) => oldDelegate.spin != spin;
}
