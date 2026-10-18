import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/models/requestor_type.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_scaffold.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_widgets.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';
import 'package:access_mobile/shared/widgets/registration_success_dialog.dart';
import 'package:access_mobile/shared/legal/access_legal_content.dart';
import 'package:access_mobile/shared/widgets/legal_agreement_widgets.dart';
import 'package:access_mobile/shared/copy/mobile_registration_copy.dart';
import 'package:access_mobile/shared/widgets/registration_email_otp_panel.dart';

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
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _acceptedLegal = false;
  String? _emailVerificationToken;
  String? _error;

  RequestorType get _type => widget.requestorType;

  bool get _isOrganizationType => _type == RequestorType.organization;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _adviserCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _screenTitle => 'Register as ${_type.label}';

  String get _introText {
    switch (_type) {
      case RequestorType.facultyStaff:
        return 'For faculty and staff who request documentation from ACCESS members. '
            'An administrator must approve your account before you can sign in.';
      case RequestorType.organization:
        return 'For registered student organizations that request documentation services. '
            'An administrator must approve your account before you can sign in.';
    }
  }

  String get _nameLabel {
    switch (_type) {
      case RequestorType.facultyStaff:
        return 'Full Name';
      case RequestorType.organization:
        return 'Organization Name';
    }
  }

  String get _nameHint {
    switch (_type) {
      case RequestorType.facultyStaff:
        return 'Prof. Maria Santos';
      case RequestorType.organization:
        return 'USTP Engineering Society';
    }
  }

  IconData get _nameIcon {
    switch (_type) {
      case RequestorType.facultyStaff:
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
      setState(() => _error = MobileRegistrationCopy.agreeLegalError);
      return;
    }
    if (_emailVerificationToken == null) {
      setState(() => _error = MobileRegistrationCopy.verifyEmailBeforeSubmit);
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
        emailVerificationToken: _emailVerificationToken,
        adviserName: _isOrganizationType ? _adviserCtrl.text.trim() : null,
      );
      if (!mounted) return;
      final email = _emailCtrl.text.trim();
      await showRegistrationSuccessDialog(
        context,
        title: 'Registration submitted',
        message: MobileRegistrationCopy.requestorSuccessMessage(email),
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
    final mobileAuth = !kIsWeb;

    final formBody = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mobileAuth) const MobileAuthBackButton(),
          if (mobileAuth)
            MobileAuthSectionHeader(
              title: _screenTitle,
              subtitle: _introText,
            )
          else
            Text(
              _introText,
              style: const TextStyle(color: kTextSecondary, fontSize: 13, height: 1.45),
            ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            mobileAuth ? mobileAuthErrorBanner(_error!) : _orgLegacyErrorBanner(_error!),
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
                mobileAuthStyle: mobileAuth,
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
                mobileAuthStyle: mobileAuth,
              ),
              if (_isOrganizationType) ...[
                const SizedBox(height: 14),
                RegistrationFormField(
                  label: 'Admin or Representative Name',
                  controller: _adviserCtrl,
                  hint: 'Prof. Maria Santos',
                  icon: Icons.person_outline,
                  validator: (v) => RegistrationValidators.required(
                    v,
                    label: 'Admin or representative name',
                  ),
                  textInputAction: TextInputAction.next,
                  mobileAuthStyle: mobileAuth,
                ),
              ],
              const SizedBox(height: 14),
              RegistrationEmailOtpPanel(
                emailController: _emailCtrl,
                nameForGreeting: _nameCtrl.text,
                onVerificationTokenChanged: (token) {
                  setState(() => _emailVerificationToken = token);
                },
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
                mobileAuthStyle: mobileAuth,
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
                mobileAuthStyle: mobileAuth,
              ),
              const SizedBox(height: 18),
              LegalAgreementCheckbox(
                value: _acceptedLegal,
                registrationAudience: RegistrationLegalAudience.requestor,
                onChanged: (v) => setState(() {
                  _acceptedLegal = v;
                  if (v) _error = null;
                }),
              ),
              const SizedBox(height: 28),
              if (mobileAuth)
                MobileAuthGradientButton(
                  label: 'Register',
                  loading: _loading,
                  onPressed: _loading || !_acceptedLegal || _emailVerificationToken == null
                      ? null
                      : _submit,
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading || !_acceptedLegal || _emailVerificationToken == null
                        ? null
                        : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              if (mobileAuth) ...[
                const SizedBox(height: 20),
                MobileAuthTextLinkRow(
                  prompt: 'Already have an account?',
                  linkLabel: 'Sign In',
                  onLinkTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
    );

    if (mobileAuth) {
      return MobileAuthScaffold(body: formBody);
    }

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
          style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: mobileScrollPadding(context),
          child: formBody,
        ),
      ),
    );
  }
}

Widget _orgLegacyErrorBanner(String message) {
  return Container(
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
        Expanded(child: Text(message, style: const TextStyle(color: kRed, fontSize: 13))),
      ],
    ),
  );
}
