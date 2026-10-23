import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/screens/registration_choice_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/login/login_brand_panel.dart';
import 'package:access_mobile/shared/widgets/login/login_form_panel.dart';
import 'package:access_mobile/shared/widgets/login/login_page_tokens.dart';
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
      lower.contains('wi-fi ip');
}

/// Enterprise login for ACCESS VisionCheck — web admin and mobile.
class VisionLoginScreen extends StatefulWidget {
  const VisionLoginScreen({super.key, this.onAuthenticated});

  final void Function()? onAuthenticated;

  @override
  State<VisionLoginScreen> createState() => _VisionLoginScreenState();
}

class _VisionLoginScreenState extends State<VisionLoginScreen> {
  static const _rememberKey = 'login_remember_email';

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;
  bool _loading = false;
  String? _error;

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
        _error = ended;
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

  void _setLoginError(String? message) {
    setState(() => _error = message);
  }

  /// Clears stale offline banners and restores JWT when the PC backend comes back.
  Future<void> _recoverWhenBackendIsReachable() async {
    final reachable = await apiClient.checkReachable();
    if (!mounted) return;
    if (!reachable) return;

    final backendBanner = _error != null && _isBackendConnectivityMessage(_error!);
    if (!backendBanner) return;

    final restored = await authController.retryPersistedSession();
    if (!mounted) return;
    if (restored) {
      setState(() => _error = null);
      widget.onAuthenticated?.call();
      return;
    }
    if (kIsWeb) {
      final ended = authController.consumeSessionEndMessage();
      setState(() => _error = ended);
    } else {
      authController.consumeSessionEndMessage();
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_rememberKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _emailCtrl.text = saved;
        _rememberMe = true;
      });
    }
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
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      _setLoginError('Please fill in all fields.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await authController.login(email, pass);
      await _persistRememberMe();
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _loading = false;
        _error = null;
      });
      widget.onAuthenticated?.call();
    } on ApiException catch (e) {
      final message = switch (e.code) {
        'pending' || 'rejected' => e.message,
        'removed' => 'Your account has been removed. Please contact the administrator.',
        _ => _loginFailureMessage(e),
      };
      setState(() => _loading = false);
      _setLoginError(message);
    } catch (e) {
      setState(() => _loading = false);
      _setLoginError(e.toString());
    }
  }

  Future<void> _openRegistration() async {
    final registeredEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegistrationChoiceScreen()),
    );
    if (!mounted || registeredEmail == null || registeredEmail.isEmpty) return;
    setState(() {
      _emailCtrl.text = registeredEmail;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration submitted. Sign in after an administrator approves your account.'),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _forgotPassword() async {
    await showForgotPasswordDialog(context, initialEmail: _emailCtrl.text.trim());
  }

  String _loginFailureMessage(ApiException e) {
    final lower = e.message.toLowerCase();
    if (e.statusCode == 401 &&
        (lower.contains('invalid credentials') || lower.contains('invalid email'))) {
      return 'Invalid email or password. Use the exact email on your account '
          '(check Profile if you changed it). On a phone, open Account settings and '
          'confirm Backend connection points to your PC.';
    }
    if (lower.contains('locked')) return e.message;
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    // One scaffold only on phone sign-in (nested scaffolds leave a colored strip above the keyboard).
    if (!kIsWeb && !wide) {
      return _mobileSignInScaffold();
    }

    return Scaffold(
      backgroundColor: wide ? LoginPageTokens.background : const Color(0xFF0C3340),
      resizeToAvoidBottomInset: true,
      body: wide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _mobileSignInScaffold() {
    return MobileAuthScaffold(
      scrollable: false,
      fixedViewport: true,
      body: MobileAuthSignInForm(
        key: const ValueKey('mobile_sign_in_form'),
        emailController: _emailCtrl,
        passwordController: _passCtrl,
        obscurePassword: _obscure,
        rememberMe: _rememberMe,
        loading: _loading,
        loginError: _error,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onRememberMeChanged: (v) => setState(() => _rememberMe = v),
        onSubmit: _submit,
        onForgotPassword: _forgotPassword,
        onCreateAccount: _openRegistration,
        onFixConnection: kIsWeb ? null : _fixMobileBackendConnection,
      ),
    );
  }

  Future<void> _fixMobileBackendConnection() async {
    final changed = await showBackendUrlDialog(context);
    if (!mounted) return;
    if (changed) {
      setState(() => _error = null);
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
            error: _error,
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
      error: _error,
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
                            padding: const EdgeInsets.fromLTRB(cardSideInset, 6, cardSideInset, 0),
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
