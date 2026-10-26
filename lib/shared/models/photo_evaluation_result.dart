import 'package:access_mobile/shared/controllers/auth_controller.dart';

/// Structured photo evaluation result (1–5 per criterion).
class CriterionScore {
  const CriterionScore({
    required this.name,
    required this.score,
    required this.explanation,
    required this.suggestion,
  });

  final String name;
  final int score;
  final String explanation;
  final String suggestion;

  String get label => scoreLabel(score);

  /// 0–100 display score (internal 1–5 scale × 20).
  int get percentScore => ((score / 5) * 100).round().clamp(0, 100);

  static String scoreLabel(int score) => switch (score) {
        5 => 'Excellent',
        4 => 'Good',
        3 => 'Fair',
        2 => 'Needs Improvement',
        _ => 'Poor',
      };

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'label': label,
        'explanation': explanation,
        'suggestion': suggestion,
      };

  factory CriterionScore.fromJson(Map<String, dynamic> j) => CriterionScore(
        name: j['name'] as String? ?? '',
        score: (j['score'] as num?)?.round().clamp(1, 5) ?? 3,
        explanation: j['explanation'] as String? ?? '',
        suggestion: j['suggestion'] as String? ?? '',
      );
}

class AiDetectionResult {
  const AiDetectionResult({
    required this.verdict,
    required this.confidence,
    required this.detail,
    this.probability,
    this.analysisStatus,
    this.isFinal = true,
    this.riskLevel,
    this.requiresReviewFlag,
    this.cameraProvenanceStrength,
    this.provenancePolicyOutcome,
    this.visualRiskLevel,
    this.detectorBackend,
    this.waverepFramesAnalyzed,
    this.waverepRequestedFrames,
    this.waverepProcessingStatus,
    this.waverepAnalysisUnavailable,
    this.exifMetadata,
    this.provenanceContainerFields = const [],
    this.isVideoProvenanceFlag,
  });

  final String verdict;
  final double confidence;
  final String detail;
  /// Synthetic-media probability 0–1 when provided by the backend.
  final double? probability;
  final String? analysisStatus;
  final bool isFinal;
  final String? riskLevel;
  final bool? requiresReviewFlag;
  final String? cameraProvenanceStrength;
  final String? provenancePolicyOutcome;
  final String? visualRiskLevel;
  final String? detectorBackend;
  final int? waverepFramesAnalyzed;
  final int? waverepRequestedFrames;
  final String? waverepProcessingStatus;
  final bool? waverepAnalysisUnavailable;
  /// Stored `exif_metadata` from ai_detection when the backend includes it.
  final Map<String, dynamic>? exifMetadata;
  /// Container / EXIF field rows (`key`, `label`, `value`) from evaluation JSON.
  final List<Map<String, String>> provenanceContainerFields;
  /// Top-level `is_video_provenance` when present on ai_detection.
  final bool? isVideoProvenanceFlag;

  bool get isDeferredAuthenticity =>
      analysisStatus == 'deferred' || isFinal == false || verdict == 'deferred';

  bool get isAiGenerated =>
      !isDeferredAuthenticity && (verdict == 'ai_generated' || verdict == 'ai');
  bool get isSuspicious => !isDeferredAuthenticity && verdict == 'suspicious';
  bool get isAuthentic => !isDeferredAuthenticity && !isAiGenerated && !isSuspicious;
  bool get requiresReview =>
      !isDeferredAuthenticity &&
      (requiresReviewFlag == true ||
          isAiGenerated ||
          isSuspicious ||
          isSourceUnverified ||
          _riskIsElevated);

  bool get _riskIsElevated {
    final r = (riskLevel ?? '').toLowerCase();
    return r == 'suspicious' || r == 'high';
  }

  bool get isLowProbeRisk {
    if (isDeferredAuthenticity) return false;
    final r = (_visualRiskBand).toLowerCase();
    if (r == 'low') return true;
    return isAuthentic && !isSuspicious && !isAiGenerated;
  }

  String get _visualRiskBand =>
      (visualRiskLevel ?? riskLevel ?? '').trim();

  bool get isSourceUnverified {
    final outcome = (provenancePolicyOutcome ?? '').toLowerCase();
    if (outcome == 'low_ai_risk') return false;
    if (requiresReviewFlag == false) return false;
    return outcome == 'source_unverified' || outcome == 'source_partially_verified';
  }

  bool get isCameraProvenanceStrong =>
      (cameraProvenanceStrength ?? '').toLowerCase() == 'strong';

  bool get isCameraProvenancePartial =>
      (cameraProvenanceStrength ?? '').toLowerCase() == 'partial' ||
      (provenancePolicyOutcome ?? '').toLowerCase() == 'source_partially_verified';

  bool get isCameraProvenanceAbsent {
    final strength = (cameraProvenanceStrength ?? '').toLowerCase();
    if (strength == 'absent') return true;
    final outcome = (provenancePolicyOutcome ?? '').toLowerCase();
    return outcome == 'source_unverified' && !isCameraProvenancePartial;
  }

  bool get isWaverepBackend =>
      (detectorBackend ?? '').trim().toLowerCase() == 'waverep_g4';

  bool get isAiAnalysisUnavailable =>
      waverepAnalysisUnavailable == true ||
      (waverepProcessingStatus ?? '').toLowerCase() == 'unavailable';

  bool get isBlocked => isAiGenerated;

  static Map<String, dynamic>? _parseExifMetadata(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static List<Map<String, String>> _parseProvenanceFieldRows(Map<String, dynamic> ai) {
    final rows = <Map<String, String>>[];
    void ingest(dynamic source) {
      if (source is! List) return;
      for (final item in source) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final key = (m['key'] ?? m['label'] ?? '').toString().trim();
        final label = (m['label'] ?? key).toString().trim();
        final value = (m['value'] ?? '').toString().trim();
        if (key.isEmpty && label.isEmpty) continue;
        if (value.isEmpty) continue;
        rows.add({'key': key.isEmpty ? label : key, 'label': label, 'value': value});
      }
    }

    ingest(ai['camera_provenance_fields']);
    final exif = _parseExifMetadata(ai['exif_metadata']);
    if (exif != null) {
      ingest(exif['fields']);
    }
    return rows;
  }

  static int? _waverepRequestedFromSupplementary(Map<String, dynamic> ai) {
    final sup = ai['waverep_supplementary'];
    if (sup is! Map) return null;
    final m = Map<String, dynamic>.from(sup);
    final raw = m['waverep_requested_frames'] ?? m['waverep_processed_frames'];
    return (raw as num?)?.toInt();
  }

  Map<String, dynamic> toJson() => {
        if (!isDeferredAuthenticity) 'verdict': verdict,
        if (!isDeferredAuthenticity) 'confidence': confidence,
        'detail': detail,
        if (probability != null) 'probability': probability,
        if (analysisStatus != null) 'analysis_status': analysisStatus,
        if (!isFinal) 'is_final': isFinal,
        if (isDeferredAuthenticity && analysisStatus == null) 'analysis_status': 'deferred',
        if (isDeferredAuthenticity && isFinal) 'is_final': false,
      };

  static AiDetectionResult? fromJsonMap(Map<String, dynamic>? ai) {
    if (ai == null) return null;
    final status = ai['analysis_status'] as String?;
    final isFinal = ai['is_final'] as bool? ?? true;
    if (status == 'deferred' || isFinal == false) {
      return AiDetectionResult(
        verdict: 'deferred',
        confidence: 0,
        detail: ai['detail'] as String? ??
            'AI authenticity risk will be assessed when you save this submission.',
        analysisStatus: status ?? 'deferred',
        isFinal: false,
      );
    }
    return AiDetectionResult(
      verdict: ai['verdict'] as String? ?? 'authentic',
      confidence: (ai['confidence'] as num?)?.toDouble() ?? 0.85,
      detail: ai['detail'] as String? ?? '',
      probability: (ai['probability'] as num?)?.toDouble() ??
          (ai['raw_detector_probability'] as num?)?.toDouble(),
      analysisStatus: status,
      isFinal: isFinal,
      riskLevel: ai['risk_level'] as String?,
      requiresReviewFlag: ai['requires_review'] as bool?,
      cameraProvenanceStrength: ai['camera_provenance_strength'] as String?,
      provenancePolicyOutcome: ai['provenance_policy_outcome'] as String?,
      visualRiskLevel: ai['visual_risk_level'] as String?,
      detectorBackend: ai['detector_backend'] as String?,
      waverepFramesAnalyzed: (ai['waverep_frames_analyzed'] as num?)?.toInt(),
      waverepRequestedFrames: (ai['waverep_requested_frames'] as num?)?.toInt() ??
          _waverepRequestedFromSupplementary(Map<String, dynamic>.from(ai)),
      waverepProcessingStatus: ai['waverep_processing_status'] as String?,
      waverepAnalysisUnavailable: ai['waverep_analysis_unavailable'] as bool?,
      exifMetadata: _parseExifMetadata(ai['exif_metadata']),
      provenanceContainerFields: _parseProvenanceFieldRows(ai),
      isVideoProvenanceFlag: ai['is_video_provenance'] as bool?,
    );
  }
}

/// Gemini-generated narrative feedback (scores come only from EfficientNet-B0).
class MediaEvaluationFeedback {
  const MediaEvaluationFeedback({
    required this.explanation,
    required this.strengths,
    required this.improvements,
    required this.tips,
    required this.closingMessage,
  });

  final String explanation;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> tips;
  final String closingMessage;

  String get combinedFeedback {
    final buf = StringBuffer(explanation);
    if (strengths.isNotEmpty) {
      buf.write('\n\nStrengths: ${strengths.join('; ')}.');
    }
    if (improvements.isNotEmpty) {
      buf.write('\n\nAreas to improve: ${improvements.join('; ')}.');
    }
    if (closingMessage.isNotEmpty) {
      buf.write('\n\n$closingMessage');
    }
    return buf.toString();
  }

  String get combinedTips => tips.isEmpty ? '' : tips.map((t) => '• $t').join('\n');

  Map<String, dynamic> toJson() => {
        'explanation': explanation,
        'strengths': strengths,
        'improvements': improvements,
        'tips': tips,
        'closing_message': closingMessage,
      };

  factory MediaEvaluationFeedback.fromJson(Map<String, dynamic> j) => MediaEvaluationFeedback(
        explanation: j['explanation'] as String? ?? '',
        strengths: (j['strengths'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        improvements: (j['improvements'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        tips: (j['tips'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        closingMessage: j['closing_message'] as String? ?? j['closingMessage'] as String? ?? '',
      );

  static String _memberFirstNameForFeedback() {
    final full = authController.user?.name.trim() ?? '';
    if (full.isEmpty) return '';
    return full.split(RegExp(r'\s+')).first;
  }

  factory MediaEvaluationFeedback.fromLocal(PhotoEvaluationResult result) {
    final isVideo = result.isVideo;
    final mediaLabel = isVideo ? 'video' : 'photo';
    final firstName = _memberFirstNameForFeedback();
    final namePrefix = firstName.isNotEmpty ? '$firstName, ' : '';
    final strong = result.criteria.where((c) => c.score >= 4).toList();
    final weak = result.criteria.where((c) => c.score <= 2).toList();

    final strengths = result.strengths.isNotEmpty
        ? result.strengths
        : strong
            .map((c) => c.explanation.trim().isNotEmpty ? c.explanation : 'Your ${c.name.toLowerCase()} looks solid.')
            .toList();
    final improvements = result.weaknesses.isNotEmpty
        ? result.weaknesses
        : weak
            .map((c) => c.explanation.trim().isNotEmpty ? c.explanation : 'There is room to improve ${c.name.toLowerCase()}.')
            .toList();
    final tips = result.criteria
        .where((c) => c.score <= 3 && c.suggestion.isNotEmpty)
        .map((c) => c.suggestion)
        .toSet()
        .toList();

    final opening = strong.isNotEmpty
        ? '${namePrefix}Great effort on this $mediaLabel! You are already showing strength in ${strong.map((c) => c.name.toLowerCase()).join(', ')}!'
        : '${namePrefix}Thank you for sharing this $mediaLabel. Every submission is a step forward in building your documentation skills!';

    final summary = result.overallPercent >= 75
        ? ' Your overall quality is coming together nicely.'
        : result.overallPercent >= 60
            ? ' You have a good foundation to build on with a bit more polish.'
            : ' There is clear potential here. Small adjustments to technique will make a noticeable difference.';

    return MediaEvaluationFeedback(
      explanation: energeticFeedbackText('$opening$summary'),
      strengths: strengths,
      improvements: improvements,
      tips: tips,
      closingMessage: 'Keep practicing and submitting. Consistency is how great documenters are made!',
    );
  }

  MediaEvaluationFeedback copyWithEnergeticTone() => MediaEvaluationFeedback(
        explanation: energeticFeedbackText(explanation),
        strengths: strengths,
        improvements: improvements,
        tips: tips,
        closingMessage: closingMessage.trim().isEmpty
            ? closingMessage
            : (closingMessage.trim().endsWith('!') ? closingMessage : '${closingMessage.trim()}!'),
      );
}

/// Adds an exclamation mark to the opening sentence for an upbeat mentor tone.
String energeticFeedbackText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;

  final firstBreak = trimmed.indexOf(RegExp(r'[.!?]'));
  if (firstBreak <= 0) {
    return trimmed.endsWith('!') ? trimmed : '$trimmed!';
  }

  final opener = trimmed.substring(0, firstBreak).trimRight();
  final rest = trimmed.substring(firstBreak);
  if (opener.endsWith('!')) return trimmed;
  if (rest.startsWith('!')) return trimmed;

  return '$opener!${rest.startsWith('.') ? rest.substring(1) : rest}';
}

/// Feedback-only color balance or composition hint (not part of the 1–5 rubric).
class SupplementaryQualityInsight {
  const SupplementaryQualityInsight({
    required this.status,
    required this.headline,
    required this.feedback,
  });

  final String status;
  final String headline;
  final String feedback;

  bool get isUnavailable => status == 'unavailable';

  factory SupplementaryQualityInsight.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const SupplementaryQualityInsight(
        status: 'unavailable',
        headline: 'Unavailable',
        feedback: '',
      );
    }
    return SupplementaryQualityInsight(
      status: j['status'] as String? ?? 'inconclusive',
      headline: j['headline'] as String? ?? 'Inconclusive',
      feedback: j['feedback'] as String? ?? '',
    );
  }
}

class AdditionalQualityInsights {
  const AdditionalQualityInsights({
    this.colorBalance,
    this.compositionFraming,
    this.motionStability,
    this.mediaType,
    this.framesAnalyzed,
  });

  final SupplementaryQualityInsight? colorBalance;
  final SupplementaryQualityInsight? compositionFraming;
  final SupplementaryQualityInsight? motionStability;
  final String? mediaType;
  final int? framesAnalyzed;

  bool get hasDisplayableData {
    final color = colorBalance;
    final comp = compositionFraming;
    final motion = motionStability;
    final colorOk = color != null && !color.isUnavailable && color.feedback.trim().isNotEmpty;
    final compOk = comp != null && !comp.isUnavailable && comp.feedback.trim().isNotEmpty;
    final motionOk =
        motion != null && !motion.isUnavailable && motion.feedback.trim().isNotEmpty;
    return colorOk || compOk || motionOk;
  }

  factory AdditionalQualityInsights.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const AdditionalQualityInsights();
    return AdditionalQualityInsights(
      colorBalance: j['color_balance'] is Map
          ? SupplementaryQualityInsight.fromJson(
              Map<String, dynamic>.from(j['color_balance'] as Map),
            )
          : null,
      compositionFraming: j['composition_framing'] is Map
          ? SupplementaryQualityInsight.fromJson(
              Map<String, dynamic>.from(j['composition_framing'] as Map),
            )
          : null,
      motionStability: j['motion_stability'] is Map
          ? SupplementaryQualityInsight.fromJson(
              Map<String, dynamic>.from(j['motion_stability'] as Map),
            )
          : null,
      mediaType: j['media_type'] as String?,
      framesAnalyzed: (j['frames_analyzed'] as num?)?.toInt(),
    );
  }
}

class PhotoEvaluationResult {
  const PhotoEvaluationResult({
    required this.criteria,
    required this.overallScore,
    required this.qualityLevel,
    required this.feedback,
    required this.improvementSuggestions,
    required this.recommendation,
    required this.aiDetection,
    this.mediaType = 'photo',
    this.scoringModel = 'legacy',
    this.strengths = const [],
    this.weaknesses = const [],
    this.geminiFeedback,
    this.geminiFeedbackIsLocal = false,
    this.integrityTier,
    this.showQualityFeedback,
    this.qualityProvisional,
    this.xpEligible,
    this.xpMultiplier,
    this.memberIntegrityMessage,
    this.xpPending,
    this.xpPointsPreview,
    this.memberScoresReleased,
    this.reviewGateMessage,
    this.additionalQualityInsights,
  });

  final List<CriterionScore> criteria;
  final double overallScore;
  final String qualityLevel;
  final String feedback;
  final String improvementSuggestions;
  final String recommendation;
  final AiDetectionResult aiDetection;
  final String mediaType;
  final String scoringModel;
  final List<String> strengths;
  final List<String> weaknesses;
  final MediaEvaluationFeedback? geminiFeedback;
  final bool geminiFeedbackIsLocal;
  final String? integrityTier;
  final bool? showQualityFeedback;
  final bool? qualityProvisional;
  final bool? xpEligible;
  final double? xpMultiplier;
  final String? memberIntegrityMessage;
  final bool? xpPending;
  final int? xpPointsPreview;
  final bool? memberScoresReleased;
  final String? reviewGateMessage;
  final AdditionalQualityInsights? additionalQualityInsights;

  int get overallPercent => ((overallScore / 5) * 100).round().clamp(0, 100);

  bool get hasAdditionalQualityInsights =>
      additionalQualityInsights?.hasDisplayableData ?? false;
  bool get isVideo => mediaType == 'video';

  bool get memberScoresReleasedEffective {
    if (memberScoresReleased != null) return memberScoresReleased!;
    if (aiDetection.requiresReview) return false;
    return showQualityFeedback ?? true;
  }

  bool get scoresHeldForReview =>
      !memberScoresReleasedEffective && !aiDetection.isDeferredAuthenticity;

  bool get showQualityFeedbackEffective =>
      memberScoresReleasedEffective &&
      (showQualityFeedback ?? !aiDetection.isAiGenerated);

  bool get qualityProvisionalEffective =>
      qualityProvisional ?? aiDetection.isSuspicious;

  bool get xpEligibleEffective =>
      xpEligible ?? aiDetection.isAuthentic;

  bool get xpPendingEffective =>
      xpPending ?? aiDetection.requiresReview;

  int get xpPointsPreviewEffective =>
      xpPointsPreview ?? ((overallScore <= 1.0 ? overallScore : overallScore / 5.0) * 100).round();

  String _sourceUnverifiedDetailOrFallback() {
    final detail = aiDetection.detail.trim();
    if (detail.isNotEmpty) return detail;
    return _sourceUnverifiedIntegrityMessage;
  }

  String get memberIntegrityMessageEffective =>
      memberIntegrityMessage ??
      (aiDetection.isAiGenerated
          ? _aiGeneratedIntegrityMessage
          : aiDetection.isSuspicious
              ? _suspiciousIntegrityMessage
              : aiDetection.isSourceUnverified
                  ? _sourceUnverifiedDetailOrFallback()
                  : '');

  static const photoCriteriaOrder = [
    'Sharpness',
    'Blur',
    'Noise',
    'Brightness',
    'Contrast',
    'Blocking Artifacts',
    'Ringing Artifacts',
  ];

  static const videoCriteriaOrder = [
    ...photoCriteriaOrder,
    'Motion Stability',
    'Flickering',
  ];

  /// Criteria in display order; video-only metrics omitted for photos.
  List<CriterionScore> displayCriteria({bool? isVideo}) =>
      orderCriteriaForDisplay(criteria, isVideo: isVideo ?? this.isVideo);

  Map<String, dynamic> toJson() {
    final byName = {for (final c in criteria) c.name: c.score};
    int s(String primary, [String? fallback]) {
      if (byName.containsKey(primary)) return byName[primary]!;
      if (fallback != null && byName.containsKey(fallback)) return byName[fallback]!;
      return 3;
    }

    final sharpness = s('Sharpness', 'Focus and Sharpness');
    final blur = s('Blur', 'Focus and Sharpness');
    final noise = s('Noise', 'Technical Quality');
    final brightness = s('Brightness', 'Lighting and Exposure');
    final contrast = s('Contrast', 'Color and White Balance');

    return {
      'criteria': criteria.map((c) => c.toJson()).toList(),
      'overall_score': overallScore,
      'quality_level': qualityLevel,
      'ai_feedback': feedback,
      'improvement_suggestions': improvementSuggestions,
      'recommendation': recommendation,
      'ai_detection': aiDetection.toJson(),
      'media_type': mediaType,
      'scoring_model': scoringModel,
      'strengths': strengths,
      'weaknesses': weaknesses,
      if (geminiFeedback != null) 'gemini_feedback': geminiFeedback!.toJson(),
      if (geminiFeedbackIsLocal) 'gemini_feedback_is_local': true,
      if (integrityTier != null) 'integrity_tier': integrityTier,
      if (showQualityFeedback != null) 'show_quality_feedback': showQualityFeedback,
      if (qualityProvisional != null) 'quality_provisional': qualityProvisional,
      if (xpEligible != null) 'xp_eligible': xpEligible,
      if (xpMultiplier != null) 'xp_multiplier': xpMultiplier,
      if (memberIntegrityMessage != null) 'member_integrity_message': memberIntegrityMessage,
      if (xpPending != null) 'xp_pending': xpPending,
      if (xpPointsPreview != null) 'xp_points_preview': xpPointsPreview,
      'composition_score': s('Composition and Framing'),
      'lighting_score': brightness,
      'focus_score': sharpness,
      'color_score': contrast,
      'subject_clarity_score': s('Subject Clarity'),
      'creativity_score': s('Creativity and Storytelling'),
      'technical_quality_score': s('Technical Quality', 'Sharpness'),
      'documentation_value_score': s('Overall Documentation Value'),
      'legacy': {
        'sharpness_score': sharpness / 5,
        'brightness_score': brightness / 5,
        'contrast_score': contrast / 5,
        'blur_score': blur / 5,
        'noise_score': 1 - noise / 5,
        'overall_score': overallScore / 5,
      },
    };
  }

  /// Payload for POST /ai/media-evaluation-feedback (scores only, no cached local Gemini).
  Map<String, dynamic> toGeminiRequestJson() {
    final map = toJson();
    map.remove('gemini_feedback');
    map.remove('gemini_feedback_is_local');
    map['member_scores_released'] = memberScoresReleasedEffective;
    map['show_quality_feedback'] = showQualityFeedbackEffective;
    map['scoring_engine'] = scoringModel.contains('efficientnet')
        ? 'efficientnet-b0+ffmpeg'
        : (scoringModel.isNotEmpty ? scoringModel : 'efficientnet-b0+ffmpeg');
    return map;
  }

  /// Criteria JSON uses 1–5; legacy DB snapshots may store 0–1 under `legacy.overall_score`.
  static double parseOverallScoreFromJson(Map<String, dynamic> j) {
    final raw = (j['overall_score'] as num?)?.toDouble();
    final legacy = j['legacy'];
    final legacyOverall = legacy is Map ? (legacy['overall_score'] as num?)?.toDouble() : null;

    if (raw != null) {
      if (raw <= 1.0) {
        if (legacyOverall != null && legacyOverall <= 1.0) {
          return (legacyOverall * 5).clamp(0.0, 5.0);
        }
        return (raw * 5).clamp(0.0, 5.0);
      }
      return raw.clamp(0.0, 5.0);
    }
    if (legacyOverall != null) {
      return legacyOverall <= 1.0
          ? (legacyOverall * 5).clamp(0.0, 5.0)
          : legacyOverall.clamp(0.0, 5.0);
    }
    return 3;
  }

  static PhotoEvaluationResult? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final raw = j['criteria'];
    final list = raw is List
        ? raw.map((e) => CriterionScore.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <CriterionScore>[];
    final ai = j['ai_detection'];
    final geminiRaw = j['gemini_feedback'];
    return PhotoEvaluationResult(
      criteria: list,
      overallScore: parseOverallScoreFromJson(j),
      qualityLevel: j['quality_level'] as String? ?? 'Fair',
      feedback: j['ai_feedback'] as String? ?? j['feedback'] as String? ?? '',
      improvementSuggestions: j['improvement_suggestions'] as String? ?? '',
      recommendation: j['recommendation'] as String? ?? 'Needs Improvement',
      mediaType: j['media_type'] as String? ?? 'photo',
      scoringModel: j['scoring_model'] as String? ?? 'legacy',
      strengths: (j['strengths'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      weaknesses: (j['weaknesses'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      geminiFeedback: geminiRaw is Map
          ? MediaEvaluationFeedback.fromJson(Map<String, dynamic>.from(geminiRaw))
          : null,
      geminiFeedbackIsLocal: j['gemini_feedback_is_local'] as bool? ?? false,
      aiDetection: ai is Map
          ? (AiDetectionResult.fromJsonMap(Map<String, dynamic>.from(ai)) ??
              const AiDetectionResult(
                verdict: 'authentic',
                confidence: 0.85,
                detail: 'No AI-generation artifacts detected.',
              ))
          : const AiDetectionResult(
              verdict: 'authentic',
              confidence: 0.85,
              detail: 'No AI-generation artifacts detected.',
            ),
      integrityTier: j['integrity_tier'] as String?,
      showQualityFeedback: j['show_quality_feedback'] as bool?,
      qualityProvisional: j['quality_provisional'] as bool?,
      xpEligible: j['xp_eligible'] as bool?,
      xpMultiplier: (j['xp_multiplier'] as num?)?.toDouble(),
      memberIntegrityMessage: j['member_integrity_message'] as String?,
      xpPending: j['xp_pending'] as bool?,
      xpPointsPreview: (j['xp_points_preview'] as num?)?.round(),
      memberScoresReleased: j['member_scores_released'] as bool?,
      reviewGateMessage: j['review_gate_message'] as String?,
      additionalQualityInsights: j['additional_quality_insights'] is Map
          ? AdditionalQualityInsights.fromJson(
              Map<String, dynamic>.from(j['additional_quality_insights'] as Map),
            )
          : null,
    );
  }

  PhotoEvaluationResult copyWithIntegrity({
    String? integrityTier,
    bool? showQualityFeedback,
    bool? qualityProvisional,
    bool? xpEligible,
    double? xpMultiplier,
    String? memberIntegrityMessage,
    bool? xpPending,
    int? xpPointsPreview,
    String? feedback,
    String? improvementSuggestions,
    bool? memberScoresReleased,
    String? reviewGateMessage,
  }) =>
      PhotoEvaluationResult(
        criteria: criteria,
        overallScore: overallScore,
        qualityLevel: qualityLevel,
        feedback: feedback ?? this.feedback,
        improvementSuggestions: improvementSuggestions ?? this.improvementSuggestions,
        recommendation: recommendation,
        aiDetection: aiDetection,
        mediaType: mediaType,
        scoringModel: scoringModel,
        strengths: strengths,
        weaknesses: weaknesses,
        geminiFeedback: geminiFeedback,
        geminiFeedbackIsLocal: geminiFeedbackIsLocal,
        integrityTier: integrityTier ?? this.integrityTier,
        showQualityFeedback: showQualityFeedback ?? this.showQualityFeedback,
        qualityProvisional: qualityProvisional ?? this.qualityProvisional,
        xpEligible: xpEligible ?? this.xpEligible,
        xpMultiplier: xpMultiplier ?? this.xpMultiplier,
        memberIntegrityMessage: memberIntegrityMessage ?? this.memberIntegrityMessage,
        xpPending: xpPending ?? this.xpPending,
        xpPointsPreview: xpPointsPreview ?? this.xpPointsPreview,
        memberScoresReleased: memberScoresReleased ?? this.memberScoresReleased,
        reviewGateMessage: reviewGateMessage ?? this.reviewGateMessage,
        additionalQualityInsights: additionalQualityInsights,
      );

  PhotoEvaluationResult copyWithGemini(MediaEvaluationFeedback gf, {bool geminiFeedbackIsLocal = false}) {
    if (!showQualityFeedbackEffective) return this;
    var newFeedback = gf.combinedFeedback;
    if (qualityProvisionalEffective) {
      final msg = memberIntegrityMessageEffective;
      if (msg.isNotEmpty) {
        final snippet = msg.substring(0, msg.length.clamp(0, 40));
        if (!newFeedback.contains(snippet)) {
          newFeedback = '$msg\n\n$newFeedback';
        }
      }
    }
    return PhotoEvaluationResult(
        criteria: criteria,
        overallScore: overallScore,
        qualityLevel: qualityLevel,
        feedback: newFeedback,
        improvementSuggestions: gf.combinedTips.isEmpty ? improvementSuggestions : gf.combinedTips,
        recommendation: recommendation,
        aiDetection: aiDetection,
        mediaType: mediaType,
        scoringModel: scoringModel,
        strengths: gf.strengths.isNotEmpty ? gf.strengths : strengths,
        weaknesses: gf.improvements.isNotEmpty ? gf.improvements : weaknesses,
        geminiFeedback: gf,
        geminiFeedbackIsLocal: geminiFeedbackIsLocal,
        integrityTier: integrityTier,
        showQualityFeedback: showQualityFeedback,
        qualityProvisional: qualityProvisional,
        xpEligible: xpEligible,
        xpMultiplier: xpMultiplier,
        memberIntegrityMessage: memberIntegrityMessage,
        xpPending: xpPending,
        xpPointsPreview: xpPointsPreview,
        additionalQualityInsights: additionalQualityInsights,
      );
  }
}

const _suspiciousIntegrityMessage =
    'This upload was flagged for integrity review. Technical scores below are provisional '
    'and may change after an officer verifies your media. XP will be awarded if your submission is approved.';

const _aiGeneratedIntegrityMessage =
    'This upload was flagged as possible AI-generated content. Quality coaching is paused until '
    'an officer reviews your file. If verified as authentic, your scores and XP will be applied.';

const _sourceUnverifiedIntegrityMessage =
    'The source of this upload could not be verified from original camera metadata. '
    'Technical scores are provisional until an officer completes review. '
    'XP will be awarded if your submission is approved.';

/// Canonical display order for AI criterion bars.
const _videoOnlyCriteria = {'Motion Stability', 'Flickering'};

List<CriterionScore> orderCriteriaForDisplay(List<CriterionScore> criteria, {required bool isVideo}) {
  final order = isVideo ? PhotoEvaluationResult.videoCriteriaOrder : PhotoEvaluationResult.photoCriteriaOrder;
  final filtered = isVideo ? criteria : criteria.where((c) => !_videoOnlyCriteria.contains(c.name));
  final sorted = filtered.toList()
    ..sort((a, b) {
      final ai = order.indexOf(a.name);
      final bi = order.indexOf(b.name);
      return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
    });
  return sorted;
}

class ImageValidationResult {
  const ImageValidationResult({
    required this.isValid,
    required this.message,
    this.issues = const [],
    this.qualityWarnings = const [],
    this.hardReject = false,
  });

  final bool isValid;
  final String message;
  final List<String> issues;
  /// Non-blocking hints (blur, lighting, etc.) — evaluation still runs.
  final List<String> qualityWarnings;
  /// True only for corrupt / unreadable / blank files.
  final bool hardReject;

  static const hardRejectMessage =
      'This file cannot be evaluated because it is not a valid or readable image.';

  static const acceptedWithIssuesMessage =
      'This image was accepted for evaluation, but some quality issues were detected. '
      'Please review the suggestions below.';

  factory ImageValidationResult.accepted({List<String> qualityWarnings = const []}) =>
      ImageValidationResult(
        isValid: true,
        message: qualityWarnings.isEmpty ? 'Image ready for evaluation.' : acceptedWithIssuesMessage,
        qualityWarnings: qualityWarnings,
      );

  factory ImageValidationResult.hardReject([List<String>? issues]) => ImageValidationResult(
        isValid: false,
        hardReject: true,
        message: hardRejectMessage,
        issues: issues ?? const [],
      );
}
