import 'package:flutter/material.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Bar color by 0–100 score band.
Color criterionPercentColor(int percent) {
  if (percent >= 90) return kGreen;
  if (percent >= 75) return kBlue;
  if (percent >= 60) return kOrange;
  return kRed;
}

/// Animated progress bar for a single AI criterion (1–5 stored, 0–100 displayed).
class CriterionScoreBar extends StatefulWidget {
  const CriterionScoreBar({
    super.key,
    required this.criterion,
    this.animationDelay = Duration.zero,
    this.dense = false,
    this.horizontal = false,
  });

  final CriterionScore criterion;
  final Duration animationDelay;
  final bool dense;
  final bool horizontal;

  @override
  State<CriterionScoreBar> createState() => _CriterionScoreBarState();
}

class _CriterionScoreBarState extends State<CriterionScoreBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.animationDelay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.animationDelay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.horizontal) {
      return _buildHorizontalRow();
    }
    return _buildStackedRow();
  }

  Widget _buildStackedRow() {
    final percent = widget.criterion.percentScore;
    final barColor = criterionPercentColor(percent);
    final targetProgress = percent / 100;
    final explanation = _explanation;
    final barHeight = widget.dense ? 5.0 : 10.0;
    final nameSize = widget.dense ? 12.0 : 13.0;
    final scoreSize = widget.dense ? 11.0 : 13.0;
    final explanationSize = widget.dense ? 11.0 : 12.0;
    final rowGap = widget.dense ? 5.0 : 8.0;
    final bottomPad = widget.dense ? 10.0 : 16.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.criterion.name,
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: nameSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: widget.dense ? 6 : 8, vertical: widget.dense ? 2 : 3),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(widget.dense ? 6 : 8),
                ),
                child: Text(
                  '$percent',
                  style: TextStyle(color: barColor, fontSize: scoreSize, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          SizedBox(height: rowGap),
          _AnimatedBar(
            progress: _progress,
            targetProgress: targetProgress,
            barHeight: barHeight,
            barColor: barColor,
            dense: widget.dense,
            pill: false,
          ),
          SizedBox(height: widget.dense ? 4 : 6),
          Text(
            explanation,
            style: TextStyle(color: kTextSecondary, fontSize: explanationSize, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalRow() {
    final percent = widget.criterion.percentScore;
    final barColor = criterionPercentColor(percent);
    final targetProgress = percent / 100;
    final explanation = _explanation;
    final barHeight = widget.dense ? 5.0 : 10.0;
    final nameSize = widget.dense ? 12.0 : 13.0;
    final scoreSize = widget.dense ? 11.0 : 13.0;
    final explanationSize = widget.dense ? 11.0 : 12.0;
    final bottomPad = widget.dense ? 10.0 : 12.0;
    final labelWidth = widget.dense ? 108.0 : 118.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  widget.criterion.name,
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: nameSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _AnimatedBar(
                    progress: _progress,
                    targetProgress: targetProgress,
                    barHeight: barHeight,
                    barColor: barColor,
                    dense: widget.dense,
                    pill: true,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$percent',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: scoreSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: labelWidth, top: widget.dense ? 4 : 5),
            child: Text(
              explanation,
              style: TextStyle(color: kTextSecondary, fontSize: explanationSize, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  String get _explanation {
    final text = widget.criterion.explanation.trim();
    return text.isNotEmpty ? text : widget.criterion.label;
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({
    required this.progress,
    required this.targetProgress,
    required this.barHeight,
    required this.barColor,
    required this.dense,
    required this.pill,
  });

  final Animation<double> progress;
  final double targetProgress;
  final double barHeight;
  final Color barColor;
  final bool dense;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final radius = pill ? barHeight / 2 : (dense ? 4.0 : 6.0);

    return AnimatedBuilder(
      animation: progress,
      builder: (_, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              Container(
                height: barHeight,
                color: kBorder.withValues(alpha: pill ? 0.85 : 1),
              ),
              FractionallySizedBox(
                widthFactor: targetProgress * progress.value,
                child: Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Staggered list of criterion score bars in canonical order.
class CriterionScoresList extends StatelessWidget {
  const CriterionScoresList({
    super.key,
    required this.criteria,
    this.isVideo = false,
    this.staggerMs = 70,
    this.dense = false,
    this.horizontal = false,
  });

  final List<CriterionScore> criteria;
  final bool isVideo;
  final int staggerMs;
  final bool dense;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (criteria.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < criteria.length; i++)
          CriterionScoreBar(
            criterion: criteria[i],
            animationDelay: Duration(milliseconds: staggerMs * i),
            dense: dense,
            horizontal: horizontal,
          ),
      ],
    );
  }
}
