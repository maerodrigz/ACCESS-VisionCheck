import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/auth_service.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/login/login_page_tokens.dart';

/// Email OTP password reset (same flow as admin web).
Future<void> showForgotPasswordDialog(
  BuildContext context, {
  String initialEmail = '',
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({this.initialEmail = ''});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailCtrl;
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  String? _error;
  String? _message;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter the email address for your account.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_step == 0) {
        final result = await authService.sendForgotPasswordOtp(email);
        if (!mounted) return;
        final dev = result.devCode?.trim();
        setState(() {
          _loading = false;
          _message = result.message;
          if (dev != null && dev.isNotEmpty) {
            _codeCtrl.text = dev;
            _message =
                'Dev code: $dev (also printed in the PC backend terminal).';
          }
          _step = 1;
        });
        return;
      }

      final code = _codeCtrl.text.trim();
      if (code.length != 6) {
        setState(() {
          _loading = false;
          _error = 'Enter the 6-digit code from your email.';
        });
        return;
      }
      final password = _passwordCtrl.text;
      if (password.length < 6) {
        setState(() {
          _loading = false;
          _error = 'Password must be at least 6 characters.';
        });
        return;
      }
      if (password != _confirmCtrl.text) {
        setState(() {
          _loading = false;
          _error = 'Passwords do not match.';
        });
        return;
      }

      final done = await authService.completeForgotPasswordReset(
        email: email,
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = done;
        _step = 2;
      });
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

  @override
  Widget build(BuildContext context) {
    final done = _step == 2;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Reset password', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _step == 0
                  ? 'We email a 6-digit code to your account address.'
                  : _step == 1
                      ? 'Enter the code and choose a new password.'
                      : 'You can sign in with your new password.',
              style: const TextStyle(height: 1.45, fontSize: 14, color: kTextSecondary),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(_message!, style: const TextStyle(height: 1.45, fontSize: 14)),
            ],
            if (!done && _step == 0) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_step == 1) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'New password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: kRed, fontSize: 13, height: 1.35),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(done ? 'Close' : 'Cancel'),
        ),
        if (!done)
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: LoginPageTokens.secondary),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_step == 0 ? 'Send code' : 'Update password'),
          ),
      ],
    );
  }
}
