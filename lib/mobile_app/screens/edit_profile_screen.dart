import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';

/// Edit the logged-in member's profile (mobile only).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;
  String? _profileImageUrl;
  bool _isMember = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    _loadProfile();
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await memberApiService.getProfile();
      if (!mounted) return;
      final role = profile['role'] as String? ?? 'Member';
      _isMember = role.toLowerCase() == 'member';
      _nameCtrl.text = profile['name'] as String? ?? '';
      _emailCtrl.text = profile['email'] as String? ?? '';
      _contactCtrl.text = profile['contact_number'] as String? ?? '';
      final img = profile['profile_image'] as String?;
      _profileImageUrl = img != null ? memberApiService.mediaUrl(img) : null;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load profile. Please try again.';
      });
    }
  }

  String _initials(String name) {
    final n = name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return n[0].toUpperCase();
  }

  Future<void> _pickAvatar() async {
    if (_saving || _uploadingAvatar) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final updated = await memberApiService.uploadProfileAvatar(
        bytes: bytes,
        fileName: file.name,
      );
      final path = updated['profile_image'] as String?;
      final imageUrl = path != null ? memberApiService.mediaUrl(path) : null;

      appState.applyProfile(
        name: updated['name'] as String? ?? _nameCtrl.text.trim(),
        email: updated['email'] as String? ?? _emailCtrl.text.trim(),
        contactNumber: updated['contact_number'] as String?,
        profileImage: imageUrl,
      );

      if (!mounted) return;
      setState(() {
        _profileImageUrl = imageUrl;
        _uploadingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: kGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _error = 'Could not upload photo. Please try again.';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving || _uploadingAvatar) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await memberApiService.updateProfile(
        name: _isMember ? _nameCtrl.text.trim() : null,
        contactNumber: _contactCtrl.text.trim(),
      );

      await authController.updateSessionProfile(
        name: updated['name'] as String?,
        email: updated['email'] as String?,
      );

      final imagePath = updated['profile_image'] as String?;
      appState.applyProfile(
        name: updated['name'] as String? ?? _nameCtrl.text.trim(),
        email: updated['email'] as String? ?? _emailCtrl.text.trim(),
        contactNumber: updated['contact_number'] as String?,
        studentId: updated['student_id'] as String?,
        profileImage: imagePath != null
            ? ApiConfig.mediaUrl(imagePath)
            : _profileImageUrl,
        role: updated['role'] as String?,
        status: updated['status'] as String?,
        uploads: updated['uploads_count'] as int?,
        skillLevel: updated['skill_level'] as String?,
        points: updated['total_points'] as int?,
        rankPosition: updated['rank_position'] as int?,
      );

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: kGreen,
        ),
      );
      Navigator.pop(context, true);
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
        _error = 'Could not save changes. Please try again.';
      });
    }
  }

  bool get _busy => _saving || _uploadingAvatar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMemberDashboardBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kDashTextPrimary),
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _error != null && _nameCtrl.text.isEmpty
              ? _LoadError(message: _error!, onRetry: _loadProfile)
              : Column(
                  children: [
                    _EditProfileHero(
                      imageUrl: _profileImageUrl,
                      initials: _initials(_nameCtrl.text),
                      displayName: _nameCtrl.text.trim(),
                      uploading: _uploadingAvatar,
                      onChangePhoto: _pickAvatar,
                    ),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: mobileScrollPadding(context, top: 16),
                          children: [
                            if (_error != null) ...[
                              _ErrorBanner(message: _error!),
                              const SizedBox(height: 16),
                            ],
                            MemberDashboardCard(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Personal details',
                                    style: memberDashboardCardTitleStyle.copyWith(fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Update your name and contact information.',
                                    style: memberDashboardMetaStyle,
                                  ),
                                  const SizedBox(height: 18),
                                  if (_isMember) ...[
                                    RegistrationFormField(
                                      label: 'Full Name',
                                      controller: _nameCtrl,
                                      icon: Icons.person_outline,
                                      validator: _EditProfileValidators.fullName,
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: 14),
                                  ] else ...[
                                    _ReadOnlyField(
                                      label: 'Full Name',
                                      value: _nameCtrl.text,
                                      icon: Icons.person_outline,
                                      hint: 'Managed by your organization',
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  _ReadOnlyField(
                                    label: 'Email Address',
                                    value: _emailCtrl.text,
                                    icon: Icons.email_outlined,
                                    hint: 'Contact an admin to change your email',
                                  ),
                                  const SizedBox(height: 14),
                                  RegistrationFormField(
                                    label: 'Contact Number',
                                    controller: _contactCtrl,
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    validator: _EditProfileValidators.contactNumber,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _save(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Email changes require an administrator.',
                              style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _ActionBar(
                      saving: _saving,
                      disabled: _busy,
                      onCancel: () => Navigator.pop(context),
                      onSave: _save,
                    ),
                  ],
                ),
    );
  }
}

class _EditProfileValidators {
  _EditProfileValidators._();

  static String? fullName(String? v) {
    final req = RegistrationValidators.required(v, label: 'Full name');
    if (req != null) return req;
    if (v!.trim().length > 120) {
      return 'Full name must be 120 characters or fewer';
    }
    return null;
  }

  static String? contactNumber(String? v) {
    final req = RegistrationValidators.required(v, label: 'Contact number');
    if (req != null) return req;
    final digits = v!.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid contact number (7–15 digits)';
    }
    return null;
  }
}

class _EditProfileHero extends StatelessWidget {
  const _EditProfileHero({
    required this.imageUrl,
    required this.initials,
    required this.displayName,
    required this.uploading,
    required this.onChangePhoto,
  });

  final String? imageUrl;
  final String initials;
  final String displayName;
  final bool uploading;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(kMemberDarkHeroMiniBottomRadius),
          bottomRight: Radius.circular(kMemberDarkHeroMiniBottomRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(padding, 4, padding, 18),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
                    child: imageUrl == null
                        ? Text(
                            initials,
                            style: dashText(const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            )),
                          )
                        : null,
                  ),
                ),
                if (uploading)
                  Container(
                    width: 94,
                    height: 94,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: kAccent,
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: kAccent.withValues(alpha: 0.35),
                    child: InkWell(
                      onTap: uploading ? null : onChangePhoto,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 17),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (displayName.isNotEmpty)
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dashText(const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
              ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: uploading ? null : onChangePhoto,
              icon: Icon(
                Icons.photo_outlined,
                size: 16,
                color: Colors.white.withValues(alpha: uploading ? 0.45 : 0.92),
              ),
              label: Text(
                'Change photo',
                style: dashText(TextStyle(
                  color: Colors.white.withValues(alpha: uploading ? 0.45 : 0.92),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: dashText(const TextStyle(
                color: kDashTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kBlueDim,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Read-only',
                style: dashText(const TextStyle(
                  color: kAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          readOnly: true,
          enabled: false,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: memberDashboardMetaStyle.copyWith(fontSize: 13),
            prefixIcon: Icon(icon, color: kIconInactive, size: 18),
            filled: true,
            fillColor: kSurfaceAlt,
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
              borderSide: const BorderSide(color: kBorder),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              message,
              style: dashText(const TextStyle(color: kRed, fontSize: 13, height: 1.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: mobileScrollPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberDashboardEmptyState(
              icon: Icons.person_off_outlined,
              message: message,
            ),
            const SizedBox(height: 16),
            MemberDashboardPrimaryButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.saving,
    required this.disabled,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final bool disabled;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        mobilePagePaddingOf(context),
        12,
        mobilePagePaddingOf(context),
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kDashBorder.withValues(alpha: 0.8))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: disabled ? null : onCancel,
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
              onPressed: disabled ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(kMobileMinTouch),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                ),
                textStyle: dashText(const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
