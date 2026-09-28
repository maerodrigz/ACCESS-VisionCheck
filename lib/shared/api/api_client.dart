import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:access_mobile/shared/constants/api_config.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;
  const ApiException(this.message, {this.statusCode, this.code});

  /// True when the JWT is missing, expired, or rejected by the server.
  bool get isUnauthorized {
    if (statusCode == 401) return true;
    final lower = message.toLowerCase();
    return lower.contains('invalid token') ||
        lower.contains('no token') ||
        lower.contains('user not found');
  }

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  /// Avoid endless spinner when PC backend is off or unreachable.
  static const Duration timeout = Duration(seconds: 15);

  /// Fast probe when scanning LAN / emulator candidates on a physical phone.
  static const Duration probeTimeout = Duration(seconds: 2);

  /// Multipart upload + server processing (practice eval save, event coverage).
  static Duration mediaUploadTimeout({
    required int byteLength,
    required String fileName,
  }) {
    final lower = fileName.toLowerCase();
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.m4v');
    final mb = byteLength / (1024 * 1024);
    if (isVideo) {
      // Upload over Wi-Fi + FFmpeg/pipeline on the PC can exceed 15s easily.
      final seconds = (180 + mb * 4).clamp(180, 600).round();
      return Duration(seconds: seconds);
    }
    final seconds = (60 + mb * 2).clamp(60, 120).round();
    return Duration(seconds: seconds);
  }

  String? _pinnedBaseUrl;

  void setToken(String? token) => _token = token;

  String? get token => _token;

  /// Clear pinned host after the user changes backend URL in settings.
  void resetConnection() => _pinnedBaseUrl = null;

  Future<void> reconnect() async {
    resetConnection();
    await warmUpConnection();
  }

  /// Finds a reachable backend once at startup (parallel batches of 3).
  Future<void> warmUpConnection() async {
    if (_pinnedBaseUrl != null) return;
    final candidates = ApiConfig.candidateBaseUrls();
    if (candidates.isEmpty) return;

    Future<String?> probe(String baseUrl) async {
      try {
        final uri = Uri.parse('${baseUrl}${ApiConfig.apiPrefix}/health');
        final response =
            await _client.get(uri, headers: _headers).timeout(probeTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return baseUrl;
        }
      } catch (_) {}
      return null;
    }

    for (var i = 0; i < candidates.length; i += 3) {
      final batch = candidates.skip(i).take(3).toList();
      final hits = await Future.wait(batch.map(probe));
      for (final hit in hits) {
        if (hit != null) {
          _pinnedBaseUrl = hit;
          await _rememberWorkingBaseUrl(hit);
          _log('Pinned API host → $hit');
          return;
        }
      }
    }
  }

  Duration _timeoutForBase(String baseUrl) {
    if (_pinnedBaseUrl != null && baseUrl == _pinnedBaseUrl) return timeout;
    if (ApiConfig.candidateBaseUrls().length <= 1) return timeout;
    return probeTimeout;
  }

  List<String> _basesToTry() {
    final all = ApiConfig.candidateBaseUrls();
    if (_pinnedBaseUrl == null) return all;
    final pinned = _pinnedBaseUrl!;
    return [pinned, ...all.where((b) => b != pinned)];
  }

  Uri _uriForBase(String baseUrl, String path, [Map<String, String>? query]) {
    final base = '$baseUrl${ApiConfig.apiPrefix}$path';
    return query == null ? Uri.parse(base) : Uri.parse(base).replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _request('GET', path, query: queryParameters);
  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body: body);
  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    required Map<String, String> fields,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? ApiClient.timeout;
    Object? lastError;
    for (final baseUrl in _basesToTry()) {
      final uri = _uriForBase(baseUrl, path);
      _log('POST (multipart) $uri  fields=${fields.keys.toList()} file=$fileName (${fileBytes.length} B)');
      final request = http.MultipartRequest('POST', uri);
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.fields.addAll(fields);
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
      try {
        final streamed = await request.send().timeout(effectiveTimeout);
        // Server may still run scoring / pipeline after the bytes arrive.
        const processingGrace = Duration(seconds: 180);
        final response = await http.Response.fromStream(streamed).timeout(
          effectiveTimeout + processingGrace,
        );
        _log('← ${response.statusCode} POST $uri (${response.body.length} B)');
        final parsed = _parseResponse(response, method: 'POST', uri: uri);
        _pinnedBaseUrl = baseUrl;
        await _rememberWorkingBaseUrl(baseUrl);
        return parsed;
      } catch (e) {
        lastError = e;
        // Try the next candidate only for connectivity failures.
        final msg = e.toString().toLowerCase();
        final isConnect = msg.contains('socketexception') ||
            msg.contains('connection refused') ||
            msg.contains('failed host lookup') ||
            msg.contains('network is unreachable') ||
            msg.contains('timeout') ||
            msg.contains('timed out');
        if (!isConnect) rethrow;
        if (_pinnedBaseUrl == baseUrl) {
          resetConnection();
          await ApiConfig.forgetLastWorkingBaseUrl(baseUrl);
        }
      }
    }
    // All candidates failed.
    final uri = _uriForBase(ApiConfig.baseUrl, path);
    throw _connectionError(lastError ?? Exception('Connection failed'), method: 'POST', uri: uri);
  }

  Future<void> _rememberWorkingBaseUrl(String baseUrl) async {
    await ApiConfig.saveLastWorkingBaseUrl(baseUrl);
  }

  ApiException _connectionError(Object e, {required String method, required Uri uri}) {
    if (e is ApiException) return e;
    final msg = e.toString().toLowerCase();
    _log('✗ $method $uri  error=$e', isError: true);

    if (msg.contains('timeout') || msg.contains('timed out')) {
      final target = uri.origin;
      final path = uri.path;
      if (path.contains('/media/upload') || path.contains('/media/evaluate')) {
        return ApiException(
          'Upload timed out at $target.\n'
          'Large videos can take several minutes on Wi-Fi. '
          'Stay on this screen with the app open and tap Save again.\n'
          'If it keeps failing, move closer to your router or use a shorter clip.',
        );
      }
      return ApiException(
        'Server timeout at $target.\n'
        '• Tap the banner above and choose Set backend URL\n'
        '• Use your PC IPv4 from ipconfig (same Wi-Fi as this phone)\n'
        '• Start backend: cd access_backend && python manage.py runserver',
      );
    }
    if (msg.contains('failed to fetch') || msg.contains('xmlhttprequest')) {
      return ApiException(
        'Browser blocked the request to ${ApiConfig.baseUrl}. '
        'Ensure backend is running, then stop Flutter and run: '
        'flutter run -d chrome --dart-define-from-file=config/api.json',
      );
    }
    if (msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable')) {
      return ApiException(
        'Cannot reach server at ${ApiConfig.baseUrl}.\n'
        '• Start backend on the PC: cd access_backend && python manage.py runserver\n'
        '• Physical phone? Use the PC LAN IPv4 — pass --dart-define=API_PUBLIC_HOST=192.168.x.x\n'
        '• Android emulator uses 10.0.2.2 (not 127.0.0.1).',
      );
    }
    return ApiException(
      'Cannot reach server at ${ApiConfig.baseUrl}. '
      'Start: cd access_backend && python manage.py runserver',
    );
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    Object? lastError;
    for (final baseUrl in _basesToTry()) {
      final queryParams = query?.map((k, v) => MapEntry(k, '$v'));
      final uri = _uriForBase(baseUrl, path, queryParams);
      _log('$method $uri${body == null ? '' : '  body=${_truncate(jsonEncode(body))}'}');
      late http.Response response;
      try {
        switch (method) {
          case 'GET':
            response = await _client.get(uri, headers: _headers).timeout(_timeoutForBase(baseUrl));
            break;
          case 'POST':
            response = await _client
                .post(uri, headers: _headers, body: jsonEncode(body))
                .timeout(_timeoutForBase(baseUrl));
            break;
          case 'PATCH':
            response = await _client
                .patch(uri, headers: _headers, body: jsonEncode(body))
                .timeout(_timeoutForBase(baseUrl));
            break;
          case 'DELETE':
            response = await _client.delete(uri, headers: _headers).timeout(_timeoutForBase(baseUrl));
            break;
          default:
            throw ApiException('Unsupported method $method');
        }
      } catch (e) {
        lastError = e;
        // Only try the next candidate for connectivity-type failures.
        final msg = e.toString().toLowerCase();
        final isConnect = msg.contains('socketexception') ||
            msg.contains('connection refused') ||
            msg.contains('failed host lookup') ||
            msg.contains('network is unreachable') ||
            msg.contains('timeout') ||
            msg.contains('timed out');
        if (!isConnect) {
          throw _connectionError(e, method: method, uri: uri);
        }
        if (_pinnedBaseUrl == baseUrl) {
          resetConnection();
          await ApiConfig.forgetLastWorkingBaseUrl(baseUrl);
        }
        continue;
      }

      _log('← ${response.statusCode} $method $uri (${response.body.length} B)');
      final parsed = _parseResponse(response, method: method, uri: uri);
      _pinnedBaseUrl = baseUrl;
      await _rememberWorkingBaseUrl(baseUrl);
      return parsed;
    }

    final uri = _uriForBase(ApiConfig.baseUrl, path);
    throw _connectionError(lastError ?? Exception('Connection failed'), method: method, uri: uri);
  }

  dynamic _parseResponse(http.Response response, {required String method, required Uri uri}) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {'error': response.body.trim()};
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? {};
    }

    final map = decoded is Map<String, dynamic> ? decoded : null;
    final detail = map?['detail'];
    final detailMsg = detail is Map<String, dynamic>
        ? (detail['message'] as String? ?? detail['details'] as String?)
        : (detail is String ? detail : null);
    final msg = map?['message'] as String? ??
        detailMsg ??
        map?['error'] as String? ??
        'Request failed (${response.statusCode})';
    final details = map?['details'] as String? ?? map?['detail'] as String?;
    final displayMsg = (msg == 'Unable to load data' && details != null && details.isNotEmpty)
        ? details
        : msg;
    _log('✗ $method $uri  status=${response.statusCode}  msg=$displayMsg', isError: true);
    throw ApiException(
      displayMsg,
      statusCode: response.statusCode,
      code: map?['error'] as String? ??
          (detail is Map<String, dynamic> ? detail['code'] as String? : null),
    );
  }

  static String _truncate(String value, [int max = 240]) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }

  static void _log(String message, {bool isError = false}) {
    if (!kDebugMode) return;
    developer.log(message, name: 'ACCESS.api', level: isError ? 1000 : 800);
  }
}

final apiClient = ApiClient();
