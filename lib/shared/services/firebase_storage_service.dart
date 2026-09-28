import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:access_mobile/shared/services/firebase_app_init.dart';

const _logName = 'ACCESS.firebase';

/// Uploads bytes to Firebase Storage and returns a public HTTPS download URL.
abstract final class FirebaseStorageService {
  static FirebaseStorage? get _storage {
    if (!isFirebaseStorageReady) return null;
    return FirebaseStorage.instance;
  }

  static String? _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    return null;
  }

  static String _safeExt(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot >= fileName.length - 1) return '';
    return fileName.substring(dot).toLowerCase();
  }

  static Future<void> _ensureAuth() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    await FirebaseAuth.instance.signInAnonymously();
  }

  /// Upload under `access-visioncheck/{folder}/...`
  static Future<String?> uploadBytes({
    required List<int> bytes,
    required String fileName,
    required String folder,
    int? userId,
  }) async {
    final storage = _storage;
    if (storage == null) return null;

    final ext = _safeExt(fileName);
    final uid = userId != null ? '$userId' : 'anonymous';
    final objectName =
        'access-visioncheck/$folder/$uid/${DateTime.now().millisecondsSinceEpoch}$ext';

    try {
      await _ensureAuth();
      final ref = storage.ref(objectName);
      final metadata = SettableMetadata(
        contentType: _contentTypeFor(fileName),
        customMetadata: {'original_name': fileName},
      );
      await ref.putData(Uint8List.fromList(bytes), metadata);
      final url = await ref.getDownloadURL();
      developer.log('Uploaded $objectName', name: _logName);
      return url;
    } catch (e, st) {
      developer.log(
        'Firebase upload failed for $fileName',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  static Future<String?> uploadMedia({
    required List<int> bytes,
    required String fileName,
    int? userId,
  }) =>
      uploadBytes(bytes: bytes, fileName: fileName, folder: 'media', userId: userId);

  static Future<String?> uploadProfileAvatar({
    required List<int> bytes,
    required String fileName,
    required int userId,
  }) =>
      uploadBytes(bytes: bytes, fileName: fileName, folder: 'profiles', userId: userId);
}
