import 'package:flutter/foundation.dart'
    show ChangeNotifier, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

/// Backend API configuration. Sync with `access_backend/.env` and
/// `config/api.json`.
///
/// Defaults are picked so the mobile app works **out of the box**:
/// - **Chrome / web admin (same PC):** `http://127.0.0.1:3001`
/// - **Web admin on a deployed server** (e.g. `http://103.x.x.x/`): same origin
///   as the page — nginx proxies `/api` on port 80 (no `:3001` in the browser).
/// - **Android emulator:** `http://10.0.2.2:3001` (special alias for the host
///   machine's localhost — works for the default Android Studio emulator).
/// - **Physical phone:** override with the PC's LAN IPv4 address using
///   `--dart-define=API_PUBLIC_HOST=192.168.x.x` or
///   `--dart-define=API_BASE_URL=http://192.168.x.x:3001`.
///
/// Examples:
/// ```
/// # Same PC + Android emulator (default — no flag needed)
/// flutter run -t lib/mobile_app/main_mobile.dart
///
/// # Physical phone on the same Wi-Fi as the PC
/// flutter run -t lib/mobile_app/main_mobile.dart \
///   --dart-define=API_PUBLIC_HOST=192.168.1.42
///
/// # Or via config file
/// flutter run --dart-define-from-file=config/api.json
/// ```
///
/// NEVER use `localhost` or `127.0.0.1` on a physical phone — those resolve
/// to the phone itself, not the PC running FastAPI.
class ApiConfig {
  ApiConfig._();

  /// Android emulator's alias for the host machine (PC) `127.0.0.1`.
  static const String androidEmulatorHost = '10.0.2.2';

  /// Default port for FastAPI (`API_PORT` in `access_backend/.env`).
  static const int defaultPort = 3001;

  /// Full base URL override (highest priority). Example:
  /// `--dart-define=API_BASE_URL=http://192.168.1.42:3001`
  static const String apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL');

  /// Host override for native mobile builds. Use the **PC's LAN IPv4** for a
  /// physical phone. Example: `--dart-define=API_PUBLIC_HOST=192.168.1.42`.
  static const String apiPublicHostOverride =
      String.fromEnvironment('API_PUBLIC_HOST');

  /// Host override for web builds. Defaults to `127.0.0.1` because that is
  /// what Chrome on the same PC sees.
  static const String apiWebHostOverride =
      String.fromEnvironment('API_WEB_HOST', defaultValue: '127.0.0.1');

  /// Generic host override (applies to all platforms). Lower priority than
  /// the platform-specific overrides above.
  static const String apiHostOverride = String.fromEnvironment('API_HOST');

  /// Compile-time port override.
  static const String apiPortOverride =
      String.fromEnvironment('API_PORT', defaultValue: '$defaultPort');

  /// When web admin is opened at a public IP or domain (not localhost), API
  /// calls must use the same origin — nginx proxies `/api` on port 80.
  static String? get _webSameOriginBaseUrl {
    if (!kIsWeb) return null;
    final page = Uri.base;
    final h = page.host;
    if (h.isEmpty || h == 'localhost' || h == '127.0.0.1') return null;
    final scheme = page.scheme.isNotEmpty ? page.scheme : 'http';
    if (!page.hasPort || page.port == 80 || page.port == 443) {
      return '$scheme://$h';
    }
    return '$scheme://$h:${page.port}';
  }

  static String get host {
    if (apiHostOverride.isNotEmpty) return apiHostOverride;

    if (kIsWeb) {
      final sameOrigin = _webSameOriginBaseUrl;
      if (sameOrigin != null) return Uri.parse(sameOrigin).host;
      return apiWebHostOverride;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Physical phone → developer must pass API_PUBLIC_HOST.
      // Emulator → 10.0.2.2 works because the emulator routes it to the
      // host PC's loopback interface.
      return apiPublicHostOverride.isNotEmpty
          ? apiPublicHostOverride
          : androidEmulatorHost;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return apiPublicHostOverride.isNotEmpty
          ? apiPublicHostOverride
          : '127.0.0.1';
    }

    // Desktop (Windows / macOS / Linux) — backend on same PC.
    return apiPublicHostOverride.isNotEmpty
        ? apiPublicHostOverride
        : '127.0.0.1';
  }

  static int get port {
    return int.tryParse(apiPortOverride) ?? defaultPort;
  }

  /// Known LAN IPs for this project (campus vs home Wi-Fi).
  ///
  /// Used for automatic failover in [ApiClient] so the app can keep working
  /// when the PC changes networks without forcing a recompile or manual entry.
  static const List<String> knownLanHosts = [
    '10.68.93.169',
    '10.93.47.169',
    '192.168.8.99',
    '192.168.8.100',
    '10.96.22.169',
    '192.168.137.25',
    '192.168.137.162',
    '192.168.0.137',
    '10.0.22.98',
  ];

  static String get baseUrl {
    if (apiBaseUrlOverride.isNotEmpty) {
      return apiBaseUrlOverride.replaceAll(RegExp(r'/+$'), '');
    }
    final sameOrigin = _webSameOriginBaseUrl;
    if (sameOrigin != null) return sameOrigin;
    return 'http://$host:$port';
  }

  /// Host that last answered an API call (failover) or user/runtime override.
  /// Use for [mediaUrl] so uploaded logos match web admin on physical phones.
  static String get effectiveBaseUrl {
    final runtime = runtimeBaseUrl.value;
    if (runtime != null && runtime.trim().isNotEmpty) {
      return runtime.trim().replaceAll(RegExp(r'/+$'), '');
    }
    final sameOrigin = _webSameOriginBaseUrl;
    if (sameOrigin != null) return sameOrigin;
    if (_lastWorkingBaseUrl != null && _lastWorkingBaseUrl!.isNotEmpty) {
      return _lastWorkingBaseUrl!;
    }
    return baseUrl;
  }

  /// Absolute URL for `/uploads/...` paths returned by the API.
  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$effectiveBaseUrl$normalized';
  }

  static final List<void Function(String base)> _onWorkingBaseUrlSaved = [];

  /// Register to rebuild logo URLs when [ApiClient] finds a working host.
  static void addWorkingBaseUrlListener(void Function(String base) listener) {
    if (!_onWorkingBaseUrlSaved.contains(listener)) {
      _onWorkingBaseUrlSaved.add(listener);
    }
  }

  /// Last LAN base URL that successfully answered (auto-saved, not user-entered).
  static String? _lastWorkingBaseUrl;

  /// Wipe device-saved URLs when developer passed `--dart-define-from-file=config/api.json`.
  static Future<void> clearStaleOverridesWhenCompileTimeHostSet() async {
    final hasCompileTime =
        apiBaseUrlOverride.isNotEmpty || apiPublicHostOverride.isNotEmpty;
    if (!hasCompileTime) return;
    _lastWorkingBaseUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access.api_last_working_base_url');
      await prefs.remove('access.api_base_url_override');
    } catch (_) {}
    await runtimeBaseUrl.clear();
  }

  static Future<void> loadLastWorkingBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('access.api_last_working_base_url');
      if (saved != null && saved.trim().isNotEmpty) {
        _lastWorkingBaseUrl = saved.trim().replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {}
  }

  static Future<void> saveLastWorkingBaseUrl(String baseUrl) async {
    final normalized = baseUrl.replaceAll(RegExp(r'/+$'), '');
    _lastWorkingBaseUrl = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access.api_last_working_base_url', normalized);
    } catch (_) {}
    for (final listener in _onWorkingBaseUrlSaved) {
      listener(normalized);
    }
  }

  /// Drop a stale saved host after a connectivity failure (wrong Wi-Fi / IP changed).
  static Future<void> forgetLastWorkingBaseUrl(String baseUrl) async {
    final normalized = baseUrl.replaceAll(RegExp(r'/+$'), '');
    if (_lastWorkingBaseUrl != normalized) return;
    _lastWorkingBaseUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access.api_last_working_base_url');
    } catch (_) {}
  }

  /// Base URLs to try in order when the backend is unreachable.
  ///
  /// Order matters on physical phones: saved/runtime URLs first, then LAN
  /// fallbacks, emulator alias last (10.0.2.2 is wrong on real devices).
  static List<String> candidateBaseUrls() {
    final out = <String>[];

    void add(String? v) {
      if (v == null) return;
      final trimmed = v.trim();
      if (trimmed.isEmpty) return;
      final normalized = trimmed.replaceAll(RegExp(r'/+$'), '');
      if (!out.contains(normalized)) out.add(normalized);
    }

    final explicitCompileTimeHost =
        apiBaseUrlOverride.isNotEmpty || apiPublicHostOverride.isNotEmpty;
    final runtime = runtimeBaseUrl.value;

    add(apiBaseUrlOverride);
    if (explicitCompileTimeHost) {
      add(baseUrl);
    }
    add(_webSameOriginBaseUrl);

    if (!explicitCompileTimeHost) {
      add(runtime);
      add(_lastWorkingBaseUrl);
      // On Android, try known LAN IPs before 10.0.2.2 (emulator-only alias).
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        add(baseUrl);
      }
    }

    if (!explicitCompileTimeHost &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      for (final h in knownLanHosts) {
        add('http://$h:$port');
      }
      add('http://$androidEmulatorHost:$port');
    }

    if (kIsWeb && _webSameOriginBaseUrl == null) {
      add('http://$apiWebHostOverride:$defaultPort');
    }

    return out;
  }

  /// Live, listenable runtime override (in-memory + SharedPreferences).
  static final RuntimeBaseUrl runtimeBaseUrl = RuntimeBaseUrl._();

  static const String apiPrefix = '/api';

  /// One-line summary for splash / debug screens.
  static String describe() =>
      'API → $baseUrl$apiPrefix '
      '(host=$host port=$port platform=${kIsWeb ? "web" : defaultTargetPlatform.name})';
}

/// Stores a user-configured backend URL on the device. Lets the user fix
/// connectivity from the in-app banner without re-running `flutter run`.
class RuntimeBaseUrl extends ChangeNotifier {
  RuntimeBaseUrl._();

  static const _prefsKey = 'access.api_base_url_override';

  String? _value;
  String? get value => _value;

  /// Load any saved override. Call once at app start (before `runApp`).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _value = saved.trim();
        notifyListeners();
      }
    } catch (_) {
      // SharedPreferences not available — ignore.
    }
  }

  /// Save a new override. Pass `null` or empty to clear.
  Future<void> save(String? raw) async {
    final normalized = _normalize(raw);
    _value = normalized;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (normalized == null || normalized.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, normalized);
      }
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> clear() => save(null);

  /// Accepts `192.168.1.42`, `192.168.1.42:3001`, or a full
  /// `http://192.168.1.42:3001`. Returns a canonical `http://host:port`
  /// without trailing slash, or `null` for empty input.
  static String? _normalize(String? raw) {
    if (raw == null) return null;
    var v = raw.trim();
    if (v.isEmpty) return null;
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      v = 'http://$v';
    }
    final uri = Uri.tryParse(v);
    if (uri == null || uri.host.isEmpty) return null;
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
    final port = uri.hasPort ? uri.port : ApiConfig.defaultPort;
    return '$scheme://${uri.host}:$port';
  }
}
