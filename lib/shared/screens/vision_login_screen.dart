import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/screens/registration_choice_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/legal_agreement_widgets.dart';
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: LoginFormPanel(
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
          onFixBackendConnection: kIsWeb ? null : _fixBackendUrl,
        ),
      ),
    );

    final links = _MobileLoginLinks(
      onCreateAccount: kIsWeb ? null : _openRegistration,
      onSetBackendUrl: kIsWeb ? null : _fixBackendUrl,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LoginPageTokens.heroGradient),
      child: SafeArea(
        top: false,
        child: keyboardOpen
            ? SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 20, bottom: 20),
                child: Column(children: [card, const SizedBox(height: 12), links]),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 5, child: LoginBrandPanel(compact: true)),
                  card,
                  const SizedBox(height: 14),
                  links,
                  const Spacer(flex: 2),
                  const LegalFooterLinks(onDarkBackground: true),
                  const SizedBox(height: 4),
                  Text(
                    '© 2026 ACCESS VisionCheck · USTP Oroquieta Campus',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }
}

/// Create account and backend setup, shown on the gradient below the floating sign-in card.
class _MobileLoginLinks extends StatelessWidget {
  const _MobileLoginLinks({this.onCreateAccount, this.onSetBackendUrl});

  final VoidCallback? onCreateAccount;
  final VoidCallback? onSetBackendUrl;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.7);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onCreateAccount != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account?", style: TextStyle(color: muted, fontSize: 13)),
              TextButton(
                onPressed: onCreateAccount,
                style: TextButton.styleFrom(
                  foregroundColor: kCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Create Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        if (onSetBackendUrl != null)
          TextButton.icon(
            onPressed: onSetBackendUrl,
            icon: const Icon(Icons.dns_outlined, size: 14),
            label: const Text('Set backend URL'),
            style: TextButton.styleFrom(
              foregroundColor: muted,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
