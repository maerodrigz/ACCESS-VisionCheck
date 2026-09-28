import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
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
    if (brandingController.lastError != null) {
      brandingController.refresh();
    }
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
          'pending' => 'Your account is still pending admin approval.',
          'rejected' => 'Your account registration was rejected. Please contact the administrator.',
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

  Future<void> _fixBackendUrl() async {
    if (kIsWeb) return;
    final changed = await showBackendUrlDialog(context);
    if (changed && mounted) {
      await apiClient.reconnect();
      setState(() => _error = null);
      await brandingController.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: LoginPageTokens.background,
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
            onFixBackendConnection: kIsWeb ? null : _fixBackendUrl,
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout() {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final keyboardOpen = viewInsets.bottom > 0;
    final screenH = MediaQuery.sizeOf(context).height;
    final heroHeight = screenH * 0.32;

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LoginPageTokens.heroGradient),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!keyboardOpen)
              SizedBox(
                height: heroHeight,
                child: const LoginBrandPanel(compact: true),
              ),
            Expanded(
              child: Transform.translate(
                offset: Offset(0, keyboardOpen ? 0 : -22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: LoginPageTokens.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: LoginFormPanel(
                    compact: true,
                    sheetStyle: true,
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
                    onFixBackendConnection: kIsWeb ? null : _fixBackendUrl,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
