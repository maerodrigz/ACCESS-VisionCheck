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
import 'package:shared_preferences/shared_preferences.dart';

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
      setState(() => _error = 'Please fill in all fields.');
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
      setState(() => _loading = false);
      widget.onAuthenticated?.call();
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = switch (e.code) {
          'pending' || 'rejected' => e.message,
          'removed' => 'Your account has been removed. Please contact the administrator.',
          _ => e.message,
        };
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
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

  void _forgotPassword() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset password', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Contact your ACCESS VisionCheck administrator to reset your password.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: LoginPageTokens.secondary),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: wide ? LoginPageTokens.background : const Color(0xFF0C3340),
      resizeToAvoidBottomInset: true,
      body: wide ? _wideLayout() : _narrowLayout(),
    );
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: LoginBrandPanel(
                    compact: true,
                    dense: keyboardOpen,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(top: 6),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight - 6),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: cardSideInset),
                              child: SizedBox(
                                width: constraints.maxWidth - cardSideInset * 2,
                                child: formPanel,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
