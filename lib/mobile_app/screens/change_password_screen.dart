import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';

/// Change password via `PATCH /profile` with current-password verification.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    final req = RegistrationValidators.password(value);
    if (req != null) return req;
    if (value == _currentPassCtrl.text) {
      return 'New password must be different from your current password';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await memberApiService.updateProfile(
        currentPassword: _currentPassCtrl.text,
        newPassword: _newPassCtrl.text,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: kGreen,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not change password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMemberDashboardBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kDashTextPrimary),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Change Password',
          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: mobileScrollPadding(context, top: 12),
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kRedDim,
                          borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                          border: Border.all(color: kRed.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: kRed, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: dashText(const TextStyle(color: kRed, fontSize: 13, height: 1.35)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    MemberDashboardCard(
                      showAccentStrip: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Update your password',
                            style: memberDashboardCardTitleStyle.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your current password, then choose a new one (at least 6 characters).',
                            style: memberDashboardMetaStyle.copyWith(height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          RegistrationFormField(
                            label: 'Current Password',
                            controller: _currentPassCtrl,
                            icon: Icons.lock_outline,
                            obscureText: _obscureCurrent,
                            validator: (v) =>
                                RegistrationValidators.required(v, label: 'Current password'),
                            textInputAction: TextInputAction.next,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureCurrent
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureCurrent = !_obscureCurrent),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RegistrationFormField(
                            label: 'New Password',
                            controller: _newPassCtrl,
                            icon: Icons.lock_reset_outlined,
                            obscureText: _obscureNew,
                            validator: _validateNewPassword,
                            textInputAction: TextInputAction.next,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(() => _obscureNew = !_obscureNew),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RegistrationFormField(
                            label: 'Confirm New Password',
                            controller: _confirmPassCtrl,
                            icon: Icons.lock_outline,
                            obscureText: _obscureConfirm,
                            validator: (v) =>
                                RegistrationValidators.confirmPassword(v, _newPassCtrl.text),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  mobilePagePaddingOf(context),
                  12,
                  mobilePagePaddingOf(context),
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: kSurface,
                  border: Border(top: BorderSide(color: kDashBorder.withValues(alpha: 0.8))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kDashTextPrimary,
                          minimumSize: const Size.fromHeight(kMobileMinTouch),
                          side: const BorderSide(color: kDashBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                          ),
                          textStyle: dashText(const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: kMemberDashboardAccent,
                          minimumSize: const Size.fromHeight(kMobileMinTouch),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                          ),
                          textStyle: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Change Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
