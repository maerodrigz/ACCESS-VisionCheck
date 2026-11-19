import 'package:flutter/material.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/overall_quality_band.dart';

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
    'Each criterion is scored from 1 to 5 based on available technical signals.';

/// Short note under overall /100 scores.
const kOverallFromFiveLevelNote =
    'Overall /100 is the average of available five-level criteria, shown on a 0–100 scale for compatibility.';

const kCriterionMeta = <String, CriterionMeta>{
  'Sharpness': CriterionMeta(
    icon: Icons.center_focus_strong_rounded,
    description: 'How crisp and well-focused the subject appears.',
  ),
  'Blur': CriterionMeta(
    icon: Icons.blur_off_rounded,
    description: 'Motion or focus blur that reduces clarity.',
  ),
  'Brightness': CriterionMeta(
    icon: Icons.wb_sunny_outlined,
    description: 'Whether exposure looks balanced across the scene.',
  ),
  'Contrast': CriterionMeta(
    icon: Icons.contrast_rounded,
    description: 'Tonal separation between light and dark areas.',
  ),
  'Blocking Artifacts': CriterionMeta(
    icon: Icons.grid_view_rounded,
    description: 'Looks for compression block patterns from heavy encoding.',
  ),
  'Color Balance': CriterionMeta(
    icon: Icons.wb_twilight_rounded,
    description: 'Checks for color cast or noticeable color shifts.',
  ),
  'Color Saturation': CriterionMeta(
    icon: Icons.palette_outlined,
    description:
        'Checks color intensity. Muted or grayscale looks may show N/A.',
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
    description: 'Checks camera steadiness using sampled frames from the video.',
  ),
  'Flickering': CriterionMeta(
    icon: Icons.flare_rounded,
    description:
        'Checks lighting consistency using sampled frames. Limited samples are not definitive.',
  ),
};

CriterionMeta criterionMetaFor(CriterionScore criterion) =>
    kCriterionMeta[criterion.name] ??
    CriterionMeta(
      icon: Icons.analytics_outlined,
      description: 'Technical quality metric for ${criterion.name.toLowerCase()}.',
    );

/// Maps a stored overall label to the four display bands.
///
/// Unknown values stay "Needs Improvement" so pending rows without a score
/// do not become Poor.
String qualityDisplayBucket(String? level) {
  final normalized = (level ?? '').trim().toLowerCase();
  if (normalized.contains('excellent')) return 'Excellent';
  if (normalized.contains('good')) return 'Good';
  if (normalized.contains('fair')) return 'Fair';
  if (normalized.contains('poor')) return 'Poor';
  return 'Needs Improvement';
}

Color qualityBucketColor(String bucket) => switch (bucket) {
      'Excellent' => kGreen,
      'Good' => kBlue,
      'Fair' => kOrange,
      'Poor' => kRed,
      _ => kOrange,
    };

/// Overall 0–100 band colors: Poor red, Fair orange, Good blue, Excellent green.
Color qualityPercentBandColor(int percent) => switch (overallQualityLabelFromPercent(percent)) {
      'Excellent' => kGreen,
      'Good' => kBlue,
      'Fair' => kOrange,
      _ => kRed,
    };

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
