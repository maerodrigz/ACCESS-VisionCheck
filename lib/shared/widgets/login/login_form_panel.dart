import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/widgets/login/login_page_tokens.dart';
import 'package:access_mobile/shared/widgets/legal_agreement_widgets.dart';

class LoginFormPanel extends StatefulWidget {
  const LoginFormPanel({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onRememberMeChanged,
    required this.onSubmit,
    required this.onForgotPassword,
    this.onCreateAccount,
    this.onFixBackendConnection,
    this.compact = false,
    this.cardStyle = false,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onFixBackendConnection;
  final bool compact;

  /// Phone layout: white card with sign-in form plus create-account / backend links.
  final bool cardStyle;

  @override
  State<LoginFormPanel> createState() => _LoginFormPanelState();
}

class _LoginFormPanelState extends State<LoginFormPanel> {
  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    if (widget.cardStyle) return _buildCard();

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final panel = LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            widget.compact ? 20 : 48,
            widget.compact ? 20 : 32,
            widget.compact ? 20 : 48,
            (widget.compact ? 20 : 32) + bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: widget.compact ? Alignment.topCenter : const Alignment(0, -0.1),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LoginPageTokens.maxFormWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._errorBlock(),
                    if (!kIsWeb && widget.onFixBackendConnection != null) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: widget.onFixBackendConnection,
                          icon: const Icon(Icons.dns_outlined, size: 16),
                          label: const Text('Set backend URL'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: widget.emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDecoration('Email Address', Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),
                    _passwordField(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        SizedBox(
                          height: 22,
                          width: 22,
                          child: Checkbox(
                            value: widget.rememberMe,
                            onChanged: (v) => widget.onRememberMeChanged(v ?? false),
                            activeColor: LoginPageTokens.secondary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Remember Me', style: TextStyle(fontSize: 13, color: LoginPageTokens.textSecondary)),
                        const Spacer(),
                        _forgotPasswordButton(),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SignInButton(
                      loading: widget.loading,
                      onSubmit: widget.onSubmit,
                      useHover: kIsWeb,
                    ),
                    if (widget.onCreateAccount != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: widget.onCreateAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LoginPageTokens.secondary,
                            side: BorderSide(color: LoginPageTokens.secondary.withValues(alpha: 0.45)),
                            minimumSize: const Size(double.infinity, 48),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
                          ),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Register as a member or campus organization',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: LoginPageTokens.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                    SizedBox(height: widget.compact ? 24 : 40),
                    const _LoginFooter(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return ColoredBox(
      color: LoginPageTokens.surface,
      child: SafeArea(child: panel),
    );
  }

  Widget _buildCard() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: LoginPageTokens.maxFormWidth),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        decoration: BoxDecoration(
          color: LoginPageTokens.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: LoginPageTokens.accent.withValues(alpha: 0.08),
              blurRadius: 24,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sign in',
              style: TextStyle(
                color: LoginPageTokens.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Access your account',
              style: TextStyle(
                color: LoginPageTokens.textSecondary.withValues(alpha: 0.95),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            ..._errorBlock(spacing: 12),
            TextField(
              controller: widget.emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(
                'Email Address',
                Icons.person_outline_rounded,
                placeholder: true,
              ),
            ),
            const SizedBox(height: 12),
            _passwordField(placeholder: true),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 14),
                child: _forgotPasswordButton(),
              ),
            ),
            _SignInButton(
              loading: widget.loading,
              onSubmit: widget.onSubmit,
              useHover: kIsWeb,
            ),
            if (widget.onCreateAccount != null) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(color: LoginPageTokens.textSecondary, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: widget.onCreateAccount,
                    style: TextButton.styleFrom(
                      foregroundColor: LoginPageTokens.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
            if (!kIsWeb && widget.onFixBackendConnection != null) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: widget.onFixBackendConnection,
                  icon: const Icon(Icons.dns_outlined, size: 14),
                  label: const Text('Set backend URL'),
                  style: TextButton.styleFrom(
                    foregroundColor: LoginPageTokens.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const LegalFooterLinks(useLoginTokens: true),
            const SizedBox(height: 10),
            const Text(
              '© 2026 ACCESS VisionCheck',
              textAlign: TextAlign.center,
              style: TextStyle(color: LoginPageTokens.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 2),
            const Text(
              'USTP Oroquieta Campus',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LoginPageTokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _errorBlock({double spacing = 16}) {
    final error = widget.error;
    if (error == null) return const [];
    final showFix = widget.onFixBackendConnection != null &&
        (error.contains('timeout') ||
            error.contains('Cannot reach') ||
            error.contains('cannot reach') ||
            error.contains('Fix backend URL') ||
            error.contains('192.168'));
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(error, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
          ],
        ),
      ),
      if (showFix) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: widget.onFixBackendConnection,
          icon: const Icon(Icons.dns_outlined, size: 16),
          label: const Text('Fix backend URL'),
        ),
      ],
      SizedBox(height: spacing),
    ];
  }

  Widget _passwordField({bool placeholder = false}) {
    return TextField(
      controller: widget.passwordController,
      obscureText: widget.obscurePassword,
      onSubmitted: (_) => widget.onSubmit(),
      decoration: _fieldDecoration(
        'Password',
        Icons.lock_outline,
        placeholder: placeholder,
        suffix: IconButton(
          icon: Icon(
            widget.obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: LoginPageTokens.textSecondary,
            size: 20,
          ),
          onPressed: widget.onToggleObscure,
        ),
      ),
    );
  }

  Widget _forgotPasswordButton() {
    return TextButton(
      onPressed: widget.onForgotPassword,
      style: TextButton.styleFrom(
        foregroundColor: LoginPageTokens.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  InputDecoration _fieldDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
    bool placeholder = false,
  }) {
    return InputDecoration(
      labelText: placeholder ? null : label,
      hintText: placeholder ? label : null,
      hintStyle: const TextStyle(color: LoginPageTokens.textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: LoginPageTokens.textSecondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: LoginPageTokens.background,
      isDense: placeholder,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: LoginPageTokens.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: LoginPageTokens.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: LoginPageTokens.secondary, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: placeholder ? 14 : 16),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LegalFooterLinks(useLoginTokens: true),
        SizedBox(height: 12),
        Text(
          '© 2026 ACCESS VisionCheck',
          textAlign: TextAlign.center,
          style: TextStyle(color: LoginPageTokens.textSecondary, fontSize: 11),
        ),
        SizedBox(height: 4),
        Text(
          'USTP Oroquieta Campus',
          textAlign: TextAlign.center,
          style: TextStyle(color: LoginPageTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SignInButton extends StatefulWidget {
  const _SignInButton({
    required this.loading,
    required this.onSubmit,
    required this.useHover,
  });

  final bool loading;
  final VoidCallback onSubmit;
  final bool useHover;

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _hovered = false;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: widget.loading ? null : widget.onSubmit,
        style: FilledButton.styleFrom(
          backgroundColor: widget.useHover && _hovered ? LoginPageTokens.primary : LoginPageTokens.secondary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
        child: widget.loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );

    if (!widget.useHover) return button;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: LoginPageTokens.secondary.withValues(alpha: _hovered ? 0.28 : 0.14),
              blurRadius: _hovered ? 14 : 8,
              offset: Offset(0, _hovered ? 6 : 3),
            ),
          ],
        ),
        child: button,
      ),
    );
  }
}
