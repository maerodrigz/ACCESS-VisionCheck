import 'package:access_mobile/shared/constants/api_config.dart';

/// Resolves API [fileUrl] values for on-device thumbnails and previews.
///
/// Supabase compact refs and unresolved paths fall back to the authenticated
/// member stream endpoint when [mediaId] is known.
String? memberMediaDisplayUrl({
  required String? fileUrl,
  required int? mediaId,
}) {
  if (fileUrl != null && fileUrl.trim() == '/uploads/__storage_removed__') {
    return null;
  }

  final raw = fileUrl?.trim() ?? '';
  if (raw.startsWith('supabase-ref:')) {
    if (mediaId != null && mediaId > 0) {
      return _memberStreamUrl(mediaId);
    }
    return null;
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return ApiConfig.mediaUrl(raw);
  }

  if (raw.isNotEmpty) {
    final absolute = ApiConfig.mediaUrl(raw);
    if (absolute.isNotEmpty) return absolute;
  }

  if (mediaId != null && mediaId > 0) {
    return _memberStreamUrl(mediaId);
  }
  return null;
}

String _memberStreamUrl(int mediaId) =>
    '${ApiConfig.effectiveBaseUrl}${ApiConfig.apiPrefix}/media/$mediaId/stream';

/// Bearer token for `/api/media/{id}/stream` requests (Image.network headers).
Map<String, String>? memberMediaImageHeaders(String url, {String? bearerToken}) {
  final token = bearerToken?.trim();
  if (token == null || token.isEmpty) return null;
  if (!url.contains('/api/media/') || !url.contains('/stream')) return null;
  return {'Authorization': 'Bearer $token'};
}

/// HTTP headers for [VideoPlayerController.networkUrl] (stream URLs need JWT).
Map<String, String> memberMediaHttpHeaders(String url, {String? bearerToken}) {
  return memberMediaImageHeaders(url, bearerToken: bearerToken) ?? const {};
}
