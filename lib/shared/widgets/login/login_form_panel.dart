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
    this.sheetStyle = false,
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
  final bool sheetStyle;

  @override
  State<LoginFormPanel> createState() => _LoginFormPanelState();
}

class _LoginFormPanelState extends State<LoginFormPanel> {
  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final tight = widget.sheetStyle;
    final panel = LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            widget.compact ? 20 : 48,
            tight ? 18 : (widget.compact ? 20 : 32),
            widget.compact ? 20 : 48,
            (tight ? 16 : (widget.compact ? 20 : 32)) + bottomInset + (tight ? bottomSafe : 0),
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
                    if (tight) ...[
                      Text(
                        'Sign in',
                        style: TextStyle(
                          color: LoginPageTokens.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.0,
                        ),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                        if (widget.error != null) ...[
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
                                  child: Text(widget.error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          if (widget.onFixBackendConnection != null &&
                              (widget.error!.contains('timeout') ||
                                  widget.error!.contains('Cannot reach') ||
                                  widget.error!.contains('192.168'))) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: widget.onFixBackendConnection,
                              icon: const Icon(Icons.dns_outlined, size: 16),
                              label: const Text('Fix backend URL'),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                        if (!kIsWeb && widget.onFixBackendConnection != null && !widget.sheetStyle) ...[
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
                          decoration: _fieldDecoration('Email Address', Icons.email_outlined, tight: tight),
                        ),
                        SizedBox(height: tight ? 10 : 16),
                        TextField(
                          controller: widget.passwordController,
                          obscureText: widget.obscurePassword,
                          onSubmitted: (_) => widget.onSubmit(),
                          decoration: _fieldDecoration(
                            'Password',
                            Icons.lock_outline,
                            tight: tight,
                            suffix: IconButton(
                              icon: Icon(
                                widget.obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: LoginPageTokens.textSecondary,
                                size: 20,
                              ),
                              onPressed: widget.onToggleObscure,
                            ),
                          ),
                        ),
                        SizedBox(height: tight ? 8 : 14),
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
                            TextButton(
                              onPressed: widget.onForgotPassword,
                              style: TextButton.styleFrom(
                                foregroundColor: LoginPageTokens.secondary,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ],
                        ),
                        SizedBox(height: tight ? 16 : 28),
                        _SignInButton(
                          loading: widget.loading,
                          onSubmit: widget.onSubmit,
                          useHover: kIsWeb,
                          compact: tight,
                        ),
                        if (widget.onCreateAccount != null) ...[
                          SizedBox(height: tight ? 10 : 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: widget.onCreateAccount,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: LoginPageTokens.secondary,
                                side: BorderSide(color: LoginPageTokens.secondary.withValues(alpha: 0.45)),
                                minimumSize: Size(double.infinity, tight ? 44 : 48),
                                padding: EdgeInsets.symmetric(vertical: tight ? 11 : 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
                              ),
                              child: const Text(
                                'Create Account',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ),
                          if (!tight) ...[
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
                        ],
                        if (tight && widget.onFixBackendConnection != null) ...[
                          const SizedBox(height: 4),
                          Center(
                            child: TextButton.icon(
                              onPressed: widget.onFixBackendConnection,
                              icon: const Icon(Icons.dns_outlined, size: 15),
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
                        SizedBox(height: tight ? 10 : (widget.compact ? 24 : 40)),
                        _LoginFooter(compact: tight),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
    );

    if (tight) return panel;

    return ColoredBox(
      color: LoginPageTokens.surface,
      child: SafeArea(child: panel),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon, {Widget? suffix, bool tight = false}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: LoginPageTokens.textSecondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: LoginPageTokens.background,
      isDense: tight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: LoginPageTokens.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: LoginPageTokens.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: LoginPageTokens.secondary, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: tight ? 13 : 16),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LegalFooterLinks(useLoginTokens: true),
        SizedBox(height: compact ? 6 : 12),
        Text(
          compact ? '© 2026 ACCESS VisionCheck · USTP Oroquieta Campus' : '© 2026 ACCESS VisionCheck',
          textAlign: TextAlign.center,
          style: TextStyle(color: LoginPageTokens.textSecondary.withValues(alpha: 0.9), fontSize: 11),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          const Text(
            'USTP Oroquieta Campus',
            textAlign: TextAlign.center,
            style: TextStyle(color: LoginPageTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _SignInButton extends StatefulWidget {
  const _SignInButton({
    required this.loading,
    required this.onSubmit,
    required this.useHover,
    this.compact = false,
  });

  final bool loading;
  final VoidCallback onSubmit;
  final bool useHover;
  final bool compact;

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
          minimumSize: Size(double.infinity, widget.compact ? 44 : 48),
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 11 : 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
        child: widget.loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
