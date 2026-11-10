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
    required this.onToggleObscure,
    required this.onRememberMeChanged,
    required this.onSubmit,
    required this.onForgotPassword,
    this.onCreateAccount,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final bool loading;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback? onCreateAccount;

  @override
  State<MobileAuthSignInForm> createState() => _MobileAuthSignInFormState();
}

class _MobileAuthSignInFormState extends State<MobileAuthSignInForm> {
  late final FocusNode _emailFocus;
  late final FocusNode _passwordFocus;
  final GlobalKey _passwordFieldKey = GlobalKey();

  /// Extra bottom padding keeps the password field above the Android keyboard.
  static const _fieldScrollPadding = EdgeInsets.fromLTRB(20, 20, 20, 140);

  @override
  void initState() {
    super.initState();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
    _passwordFocus.addListener(_ensurePasswordVisible);
  }

  @override
  void dispose() {
    _passwordFocus.removeListener(_ensurePasswordVisible);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _ensurePasswordVisible() {
    if (!_passwordFocus.hasFocus) return;
    // One soft scroll into view — avoid fighting the IME on every frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _passwordFieldKey.currentContext;
      if (!mounted || ctx == null || !_passwordFocus.hasFocus) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: 0.25,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MobileAuthSectionHeader(
          title: 'Welcome Back!',
          subtitle: 'Continue to your account.',
          compact: true,
        ),
        const SizedBox(height: 12),
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
        KeyedSubtree(
          key: _passwordFieldKey,
          child: TextField(
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
        const SizedBox(height: 14),
        MobileAuthGradientButton(
          label: 'Sign In',
          loading: widget.loading,
          onPressed: widget.loading ? null : widget.onSubmit,
          compact: true,
        ),
        if (widget.onCreateAccount != null) ...[
          const SizedBox(height: 12),
          MobileAuthTextLinkRow(
            prompt: "Don't have an account?",
            linkLabel: 'Sign Up',
            onLinkTap: widget.onCreateAccount!,
          ),
        ],
        const SizedBox(height: 14),
        // Keep footer mounted (opacity only) so keyboard open/close does not
        // resize the form and jump the email/password fields.
        Opacity(
          opacity: keyboardOpen ? 0 : 1,
          child: IgnorePointer(
            ignoring: keyboardOpen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LegalFooterLinks(useLoginTokens: false),
                const SizedBox(height: 4),
                Text(
                  '© 2026 ACCESS VisionCheck · USTP Oroquieta',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: kTextSecondary, fontSize: 10),
                ),
                SizedBox(height: bottomInset > 0 ? bottomInset : 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
