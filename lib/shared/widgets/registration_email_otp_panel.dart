import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/auth_service.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/copy/mobile_registration_copy.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_widgets.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';

/// Email OTP verification before member / requestor registration.
class RegistrationEmailOtpPanel extends StatefulWidget {
  const RegistrationEmailOtpPanel({
    super.key,
    required this.emailController,
    this.nameForGreeting,
    required this.onVerificationTokenChanged,
  });

  final TextEditingController emailController;
  final String? nameForGreeting;
  final ValueChanged<String?> onVerificationTokenChanged;

  @override
  State<RegistrationEmailOtpPanel> createState() => _RegistrationEmailOtpPanelState();
}

class _RegistrationEmailOtpPanelState extends State<RegistrationEmailOtpPanel> {
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  bool _verified = false;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    widget.emailController.removeListener(_onEmailChanged);
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    if (_verified || _codeCtrl.text.isNotEmpty || _status != null) {
      setState(() {
        _status = null;
        _error = null;
      });
      _clearVerification();
    }
  }

  void _clearVerification() {
    _verified = false;
    widget.onVerificationTokenChanged(null);
  }

  String? _emailError() {
    final email = widget.emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      return 'Enter your email address above, then tap Send code.';
    }
    return null;
  }

  Future<void> _sendCode() async {
    final emailErr = _emailError();
    if (emailErr != null) {
      setState(() => _error = emailErr);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _status = null;
    });
    _clearVerification();
    try {
      final result = await authService.sendRegistrationOtp(
        email: widget.emailController.text.trim(),
        name: widget.nameForGreeting?.trim(),
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        final dev = result.devCode?.trim();
        if (dev != null && dev.isNotEmpty) {
          _codeCtrl.text = dev;
          _status = 'Dev code: $dev (also printed in the PC backend terminal).';
        } else {
          _status = result.message;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _verifyCode() async {
    final emailErr = _emailError();
    if (emailErr != null) {
      setState(() => _error = emailErr);
      return;
    }
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the 6-digit verification code from your email.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final token = await authService.verifyRegistrationOtp(
        email: widget.emailController.text.trim(),
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = true;
        _status = 'Email verified.';
      });
      widget.onVerificationTokenChanged(token);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.message;
      });
      widget.onVerificationTokenChanged(null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.toString();
      });
      widget.onVerificationTokenChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          MobileRegistrationCopy.emailVerificationTitle,
          style: TextStyle(
            color: kTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          MobileRegistrationCopy.emailVerificationBody,
          style: TextStyle(color: kTextSecondary, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        MobileAuthOutlineButton(
          label: 'Send code',
          loading: _sending,
          onPressed: _sending || _verified ? null : _sendCode,
        ),
        const SizedBox(height: 12),
        RegistrationFormField(
          label: 'Verification code',
          controller: _codeCtrl,
          hint: '6-digit code',
          icon: Icons.mark_email_read_outlined,
          keyboardType: TextInputType.number,
          enabled: !_verified,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _verifyCode(),
          mobileAuthStyle: true,
        ),
        const SizedBox(height: 10),
        MobileAuthGradientButton(
          label: _verified ? 'Email verified' : 'Confirm code',
          loading: _verifying,
          compact: true,
          onPressed: _verifying || _verified ? null : _verifyCode,
        ),
        if (_status != null) ...[
          const SizedBox(height: 8),
          Text(
            _status!,
            style: TextStyle(color: _verified ? kGreen : kTextSecondary, fontSize: 12),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: kRed, fontSize: 12)),
        ],
      ],
    );
  }
}
