import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/eval_ai_chip_illustration.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';

enum EvalProcessingPhase { scoring, gemini }

/// Full-screen AI processing UI with animated chip, stages, and ETA.
class EvalAiProcessingView extends StatefulWidget {
  const EvalAiProcessingView({
    super.key,
    required this.isVideo,
    required this.phase,
  });

  final bool isVideo;
  final EvalProcessingPhase phase;

  static const _photoStages = [
    'Analyzing Sharpness…',
    'Analyzing Blur…',
    'Analyzing Noise…',
    'Analyzing Brightness…',
    'Analyzing Contrast…',
    'Analyzing Blocking Artifacts…',
    'Analyzing Ringing Artifacts…',
  ];

  static const _videoExtraStages = [
    'Analyzing Flickering…',
    'Analyzing Motion Stability…',
  ];

  static const _geminiStage = 'Preparing Gemini Feedback…';

  @override
  State<EvalAiProcessingView> createState() => _EvalAiProcessingViewState();
}

class _EvalAiProcessingViewState extends State<EvalAiProcessingView> with TickerProviderStateMixin {
  static const _stageDuration = Duration(milliseconds: 1650);
  static const _geminiEstimateSeconds = 10;
  static const _scoringProgressCap = 0.82;

  late final AnimationController _bgPulse;
  late final AnimationController _ringSpin;
  late final AnimationController _progressSmooth;

  Timer? _stageTimer;
  Timer? _etaTimer;
  int _stageIndex = 0;
  int _secondsRemaining = 0;
  DateTime? _geminiStartedAt;
  List<String> _stages = const [];

  int get _geminiStageIndex => _stages.length - 1;
  int get _scoringStageCount => _geminiStageIndex;

  @override
  void initState() {
    super.initState();
    _stages = _buildStages();
    _secondsRemaining = _estimateScoringSeconds();

    _bgPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();
    _ringSpin = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
    _progressSmooth = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _stageTimer = Timer.periodic(_stageDuration, (_) => _advanceStage());
    _etaTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickEta());
    _updateProgress(animate: false);
  }

  @override
  void didUpdateWidget(EvalAiProcessingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase && widget.phase == EvalProcessingPhase.gemini) {
      _enterGeminiPhase();
    }
  }

  List<String> _buildStages() {
    final list = [...EvalAiProcessingView._photoStages];
    if (widget.isVideo) list.addAll(EvalAiProcessingView._videoExtraStages);
    list.add(EvalAiProcessingView._geminiStage);
    return list;
  }

  int _estimateScoringSeconds() {
    return (_scoringStageCount * _stageDuration.inMilliseconds / 1000).ceil();
  }

  void _advanceStage() {
    if (!mounted) return;
    if (widget.phase == EvalProcessingPhase.gemini) return;
    if (_stageIndex >= _scoringStageCount - 1) return;
    setState(() => _stageIndex++);
    _updateProgress();
    _syncEtaFromPhase();
  }

  void _enterGeminiPhase() {
    _geminiStartedAt ??= DateTime.now();
    if (_stageIndex != _geminiStageIndex) {
      setState(() => _stageIndex = _geminiStageIndex);
    }
    _syncEtaFromPhase();
    _updateProgress();
  }

  void _tickEta() {
    if (!mounted) return;
    _syncEtaFromPhase();
    if (widget.phase == EvalProcessingPhase.gemini) {
      _updateProgress();
    }
  }

  void _syncEtaFromPhase() {
    if (widget.phase == EvalProcessingPhase.gemini) {
      final started = _geminiStartedAt ?? DateTime.now();
      final elapsed = DateTime.now().difference(started).inSeconds;
      final next = (_geminiEstimateSeconds - elapsed).clamp(0, _geminiEstimateSeconds);
      if (next != _secondsRemaining) {
        setState(() => _secondsRemaining = next);
      }
      return;
    }

    final remainingStages = (_scoringStageCount - _stageIndex - 1).clamp(0, _scoringStageCount);
    final next = ((remainingStages + 1) * _stageDuration.inMilliseconds / 1000).ceil();
    if (next != _secondsRemaining) {
      setState(() => _secondsRemaining = next);
    }
  }

  double _targetProgress() {
    if (widget.phase == EvalProcessingPhase.gemini) {
      final started = _geminiStartedAt ?? DateTime.now();
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      final geminiSpan = _geminiEstimateSeconds * 1000;
      final geminiRatio = (elapsed / geminiSpan).clamp(0.0, 1.0);
      return (_scoringProgressCap + geminiRatio * (0.98 - _scoringProgressCap)).clamp(0.0, 0.98);
    }

    if (_scoringStageCount <= 0) return 0.1;
    final scoringRatio = (_stageIndex + 1) / _scoringStageCount;
    return (scoringRatio * _scoringProgressCap).clamp(0.08, _scoringProgressCap);
  }

  void _updateProgress({bool animate = true}) {
    final target = _targetProgress();
    if (animate) {
      _progressSmooth.animateTo(target);
    } else {
      _progressSmooth.value = target;
    }
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _etaTimer?.cancel();
    _bgPulse.dispose();
    _ringSpin.dispose();
    _progressSmooth.dispose();
    super.dispose();
  }

  String get _etaLabel {
    if (widget.phase == EvalProcessingPhase.gemini) {
      if (_secondsRemaining <= 0) return 'Finishing feedback…';
      if (_secondsRemaining < 60) return '~$_secondsRemaining sec for feedback';
      final m = (_secondsRemaining / 60).ceil();
      return '~$m min for feedback';
    }
    if (_secondsRemaining <= 0) return 'Scoring complete…';
    if (_secondsRemaining < 60) return '~$_secondsRemaining sec scoring';
    final m = (_secondsRemaining / 60).ceil();
    return '~$m min scoring';
  }

  @override
  Widget build(BuildContext context) {
    final stageLabel = _stages[_stageIndex.clamp(0, _stages.length - 1)];

    return AnimatedBuilder(
      animation: _bgPulse,
      builder: (_, __) {
        final pulse = 0.5 + 0.5 * math.sin(_bgPulse.value * math.pi * 2);
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kEvalBg,
                Color.lerp(kEvalPrimaryLight, kEvalBg, 0.35 + pulse * 0.15)!,
                kEvalSecondaryLight.withValues(alpha: 0.45 + pulse * 0.12),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'AI Processing',
                    style: dashText(const TextStyle(
                      color: kDashTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    )),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isVideo ? 'Evaluating your video' : 'Evaluating your photo',
                    style: evalBodyStyle.copyWith(fontSize: 14),
                  ),
                  const Spacer(flex: 2),
                  const EvalAiChipIllustration(size: 148),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_ringSpin, _progressSmooth]),
                      builder: (_, __) {
                        return CustomPaint(
                          painter: _ProcessingRingPainter(
                            progress: _progressSmooth.value,
                            spin: _ringSpin.value,
                            pulse: pulse,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(_progressSmooth.value * 100).round()}%',
                                  style: dashText(const TextStyle(
                                    color: kDashTextPrimary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  )),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Complete',
                                  style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Spacer(flex: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      stageLabel,
                      key: ValueKey(stageLabel),
                      textAlign: TextAlign.center,
                      style: dashText(const TextStyle(
                        color: kEvalSecondary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      )),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StageDots(
                    total: _stages.length,
                    activeIndex: _stageIndex,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kEvalPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _etaLabel,
                          key: ValueKey(_etaLabel),
                          style: evalBodyStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StageDots extends StatelessWidget {
  const _StageDots({required this.total, required this.activeIndex});

  final int total;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final visible = total.clamp(0, 9);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(visible, (i) {
        final active = i <= activeIndex.clamp(0, visible - 1);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: active ? kEvalPrimary : kEvalPrimary.withValues(alpha: 0.22),
          ),
        );
      }),
    );
  }
}

class _ProcessingRingPainter extends CustomPainter {
  _ProcessingRingPainter({
    required this.progress,
    required this.spin,
    required this.pulse,
  });

  final double progress;
  final double spin;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const stroke = 9.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = kEvalPrimary.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          colors: [kEvalPrimary, kEvalSecondary, kEvalPrimary],
          transform: GradientRotation(spin * 2 * math.pi),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // Outer glow ring
    canvas.drawCircle(
      center,
      radius + 6,
      Paint()
        ..color = kEvalSecondary.withValues(alpha: 0.08 + pulse * 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ProcessingRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.spin != spin || oldDelegate.pulse != pulse;
}
