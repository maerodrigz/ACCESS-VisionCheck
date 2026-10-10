import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/edit_profile_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_logout_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_settings_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_skeleton.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/branding_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';

const _kSectionGap = 20.0;

/// Requestor profile — light layout aligned with member profile, requestor settings only.
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final compact = MediaQuery.sizeOf(context).width < 360;
        final pagePadding = mobilePagePaddingOf(context);

        final profileLoadFailed = memberDataController.profileLoadError != null &&
            !memberDataController.isLoading &&
            !memberDataController.profileLoaded;
        final profileLoading = !memberDataController.profileLoaded &&
            !profileLoadFailed &&
            (memberDataController.isLoading || !memberDataController.profileLoadAttempted);

        return Scaffold(
          backgroundColor: kBg,
          body: RefreshIndicator(
            color: kAccent,
            onRefresh: () => memberDataController.refreshAll(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: profileLoading
                      ? const RequestorProfileHeroSkeleton()
                      : profileLoadFailed
                          ? Padding(
                              padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 0),
                              child: MemberProfileLoadError(
                                onRetry: memberDataController.refreshProfile,
                              ),
                            )
                          : _RequestorProfileHeader(
                              onEdit: _openEditProfile,
                              compact: compact,
                            ),
                ),
                if (profileLoading)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pagePadding, 14, pagePadding, 36),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(const [
                        MemberProfileActionRowSkeleton(),
                        SizedBox(height: 20),
                        MemberProfileAchievementsSkeleton(),
                      ]),
                    ),
                  )
                else if (!profileLoadFailed)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pagePadding, 14, pagePadding, 36),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const MemberProfileSettingsSection(forRequestor: true),
                        const SizedBox(height: _kSectionGap),
                        const MemberProfileLogoutSection(),
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
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

class _RequestorProfileHeader extends StatelessWidget {
  const _RequestorProfileHeader({
    required this.onEdit,
    required this.compact,
  });

  final VoidCallback onEdit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final displayName = appState.profileName.trim().isNotEmpty
        ? appState.profileName.trim()
        : (authController.user?.name ?? 'Organization');
    final email = appState.profileEmail.trim().isNotEmpty
        ? appState.profileEmail.trim()
        : (authController.user?.email ?? '');
    final imageUrl = appState.profileImageUrl;
    final initials = memberDisplayInitials(displayName);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.9))),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 6 : 8, 4, padding - 4, 0),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: kTextSecondary,
                      iconSize: 22,
                      style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                    ),
                  Expanded(
                    child: Text(
                      'Profile',
                      style: dashText(const TextStyle(
                        color: kTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      )),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 8, padding, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RequestorProfileAvatar(
                    initials: initials,
                    imageUrl: imageUrl,
                    compact: compact,
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
                            fontSize: compact ? 18 : 20,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.3,
                          )),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.business_outlined, size: 13, color: kAccent),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Organization requestor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: dashText(const TextStyle(
                                  color: kAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                              ),
                            ),
                          ],
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 13, color: kTextSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: dashText(const TextStyle(
                                    color: kTextSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  )),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Material(
                            color: kAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: onEdit,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: compact ? 14 : 15,
                                      color: kAccent,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Edit profile',
                                      style: dashText(const TextStyle(
                                        color: kAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestorProfileAvatar extends StatelessWidget {
  const _RequestorProfileAvatar({
    required this.initials,
    required this.compact,
    this.imageUrl,
  });

  final String initials;
  final bool compact;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 64.0 : 72.0;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kAccent.withValues(alpha: 0.35), width: 2),
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
      color: kAccent.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: kAccent,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}
