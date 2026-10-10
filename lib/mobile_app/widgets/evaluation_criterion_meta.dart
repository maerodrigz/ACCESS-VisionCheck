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

const kCriterionMeta = <String, CriterionMeta>{
  'Sharpness': CriterionMeta(
    icon: Icons.center_focus_strong_rounded,
    description: 'Measures how crisp and well-focused the subject appears.',
  ),
  'Blur': CriterionMeta(
    icon: Icons.blur_off_rounded,
    description: 'Detects motion or focus blur that reduces clarity.',
  ),
  'Noise': CriterionMeta(
    icon: Icons.grain_rounded,
    description: 'Evaluates visible grain or digital noise in the image.',
  ),
  'Brightness': CriterionMeta(
    icon: Icons.wb_sunny_outlined,
    description: 'Checks whether exposure is balanced across the scene.',
  ),
  'Contrast': CriterionMeta(
    icon: Icons.contrast_rounded,
    description: 'Assesses tonal separation between light and dark areas.',
  ),
  'Blocking Artifacts': CriterionMeta(
    icon: Icons.grid_view_rounded,
    description: 'Looks for compression block patterns from heavy encoding.',
  ),
  'Ringing Artifacts': CriterionMeta(
    icon: Icons.waves_rounded,
    description: 'Detects edge halos and ringing from sharpening or compression.',
  ),
  'Motion Stability': CriterionMeta(
    icon: Icons.video_stable_rounded,
    description: 'Measures how steady the camera movement is throughout the clip.',
  ),
  'Flickering': CriterionMeta(
    icon: Icons.flare_rounded,
    description: 'Detects unstable lighting or frame-to-frame brightness flicker.',
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

const kQualityPercentLegend = [
  (color: kRed, label: 'Needs Improvement', range: '0–49'),
  (color: kOrange, label: 'Fair', range: '50–69'),
  (color: kBlue, label: 'Good', range: '70–89'),
  (color: kGreen, label: 'Excellent', range: '90–100'),
];
