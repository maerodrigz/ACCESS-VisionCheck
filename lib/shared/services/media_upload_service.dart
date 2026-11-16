import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/constants/api_config.dart';

/// Uploads media through the FastAPI backend (Supabase Storage when enabled on server).
abstract final class MediaUploadService {
  static Future<Map<String, dynamic>> uploadMedia({
    required ApiClient client,
    required List<int> bytes,
    required String fileName,
    int? requestId,
    String? displayName,
    String? evaluationMetadata,
    int? replacesMediaId,
    int? userId,
  }) async {
    final data = await client.postMultipart(
      '/media/upload',
      fileBytes: bytes,
      fileName: fileName,
      fields: {
        if (requestId != null) 'request_id': '$requestId',
        if (displayName != null) 'file_name': displayName,
        if (evaluationMetadata != null) 'evaluation_metadata': evaluationMetadata,
        if (replacesMediaId != null) 'replaces_media_id': '$replacesMediaId',
      },
      timeout: ApiClient.mediaUploadTimeout(byteLength: bytes.length, fileName: fileName),
    );
    final m = Map<String, dynamic>.from(data as Map);
    m['file_url'] = ApiConfig.mediaUrl(m['file_url'] as String? ?? '');
    return m;
  }

  static Future<Map<String, dynamic>> uploadProfileAvatar({
    required ApiClient client,
    required List<int> bytes,
    required String fileName,
    required int userId,
  }) async {
    final data = await client.postMultipart(
      '/profile/avatar',
      fileBytes: bytes,
      fileName: fileName,
      fields: {},
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
