import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:http/http.dart' as http;

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

bool isMemberMediaStreamUrl(String url) =>
    url.contains('/api/media/') && url.contains('/stream');

/// Bearer token for `/api/media/{id}/stream` requests (Image.network headers).
Map<String, String>? memberMediaImageHeaders(String url, {String? bearerToken}) {
  final token = bearerToken?.trim();
  if (token == null || token.isEmpty) return null;
  if (!isMemberMediaStreamUrl(url)) return null;
  return {'Authorization': 'Bearer $token'};
}

/// HTTP headers for [VideoPlayerController.networkUrl] (stream URLs need JWT).
Map<String, String> memberMediaHttpHeaders(String url, {String? bearerToken}) {
  return memberMediaImageHeaders(url, bearerToken: bearerToken) ?? const {};
}

/// Playable URI after resolving authenticated stream redirects to signed storage URLs.
///
/// Supabase private objects are streamed as `307` to a short-lived signed HTTPS URL.
/// Video players must play that Location without forwarding the JWT.
class MemberMediaPlayable {
  const MemberMediaPlayable({
    required this.uri,
    this.httpHeaders = const {},
  });

  final Uri uri;
  final Map<String, String> httpHeaders;

  bool get usesAuthHeaders => httpHeaders.isNotEmpty;
}

/// Resolve a member media URL for [video_player] / [video_thumbnail].
///
/// For `/api/media/{id}/stream`, follows redirects with a ranged probe so the
/// player can use Supabase Range support on the signed URL. Does not expose
/// service-role keys; signed URLs remain short-lived and authorization still
/// happens on the API hop.
Future<MemberMediaPlayable> resolveMemberMediaPlayableUri(
  String url, {
  String? bearerToken,
}) async {
  final uri = Uri.parse(url);
  final authHeaders = memberMediaHttpHeaders(url, bearerToken: bearerToken);
  if (authHeaders.isEmpty) {
    return MemberMediaPlayable(uri: uri);
  }

  final client = http.Client();
  try {
    var current = uri;
    var hopHeaders = Map<String, String>.from(authHeaders);
    for (var hop = 0; hop < 5; hop++) {
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(hopHeaders)
        ..headers['Range'] = 'bytes=0-0';
      final streamed = await client.send(request).timeout(const Duration(seconds: 25));
      final code = streamed.statusCode;
      if (code >= 300 && code < 400) {
        final loc = streamed.headers['location'];
        await streamed.stream.drain();
        if (loc == null || loc.trim().isEmpty) break;
        current = current.resolve(loc.trim());
        hopHeaders = {};
        continue;
      }
      await streamed.stream.drain();
      if (hop == 0 && (code == 200 || code == 206)) {
        // Local FileResponse (or ranged proxy): keep JWT on the API stream URL.
        return MemberMediaPlayable(uri: uri, httpHeaders: authHeaders);
      }
      return MemberMediaPlayable(uri: current);
    }
    return MemberMediaPlayable(uri: current);
  } catch (_) {
    return MemberMediaPlayable(uri: uri, httpHeaders: authHeaders);
  } finally {
    client.close();
  }
}
