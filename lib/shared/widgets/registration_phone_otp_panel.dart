import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/auth_service.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';

/// SMS OTP verification before member / requestor registration.
class RegistrationPhoneOtpPanel extends StatefulWidget {
  const RegistrationPhoneOtpPanel({
    super.key,
    required this.phoneController,
    required this.onVerificationTokenChanged,
  });

  final TextEditingController phoneController;
  final ValueChanged<String?> onVerificationTokenChanged;

  @override
  State<RegistrationPhoneOtpPanel> createState() => _RegistrationPhoneOtpPanelState();
}

class _RegistrationPhoneOtpPanelState extends State<RegistrationPhoneOtpPanel> {
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  bool _verified = false;
  String? _status;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _clearVerification() {
    _verified = false;
    widget.onVerificationTokenChanged(null);
  }

  Future<void> _sendCode() async {
    final phone = widget.phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your mobile number first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _status = null;
    });
    _clearVerification();
    try {
      final message = await authService.sendRegistrationOtp(phone);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _status = message;
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
    final phone = widget.phoneController.text.trim();
    final code = _codeCtrl.text.trim();
    if (phone.isEmpty || code.isEmpty) {
      setState(() => _error = 'Enter your number and the 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final token = await authService.verifyRegistrationOtp(phone: phone, code: code);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = true;
        _status = 'Mobile number verified.';
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
        RegistrationFormField(
          label: 'Mobile Number',
          controller: widget.phoneController,
          hint: '09XX XXX XXXX',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          enabled: !_verified,
          validator: (v) => RegistrationValidators.required(v, label: 'Mobile number'),
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_verified || _codeCtrl.text.isNotEmpty || _status != null) {
              setState(() {
                _status = null;
                _error = null;
              });
              _clearVerification();
            }
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _sending || _verified ? null : _sendCode,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: const BorderSide(color: kAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send code', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RegistrationFormField(
          label: 'Verification code',
          controller: _codeCtrl,
          hint: '6-digit SMS code',
          icon: Icons.sms_outlined,
          keyboardType: TextInputType.number,
          enabled: !_verified,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _verifying || _verified ? null : _verifyCode,
          style: FilledButton.styleFrom(
            backgroundColor: kAccent,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: _verifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _verified ? 'Verified' : 'Verify number',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
