import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/screens/registration_choice_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/login/login_brand_panel.dart';
import 'package:access_mobile/shared/widgets/login/login_error_toast.dart';
import 'package:access_mobile/shared/widgets/login/login_form_panel.dart';
import 'package:access_mobile/shared/widgets/login/login_notice_host.dart';
import 'package:access_mobile/shared/widgets/login/login_page_tokens.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_navigation.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_scaffold.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_sign_in_form.dart';
import 'package:access_mobile/shared/widgets/forgot_password_dialog.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _isBackendConnectivityMessage(String message) {
  final lower = message.toLowerCase();
  return lower.contains('cannot reach') ||
      lower.contains("can't reach") ||
      lower.contains('pc backend') ||
      lower.contains('backend url') ||
      lower.contains('wi-fi ip') ||
      lower.contains('timed out') ||
      lower.contains('server timeout') ||
      lower.contains('fix connection');
}

/// Builds the lockout body from the backend detail (remaining minutes).
/// Never hardcodes a duration; falls back when the API omits a timer.
@visibleForTesting
String lockoutSupportingMessage(String raw) {
  final match = RegExp(r'(\d+)\s+minutes?', caseSensitive: false).firstMatch(raw);
  if (match != null) {
    final minutes = match.group(1)!;
    final unit = minutes == '1' ? 'minute' : 'minutes';
    return 'Please try again in $minutes $unit.';
  }
  return 'Please try again later.';
}

/// Enterprise login for ACCESS VisionCheck — web admin and mobile.
class VisionLoginScreen extends StatefulWidget {
  const VisionLoginScreen({super.key, this.onAuthenticated});

  final void Function()? onAuthenticated;

  @override
  State<VisionLoginScreen> createState() => _VisionLoginScreenState();
}

class _VisionLoginScreenState extends State<VisionLoginScreen>
    with LoginNoticeHost<VisionLoginScreen> {
  static const _rememberKey = 'login_remember_email';

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;
  bool _loading = false;
  /// Guards rapid re-entry before the first [setState] paints `loading`.
  bool _submitLocked = false;

  @override
  void initState() {
    super.initState();
    // Keep login hero in sync with GET /branding (tagline, custom logo, app name).
    unawaited(brandingController.refresh());
    _loadRememberedEmail();
    // Drop stale session messages on mobile so sign-in stays clean (no banner/snack).
    if (kIsWeb) {
      final ended = authController.consumeSessionEndMessage();
      if (ended != null && ended.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showLoginNotice(ended, LoginNoticeKind.server);
        });
      }
    } else {
      authController.consumeSessionEndMessage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      });
    }
    unawaited(_recoverWhenBackendIsReachable());
  }

  /// Clears stale offline banners and restores JWT when the PC backend comes back.
  Future<void> _recoverWhenBackendIsReachable() async {
    final reachable = await apiClient.checkReachable();
    if (!mounted) return;
    if (!reachable) return;

    final backendBanner = loginNoticeMessage != null &&
        _isBackendConnectivityMessage(loginNoticeMessage!);
    if (!backendBanner) return;

    final restored = await authController.retryPersistedSession();
    if (!mounted) return;
    if (restored) {
      dismissLoginNotice();
      widget.onAuthenticated?.call();
      return;
    }
    if (kIsWeb) {
      final ended = authController.consumeSessionEndMessage();
      if (ended != null && ended.isNotEmpty) {
        showLoginNotice(ended, LoginNoticeKind.server);
      } else {
        dismissLoginNotice();
      }
    } else {
      authController.consumeSessionEndMessage();
      dismissLoginNotice();
    }
  }

  @override
  void dispose() {
    disposeLoginNotice();
    _passCtrl.clear();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_rememberKey);
    if (!mounted || saved == null || saved.isEmpty) return;
    // Never overwrite email the user already started typing.
    if (_emailCtrl.text.trim().isNotEmpty) {
      setState(() => _rememberMe = true);
      return;
    }
    setState(() {
      _emailCtrl.value = TextEditingValue(
        text: saved,
        selection: TextSelection.collapsed(offset: saved.length),
      );
      _rememberMe = true;
    });
  }

  Future<void> _persistRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_rememberKey, _emailCtrl.text.trim());
    } else {
      await prefs.remove(_rememberKey);
    }
  }

  Future<void> _submit() async {
    if (_loading || _submitLocked) return;
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      showLoginNotice('Please fill in all fields.', LoginNoticeKind.validation);
      return;
    }
    _submitLocked = true;
    setState(() => _loading = true);
    dismissLoginNotice();
    // Snapshot credentials once — never rewrite controllers on failure.
    try {
      await authController.login(email, pass);
      await _persistRememberMe();
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      _passCtrl.clear();
      dismissLoginNotice();
      setState(() => _loading = false);
      widget.onAuthenticated?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      // Keep email/password text and focus exactly as the user left them.
      _presentApiLoginError(e);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showLoginNotice(
        'Something went wrong. Please try again.',
        LoginNoticeKind.server,
      );
    } finally {
      _submitLocked = false;
    }
  }

  void _presentApiLoginError(ApiException e) {
    final kind = _classifyLoginError(e);
    final message = _compactLoginMessage(e, kind);
    final title = kind == LoginNoticeKind.lockout
        ? 'Account temporarily locked'
        : null;
    final showFix = kind == LoginNoticeKind.network && !kIsWeb;
    showLoginNotice(
      message,
      kind,
      title: title,
      actionLabel: showFix ? 'Fix connection' : null,
      onAction: showFix ? _fixMobileBackendConnection : null,
    );
  }

  LoginNoticeKind _classifyLoginError(ApiException e) {
    final lower = e.message.toLowerCase();
    final code = e.code?.toLowerCase();
    if (code == 'pending' || code == 'rejected' || code == 'removed') {
      return LoginNoticeKind.server;
    }
    if (e.statusCode == 403 && lower.contains('locked')) {
      return LoginNoticeKind.lockout;
    }
    if (e.statusCode == 401 ||
        lower.contains('invalid credentials') ||
        lower.contains('invalid email or password')) {
      return LoginNoticeKind.credentials;
    }
    if (e.statusCode == null || _isBackendConnectivityMessage(e.message)) {
      return LoginNoticeKind.network;
    }
    if (e.statusCode != null && e.statusCode! >= 500) {
      return LoginNoticeKind.server;
    }
    if (_isBackendConnectivityMessage(e.message)) {
      return LoginNoticeKind.network;
    }
    return LoginNoticeKind.server;
  }

  String _compactLoginMessage(ApiException e, LoginNoticeKind kind) {
    switch (kind) {
      case LoginNoticeKind.credentials:
        return 'Invalid email or password.';
      case LoginNoticeKind.lockout:
        return lockoutSupportingMessage(e.message);
      case LoginNoticeKind.network:
        return 'Cannot reach the server. Check your connection.';
      case LoginNoticeKind.validation:
        return e.message;
      case LoginNoticeKind.server:
        final code = e.code?.toLowerCase();
        if (code == 'pending' || code == 'rejected' || code == 'removed') {
          if (code == 'removed') {
            return 'Your account has been removed. Please contact the administrator.';
          }
          return e.message.trim().isEmpty
              ? 'Unable to sign in right now.'
              : e.message.trim();
        }
        return 'Something went wrong. Please try again.';
    }
  }

  Future<void> _openRegistration() async {
    final registeredEmail = await pushMobileAuthPage<String>(
      context,
      const RegistrationChoiceScreen(),
    );
    if (!mounted || registeredEmail == null || registeredEmail.isEmpty) return;
    setState(() {
      _emailCtrl.text = registeredEmail;
    });
    dismissLoginNotice();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registration submitted. Sign in after an administrator approves your account.',
        ),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _forgotPassword() async {
    await showForgotPasswordDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    // One scaffold only on phone sign-in (nested scaffolds leave a colored strip above the keyboard).
    final Widget content;
    if (!kIsWeb && !wide) {
      content = _mobileSignInScaffold();
    } else {
      content = Scaffold(
        backgroundColor: wide ? LoginPageTokens.background : const Color(0xFF0C3340),
        resizeToAvoidBottomInset: true,
        body: wide ? _wideLayout() : _narrowLayout(),
      );
    }

    return buildWithLoginNotice(content);
  }

  Widget _mobileSignInScaffold() {
    return MobileAuthScaffold(
      scrollable: false,
      fixedViewport: true,
      backgroundAsset: MobileAuthConstants.signInBackgroundAsset,
      body: MobileAuthSignInForm(
        key: const ValueKey('mobile_sign_in_form'),
        emailController: _emailCtrl,
        passwordController: _passCtrl,
        obscurePassword: _obscure,
        rememberMe: _rememberMe,
        loading: _loading,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onRememberMeChanged: (v) => setState(() => _rememberMe = v),
        onSubmit: _submit,
        onForgotPassword: _forgotPassword,
        onCreateAccount: _openRegistration,
      ),
    );
  }

  Future<void> _fixMobileBackendConnection() async {
    final changed = await showBackendUrlDialog(context);
    if (!mounted) return;
    if (changed) {
      dismissLoginNotice();
      apiClient.resetConnection();
      await apiClient.warmUpConnection();
    }
  }

  Widget _wideLayout() {
    return Row(
      children: [
        const Expanded(flex: 6, child: LoginBrandPanel()),
        Expanded(
          flex: 4,
          child: LoginFormPanel(
            emailController: _emailCtrl,
            passwordController: _passCtrl,
            obscurePassword: _obscure,
            rememberMe: _rememberMe,
            loading: _loading,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            onRememberMeChanged: (v) => setState(() => _rememberMe = v),
            onSubmit: _submit,
            onForgotPassword: _forgotPassword,
            onCreateAccount: kIsWeb ? null : _openRegistration,
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout() {
    const cardSideInset = 12.0;
    final topInset = MediaQuery.paddingOf(context).top;
    final viewHeight = MediaQuery.sizeOf(context).height;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Web embeds / short viewports: hero + card exceed height without scroll.
    final hideBrandHero = keyboardOpen || viewHeight < 560;

    final formPanel = LoginFormPanel(
      key: const ValueKey('mobile-login-card'),
      cardStyle: true,
      emailController: _emailCtrl,
      passwordController: _passCtrl,
      obscurePassword: _obscure,
      rememberMe: _rememberMe,
      loading: _loading,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      onRememberMeChanged: (v) => setState(() => _rememberMe = v),
      onSubmit: _submit,
      onForgotPassword: _forgotPassword,
      onCreateAccount: kIsWeb ? null : _openRegistration,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: LoginPageTokens.heroGradient),
        ),
        SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(top: topInset + 4, bottom: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hideBrandHero)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: const LoginBrandPanel(compact: true),
                          ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              cardSideInset,
                              6,
                              cardSideInset,
                              0,
                            ),
                            child: formPanel,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
