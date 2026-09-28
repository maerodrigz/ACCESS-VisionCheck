import 'package:flutter/foundation.dart' show kIsWeb;

/// Meta / Facebook credentials for flutter_facebook_auth.
///
/// **Web (Chrome admin):** set [webAppId] below OR run:
/// `flutter run -d chrome --dart-define=FACEBOOK_APP_ID=your_id`
///
/// **Android:** also set `android/app/src/main/res/values/strings.xml`
///
/// Meta Console: https://developers.facebook.com → your app → add **Web** platform
/// with site URL `http://localhost` (and your LAN URL if needed).
class FacebookConfig {
  FacebookConfig._();

  /// ACCESS org Facebook Page (must match access_backend/.env FACEBOOK_PAGE_ID).
  /// https://www.facebook.com/profile.php?id=1202339146306816
  static const String defaultPageId = '1202339146306816';

  /// Paste your Meta App ID here for web admin (Chrome). Leave empty to use --dart-define only.
  static const String webAppId = '';

  static const String webClientToken = '';

  static const String appId = String.fromEnvironment(
    'FACEBOOK_APP_ID',
    defaultValue: '',
  );

  static const String clientToken = String.fromEnvironment(
    'FACEBOOK_CLIENT_TOKEN',
    defaultValue: '',
  );

  static String get effectiveAppId {
    if (appId.isNotEmpty && !_isPlaceholder(appId)) return appId;
    if (webAppId.isNotEmpty && !_isPlaceholder(webAppId)) return webAppId;
    return '';
  }

  static String get effectiveClientToken {
    if (clientToken.isNotEmpty && !_isPlaceholder(clientToken)) return clientToken;
    if (webClientToken.isNotEmpty && !_isPlaceholder(webClientToken)) return webClientToken;
    return '';
  }

  static bool _isPlaceholder(String v) =>
      v.startsWith('YOUR_') || v == '0';

  static bool get isConfigured =>
      effectiveAppId.isNotEmpty && effectiveClientToken.isNotEmpty;

  static bool get isConfiguredAppIdOnly => effectiveAppId.isNotEmpty;

  static String setupHint({bool? forWeb}) {
    final web = forWeb ?? kIsWeb;
    if (web) {
      return '1. Create a Meta app at developers.facebook.com\n'
          '2. Add Web platform → Site URL: http://localhost\n'
          '3. Set webAppId in lib/shared/constants/facebook_config.dart\n'
          '   OR: flutter run -d chrome --dart-define=FACEBOOK_APP_ID=YOUR_ID\n'
          '4. Hot restart, then click Connect with Facebook';
    }
    return 'Set facebook_app_id in android/app/src/main/res/values/strings.xml';
  }
}
