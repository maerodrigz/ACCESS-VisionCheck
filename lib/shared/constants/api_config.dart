import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show rootBundle;
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

  /// USB + `adb reverse tcp:3001 tcp:3001` — original backend on the dev PC.
  static const String originalUsbDevBaseUrl = 'http://127.0.0.1:3001';

  /// Isolated QA stack (access_waverep_test) — must not override original app.
  static const int isolatedQaApiPort = 3003;

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
      if (apiPublicHostOverride.isNotEmpty) {
        return apiPublicHostOverride;
      }
      final runtime = runtimeBaseUrl.value?.trim();
      if (runtime != null && runtime.isNotEmpty) {
        try {
          return Uri.parse(runtime).host;
        } catch (_) {}
      }
      // Physical phone (default): PC LAN IP from config/api.json / knownLanHosts.
      // Emulator only: flutter run --dart-define=API_PUBLIC_HOST=10.0.2.2
      if (_androidIsPhysicalDevice == false) {
        return androidEmulatorHost;
      }
      if (knownLanHosts.isNotEmpty) return knownLanHosts.first;
      return androidEmulatorHost;
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
    '192.168.8.97',
    '10.216.233.169',
    '10.210.8.169',
    '192.168.8.94',
    '192.168.8.96',
    '192.168.8.98',
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
    final runtime = runtimeBaseUrl.value?.trim();
    if (runtime != null && runtime.isNotEmpty) {
      return runtime.replaceAll(RegExp(r'/+$'), '');
    }
    if (_lastWorkingBaseUrl != null && _lastWorkingBaseUrl!.isNotEmpty) {
      return _lastWorkingBaseUrl!;
    }
    return 'http://$host:$port';
  }

  /// Host that last answered an API call (failover) or user/runtime override.
  /// Use for [mediaUrl] so uploaded logos match web admin on physical phones.
  static String get effectiveBaseUrl {
    if (apiBaseUrlOverride.isNotEmpty) {
      return apiBaseUrlOverride.replaceAll(RegExp(r'/+$'), '');
    }
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
    if (path.startsWith('supabase-ref:')) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      // Legacy Supabase signed URLs missing /storage/v1 (404 on device).
      if (path.contains('supabase.co/object/') && !path.contains('/storage/v1/object/')) {
        return path.replaceFirst('.supabase.co/object/', '.supabase.co/storage/v1/object/');
      }
      return path;
    }
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

  /// Dev default from [config/api.json] (bundled asset). Used on Android when
  /// no runtime URL is saved so physical phones do not stay on 10.0.2.2 only.
  /// Drop saved 10.0.2.2 override — that host is emulator-only and breaks physical phones.
  /// True when [raw] points at the isolated QA API (port 3003).
  static bool isIsolatedQaBackendUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    if (trimmed.contains(':3003')) return true;
    try {
      final uri = Uri.parse(
        trimmed.startsWith('http') ? trimmed : 'http://$trimmed',
      );
      return uri.port == isolatedQaApiPort;
    } catch (_) {
      return false;
    }
  }

  static bool isLocalOriginalUsbBackendUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    try {
      final uri = Uri.parse(
        trimmed.startsWith('http') ? trimmed : 'http://$trimmed',
      );
      return (uri.host == '127.0.0.1' || uri.host == 'localhost') &&
          uri.port == defaultPort;
    } catch (_) {
      return trimmed.contains('127.0.0.1:3001');
    }
  }

  static String _originalDevBackendTarget() {
    if (apiBaseUrlOverride.isNotEmpty) {
      return apiBaseUrlOverride.replaceAll(RegExp(r'/+$'), '');
    }
    return originalUsbDevBaseUrl;
  }

  /// Rewrites saved QA `:3003` overrides to the original USB backend (`:3001`).
  static Future<bool> migrateIsolatedQaBackendToOriginalUsb() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final target = _originalDevBackendTarget();
    var migrated = false;

    final runtime = runtimeBaseUrl.value?.trim();
    if (isIsolatedQaBackendUrl(runtime)) {
      await runtimeBaseUrl.save(target);
      migrated = true;
    }

    if (_lastWorkingBaseUrl != null &&
        isIsolatedQaBackendUrl(_lastWorkingBaseUrl)) {
      final stale = _lastWorkingBaseUrl!;
      await forgetLastWorkingBaseUrl(stale);
      await saveLastWorkingBaseUrl(target);
      migrated = true;
    }

    return migrated;
  }

  static Future<void> clearStaleEmulatorBackendOverride() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    // Compile-time base (e.g. emulator --dart-define=API_BASE_URL=10.0.2.2:3002) wins.
    if (apiBaseUrlOverride.isNotEmpty || apiPublicHostOverride.isNotEmpty) return;
    final saved = runtimeBaseUrl.value?.trim().toLowerCase() ?? '';
    if (saved.contains('10.0.2.2')) {
      await runtimeBaseUrl.clear();
    }
    if (_lastWorkingBaseUrl != null &&
        _lastWorkingBaseUrl!.toLowerCase().contains('10.0.2.2')) {
      await forgetLastWorkingBaseUrl(_lastWorkingBaseUrl!);
    }
  }

  /// Same /24 IPv4 prefix (e.g. home Wi-Fi DHCP last-octet changes).
  static bool isSameIpv4Subnet24(String hostA, String hostB) {
    final a = hostA.split('.');
    final b = hostB.split('.');
    if (a.length != 4 || b.length != 4) return false;
    return '${a[0]}.${a[1]}.${a[2]}' == '${b[0]}.${b[1]}.${b[2]}';
  }

  /// Drop saved URLs on the same LAN /24 as [bundledBase] when the host octet changed.
  static Future<void> migrateStaleDeviceUrlsForBundledDevBase(String bundledBase) async {
    try {
      final bundledHost = Uri.parse(bundledBase).host;
      final existing = runtimeBaseUrl.value?.trim();
      if (existing != null && existing.isNotEmpty) {
        final existingHost =
            Uri.parse(existing.startsWith('http') ? existing : 'http://$existing').host;
        if (isSameIpv4Subnet24(existingHost, bundledHost) && existingHost != bundledHost) {
          await runtimeBaseUrl.save(bundledBase);
        }
      }
      final last = _lastWorkingBaseUrl;
      if (last != null && last.trim().isNotEmpty) {
        final lastHost = Uri.parse(last).host;
        if (isSameIpv4Subnet24(lastHost, bundledHost) && lastHost != bundledHost) {
          await forgetLastWorkingBaseUrl(last);
        }
      }
    } catch (_) {}
  }

  static Future<void> loadBundledMobileBackendDefault() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (apiBaseUrlOverride.isNotEmpty || apiPublicHostOverride.isNotEmpty) {
      return;
    }
    // Bundled LAN IP breaks the Android emulator; use 10.0.2.2 default instead.
    if (defaultTargetPlatform == TargetPlatform.android &&
        _androidIsPhysicalDevice == false) {
      return;
    }
    try {
      final raw = await rootBundle.loadString('config/api.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final base = (map['API_BASE_URL'] as String?)?.trim();
      if (base == null || base.isEmpty) return;
      await migrateStaleDeviceUrlsForBundledDevBase(base);
      final existing = runtimeBaseUrl.value?.trim();
      if (existing == null || existing.isEmpty) {
        await runtimeBaseUrl.save(base);
        return;
      }
      if (isLocalOriginalUsbBackendUrl(existing) ||
          isIsolatedQaBackendUrl(existing)) {
        return;
      }
      // Refresh when bundled dev IP changed (e.g. Wi-Fi DHCP) or stale emulator host.
      if (existing.contains('10.0.2.2')) {
        await runtimeBaseUrl.save(base);
        return;
      }
      if (existing != base &&
          !isLocalOriginalUsbBackendUrl(existing) &&
          !existing.contains('127.0.0.1')) {
        await runtimeBaseUrl.save(base);
        return;
      }
      // Wrong subnet saved (e.g. old 192.168.8.96 while bundled says .94).
      try {
        final bundledHost = Uri.parse(base).host;
        final existingHost = Uri.parse(existing.startsWith('http') ? existing : 'http://$existing').host;
        if (bundledHost != existingHost &&
            bundledHost.startsWith('192.168.') &&
            existingHost.startsWith('192.168.')) {
          await runtimeBaseUrl.save(base);
        }
      } catch (_) {}
    } catch (_) {
      // Asset missing or invalid — ignore.
    }
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

  /// Set from [initAndroidDeviceProfile] in mobile main() before API calls.
  static bool? _androidIsPhysicalDevice;

  static Future<void> initAndroidDeviceProfile() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _androidIsPhysicalDevice = info.isPhysicalDevice;
    } catch (_) {
      _androidIsPhysicalDevice = true;
    }
  }

  /// True when Android build targets the Studio emulator (no phone LAN override).
  static bool get androidEmulatorDefault {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (apiBaseUrlOverride.isNotEmpty || apiPublicHostOverride.isNotEmpty) {
      return false;
    }
    final runtime = runtimeBaseUrl.value?.trim();
    return runtime == null || runtime.isEmpty;
  }

  /// Base URLs to try in order when the backend is unreachable.
  ///
  /// Physical phone: saved/runtime URL first, then LAN fallbacks.
  /// Emulator (no override): [10.0.2.2] first so login is not delayed by stale LAN IPs.
  static List<String> candidateBaseUrls() {
    if (apiBaseUrlOverride.isNotEmpty) {
      return [apiBaseUrlOverride.replaceAll(RegExp(r'/+$'), '')];
    }
    if (apiPublicHostOverride.isNotEmpty) {
      return [baseUrl];
    }

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
    final emulatorDefault = androidEmulatorDefault;

    add(apiBaseUrlOverride);
    if (explicitCompileTimeHost) {
      add(baseUrl);
    }
    add(_webSameOriginBaseUrl);

    if (!explicitCompileTimeHost) {
      add(runtime);
      add(_lastWorkingBaseUrl);
      if (_androidIsPhysicalDevice != false) {
        add('http://${knownLanHosts.first}:$port');
      }
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        add(baseUrl);
      } else if (!emulatorDefault) {
        add(baseUrl);
      }
    }

    if (!explicitCompileTimeHost &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      for (final h in knownLanHosts) {
        add('http://$h:$port');
      }
      if (_androidIsPhysicalDevice == false) {
        add('http://$androidEmulatorHost:$port');
      }
    }

    if (kIsWeb && _webSameOriginBaseUrl == null) {
      add('http://$apiWebHostOverride:$port');
    }

    return out;
  }

  /// Sign-in: prefer saved/device URL, then configured host, then same-subnet LAN fallbacks.
  static List<String> loginBaseUrls() {
    if (apiBaseUrlOverride.isNotEmpty) {
      return [apiBaseUrlOverride.replaceAll(RegExp(r'/+$'), '')];
    }
    if (apiPublicHostOverride.isNotEmpty) {
      return [baseUrl];
    }

    final out = <String>[];

    void add(String? v) {
      if (v == null) return;
      final trimmed = v.trim();
      if (trimmed.isEmpty) return;
      final normalized = trimmed.replaceAll(RegExp(r'/+$'), '');
      if (!out.contains(normalized)) out.add(normalized);
    }

    final emulatorDefault = androidEmulatorDefault;

    add(runtimeBaseUrl.value);
    add(_lastWorkingBaseUrl);
    add(_webSameOriginBaseUrl);

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      add(baseUrl);
    } else if (emulatorDefault) {
      add('http://$androidEmulatorHost:$port');
    } else {
      add(baseUrl);
    }

    _addLoginSubnetLanFallbacks(out, add);

    if (kIsWeb && _webSameOriginBaseUrl == null) {
      add('http://$apiWebHostOverride:$port');
    }

    if (out.isEmpty) {
      add(baseUrl);
    }
    return out;
  }

  /// When the PC DHCP last octet changes (e.g. .94 → .97), try other known hosts on the same /24.
  static void _addLoginSubnetLanFallbacks(
    List<String> current,
    void Function(String? url) add,
  ) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    String? anchorHost;
    for (final url in current) {
      try {
        anchorHost = Uri.parse(url).host;
        if (anchorHost.isNotEmpty) break;
      } catch (_) {}
    }
    anchorHost ??= host;
    final parts = anchorHost.split('.');
    if (parts.length != 4) return;
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
    for (final h in knownLanHosts) {
      if (h.startsWith(prefix)) {
        add('http://$h:$port');
      }
    }
  }

  /// Live, listenable runtime override (in-memory + SharedPreferences).
  static final RuntimeBaseUrl runtimeBaseUrl = RuntimeBaseUrl._();

  static const String apiPrefix = '/api';

  /// Example URL shown when a physical phone cannot reach the PC backend.
  static String get suggestedPhoneBackendUrl {
    if (apiBaseUrlOverride.isNotEmpty) {
      return apiBaseUrlOverride.replaceAll(RegExp(r'/+$'), '');
    }
    if (apiPublicHostOverride.isNotEmpty) {
      return 'http://$apiPublicHostOverride:$port';
    }
    if (knownLanHosts.isNotEmpty) {
      return 'http://${knownLanHosts.first}:$port';
    }
    return 'http://<PC Wi-Fi IPv4>:$port';
  }

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
