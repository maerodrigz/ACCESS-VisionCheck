import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Animated overlay shown while EfficientNet-B0 and Gemini process media.
class AiProcessingOverlay extends StatefulWidget {
  const AiProcessingOverlay({
    super.key,
    required this.message,
    this.subtitle,
    this.activeStep = 1,
  });

  final String message;
  final String? subtitle;

  /// 1 = EfficientNet-B0 scoring, 2 = Gemini feedback generation.
  final int activeStep;

  @override
  State<AiProcessingOverlay> createState() => _AiProcessingOverlayState();
}

class _AiProcessingOverlayState extends State<AiProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          _PipelineSteps(activeStep: widget.activeStep),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final scale = 0.92 + _pulse.value * 0.08;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        kAccent.withValues(alpha: 0.15 + _pulse.value * 0.12),
                        kCyan.withValues(alpha: 0.12 + _pulse.value * 0.1),
                      ],
                    ),
                  ),
                  child: Icon(
                    widget.activeStep == 1 ? Icons.memory_rounded : Icons.psychology_rounded,
                    color: kAccent,
                    size: 34,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: kAccent),
          ),
        ],
      ),
    );
  }
}

class _PipelineSteps extends StatelessWidget {
  const _PipelineSteps({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StepTile(label: 'EfficientNet-B0', subtitle: 'Technical scores', step: 1, activeStep: activeStep)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: activeStep >= 2 ? kAccent : kBorder),
        ),
        Expanded(child: _StepTile(label: 'Gemini', subtitle: 'Human feedback', step: 2, activeStep: activeStep)),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.label,
    required this.subtitle,
    required this.step,
    required this.activeStep,
  });

  final String label;
  final String subtitle;
  final int step;
  final int activeStep;

  bool get _done => activeStep > step;
  bool get _active => activeStep == step;

  @override
  Widget build(BuildContext context) {
    final color = _done || _active ? kAccent : kTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _active ? kAccent.withValues(alpha: 0.1) : kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _active ? kAccent.withValues(alpha: 0.35) : kBorder),
      ),
      child: Column(
        children: [
          Icon(
            _done ? Icons.check_circle_rounded : (_active ? Icons.sync_rounded : Icons.radio_button_unchecked),
            size: 18,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: kTextSecondary, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
