import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/models/requestor_type.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';
import 'package:access_mobile/shared/widgets/registration_success_dialog.dart';
import 'package:access_mobile/shared/widgets/legal_agreement_widgets.dart';

/// Self-service requestor registration (pending admin approval).
///
/// API account role remains `Organization` (system Requestor role).
/// [RequestorType] is stored via `student_id` (unused for requestor accounts).
class RequestorRegistrationScreen extends StatefulWidget {
  const RequestorRegistrationScreen({
    super.key,
    required this.requestorType,
  });

  final RequestorType requestorType;

  @override
  State<RequestorRegistrationScreen> createState() =>
      _RequestorRegistrationScreenState();
}

class _RequestorRegistrationScreenState extends State<RequestorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _adviserCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _acceptedLegal = false;
  String? _error;

  RequestorType get _type => widget.requestorType;

  bool get _isOrganizationType => _type == RequestorType.organization;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _adviserCtrl.dispose();
    _contactCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _screenTitle => 'Register as ${_type.label}';

  String get _introText {
    switch (_type) {
      case RequestorType.faculty:
        return 'Register as a faculty requestor. An administrator will review your '
            'application before you can sign in and submit documentation requests.';
      case RequestorType.instructor:
        return 'Register as an instructor requestor. An administrator will review your '
            'application before you can sign in and submit documentation requests.';
      case RequestorType.organization:
        return 'Register your student organization to request documentation services. '
            'An administrator will review your application before you can sign in.';
    }
  }

  String get _nameLabel {
    switch (_type) {
      case RequestorType.faculty:
      case RequestorType.instructor:
        return 'Full Name';
      case RequestorType.organization:
        return 'Organization Name';
    }
  }

  String get _nameHint {
    switch (_type) {
      case RequestorType.faculty:
        return 'Prof. Maria Santos';
      case RequestorType.instructor:
        return 'Instructor Juan Dela Cruz';
      case RequestorType.organization:
        return 'USTP Engineering Society';
    }
  }

  IconData get _nameIcon {
    switch (_type) {
      case RequestorType.faculty:
      case RequestorType.instructor:
        return Icons.person_outline;
      case RequestorType.organization:
        return Icons.business_outlined;
    }
  }

  String get _emailLabel =>
      _isOrganizationType ? 'Organization Email' : 'Email Address';

  String get _emailHint =>
      _isOrganizationType ? 'org@ustp.edu.ph' : 'name@ustp.edu.ph';

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
        role: 'Organization',
        studentId: _type.storageValue,
        contactNumber: _contactCtrl.text.trim(),
        adviserName: _isOrganizationType ? _adviserCtrl.text.trim() : null,
      );
      if (!mounted) return;
      final email = _emailCtrl.text.trim();
      await showRegistrationSuccessDialog(
        context,
        title: 'Registration submitted',
        message:
            'Your requestor account is pending administrator approval. '
            'We will email you at $email when an administrator approves or declines your registration. '
            'Until then, Sign in will show that your account is still pending.',
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
        title: Text(
          _screenTitle,
          style: const TextStyle(
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
              Text(
                _introText,
                style: const TextStyle(color: kTextSecondary, fontSize: 13, height: 1.45),
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
                        child: Text(
                          _error!,
                          style: const TextStyle(color: kRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              RegistrationFormField(
                label: _nameLabel,
                controller: _nameCtrl,
                hint: _nameHint,
                icon: _nameIcon,
                validator: (v) => RegistrationValidators.required(
                  v,
                  label: _nameLabel.toLowerCase(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              RegistrationFormField(
                label: _emailLabel,
                controller: _emailCtrl,
                hint: _emailHint,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: RegistrationValidators.email,
                textInputAction: TextInputAction.next,
              ),
              if (_isOrganizationType) ...[
                const SizedBox(height: 14),
                RegistrationFormField(
                  label: 'Adviser or Representative Name',
                  controller: _adviserCtrl,
                  hint: 'Prof. Maria Santos',
                  icon: Icons.person_outline,
                  validator: (v) => RegistrationValidators.required(
                    v,
                    label: 'Adviser or representative name',
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ],
              const SizedBox(height: 14),
              RegistrationFormField(
                label: 'Contact Number',
                controller: _contactCtrl,
                hint: '09XX XXX XXXX',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    RegistrationValidators.required(v, label: 'Contact number'),
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
                    _obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
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
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
