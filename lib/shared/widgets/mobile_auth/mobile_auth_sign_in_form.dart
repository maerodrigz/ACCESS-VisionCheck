import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/legal_agreement_widgets.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_widgets.dart';

/// Mobile sign-in fields (used inside [MobileAuthScaffold] with [fixedViewport]).
class MobileAuthSignInForm extends StatefulWidget {
  const MobileAuthSignInForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.loading,
    this.loginError,
    required this.onToggleObscure,
    required this.onRememberMeChanged,
    required this.onSubmit,
    required this.onForgotPassword,
    this.onCreateAccount,
    this.onFixConnection,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final bool loading;
  final String? loginError;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onFixConnection;

  @override
  State<MobileAuthSignInForm> createState() => _MobileAuthSignInFormState();
}

class _MobileAuthSignInFormState extends State<MobileAuthSignInForm> {
  late final FocusNode _emailFocus;
  late final FocusNode _passwordFocus;

  /// Small fixed padding only — large values fight the framework and steal focus.
  static const _fieldScrollPadding = EdgeInsets.all(20);

  @override
  void initState() {
    super.initState();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MobileAuthSectionHeader(
          title: 'Sign In',
          subtitle: 'Continue to your account.',
          compact: true,
        ),
        const SizedBox(height: 12),
        if (widget.loginError != null && widget.loginError!.isNotEmpty) ...[
          Text(
            widget.loginError!,
            style: const TextStyle(color: kRed, fontSize: 12, height: 1.35),
          ),
          if (widget.onFixConnection != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onFixConnection,
                style: TextButton.styleFrom(
                  foregroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.dns_outlined, size: 16),
                label: const Text(
                  'Fix connection',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
        TextField(
          key: const ValueKey('mobile_sign_in_email'),
          controller: widget.emailController,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          scrollPadding: _fieldScrollPadding,
          cursorColor: kAccent,
          enableInteractiveSelection: true,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: mobileAuthInputDecoration(
            hint: 'Email Address',
            icon: Icons.email_outlined,
            dense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('mobile_sign_in_password'),
          controller: widget.passwordController,
          focusNode: _passwordFocus,
          obscureText: widget.obscurePassword,
          textInputAction: TextInputAction.done,
          scrollPadding: _fieldScrollPadding,
          cursorColor: kAccent,
          enableInteractiveSelection: true,
          onSubmitted: (_) => widget.onSubmit(),
          decoration: mobileAuthInputDecoration(
            hint: 'Password',
            icon: Icons.lock_outline,
            dense: true,
            suffix: IconButton(
              icon: Icon(
                widget.obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: kTextSecondary,
                size: 20,
              ),
              onPressed: widget.onToggleObscure,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: Checkbox(
                value: widget.rememberMe,
                onChanged: (v) => widget.onRememberMeChanged(v ?? false),
                activeColor: kCyan,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Remember Me', style: TextStyle(fontSize: 13, color: kTextSecondary)),
            const Spacer(),
            TextButton(
              onPressed: widget.onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: kCyan,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        MobileAuthGradientButton(
          label: 'Sign In',
          loading: widget.loading,
          onPressed: widget.loading ? null : widget.onSubmit,
          compact: true,
        ),
        if (widget.onCreateAccount != null) ...[
          const SizedBox(height: 10),
          MobileAuthTextLinkRow(
            prompt: "Don't have an account?",
            linkLabel: 'Sign Up',
            onLinkTap: widget.onCreateAccount!,
          ),
        ],
        SizedBox(height: keyboardOpen ? 16 : 32),
        if (!keyboardOpen) ...[
          const LegalFooterLinks(useLoginTokens: false),
          const SizedBox(height: 4),
          Text(
            '© 2026 ACCESS VisionCheck · USTP Oroquieta',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: kTextSecondary, fontSize: 10),
          ),
          SizedBox(height: bottomInset + 10),
        ],
      ],
    );
  }
}
