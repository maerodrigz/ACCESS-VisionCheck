import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';
import 'package:access_mobile/shared/widgets/registration_success_dialog.dart';
import 'package:access_mobile/shared/widgets/legal_agreement_widgets.dart';

/// Self-service member registration (pending admin approval).
class MemberRegistrationScreen extends StatefulWidget {
  const MemberRegistrationScreen({super.key});

  @override
  State<MemberRegistrationScreen> createState() => _MemberRegistrationScreenState();
}

class _MemberRegistrationScreenState extends State<MemberRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _acceptedLegal = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studentIdCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedLegal) {
      setState(() => _error = 'Please agree to the Terms and Conditions and Privacy Policy.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await authController.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        role: 'Member',
        studentId: _studentIdCtrl.text.trim(),
        contactNumber: _contactCtrl.text.trim(),
      );
      if (!mounted) return;
      final email = _emailCtrl.text.trim();
      await showRegistrationSuccessDialog(
        context,
        title: 'Registration submitted',
        message:
            'Your member account is pending administrator approval. '
            'You will be able to sign in once an admin approves your registration.',
      );
      if (!mounted) return;
      Navigator.pop(context, email);
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Register as Member',
          style: TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: mobileScrollPadding(context),
            children: [
              const Text(
                'Create your member account. An administrator will review and approve your registration before you can sign in.',
                style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kRedDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: kRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              RegistrationFormField(
                label: 'Full Name',
                controller: _nameCtrl,
                hint: 'Juan Dela Cruz',
                icon: Icons.person_outline,
                validator: (v) => RegistrationValidators.required(v, label: 'Full name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              RegistrationFormField(
                label: 'Student ID',
                controller: _studentIdCtrl,
                hint: '2024-00001',
                icon: Icons.badge_outlined,
                validator: (v) => RegistrationValidators.required(v, label: 'Student ID'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              RegistrationFormField(
                label: 'Email',
                controller: _emailCtrl,
                hint: 'you@student.ustp.edu.ph',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: RegistrationValidators.email,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              RegistrationFormField(
                label: 'Contact Number',
                controller: _contactCtrl,
                hint: '09XX XXX XXXX',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => RegistrationValidators.required(v, label: 'Contact number'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              RegistrationFormField(
                label: 'Password',
                controller: _passwordCtrl,
                hint: 'At least 6 characters',
                icon: Icons.lock_outline,
                obscureText: _obscurePass,
                validator: RegistrationValidators.password,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              RegistrationFormField(
                label: 'Confirm Password',
                controller: _confirmCtrl,
                hint: 'Re-enter password',
                icon: Icons.lock_outline,
                obscureText: _obscureConfirm,
                validator: (v) =>
                    RegistrationValidators.confirmPassword(v, _passwordCtrl.text),
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 18),
              LegalAgreementCheckbox(
                value: _acceptedLegal,
                onChanged: (v) => setState(() {
                  _acceptedLegal = v;
                  if (v) _error = null;
                }),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
