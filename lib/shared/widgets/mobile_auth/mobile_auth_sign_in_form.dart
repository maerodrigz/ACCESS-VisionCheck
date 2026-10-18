import 'package:flutter/material.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
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
    required this.error,
    required this.onToggleObscure,
    required this.onRememberMeChanged,
    required this.onSubmit,
    required this.onForgotPassword,
    this.onCreateAccount,
    this.onFixBackendConnection,
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

  static bool isBackendConnectivityMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('cannot reach') ||
        lower.contains("can't reach") ||
        lower.contains('pc backend') ||
        lower.contains('fix backend') ||
        lower.contains('set backend') ||
        lower.contains('backend url') ||
        lower.contains('wi-fi ip');
  }

  @override
  State<MobileAuthSignInForm> createState() => _MobileAuthSignInFormState();
}

class _MobileAuthSignInFormState extends State<MobileAuthSignInForm> {
  late final FocusNode _emailFocus;
  late final FocusNode _passwordFocus;

  @override
  void initState() {
    super.initState();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
    for (final node in [_emailFocus, _passwordFocus]) {
      node.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    for (final node in [_emailFocus, _passwordFocus]) {
      node.removeListener(_onFocusChange);
      node.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  bool _compactLayout(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return true;
    return _emailFocus.hasFocus || _passwordFocus.hasFocus;
  }

  String? _displayError() {
    final raw = widget.error;
    if (raw == null || raw.isEmpty) return null;
    if (widget.onFixBackendConnection != null &&
        MobileAuthSignInForm.isBackendConnectivityMessage(raw)) {
      final host = ApiConfig.effectiveBaseUrl;
      return 'Cannot reach the backend at $host. Same Wi-Fi as the PC? Tap Set backend URL.';
    }
    if (raw.length > 120) {
      return '${raw.substring(0, 117)}…';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final compact = _compactLayout(context);
    final displayError = _displayError();

    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          const MobileAuthSectionHeader(
            title: 'Sign In',
            subtitle: 'Continue to your account.',
            compact: true,
          ),
        if (!compact) const SizedBox(height: 12),
        if (displayError != null) ...[
          mobileAuthErrorBanner(displayError, maxLines: compact ? 2 : 2),
          SizedBox(height: compact ? 6 : 8),
        ],
        TextField(
          controller: widget.emailController,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: mobileAuthInputDecoration(
            hint: 'Email Address',
            icon: Icons.email_outlined,
            dense: true,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        TextField(
          controller: widget.passwordController,
          focusNode: _passwordFocus,
          obscureText: widget.obscurePassword,
          textInputAction: TextInputAction.done,
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
        if (compact)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: kCyan,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ),
        if (!compact) ...[
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
        ],
        SizedBox(height: compact ? 8 : 16),
        MobileAuthGradientButton(
          label: 'Sign In',
          loading: widget.loading,
          onPressed: widget.loading ? null : widget.onSubmit,
          compact: true,
        ),
        if (!compact && widget.onCreateAccount != null) ...[
          const SizedBox(height: 10),
          MobileAuthTextLinkRow(
            prompt: "Don't have an account?",
            linkLabel: 'Sign Up',
            onLinkTap: widget.onCreateAccount!,
          ),
        ],
        if (!compact && widget.onFixBackendConnection != null) ...[
          const SizedBox(height: 2),
          Center(
            child: TextButton.icon(
              onPressed: widget.onFixBackendConnection,
              icon: const Icon(Icons.dns_outlined, size: 14),
              label: const Text('Set backend URL'),
              style: TextButton.styleFrom(
                foregroundColor: kTextSecondary,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return fields;
    }

    const footer = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LegalFooterLinks(useLoginTokens: false),
        SizedBox(height: 4),
        Text(
          '© 2026 ACCESS VisionCheck · USTP Oroquieta',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: kTextSecondary, fontSize: 10),
        ),
      ],
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fields,
        footer,
      ],
    );
  }
}
