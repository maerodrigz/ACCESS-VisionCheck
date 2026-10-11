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

const _kCardRadius = 18.0;
const _kSectionGap = 20.0;
const _kRowDivider = Color(0xFFF1F5F9);

/// Requestor profile — compact app bar, organization card, security, legal, logout.
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
            (memberDataController.isLoading || !memberDataController.profileLoadAttempted);

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: kTextPrimary),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'Profile',
              style: memberDashboardSectionTitleStyle.copyWith(fontSize: 17),
            ),
            centerTitle: false,
            titleSpacing: 0,
          ),
          body: RefreshIndicator(
            color: kAccent,
            onRefresh: () => memberDataController.refreshAll(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                if (profileLoading)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 36),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(const [
                        _RequestorProfileCardSkeleton(),
                        SizedBox(height: _kSectionGap),
                        MemberProfileActionRowSkeleton(),
                      ]),
                    ),
                  )
                else if (profileLoadFailed)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 36),
                      child: MemberProfileLoadError(
                        onRetry: memberDataController.refreshProfile,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 36),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _RequestorOrganizationCard(onEdit: _openEditProfile),
                        const SizedBox(height: _kSectionGap),
                        const _RequestorSectionTitle(title: 'Account & Security'),
                        const SizedBox(height: 8),
                        MemberDashboardCard(
                          padding: EdgeInsets.zero,
                          child: _RequestorSettingsRow(
                            icon: Icons.lock_outline_rounded,
                            title: 'Change Password',
                            subtitle: 'Update your sign-in credentials',
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: _kSectionGap),
                        const _RequestorSectionTitle(title: 'Legal & Policies'),
                        const SizedBox(height: 8),
                        MemberDashboardCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _RequestorSettingsRow(
                                icon: Icons.description_outlined,
                                title: 'Terms & Conditions',
                                showSubtitle: false,
                                onTap: () => _openLegal(AccessLegalDocument.terms),
                              ),
                              const Divider(height: 1, thickness: 1, color: _kRowDivider),
                              _RequestorSettingsRow(
                                icon: Icons.privacy_tip_outlined,
                                title: 'Privacy Policy',
                                showSubtitle: false,
                                onTap: () => _openLegal(AccessLegalDocument.privacy),
                              ),
                              const Divider(height: 1, thickness: 1, color: _kRowDivider),
                              _RequestorSettingsRow(
                                icon: Icons.policy_outlined,
                                title: 'Content Standards',
                                showSubtitle: false,
                                onTap: () =>
                                    _openLegal(AccessLegalDocument.contentStandards),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _RequestorLogoutButton(),
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 4),
                          child: Center(
                            child: Text(
                              '${brandingController.appName} · ${brandingController.organization}',
                              textAlign: TextAlign.center,
                              style: memberDashboardMetaStyle.copyWith(fontSize: 10),
                            ),
                          ),
                        ),
                      ]),
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

class _RequestorSectionTitle extends StatelessWidget {
  const _RequestorSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15),
    );
  }
}

class _RequestorOrganizationCard extends StatelessWidget {
  const _RequestorOrganizationCard({required this.onEdit});

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

    return MemberDashboardCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RequestorAvatar(
            initials: initials,
            imageUrl: imageUrl,
            size: compact ? 56 : 64,
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: kTextPrimary,
                    fontSize: compact ? 17 : 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.2,
                  )),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      size: 14,
                      color: kAccent.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Organization Requestor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(const TextStyle(
                          color: kAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        )),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.mail_outline_rounded,
                          size: 15,
                          color: kTextSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(const TextStyle(
                            color: kTextSecondary,
                            fontSize: 12,
                            height: 1.35,
                          )),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: compact ? 16 : 17, color: kAccent),
                  label: Text(
                    'Edit Profile',
                    style: dashText(const TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccent,
                    side: BorderSide(color: kAccent.withValues(alpha: 0.45)),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 14,
                      vertical: compact ? 6 : 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
        border: Border.all(color: kBorder),
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
      color: kAccent.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: kAccent,
            fontWeight: FontWeight.w800,
            fontSize: initials.length > 2 ? 18 : 22,
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kAccent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                    ),
                    if (showSubtitle && subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: kTextSecondary.withValues(alpha: 0.75),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestorLogoutButton extends StatelessWidget {
  const _RequestorLogoutButton();

  static Future<bool> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out?',
          style: memberDashboardSectionTitleStyle.copyWith(fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
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
              'Log Out',
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
          final confirmed = await _confirmLogout(context);
          if (!confirmed || !context.mounted) return;
          await authController.logout();
        },
        icon: Icon(Icons.logout_rounded, color: kRed.withValues(alpha: 0.9), size: 20),
        label: Text(
          'Log Out',
          style: dashText(const TextStyle(
            color: kRed,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          )),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: kRed,
          side: BorderSide(color: kRed.withValues(alpha: 0.35)),
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kCardRadius),
          ),
        ),
      ),
    );
  }
}

class _RequestorProfileCardSkeleton extends StatelessWidget {
  const _RequestorProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return MemberDashboardCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberProfileSkeletonBone(
            height: compact ? 56 : 64,
            width: compact ? 56 : 64,
            radius: 999,
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MemberProfileSkeletonBone(height: compact ? 17 : 18, radius: 6),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.55,
                  alignment: Alignment.centerLeft,
                  child: MemberProfileSkeletonBone(height: 12, radius: 4),
                ),
                const SizedBox(height: 8),
                MemberProfileSkeletonBone(height: 12, radius: 4),
                const SizedBox(height: 12),
                MemberProfileSkeletonBone(
                  height: 34,
                  width: compact ? 108 : 118,
                  radius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
