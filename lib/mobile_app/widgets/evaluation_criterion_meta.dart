import 'package:flutter/material.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';

class CriterionMeta {
  const CriterionMeta({
    required this.icon,
    required this.description,
  });

  final IconData icon;
  final String description;
}

/// Short member-facing note for technical quality sections.
const kFiveLevelCriteriaIntro =
    'Each criterion is a five-level experimental estimate (1 to 5), not a precise percentage.';

/// Short note under overall /100 scores.
const kOverallFromFiveLevelNote =
    'Overall /100 is the average of available five-level criteria, shown on a 0–100 scale for compatibility.';

const kCriterionMeta = <String, CriterionMeta>{
  'Sharpness': CriterionMeta(
    icon: Icons.center_focus_strong_rounded,
    description: 'Estimates how crisp and well-focused the subject appears.',
  ),
  'Blur': CriterionMeta(
    icon: Icons.blur_off_rounded,
    description: 'Estimates motion or focus blur that reduces clarity.',
  ),
  'Brightness': CriterionMeta(
    icon: Icons.wb_sunny_outlined,
    description: 'Estimates whether exposure is balanced across the scene.',
  ),
  'Contrast': CriterionMeta(
    icon: Icons.contrast_rounded,
    description: 'Estimates tonal separation between light and dark areas.',
  ),
  'Blocking Artifacts': CriterionMeta(
    icon: Icons.grid_view_rounded,
    description: 'Looks for compression block patterns from heavy encoding.',
  ),
  'Color Balance': CriterionMeta(
    icon: Icons.wb_twilight_rounded,
    description:
        'Experimental heuristic for color cast strength. Not a measure of artistic quality or perfect color.',
  ),
  'Color Saturation': CriterionMeta(
    icon: Icons.palette_outlined,
    description:
        'Experimental heuristic for color intensity. Not artistic quality; muted or grayscale looks may show N/A.',
  ),
  // Historical criteria (older evaluations).
  'Noise': CriterionMeta(
    icon: Icons.grain_rounded,
    description: 'Historical criterion. Evaluates visible grain or digital noise.',
  ),
  'Ringing Artifacts': CriterionMeta(
    icon: Icons.waves_rounded,
    description: 'Historical criterion. Detects edge halos from sharpening or compression.',
  ),
  'Motion Stability': CriterionMeta(
    icon: Icons.video_stable_rounded,
    description:
        'Uses changes in frame sharpness as a proxy for camera steadiness. Experimental estimate.',
  ),
  'Flickering': CriterionMeta(
    icon: Icons.flare_rounded,
    description:
        'Uses changes in frame brightness as a proxy for lighting flicker. Experimental estimate.',
  ),
};

CriterionMeta criterionMetaFor(CriterionScore criterion) =>
    kCriterionMeta[criterion.name] ??
    CriterionMeta(
      icon: Icons.analytics_outlined,
      description: 'Technical quality metric for ${criterion.name.toLowerCase()}.',
    );

/// Maps backend quality labels to the three display buckets.
String qualityDisplayBucket(String? level) {
  final normalized = (level ?? '').trim().toLowerCase();
  if (normalized.contains('excellent')) return 'Excellent';
  if (normalized == 'good' || normalized == 'fair') return 'Good';
  return 'Needs Improvement';
}

Color qualityBucketColor(String bucket) => switch (bucket) {
      'Excellent' => const Color(0xFF22C55E),
      'Good' => kAccent,
      _ => const Color(0xFFF97316),
    };

/// Overall 0–100 band colors aligned with backend 1–5 thresholds (2.5 / 3.5 / 4.5).
Color qualityPercentBandColor(int percent) {
  if (percent >= 90) return kGreen;
  if (percent >= 70) return kBlue;
  if (percent >= 50) return kOrange;
  return kRed;
}

/// Color for an individual 1–5 criterion (Poor / Fair / Good / Excellent bands).
Color criterionLevelColor(int score) {
  if (score >= 5) return kGreen;
  if (score >= 4) return kBlue;
  if (score >= 3) return kOrange;
  return kRed;
}

const kQualityPercentLegend = [
  (color: kRed, label: 'Poor', range: '0–59'),
  (color: kOrange, label: 'Fair', range: '60–74'),
  (color: kBlue, label: 'Good', range: '75–89'),
  (color: kGreen, label: 'Excellent', range: '90–100'),
];
