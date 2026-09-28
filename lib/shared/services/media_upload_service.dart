import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/services/firebase_storage_service.dart';

/// Uploads media to Firebase (when configured) then registers with the FastAPI backend.
abstract final class MediaUploadService {
  static Future<Map<String, dynamic>> uploadMedia({
    required ApiClient client,
    required List<int> bytes,
    required String fileName,
    int? requestId,
    String? displayName,
    String? evaluationMetadata,
    int? userId,
  }) async {
    final cloudUrl = await FirebaseStorageService.uploadMedia(
      bytes: bytes,
      fileName: fileName,
      userId: userId,
    );

    final data = await client.postMultipart(
      '/media/upload',
      fileBytes: bytes,
      fileName: fileName,
      fields: {
        if (requestId != null) 'request_id': '$requestId',
        if (displayName != null) 'file_name': displayName,
        if (evaluationMetadata != null) 'evaluation_metadata': evaluationMetadata,
        if (cloudUrl != null) 'cloud_file_url': cloudUrl,
      },
      timeout: ApiClient.mediaUploadTimeout(byteLength: bytes.length, fileName: fileName),
    );
    final m = Map<String, dynamic>.from(data as Map);
    m['file_url'] = ApiConfig.mediaUrl(m['file_url'] as String? ?? '');
    if (cloudUrl != null) {
      m['cloud_file_url'] = cloudUrl;
    }
    return m;
  }

  static Future<Map<String, dynamic>> uploadProfileAvatar({
    required ApiClient client,
    required List<int> bytes,
    required String fileName,
    required int userId,
  }) async {
    final cloudUrl = await FirebaseStorageService.uploadProfileAvatar(
      bytes: bytes,
      fileName: fileName,
      userId: userId,
    );

    final data = await client.postMultipart(
      '/profile/avatar',
      fileBytes: bytes,
      fileName: fileName,
      fields: {
        if (cloudUrl != null) 'cloud_file_url': cloudUrl,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
