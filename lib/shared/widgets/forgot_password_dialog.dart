import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/auth_service.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/login/login_page_tokens.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_constants.dart';

/// SMS-only password recovery (Member / Requestor / shared Flutter login).
///
/// Three compact steps: mobile number → OTP entry → new password.
/// OTP is validated server-side only on the final complete call.
Future<void> showForgotPasswordDialog(
  BuildContext context, {
  String initialPhone = '',
}) {
  if (kIsWeb) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ForgotPasswordRecoverySheet(initialPhone: initialPhone),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: MobileAuthConstants.midnightScaffoldColor.withValues(alpha: 0.78),
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ForgotPasswordRecoverySheet(initialPhone: initialPhone),
      );
    },
  );
}

/// Compact three-step SMS password recovery sheet.
class ForgotPasswordRecoverySheet extends StatefulWidget {
  const ForgotPasswordRecoverySheet({super.key, this.initialPhone = ''});

  final String initialPhone;

  @override
  State<ForgotPasswordRecoverySheet> createState() =>
      _ForgotPasswordRecoverySheetState();
}

class _ForgotPasswordRecoverySheetState extends State<ForgotPasswordRecoverySheet> {
  static const _stepLabels = ['Mobile', 'Code', 'Password'];

  late final TextEditingController _phoneCtrl;
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  /// 0 phone, 1 OTP, 2 password, 3 success
  int _step = 0;
  bool _loading = false;
  String? _error;
  String? _info;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds > 0 ? seconds : 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _sendCode({bool isResend = false}) async {
    setState(() {
      _error = null;
      if (!isResend) _info = null;
    });
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter your registered Philippine mobile number.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await authService.sendForgotPasswordOtp(phone);
      if (!mounted) return;
      final dev = result.devCode?.trim();
      setState(() {
        _loading = false;
        _info = result.message;
        if (dev != null && dev.isNotEmpty) {
          _codeCtrl.text = dev;
          _info = 'Dev code: $dev (SMS_PROVIDER=log).';
        }
        if (!isResend) {
          _step = 1;
        }
      });
      _startResendCooldown(result.resendAfterSeconds ?? 60);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Check your connection.';
      });
    }
  }

  /// Advances UI only. Does not call the backend; OTP is checked on complete.
  void _continueFromOtp() {
    setState(() => _error = null);
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your SMS.');
      return;
    }
    setState(() {
      _info = null;
      _step = 2;
    });
  }

  Future<void> _resetPassword() async {
    setState(() => _error = null);
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (code.length != 6) {
      setState(() {
        _error = 'Enter the 6-digit code from your SMS.';
        _step = 1;
      });
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      final done = await authService.completeForgotPasswordReset(
        phone: phone,
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _info = done;
        _error = null;
        _step = 3;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      final looksLikeOtp = msg.toLowerCase().contains('code') ||
          msg.toLowerCase().contains('otp') ||
          msg.toLowerCase().contains('verification');
      setState(() {
        _loading = false;
        _error = msg;
        if (looksLikeOtp) _step = 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Check your connection.';
      });
    }
  }

  void _goBack() {
    if (_loading) return;
    setState(() {
      _error = null;
      if (_step == 2) {
        _step = 1;
      } else if (_step == 1) {
        _step = 0;
      }
    });
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: LoginPageTokens.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LoginPageTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LoginPageTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LoginPageTokens.accent, width: 1.5),
      ),
      suffixIcon: suffix,
      counterText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * (kIsWeb ? 0.72 : 0.78);

    return Align(
      alignment: kIsWeb ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
        child: Material(
          color: LoginPageTokens.surface,
          elevation: 8,
          shadowColor: Colors.black26,
          borderRadius: kIsWeb
              ? BorderRadius.circular(20)
              : const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!kIsWeb)
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: LoginPageTokens.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _step == 3 ? 'Password updated' : 'Reset password',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: LoginPageTokens.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _step == 3 ? 'Close' : 'Cancel',
                        onPressed: _loading ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 22),
                      ),
                    ],
                  ),
                  if (_step < 3) ...[
                    const SizedBox(height: 6),
                    _StepProgress(current: _step, labels: _stepLabels),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_step == 0) _buildPhoneStep(),
                          if (_step == 1) _buildOtpStep(),
                          if (_step == 2) _buildPasswordStep(),
                          if (_step == 3) _buildSuccessStep(),
                          if (_info != null && _step != 3) ...[
                            const SizedBox(height: 10),
                            Text(
                              _info!,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: LoginPageTokens.textSecondary,
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: kRed,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter the verified mobile number on your account. We will text a 6-digit code if it matches.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: LoginPageTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
          ],
          autocorrect: false,
          decoration: _fieldDecoration(
            label: 'Mobile number',
            hint: '09XX XXX XXXX',
            suffix: const Icon(Icons.phone_android_rounded, size: 20, color: kIconInactive),
          ),
          onSubmitted: (_) {
            if (!_loading) _sendCode();
          },
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the 6-digit code sent to ${_maskPhone(_phoneCtrl.text.trim())}.',
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: LoginPageTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofocus: true,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _fieldDecoration(label: 'SMS code', hint: '000000'),
          onSubmitted: (_) => _continueFromOtp(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: (_loading || _resendSeconds > 0)
                ? null
                : () => _sendCode(isResend: true),
            child: Text(
              _resendSeconds > 0
                  ? 'Resend code in ${_resendSeconds}s'
                  : 'Resend code',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose a new password for your account.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: LoginPageTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: LoginPageTokens.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LoginPageTokens.border),
          ),
          child: const Text(
            'Use at least 6 characters. Avoid passwords you use on other sites.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: LoginPageTokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePass,
          textInputAction: TextInputAction.next,
          autofocus: true,
          decoration: _fieldDecoration(
            label: 'New password',
            suffix: IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmCtrl,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          decoration: _fieldDecoration(
            label: 'Confirm password',
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          onSubmitted: (_) {
            if (!_loading) _resetPassword();
          },
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: kGreen.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: kGreen, size: 32),
        ),
        const SizedBox(height: 14),
        Text(
          _info ?? 'Password updated. Sign in with your new password.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: LoginPageTokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    if (_step == 3) {
      return FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: LoginPageTokens.secondary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Back to Sign In', style: TextStyle(fontWeight: FontWeight.w700)),
      );
    }

    final primaryLabel = switch (_step) {
      0 => 'Send SMS Code',
      1 => 'Continue',
      _ => 'Update password',
    };

    return Row(
      children: [
        if (_step > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _loading ? null : _goBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: LoginPageTokens.textSecondary,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: LoginPageTokens.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        if (_step > 0) const SizedBox(width: 10),
        Expanded(
          flex: _step > 0 ? 2 : 1,
          child: FilledButton(
            onPressed: _loading
                ? null
                : () {
                    if (_step == 0) {
                      _sendCode();
                    } else if (_step == 1) {
                      _continueFromOtp();
                    } else {
                      _resetPassword();
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: LoginPageTokens.secondary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: LoginPageTokens.secondary.withValues(alpha: 0.45),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  static String _maskPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return raw.isEmpty ? 'your phone' : raw;
    final tail = digits.substring(digits.length - 4);
    return '•••• $tail';
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.labels});

  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i <= current
                    ? LoginPageTokens.accent.withValues(alpha: 0.85)
                    : LoginPageTokens.border,
              ),
            ),
          _StepDot(index: i, active: i <= current, label: labels[i], current: current == i),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.active,
    required this.label,
    required this.current,
  });

  final int index;
  final bool active;
  final bool current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bg = active ? LoginPageTokens.primary : LoginPageTokens.border;
    final fg = active ? Colors.white : LoginPageTokens.textSecondary;
    return Column(
      children: [
        Container(
          width: current ? 26 : 22,
          height: current ? 26 : 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: current
                ? Border.all(color: LoginPageTokens.accent, width: 2)
                : null,
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            color: active ? LoginPageTokens.textPrimary : LoginPageTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}
