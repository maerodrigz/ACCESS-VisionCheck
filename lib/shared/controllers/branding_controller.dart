import 'package:flutter/foundation.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';

/// Loads custom logo and system display names from API.
class BrandingController extends ChangeNotifier {
  String? _logoUrl;
  String? _updatedAt;
  bool _isCustomLogo = false;
  bool _namesCustom = false;

  String _appName = AppConstants.appName;
  String _tagline = AppConstants.tagline;
  String _shortTagline = AppConstants.shortTagline;
  String _organization = AppConstants.organization;
  String _webAdminTitle = AppConstants.webAdminTitle;

  bool isLoading = false;
  String? lastError;

  String get appName => _appName;
  String get tagline => _tagline;
  String get shortTagline => _shortTagline;
  /// Login hero subtitle (API [short_tagline], bundled default before load).
  String get loginHeroTagline => _shortTagline;
  String get organization => _organization;
  String get webAdminTitle => _webAdminTitle;
  String get mobileTitle => _appName;
  bool get isCustomLogo => _isCustomLogo;
  bool get namesCustom => _namesCustom;
  String? get updatedAt => _updatedAt;

  String? get networkLogoUrl {
    if (_logoUrl == null || _logoUrl!.isEmpty) return null;
    final base = ApiConfig.mediaUrl(_logoUrl);
    if (_updatedAt != null && _updatedAt!.isNotEmpty) {
      final sep = base.contains('?') ? '&' : '?';
      return '$base${sep}v=${Uri.encodeComponent(_updatedAt!)}';
    }
    return base;
  }

  BrandingController() {
    ApiConfig.addWorkingBaseUrlListener((_) => notifyListeners());
  }

  void _applyPayload(Map<String, dynamic> map) {
    final path = map['logo_url'] as String?;
    _updatedAt = map['updated_at'] as String?;
    _isCustomLogo = map['is_custom'] as bool? ?? (path != null && path.isNotEmpty);
    _logoUrl = (path != null && path.isNotEmpty) ? path : null;
    _namesCustom = map['names_custom'] as bool? ?? false;
    _appName = (map['app_name'] as String?)?.trim().isNotEmpty == true
        ? map['app_name'] as String
        : AppConstants.appName;
    _tagline = (map['tagline'] as String?)?.trim().isNotEmpty == true
        ? map['tagline'] as String
        : AppConstants.tagline;
    _shortTagline = (map['short_tagline'] as String?)?.trim().isNotEmpty == true
        ? map['short_tagline'] as String
        : AppConstants.shortTagline;
    _organization = (map['organization'] as String?)?.trim().isNotEmpty == true
        ? map['organization'] as String
        : AppConstants.organization;
    _webAdminTitle = (map['web_admin_title'] as String?)?.trim().isNotEmpty == true
        ? map['web_admin_title'] as String
        : '$_appName - Admin';
  }

  Future<void> refresh() async {
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      final data = await apiClient.get('/branding');
      _applyPayload(Map<String, dynamic>.from(data as Map));
      lastError = null;
    } catch (e) {
      lastError = e.toString();
      if (!_isCustomLogo) _logoUrl = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void applyPayload(Map<String, dynamic> result) {
    _applyPayload(result);
    notifyListeners();
  }

  void applyUploadResult(Map<String, dynamic> result) => applyPayload(result);

  void applyResetLogoResult(Map<String, dynamic> result) => applyPayload(result);
}

final brandingController = BrandingController();
