import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/screens/change_password_screen.dart';
import 'package:access_mobile/mobile_app/screens/edit_profile_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_skeleton.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/legal/access_legal_content.dart';
import 'package:access_mobile/shared/screens/legal_document_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';

const _kCardRadius = 16.0;
const _kSectionGap = 16.0;
const _kRowDivider = Color(0xFFEAF0F5);
const _kSky = Color(0xFFEAF7FC);
const _kSkyBorder = Color(0xFFD0EBF5);
const _kCyan = Color(0xFF079FC6);
const _kNavy = Color(0xFF173650);
const _kMeta = Color(0xFF617F91);

/// Requestor profile — compact sky-blue identity card, settings, Sign Out.
class RequestorProfileScreen extends StatefulWidget {
  const RequestorProfileScreen({super.key});

  @override
  State<RequestorProfileScreen> createState() => _RequestorProfileScreenState();
}

class _RequestorProfileScreenState extends State<RequestorProfileScreen> {
  Future<void> _openEditProfile() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (saved == true && mounted) {
      await memberDataController.refreshAll();
    }
  }

  void _openLegal(AccessLegalDocument document) {
    openAccessLegalDocument(
      context,
      document,
      registrationAudience: RegistrationLegalAudience.requestor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final pagePadding = mobilePagePaddingOf(context);
        final profileLoadFailed = memberDataController.profileLoadError != null &&
            !memberDataController.isLoading &&
            !memberDataController.profileLoaded;
        final profileLoading = !memberDataController.profileLoaded &&
            !profileLoadFailed &&
            (memberDataController.isLoading ||
                !memberDataController.profileLoadAttempted);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RequestorProfileAppBar(
                  padding: pagePadding,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: kAccent,
                    onRefresh: () => memberDataController.refreshAll(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            pagePadding,
                            8,
                            pagePadding,
                            12,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (profileLoadFailed) ...[
                                      const _RequestorProfileCardShell(),
                                      const SizedBox(height: 12),
                                      MemberProfileLoadError(
                                        onRetry:
                                            memberDataController.refreshProfile,
                                      ),
                                    ] else if (profileLoading) ...[
                                      const _RequestorProfileCardSkeleton(),
                                      const SizedBox(height: _kSectionGap),
                                      const MemberProfileActionRowSkeleton(),
                                    ] else ...[
                                      _RequestorProfileCard(
                                        onEdit: _openEditProfile,
                                      ),
                                      const SizedBox(height: _kSectionGap),
                                      const _RequestorSectionTitle(
                                        title: 'Account & Security',
                                      ),
                                      const SizedBox(height: 8),
                                      _RequestorSettingsCard(
                                        child: _RequestorSettingsRow(
                                          icon: Icons.lock_outline_rounded,
                                          title: 'Change Password',
                                          subtitle:
                                              'Update your sign-in credentials',
                                          onTap: () => Navigator.push<void>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ChangePasswordScreen(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: _kSectionGap),
                                      const _RequestorSectionTitle(
                                        title: 'Legal & Policies',
                                      ),
                                      const SizedBox(height: 8),
                                      _RequestorSettingsCard(
                                        child: Column(
                                          children: [
                                            _RequestorSettingsRow(
                                              icon: Icons.description_outlined,
                                              title: 'Terms & Conditions',
                                              showSubtitle: false,
                                              onTap: () => _openLegal(
                                                AccessLegalDocument.terms,
                                              ),
                                            ),
                                            const Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: _kRowDivider,
                                            ),
                                            _RequestorSettingsRow(
                                              icon: Icons.privacy_tip_outlined,
                                              title: 'Privacy Policy',
                                              showSubtitle: false,
                                              onTap: () => _openLegal(
                                                AccessLegalDocument.privacy,
                                              ),
                                            ),
                                            const Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: _kRowDivider,
                                            ),
                                            _RequestorSettingsRow(
                                              icon: Icons.policy_outlined,
                                              title: 'Content Standards',
                                              showSubtitle: false,
                                              onTap: () => _openLegal(
                                                AccessLegalDocument
                                                    .contentStandards,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (!profileLoading) ...[
                                  const SizedBox(height: 24),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _RequestorSignOutButton(),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          0,
                                          14,
                                          0,
                                          8,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${brandingController.appName} · ${brandingController.organization}',
                                            textAlign: TextAlign.center,
                                            style: memberDashboardMetaStyle
                                                .copyWith(fontSize: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RequestorProfileAppBar extends StatelessWidget {
  const _RequestorProfileAppBar({required this.padding});

  final double padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding - 8, 4, padding, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: _kNavy,
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
          ),
          Expanded(
            child: Text(
              'Profile',
              style: memberDashboardSectionTitleStyle.copyWith(
                fontSize: 17,
                color: _kNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestorSectionTitle extends StatelessWidget {
  const _RequestorSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: memberDashboardSectionTitleStyle.copyWith(
        fontSize: 14,
        color: _kNavy,
      ),
    );
  }
}

class _RequestorProfileCardShell extends StatelessWidget {
  const _RequestorProfileCardShell();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _kSky,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kSkyBorder),
      ),
      child: Text(
        'Profile unavailable',
        style: memberDashboardMetaStyle.copyWith(color: _kMeta),
      ),
    );
  }
}

class _RequestorProfileCardSkeleton extends StatelessWidget {
  const _RequestorProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _kSky,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kSkyBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestorProfileCard extends StatelessWidget {
  const _RequestorProfileCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final displayName = appState.profileName.trim().isNotEmpty
        ? appState.profileName.trim()
        : (authController.user?.name ?? 'Organization');
    final email = appState.profileEmail.trim().isNotEmpty
        ? appState.profileEmail.trim()
        : (authController.user?.email ?? '');
    final imageUrl = appState.profileImageUrl;
    final initials = memberDisplayInitials(displayName);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: _kSky,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kSkyBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RequestorAvatar(
            initials: initials,
            imageUrl: imageUrl,
            size: compact ? 52 : 56,
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardCardTitleStyle.copyWith(
                    fontSize: compact ? 15 : 16,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      size: 14,
                      color: _kCyan.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Organization Requestor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardMetaStyle.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kMeta,
                        ),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.mail_outline_rounded,
                          size: 14,
                          color: _kCyan.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          email,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: memberDashboardMetaStyle.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _kMeta,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 12,
                          vertical: compact ? 7 : 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kSkyBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: compact ? 15 : 16,
                              color: _kCyan,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Edit Profile',
                              style: dashText(TextStyle(
                                color: _kNavy,
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 12.5 : 13,
                              )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestorAvatar extends StatelessWidget {
  const _RequestorAvatar({
    required this.initials,
    required this.size,
    this.imageUrl,
  });

  final String initials;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => _InitialsPlate(initials: initials),
              )
            : _InitialsPlate(initials: initials),
      ),
    );
  }
}

class _InitialsPlate extends StatelessWidget {
  const _InitialsPlate({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kAccent.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: kAccent,
            fontWeight: FontWeight.w800,
            fontSize: initials.length > 2 ? 16 : 20,
          ),
        ),
      ),
    );
  }
}

class _RequestorSettingsCard extends StatelessWidget {
  const _RequestorSettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kSkyBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _RequestorSettingsRow extends StatelessWidget {
  const _RequestorSettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showSubtitle = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kSky,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _kCyan, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: memberDashboardCardTitleStyle.copyWith(
                        fontSize: 13.5,
                        color: _kNavy,
                      ),
                    ),
                    if (showSubtitle &&
                        subtitle != null &&
                        subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardMetaStyle.copyWith(
                          fontSize: 11,
                          color: _kMeta,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _kMeta.withValues(alpha: 0.8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestorSignOutButton extends StatelessWidget {
  const _RequestorSignOutButton();

  static Future<bool> _confirmSignOut(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out?',
          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: memberDashboardMetaStyle.copyWith(height: 1.45, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: dashText(const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Sign Out',
              style: dashText(const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: kMobileMinTouch,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await _confirmSignOut(context);
          if (!confirmed || !context.mounted) return;
          await authController.logout();
        },
        icon: Icon(
          Icons.logout_rounded,
          color: kRed.withValues(alpha: 0.95),
          size: 20,
        ),
        label: Text(
          'Sign Out',
          style: dashText(const TextStyle(
            color: kRed,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          )),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: kRed,
          side: BorderSide(color: kRed.withValues(alpha: 0.4)),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kCardRadius),
          ),
        ),
      ),
    );
  }
}
