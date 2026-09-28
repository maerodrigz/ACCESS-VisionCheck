import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/edit_profile_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_logout_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_settings_section.dart';
import 'package:access_mobile/mobile_app/widgets/member_profile_skeleton.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/auth_controller.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Requestor profile — account settings without member-only performance sections.
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
    return Scaffold(
      backgroundColor: kBg,
      body: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (context, _) {
          final loading =
              memberDataController.isLoading && !memberDataController.profileLoaded;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading)
                const RequestorProfileHeroSkeleton()
              else
                _RequestorProfileMiniHero(
                  onEdit: _openEditProfile,
                ),
              Expanded(
                child: loading
                    ? const SizedBox.shrink()
                    : RefreshIndicator(
                        color: kMemberPrimary,
                        onRefresh: () => memberDataController.refreshAll(),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(
                            kMemberDashboardPagePadding,
                            14,
                            kMemberDashboardPagePadding,
                            36,
                          ),
                          children: const [
                            MemberProfileSettingsSection(forRequestor: true),
                            SizedBox(height: kMemberDashboardSectionGap),
                            MemberProfileLogoutSection(),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Single dark hero — identity only, no duplicate stats or second gradient card.
class _RequestorProfileMiniHero extends StatelessWidget {
  const _RequestorProfileMiniHero({
    required this.onEdit,
  });

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final displayName = appState.profileName.trim().isNotEmpty
        ? appState.profileName.trim()
        : (authController.user?.name ?? 'Requestor');
    final email = appState.profileEmail.trim().isNotEmpty
        ? appState.profileEmail.trim()
        : (authController.user?.email ?? '');
    final imageUrl = appState.profileImageUrl;
    final initials = memberDisplayInitials(displayName);
    final avatarSize = compact ? 68.0 : 80.0;
    final badgeLabel = compact ? 'Org requestor' : 'Organization requestor';

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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, compact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (Navigator.canPop(context))
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: kMobileMinTouch,
                          height: kMobileMinTouch,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      'Your profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dashText(TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      )),
                    ),
                  ),
                  _ProfileEditButton(compact: compact, onTap: onEdit),
                ],
              ),
              SizedBox(height: compact ? 12 : 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: avatarSize,
                    height: avatarSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                        image: imageUrl != null && imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageUrl == null || imageUrl.isEmpty
                          ? Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 20 : 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  SizedBox(width: compact ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.15,
                          )),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: dashText(TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            )),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.business_rounded,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        badgeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        )),
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

class _ProfileEditButton extends StatelessWidget {
  const _ProfileEditButton({
    required this.compact,
    required this.onTap,
  });

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 36.0;

    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.edit_rounded,
            size: compact ? 17 : 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
