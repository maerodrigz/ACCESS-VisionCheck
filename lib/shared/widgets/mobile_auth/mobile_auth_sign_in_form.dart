import 'package:flutter/material.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/legal_agreement_widgets.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_widgets.dart';

/// Mobile sign-in fields (used inside [MobileAuthScaffold] with [fixedViewport]).
class MobileAuthSignInForm extends StatelessWidget {
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

  String? _displayError() {
    final raw = error;
    if (raw == null || raw.isEmpty) return null;
    if (onFixBackendConnection != null && isBackendConnectivityMessage(raw)) {
      final host = ApiConfig.effectiveBaseUrl;
      return 'Cannot reach the backend at $host. Same Wi-Fi as the PC? Tap Set backend URL.';
    }
    if (raw.length > 120) {
      return '${raw.substring(0, 117)}…';
    }
    return raw;
  }

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
  Widget build(BuildContext context) {
    final displayError = _displayError();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MobileAuthSectionHeader(
          title: 'Sign In',
          subtitle: 'Continue to your account.',
          compact: true,
        ),
        SizedBox(height: keyboardOpen ? 6 : 12),
        if (displayError != null) ...[
          mobileAuthErrorBanner(displayError, maxLines: keyboardOpen ? 3 : 2),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: mobileAuthInputDecoration(
            hint: 'Email Address',
            icon: Icons.email_outlined,
            dense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: mobileAuthInputDecoration(
            hint: 'Password',
            icon: Icons.lock_outline,
            dense: true,
            suffix: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: kTextSecondary,
                size: 20,
              ),
              onPressed: onToggleObscure,
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
                value: rememberMe,
                onChanged: (v) => onRememberMeChanged(v ?? false),
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
              onPressed: onForgotPassword,
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
          loading: loading,
          onPressed: loading ? null : onSubmit,
          compact: true,
        ),
        if (onCreateAccount != null) ...[
          const SizedBox(height: 10),
          MobileAuthTextLinkRow(
            prompt: "Don't have an account?",
            linkLabel: 'Sign Up',
            onLinkTap: onCreateAccount!,
          ),
        ],
        if (onFixBackendConnection != null) ...[
          const SizedBox(height: 2),
          Center(
            child: TextButton.icon(
              onPressed: onFixBackendConnection,
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

    final footer = Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
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

    if (keyboardOpen) {
      return fields;
    }

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
