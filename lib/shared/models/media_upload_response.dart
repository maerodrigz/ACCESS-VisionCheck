/// Parsed response from POST /api/media/upload (Step 7A deferred evaluation).
class MediaUploadResponse {
  const MediaUploadResponse({
    required this.id,
    this.processingStatus,
    this.overallScore,
    this.aiProbability,
    this.feedback,
    this.fileUrl,
  });

  final int id;
  final String? processingStatus;
  final double? overallScore;
  final double? aiProbability;
  final String? feedback;
  final String? fileUrl;

  static MediaUploadResponse fromJson(Map<String, dynamic> json) {
    return MediaUploadResponse(
      id: json['id'] as int? ?? 0,
      processingStatus: json['processing_status'] as String?,
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      aiProbability: (json['ai_probability'] as num?)?.toDouble(),
      feedback: json['feedback'] as String?,
      fileUrl: json['file_url'] as String?,
    );
  }

  bool get isExplicitProcessing => processingStatus == 'processing';

  bool get isExplicitCompleted => processingStatus == 'completed';

  /// Whether the client should poll GET /media/{id} for backend evaluation completion.
  bool get needsDeferredProcessingPoll {
    if (isExplicitProcessing) return true;
    if (isExplicitCompleted) return false;
    // Legacy synchronous backend: scores present → done.
    if (overallScore != null || aiProbability != null || (feedback != null && feedback!.isNotEmpty)) {
      return false;
    }
    // Step 7A: null scores without status → treat as processing when upload returned an id.
    return id > 0;
  }
}
