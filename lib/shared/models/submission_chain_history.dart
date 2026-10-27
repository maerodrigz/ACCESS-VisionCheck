/// Member submission chain history from GET /evaluations/chains/{root_media_id}.
class SubmissionChainHistory {
  const SubmissionChainHistory({
    required this.chainId,
    required this.rootMediaId,
    required this.media,
    this.xpAwardedTotal = 0,
    this.xpAwardLocked = false,
    this.activeReplacementMediaId,
    this.awaitingReplacementMediaId,
  });

  final int chainId;
  final int rootMediaId;
  final List<SubmissionChainMediaItem> media;
  final int xpAwardedTotal;
  final bool xpAwardLocked;
  final int? activeReplacementMediaId;
  final int? awaitingReplacementMediaId;

  factory SubmissionChainHistory.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media'];
    final items = rawMedia is List
        ? rawMedia
            .map((e) => SubmissionChainMediaItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <SubmissionChainMediaItem>[];
    return SubmissionChainHistory(
      chainId: _int(json['chain_id']) ?? 0,
      rootMediaId: _int(json['root_media_id']) ?? 0,
      media: items,
      xpAwardedTotal: _int(json['xp_awarded_total']) ?? 0,
      xpAwardLocked: json['xp_award_locked'] == true,
      activeReplacementMediaId: _int(json['active_replacement_media_id']),
      awaitingReplacementMediaId: _int(json['awaiting_replacement_media_id']),
    );
  }
}

class SubmissionChainMediaItem {
  const SubmissionChainMediaItem({
    required this.mediaId,
    required this.fileName,
    this.fileType,
    this.uploadedAt,
    this.reviewStatus,
    this.replacesMediaId,
    this.chainRole,
    this.replacementLifecycle,
  });

  final int mediaId;
  final String fileName;
  final String? fileType;
  final String? uploadedAt;
  final String? reviewStatus;
  final int? replacesMediaId;
  final String? chainRole;
  final String? replacementLifecycle;

  bool get isRoot => replacesMediaId == null && chainRole != 'replacement';

  factory SubmissionChainMediaItem.fromJson(Map<String, dynamic> json) {
    return SubmissionChainMediaItem(
      mediaId: _int(json['media_id']) ?? 0,
      fileName: json['file_name'] as String? ?? 'Upload',
      fileType: json['file_type'] as String?,
      uploadedAt: json['uploaded_at'] as String?,
      reviewStatus: json['review_status'] as String?,
      replacesMediaId: _int(json['replaces_media_id']),
      chainRole: json['chain_role'] as String?,
      replacementLifecycle: json['replacement_lifecycle'] as String?,
    );
  }
}

int? _int(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
