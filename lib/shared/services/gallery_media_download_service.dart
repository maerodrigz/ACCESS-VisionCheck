import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';

/// Saves approved event gallery media to the device photo library (mobile only).
class GalleryMediaDownloadService {
  static const _rebuildHint =
      'Stop the app completely, then run it again from your IDE or flutter run. '
      'Hot restart does not load new native plugins.';

  static Future<String> saveToDevice(EventGalleryMedia item) async {
    if (kIsWeb) {
      throw UnsupportedError('Save to device is not available in the browser.');
    }

    try {
      return await _saveToDevice(item);
    } on MissingPluginException {
      throw Exception(_rebuildHint);
    }
  }

  static Future<String> _saveToDevice(EventGalleryMedia item) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw Exception('Photo library access was denied.');
      }
    }

    final url = item.thumbnailUrl;
    if (url.isEmpty) {
      throw Exception('Media URL is missing.');
    }

    final headers = <String, String>{};
    final token = apiClient.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(ApiClient.timeout);
    if (response.statusCode != 200) {
      throw Exception('Could not download media (${response.statusCode}).');
    }

    final fileName = _safeFileName(item.fileName, item.isVideo);

    if (item.isVideo) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes);
      try {
        await Gal.putVideo(path);
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
      return fileName;
    }

    await Gal.putImageBytes(response.bodyBytes, name: fileName);
    return fileName;
  }

  static String _safeFileName(String fileName, bool isVideo) {
    final trimmed = fileName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final ext = isVideo ? 'mp4' : 'jpg';
    return 'access_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }
}
