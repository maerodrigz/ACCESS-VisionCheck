import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/member_review_status.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
import 'package:access_mobile/mobile_app/widgets/admin_review_status_badge.dart';
import 'package:access_mobile/mobile_app/widgets/criterion_score_bar.dart';
import 'package:access_mobile/mobile_app/screens/ai_media_evaluation_screen.dart';
import 'package:access_mobile/mobile_app/screens/evaluation_report_screen.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_criterion_meta.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_how_it_works_guide.dart';
import 'package:access_mobile/mobile_app/utils/practice_evaluation_display.dart';
import 'package:access_mobile/mobile_app/utils/practice_storage_removal.dart';
import 'package:access_mobile/mobile_app/widgets/verified_eval_swipe_tile.dart';

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({
    super.key,
    this.onNotificationsTap,
    this.onProfileTap,
    this.scrollToAllEvaluations = false,
    this.onDidScrollToAllEvaluations,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  /// When true (e.g. Dashboard Recent Uploads → View All), scroll to All Evaluations.
  final bool scrollToAllEvaluations;
  final VoidCallback? onDidScrollToAllEvaluations;

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final _allEvaluationsSectionKey = GlobalKey();
  var _scrollToAllAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(memberDataController.ensureEvaluationsTab());
      if (widget.scrollToAllEvaluations) {
        _scheduleScrollToAllEvaluations();
      }
    });
  }

  @override
  void didUpdateWidget(covariant EvaluationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToAllEvaluations && !oldWidget.scrollToAllEvaluations) {
      _scrollToAllAttempts = 0;
      _scheduleScrollToAllEvaluations();
    }
  }

  void _scheduleScrollToAllEvaluations() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _allEvaluationsSectionKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
        widget.onDidScrollToAllEvaluations?.call();
        return;
      }
      if (_scrollToAllAttempts >= 40) {
        widget.onDidScrollToAllEvaluations?.call();
        return;
      }
      _scrollToAllAttempts++;
      _scheduleScrollToAllEvaluations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (_, __) {
          final loading = memberDataController.evaluationsTabLoading &&
              appState.evaluations.isEmpty &&
              !memberDataController.evaluationsTabSynced;
          final loadError = memberDataController.evaluationsTabError;

          if (loading) {
            return const MobileLoadingView(message: 'Loading evaluations…');
          }

          if (loadError != null && appState.evaluations.isEmpty) {
            return RefreshIndicator(
              color: kMemberPrimary,
              backgroundColor: kDashCardBg,
              onRefresh: memberDataController.refreshEvaluationsTab,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                  MobileEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Unable to load evaluations',
                    subtitle: loadError,
                    actionLabel: 'Retry',
                    onAction: memberDataController.refreshEvaluationsTab,
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: kMemberPrimary,
              backgroundColor: kDashCardBg,
              onRefresh: () => memberDataController.refreshEvaluationsTab(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                SliverToBoxAdapter(
                  child: _EvaluationPageHeader(
                    onNotificationsTap: widget.onNotificationsTap,
                    onProfileTap: widget.onProfileTap,
                  ),
                ),
                if (memberDataController.pendingPracticeAnalysisCount > 0)
                  SliverToBoxAdapter(
                    child: _PendingPracticeAnalysisBanner(
                      count: memberDataController.pendingPracticeAnalysisCount,
                    ),
                  ),
                SliverToBoxAdapter(child: const _EvalAiHeroCard()),
                SliverToBoxAdapter(
                  child: MemberDashboardFadeSlide(
                    index: 1,
                    child: const EvaluationHowItWorksGuide(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: MemberDashboardFadeSlide(
                    index: 2,
                    child: _EvalOptionsSection(
                      onPhoto: () => _openEvaluation(context, isVideo: false),
                      onVideo: () => _openEvaluation(context, isVideo: true),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: MemberDashboardFadeSlide(
                    index: 3,
                    child: KeyedSubtree(
                      key: _allEvaluationsSectionKey,
                      child: _RecentEvaluationsSection(
                        evaluations: practiceEvaluationsForDisplay(
                          evaluations: appState.evaluations,
                          practiceMedia: appState.gallery,
                        ),
                        onTap: (ev) {
                          if (ev.isAnalysisInProgress) {
                            showMobileToast(
                              context,
                              'Analysis is still running. Pull down to refresh in a moment.',
                              success: false,
                            );
                            unawaited(memberDataController.refreshEvaluationsTab());
                            return;
                          }
                          openEvaluationReport(
                            context,
                            ev,
                            allEvaluations: appState.evaluations,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
            ),
          );
        },
      ),
    );
  }
}

// ── Page header ──────────────────────────────────────────────────────────────

class _EvaluationPageHeader extends StatelessWidget {
  const _EvaluationPageHeader({this.onNotificationsTap, this.onProfileTap});

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        6,
        kMemberDashboardPagePadding,
        4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Evaluation',
                  style: dashText(const TextStyle(
                    color: kTextPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.45,
                    height: 1.12,
                  )),
                ),
                const SizedBox(height: 3),
                Text(
                  'Quality Analysis & Feedback',
                  style: evalSectionSubtitleStyle.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          MemberPageNotificationButton(onTap: onNotificationsTap),
          MemberPageProfileAvatar(onTap: onProfileTap),
        ],
      ),
    );
  }
}

void _openEvaluation(BuildContext context, {required bool isVideo}) {
  if (appState.evaluationsTodayAtLimitConfirmed) {
    showMobileToast(
      context,
      'Daily limit reached. ${appState.dailyEvaluationLimit} evaluations per day.',
      success: false,
    );
    return;
  }
  openAiMediaEvaluation(
    context,
    mode: isVideo ? AiMediaEvaluationMode.video : AiMediaEvaluationMode.photo,
  );
}

// ── 1. Media Evaluation banner + Daily Practice card ─────────────────────────

const _kEvalBannerAsset = 'assets/images/evaluation/media_evaluation_bg.png';
/// Native asset size 2164×727.
const _kEvalBannerAspectRatio = 2164 / 727;
const _kEvalBannerNavy = Color(0xFF1E293B);
const _kEvalBannerNavyMuted = Color(0xFF475569);
const _kEvalBannerRadius = 16.0;

class _EvalAiHeroCard extends StatefulWidget {
  const _EvalAiHeroCard();

  @override
  State<_EvalAiHeroCard> createState() => _EvalAiHeroCardState();
}

class _EvalAiHeroCardState extends State<_EvalAiHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);
    _fade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (_, __) {
        final done = appState.evaluationsTodayCount;
        final limit = appState.dailyEvaluationLimit;
        final remaining = appState.evaluationsRemainingToday;
        final resetLabel =
            evaluationDailyLimitResetLabel(appState.evaluationDailyTimezone);
        final quotaConfirmed = appState.evaluationsTodayQuotaConfirmed;
        final quotaSyncing = memberDataController.participationQuotaSyncing;
        final quotaSyncError = memberDataController.participationQuotaSyncError;
        final narrow = MediaQuery.sizeOf(context).width < 360;

        return FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              kMemberDashboardPagePadding,
              8,
              kMemberDashboardPagePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    // Keep a compact banner; clamp so small phones stay readable.
                    final height = (width / _kEvalBannerAspectRatio)
                        .clamp(narrow ? 108.0 : 112.0, narrow ? 128.0 : 136.0);

                    return Container(
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(_kEvalBannerRadius),
                        boxShadow: [
                          BoxShadow(
                            color: _kEvalBannerNavy.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Slight scale crops the asset's baked-in white frame.
                          Transform.scale(
                            scale: 1.12,
                            child: Image.asset(
                              _kEvalBannerAsset,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0.62, 0),
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: Color(0xFFE8F4FC),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              narrow ? 14 : 16,
                              narrow ? 12 : 14,
                              narrow ? 12 : 14,
                              narrow ? 12 : 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: narrow ? 7 : 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Media Evaluation',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: dashText(TextStyle(
                                          color: _kEvalBannerNavy,
                                          fontSize: narrow ? 17 : 18.5,
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                          letterSpacing: -0.3,
                                        )),
                                      ),
                                      SizedBox(height: narrow ? 4 : 5),
                                      Text(
                                        'Evaluate media to improve your capture quality.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: dashText(TextStyle(
                                          color: _kEvalBannerNavyMuted,
                                          fontSize: narrow ? 11.5 : 12.5,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                        )),
                                      ),
                                    ],
                                  ),
                                ),
                                // Keep illustration clear on the right.
                                SizedBox(width: narrow ? 86 : 112),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _EvalDailyPracticeCard(
                  done: done,
                  limit: limit,
                  remaining: remaining,
                  dailyResetLabel: resetLabel,
                  quotaConfirmed: quotaConfirmed,
                  quotaSyncing: quotaSyncing,
                  quotaSyncError: quotaSyncError,
                  compact: narrow,
                  onRetrySync: () {
                    unawaited(
                      memberDataController.refreshParticipationQuota(
                        reason: 'evaluations_hero_retry',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EvalDailyPracticeCard extends StatelessWidget {
  const _EvalDailyPracticeCard({
    required this.done,
    required this.limit,
    required this.remaining,
    required this.dailyResetLabel,
    required this.quotaConfirmed,
    required this.quotaSyncing,
    this.quotaSyncError,
    this.onRetrySync,
    this.compact = false,
  });

  final int done;
  final int limit;
  final int remaining;
  final String dailyResetLabel;
  final bool quotaConfirmed;
  final bool quotaSyncing;
  final String? quotaSyncError;
  final VoidCallback? onRetrySync;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final atLimit = quotaConfirmed && remaining <= 0;
    final low = quotaConfirmed && !atLimit && remaining <= 1;
    final progress = quotaConfirmed && limit > 0
        ? (done / limit).clamp(0.0, 1.0)
        : 0.0;
    final countLabel = quotaSyncing
        ? '…'
        : (quotaConfirmed ? '$done/$limit' : '—/$limit');
    final subLabel = quotaSyncing
        ? 'Syncing…'
        : (quotaSyncError != null
            ? 'Tap to sync'
            : (atLimit
                ? 'Limit reached'
                : (quotaConfirmed ? '$remaining left' : 'Sync quota')));

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: quotaSyncError != null && !quotaSyncing ? onRetrySync : null,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 14,
            compact ? 11 : 12,
            compact ? 12 : 14,
            compact ? 11 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: compact ? 34 : 36,
                    height: compact ? 34 : 36,
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      atLimit
                          ? Icons.hourglass_disabled_rounded
                          : Icons.speed_rounded,
                      size: compact ? 18 : 19,
                      color: atLimit ? const Color(0xFFDC2626) : kAccent,
                    ),
                  ),
                  SizedBox(width: compact ? 10 : 12),
                  Expanded(
                    child: Text(
                      'Daily Practice',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dashText(TextStyle(
                        color: _kEvalBannerNavy,
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w800,
                      )),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 9 : 10,
                      vertical: compact ? 6 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (quotaSyncing)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kAccent,
                            ),
                          )
                        else
                          Text(
                            countLabel,
                            style: dashText(TextStyle(
                              color: _kEvalBannerNavy,
                              fontSize: compact ? 14 : 15,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            )),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          subLabel,
                          style: dashText(TextStyle(
                            color: atLimit
                                ? const Color(0xFFDC2626)
                                : (quotaSyncError != null
                                    ? const Color(0xFFD97706)
                                    : (low
                                        ? const Color(0xFFD97706)
                                        : _kEvalBannerNavyMuted)),
                            fontSize: compact ? 10 : 10.5,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          )),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Resets at midnight ($dailyResetLabel)',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: dashText(TextStyle(
                  color: _kEvalBannerNavyMuted,
                  fontSize: compact ? 11 : 11.5,
                  fontWeight: FontWeight.w500,
                )),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: kAccent.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      atLimit
                          ? const Color(0xFFEF4444)
                          : (low ? const Color(0xFFD97706) : kAccent),
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

// ── 2. Evaluation Options (Design 3 selection cards) ─────────────────────────

const _kEvalPhotoCardBg = Color(0xFFE8F9FC);
const _kEvalVideoCardBg = Color(0xFFEAF3FF);
const _kEvalSelectNavy = Color(0xFF1E293B);
const _kEvalSelectNavyMuted = Color(0xFF64748B);

class _EvalOptionsSection extends StatelessWidget {
  const _EvalOptionsSection({required this.onPhoto, required this.onVideo});

  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        14,
        kMemberDashboardPagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What would you like to evaluate?',
            style: evalSectionTitleStyle.copyWith(
              fontSize: narrow ? 15 : 16,
              color: _kEvalSelectNavy,
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _EvalSelectionCard(
                    icon: Icons.photo_camera_outlined,
                    title: 'Photo Evaluation',
                    description: 'Analyze photo quality and get feedback.',
                    accent: kCyan,
                    background: _kEvalPhotoCardBg,
                    compact: narrow,
                    onTap: onPhoto,
                  ),
                ),
                SizedBox(width: narrow ? 8 : 10),
                Expanded(
                  child: _EvalSelectionCard(
                    icon: Icons.videocam_outlined,
                    title: 'Video Evaluation',
                    description: 'Analyze video quality and get feedback.',
                    accent: kAccent,
                    background: _kEvalVideoCardBg,
                    compact: narrow,
                    onTap: onVideo,
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

class _EvalSelectionCard extends StatefulWidget {
  const _EvalSelectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.background,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final Color background;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_EvalSelectionCard> createState() => _EvalSelectionCardState();
}

class _EvalSelectionCardState extends State<_EvalSelectionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) {
          if (_pressed != v) setState(() => _pressed = v);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            compact ? 11 : 12,
            compact ? 12 : 13,
            compact ? 10 : 11,
            compact ? 12 : 13,
          ),
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? widget.accent.withValues(alpha: 0.28)
                  : widget.accent.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: _kEvalSelectNavy.withValues(alpha: _pressed ? 0.08 : 0.05),
                blurRadius: _pressed ? 10 : 8,
                offset: Offset(0, _pressed ? 3 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 34 : 36,
                    height: compact ? 34 : 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accent,
                      size: compact ? 18 : 19,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: compact ? 24 : 26,
                    height: compact ? 24 : 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accent.withValues(alpha: 0.92),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: compact ? 13 : 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 11),
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: dashText(TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  color: _kEvalSelectNavy,
                  height: 1.15,
                  letterSpacing: -0.15,
                )),
              ),
              SizedBox(height: compact ? 4 : 5),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    widget.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(TextStyle(
                      fontSize: compact ? 10.5 : 11.5,
                      fontWeight: FontWeight.w500,
                      color: _kEvalSelectNavyMuted,
                      height: 1.35,
                    )),
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

// ── 5. Recent Evaluations ────────────────────────────────────────────────────

const _kEvalRecentWindowDays = 30;
const _kEvalRecentMaxCount = 5;

List<Evaluation> _evaluationsNewestFirst(List<Evaluation> all) {
  final copy = [...all];
  copy.sort((a, b) {
    final ad = a.evaluatedAt;
    final bd = b.evaluatedAt;
    if (ad != null && bd != null) return bd.compareTo(ad);
    if (ad != null) return -1;
    if (bd != null) return 1;
    return 0;
  });
  return copy;
}

List<Evaluation> _pickRecentEvaluations(List<Evaluation> evaluations) {
  if (evaluations.isEmpty) return const [];

  final sorted = _evaluationsNewestFirst(evaluations);
  final today = DateTime.now();
  final cutoff = DateTime(today.year, today.month, today.day)
      .subtract(const Duration(days: _kEvalRecentWindowDays));

  final recent = <Evaluation>[];
  for (final ev in sorted) {
    if (recent.length >= _kEvalRecentMaxCount) break;
    final date = ev.evaluatedAt;
    if (date == null) continue;
    final day = DateTime(date.year, date.month, date.day);
    if (!day.isBefore(cutoff)) {
      recent.add(ev);
    }
  }
  return recent;
}

class _PendingPracticeAnalysisBanner extends StatelessWidget {
  const _PendingPracticeAnalysisBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? '1 upload is still being analyzed'
        : '$count uploads are still being analyzed';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        8,
        kMemberDashboardPagePadding,
        0,
      ),
      child: Material(
        color: kEvalPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => memberDataController.refreshEvaluationsTab(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: kEvalPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: evalCardTitleStyle.copyWith(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        'Pull to refresh or wait for a notification when scoring finishes.',
                        style: memberDashboardMetaStyle.copyWith(fontSize: 11, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.refresh_rounded, size: 20, color: kEvalPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EvaluationsCompactEmpty extends StatelessWidget {
  const _EvaluationsCompactEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kEvalPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.photo_library_outlined, size: 20, color: kEvalPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No evaluations yet',
                  style: evalCardTitleStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Run your first practice photo or video above. Results and admin review status show up here.',
                  style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _AllEvalMediaFilter { all, photos, videos }

enum _AllEvalStatusTab { pending, verified }

/// Pending Verification tab: awaiting admin review, score hold, or re-upload.
bool _isPendingVerificationEval(Evaluation e) {
  if (MemberReviewStatus.isAdminVerified(e.reviewStatus)) return false;
  if (MemberReviewStatus.isReviewPending(e.reviewStatus)) return true;
  if (MemberReviewStatus.isReuploadRequested(e.reviewStatus)) return true;
  if (e.isPending) return true;
  return false;
}

bool _isVerifiedEval(Evaluation e) => !_isPendingVerificationEval(e);

class _RecentEvaluationsSection extends StatefulWidget {
  const _RecentEvaluationsSection({
    required this.evaluations,
    required this.onTap,
  });

  final List<Evaluation> evaluations;
  final ValueChanged<Evaluation> onTap;

  @override
  State<_RecentEvaluationsSection> createState() =>
      _RecentEvaluationsSectionState();
}

class _RecentEvaluationsSectionState extends State<_RecentEvaluationsSection> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  _AllEvalMediaFilter _filter = _AllEvalMediaFilter.all;
  _AllEvalStatusTab _statusTab = _AllEvalStatusTab.pending;
  String? _openSwipeEvalId;
  bool _verifiedDeleteBusy = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Evaluation> get _allSorted =>
      _evaluationsNewestFirst(widget.evaluations);

  List<Evaluation> get _pendingSorted =>
      _allSorted.where(_isPendingVerificationEval).toList();

  List<Evaluation> get _verifiedSorted =>
      _allSorted.where(_isVerifiedEval).toList();

  List<Evaluation> get _tabSorted => switch (_statusTab) {
        _AllEvalStatusTab.pending => _pendingSorted,
        _AllEvalStatusTab.verified => _verifiedSorted,
      };

  List<Evaluation> get _filteredTab {
    var list = _tabSorted;
    switch (_filter) {
      case _AllEvalMediaFilter.photos:
        list = list.where((e) => e.mediaType != 'video').toList();
      case _AllEvalMediaFilter.videos:
        list = list.where((e) => e.mediaType == 'video').toList();
      case _AllEvalMediaFilter.all:
        break;
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((e) {
      final title = e.title.toLowerCase();
      final date = e.date.toLowerCase();
      final quality = qualityDisplayBucket(e.qualityLevel).toLowerCase();
      final integrity = _integrityTierFor(e).toLowerCase();
      return title.contains(q) ||
          date.contains(q) ||
          quality.contains(q) ||
          integrity.contains(q);
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final recent = _pickRecentEvaluations(widget.evaluations);
    final showRecentRow = recent.isNotEmpty;
    final pendingCount = _pendingSorted.length;
    final verifiedCount = _verifiedSorted.length;
    final filtered = _filteredTab;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final allowRemoveOnTab = _statusTab == _AllEvalStatusTab.pending;
    final tabCount = _statusTab == _AllEvalStatusTab.pending
        ? pendingCount
        : verifiedCount;
    final tabCountLabel = _statusTab == _AllEvalStatusTab.pending
        ? '$tabCount pending'
        : '$tabCount verified';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kMemberDashboardPagePadding,
        kMemberDashboardSectionGap,
        kMemberDashboardPagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.evaluations.isEmpty) ...[
            Text('Recent Evaluations', style: evalSectionTitleStyle),
            const SizedBox(height: 8),
            const _EvaluationsCompactEmpty(),
          ] else ...[
            if (showRecentRow) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent Evaluations', style: evalSectionTitleStyle),
                        const SizedBox(height: 4),
                        Text(
                          'Last $_kEvalRecentWindowDays days · swipe for more',
                          style: evalSectionSubtitleStyle,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${recent.length} new',
                    style: memberDashboardMetaStyle.copyWith(
                      color: kEvalSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RecentEvalCoverFlow(
                evaluations: recent,
                onTap: widget.onTap,
              ),
              const SizedBox(height: 20),
            ],
            Text('All Evaluations', style: evalSectionTitleStyle),
            const SizedBox(height: 4),
            Text(tabCountLabel, style: evalSectionSubtitleStyle),
            const SizedBox(height: 12),
            _AllEvalStatusSegmentedControl(
              selected: _statusTab,
              pendingCount: pendingCount,
              verifiedCount: verifiedCount,
              compact: compact,
              onSelected: (tab) => setState(() {
                _statusTab = tab;
                _openSwipeEvalId = null;
              }),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: SizedBox(
                height: compact ? 42 : 44,
                child: Row(
                  children: [
                    Expanded(
                      child: _AllEvalSearchField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        hasQuery: _searchQuery.trim().isNotEmpty,
                        compact: compact,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        onClear: _clearSearch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AllEvalFilterButton(
                      selected: _filter,
                      compact: compact,
                      onSelected: (f) => setState(() => _filter = f),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              _AllEvalSearchEmpty(
                hasQuery: _searchQuery.trim().isNotEmpty ||
                    _filter != _AllEvalMediaFilter.all,
                statusTab: _statusTab,
              )
            else
              ...filtered.asMap().entries.map(
                    (entry) {
                      final ev = entry.value;
                      final card = _RecentEvalCard(
                        ev: ev,
                        onTap: () {
                          if (_statusTab == _AllEvalStatusTab.verified &&
                              _openSwipeEvalId == ev.id) {
                            setState(() => _openSwipeEvalId = null);
                            return;
                          }
                          widget.onTap(ev);
                        },
                        showRemoveAction: allowRemoveOnTab &&
                            ev.canRemovePracticeStorage,
                      );
                      final body = _statusTab == _AllEvalStatusTab.verified &&
                              ev.canRemovePracticeStorage
                          ? VerifiedEvalSwipeTile(
                              key: ValueKey('verified-swipe-${ev.id}'),
                              isOpen: _openSwipeEvalId == ev.id,
                              onOpenChanged: (open) {
                                setState(() {
                                  _openSwipeEvalId = open ? ev.id : null;
                                });
                              },
                              onDeletePressed: () {
                                unawaited(_onVerifiedSwipeDelete(ev));
                              },
                              child: card,
                            )
                          : card;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key < filtered.length - 1 ? 8 : 0,
                        ),
                        child: body,
                      );
                    },
                  ),
          ],
        ],
      ),
    );
  }

  Future<void> _onVerifiedSwipeDelete(Evaluation ev) async {
    final removed = await confirmVerifiedEvaluationDelete(
      context,
      evaluation: ev,
      isBusy: () => _verifiedDeleteBusy,
      setBusy: () => setState(() => _verifiedDeleteBusy = true),
      clearBusy: () {
        if (mounted) setState(() => _verifiedDeleteBusy = false);
      },
    );
    if (!mounted) return;
    setState(() => _openSwipeEvalId = null);
    if (removed) {
      // Storage remove keeps the evaluation row; refresh so UI matches server.
      await memberDataController.refreshEvaluationsTab();
    }
  }
}

class _AllEvalStatusSegmentedControl extends StatelessWidget {
  const _AllEvalStatusSegmentedControl({
    required this.selected,
    required this.pendingCount,
    required this.verifiedCount,
    required this.onSelected,
    this.compact = false,
  });

  final _AllEvalStatusTab selected;
  final int pendingCount;
  final int verifiedCount;
  final ValueChanged<_AllEvalStatusTab> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 40.0 : 44.0;
    final pendingSelected = selected == _AllEvalStatusTab.pending;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6FC),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: kBorder.withValues(alpha: 0.85)),
      ),
      padding: const EdgeInsets.all(3),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: pendingSelected
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular((height - 6) / 2),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _AllEvalStatusSegment(
                  label: compact ? 'Pending' : 'Pending Verification',
                  count: pendingCount,
                  selected: pendingSelected,
                  compact: compact,
                  onTap: () => onSelected(_AllEvalStatusTab.pending),
                ),
              ),
              Expanded(
                child: _AllEvalStatusSegment(
                  label: 'Verified',
                  count: verifiedCount,
                  selected: !pendingSelected,
                  compact: compact,
                  onTap: () => onSelected(_AllEvalStatusTab.verified),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllEvalStatusSegment extends StatelessWidget {
  const _AllEvalStatusSegment({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : kTextPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: dashText(TextStyle(
                      color: color,
                      fontSize: compact ? 11.5 : 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    )),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : kAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: dashText(TextStyle(
                        color: color,
                        fontSize: compact ? 10.5 : 11,
                        fontWeight: FontWeight.w800,
                      )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllEvalSearchField extends StatelessWidget {
  const _AllEvalSearchField({
    required this.controller,
    required this.focusNode,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: false,
      style: dashText(TextStyle(
        fontSize: compact ? 13 : 14,
        color: kTextPrimary,
        fontWeight: FontWeight.w500,
      )),
      decoration: InputDecoration(
        hintText: 'Search evaluations...',
        hintStyle: dashText(TextStyle(
          fontSize: compact ? 13 : 14,
          color: kTextSecondary,
          fontWeight: FontWeight.w500,
        )),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: kEvalPrimary.withValues(alpha: 0.9),
          size: compact ? 20 : 22,
        ),
        suffixIcon: hasQuery
            ? IconButton(
                onPressed: onClear,
                tooltip: 'Clear search',
                icon: Icon(
                  Icons.close_rounded,
                  color: kEvalPrimary.withValues(alpha: 0.75),
                  size: compact ? 20 : 22,
                ),
              )
            : null,
        filled: true,
        fillColor: kSurface,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: compact ? 10 : 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: kEvalPrimary.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _AllEvalFilterButton extends StatelessWidget {
  const _AllEvalFilterButton({
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final _AllEvalMediaFilter selected;
  final ValueChanged<_AllEvalMediaFilter> onSelected;
  final bool compact;

  String get _label => switch (selected) {
        _AllEvalMediaFilter.all => 'All',
        _AllEvalMediaFilter.photos => 'Photos',
        _AllEvalMediaFilter.videos => 'Videos',
      };

  @override
  Widget build(BuildContext context) {
    final active = selected != _AllEvalMediaFilter.all;
    return PopupMenuButton<_AllEvalMediaFilter>(
      tooltip: 'Filter evaluations',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _AllEvalMediaFilter.all,
          child: Text('All'),
        ),
        PopupMenuItem(
          value: _AllEvalMediaFilter.photos,
          child: Text('Photos'),
        ),
        PopupMenuItem(
          value: _AllEvalMediaFilter.videos,
          child: Text('Videos'),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? kEvalPrimary.withValues(alpha: 0.10) : kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? kEvalPrimary.withValues(alpha: 0.35)
                : kBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: compact ? 18 : 19,
              color: active ? kEvalPrimary : kTextSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: dashText(TextStyle(
                fontSize: compact ? 12.5 : 13,
                fontWeight: FontWeight.w700,
                color: active ? kEvalPrimary : kTextPrimary,
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllEvalSearchEmpty extends StatelessWidget {
  const _AllEvalSearchEmpty({
    required this.hasQuery,
    required this.statusTab,
  });

  final bool hasQuery;
  final _AllEvalStatusTab statusTab;

  @override
  Widget build(BuildContext context) {
    final emptyTab = statusTab == _AllEvalStatusTab.pending
        ? 'No pending verification evaluations.'
        : 'No verified evaluations yet.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        hasQuery
            ? 'No evaluations match your search or filter.'
            : emptyTab,
        style: memberDashboardMetaStyle.copyWith(fontSize: 12.5, height: 1.35),
      ),
    );
  }
}

/// Center-focused Recent Evaluations cover-flow carousel.
class _RecentEvalCoverFlow extends StatefulWidget {
  const _RecentEvalCoverFlow({
    required this.evaluations,
    required this.onTap,
  });

  final List<Evaluation> evaluations;
  final ValueChanged<Evaluation> onTap;

  @override
  State<_RecentEvalCoverFlow> createState() => _RecentEvalCoverFlowState();
}

class _RecentEvalCoverFlowState extends State<_RecentEvalCoverFlow> {
  static const _viewportFraction = 0.82;
  static const _centerScale = 1.0;
  static const _sideScale = 0.90;
  static const _sideOpacity = 0.80;

  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: _viewportFraction);
    _controller.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPageScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (!_controller.hasClients || !_controller.position.haveDimensions) {
      return;
    }
    final next = _controller.page ?? 0;
    if ((next - _page).abs() < 0.001) return;
    setState(() => _page = next);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final height = narrow ? 196.0 : 208.0;

    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.evaluations.length,
        padEnds: true,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final ev = widget.evaluations[index];
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final page = _controller.hasClients &&
                      _controller.position.haveDimensions
                  ? (_controller.page ?? _page)
                  : _page;
              final dist = (page - index).abs().clamp(0.0, 1.0);
              final scale =
                  _centerScale - ((_centerScale - _sideScale) * dist);
              final opacity =
                  1.0 - ((1.0 - _sideOpacity) * dist);

              return Center(
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                  child: Opacity(
                    opacity: opacity,
                    child: child,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: _RecentEvalHorizontalCard(
                ev: ev,
                onTap: () => widget.onTap(ev),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecentEvalHorizontalCard extends StatelessWidget {
  const _RecentEvalHorizontalCard({
    required this.ev,
    required this.onTap,
  });

  final Evaluation ev;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = ev.displayPercent;
    final bucket = qualityDisplayBucket(ev.qualityLevel);
    final accent = qualityBucketColor(bucket);

    return MemberDashboardTapScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: _EvalMediaPreview(ev: ev, accent: accent, height: 208),
            ),
            if (ev.mediaType == 'video')
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded,
                          color: Colors.white, size: 12),
                      SizedBox(width: 3),
                      Text(
                        'Video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (ev.canRemovePracticeStorage)
              Positioned(
                top: 4,
                left: 4,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: _PracticeEvalOverflowMenu(evaluation: ev),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RecentEvalBottomStrip(
                title: ev.title,
                percent: pct,
                pending: ev.isPending,
                processing: ev.isAnalysisInProgress,
                qualityLabel: bucket,
                qualityColor: accent,
                integrityLabel: _integrityTierFor(ev),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact bottom info strip over the thumbnail (no frosted panel).
class _RecentEvalBottomStrip extends StatelessWidget {
  const _RecentEvalBottomStrip({
    required this.title,
    required this.percent,
    required this.pending,
    required this.processing,
    required this.qualityLabel,
    required this.qualityColor,
    required this.integrityLabel,
  });

  final String title;
  final int percent;
  final bool pending;
  final bool processing;
  final String qualityLabel;
  final Color qualityColor;
  final String integrityLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.72),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 18, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    )),
                  ),
                  const SizedBox(height: 4),
                  _EvaluationResultPills(
                    qualityLabel: qualityLabel,
                    qualityColor: qualityColor,
                    integrityLabel: integrityLabel,
                    compact: true,
                    onDark: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _ScoreBadge(
              percent: percent,
              pending: pending,
              processing: processing,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _EvalMediaPreview extends StatelessWidget {
  const _EvalMediaPreview({
    required this.ev,
    required this.accent,
    required this.height,
  });

  final Evaluation ev;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : height;
        final w = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        return IgnorePointer(
          child: EvaluationMediaThumbnail(
            imageUrl: ev.imageUrl,
            mediaType: ev.mediaType,
            memoryBytes: ev.images.isNotEmpty ? ev.images.first : null,
            width: w,
            height: h,
            fallbackIconColor: accent,
            fallbackIconSize: 36,
            storageRemoved: ev.storageRemoved,
          ),
        );
      },
    );
  }
}

class _RecentEvalCard extends StatelessWidget {
  const _RecentEvalCard({
    required this.ev,
    required this.onTap,
    this.showRemoveAction = true,
  });

  final Evaluation ev;
  final VoidCallback onTap;
  final bool showRemoveAction;

  Color _tintFor(String bucket) => switch (bucket) {
        'Excellent' => kGreenDim,
        'Good' => kCyanDim,
        _ => kYellowDim,
      };

  @override
  Widget build(BuildContext context) {
    final pct = ev.displayPercent;
    final bucket = qualityDisplayBucket(ev.qualityLevel);
    final accent = qualityBucketColor(bucket);
    final tint = _tintFor(bucket);

    return MemberDashboardTapScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
        child: Row(
          children: [
            _EvalThumbnail(ev: ev, accent: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ev.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: evalCardTitleStyle.copyWith(fontSize: 14, height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ev.date,
                    style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  _EvaluationResultPills(
                    qualityLabel: bucket,
                    qualityColor: accent,
                    integrityLabel: _integrityTierFor(ev),
                  ),
                  if (MemberReviewStatus.isReuploadRequested(ev.reviewStatus)) ...[
                    const SizedBox(height: 6),
                    AdminReviewStatusBadge(reviewStatus: ev.reviewStatus!, compact: true),
                  ],
                  if (showRemoveAction && ev.canRemovePracticeStorage) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _PracticeEvalOverflowMenu(evaluation: ev),
                    ),
                  ],
                ],
              ),
            ),
            _ScoreBadge(
              percent: pct,
              pending: ev.isPending,
              processing: ev.isAnalysisInProgress,
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeEvalOverflowMenu extends StatelessWidget {
  const _PracticeEvalOverflowMenu({required this.evaluation});

  final Evaluation evaluation;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      padding: EdgeInsets.zero,
      splashRadius: 18,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: kDashTextSecondary.withValues(alpha: 0.75),
      ),
      onSelected: (value) {
        if (value == 'remove') {
          unawaited(confirmAndRemovePracticeStorage(context, evaluation: evaluation));
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'remove',
          child: Text('Remove file (keep score)'),
        ),
      ],
    );
  }
}

String _integrityTierFor(Evaluation ev) {
  if (MemberReviewStatus.isReuploadRequested(ev.reviewStatus)) {
    return 'Re-upload Required';
  }
  final ai = ev.parsedEvaluation?.aiDetection;
  if (ai != null) {
    return memberEvaluationListIntegrityLabel(
      automated: ai,
      adminReviewStatus: ev.reviewStatus,
    );
  }
  if (ev.isUnderAdminReview || ev.isPending) return 'Needs Review';
  return 'Low AI Risk';
}

class _EvaluationResultPills extends StatelessWidget {
  const _EvaluationResultPills({
    required this.qualityLabel,
    required this.qualityColor,
    required this.integrityLabel,
    this.compact = false,
    this.onDark = false,
  });

  final String qualityLabel;
  final Color qualityColor;
  final String integrityLabel;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final integrityColor = memberIntegrityTierColor(integrityLabel);
    return Wrap(
      spacing: compact ? 4 : 5,
      runSpacing: compact ? 3 : 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _QualityPill(
          label: qualityLabel,
          color: qualityColor,
          compact: compact,
          onDark: onDark,
        ),
        _IntegrityTierPill(
          label: integrityLabel,
          color: integrityColor,
          compact: compact,
          onDark: onDark,
        ),
      ],
    );
  }
}

class _IntegrityTierPill extends StatelessWidget {
  const _IntegrityTierPill({
    required this.label,
    required this.color,
    this.compact = false,
    this.onDark = false,
  });

  final String label;
  final Color color;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.16)
            : kSurface.withValues(alpha: compact ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.28)
              : color.withValues(alpha: 0.32),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onDark ? Colors.white : color,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QualityPill extends StatelessWidget {
  const _QualityPill({
    required this.label,
    required this.color,
    this.compact = false,
    this.onDark = false,
  });

  final String label;
  final Color color;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.16)
            : kSurface.withValues(alpha: compact ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onDark
              ? color.withValues(alpha: 0.75)
              : color.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onDark ? Colors.white : color,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EvalThumbnail extends StatelessWidget {
  const _EvalThumbnail({required this.ev, required this.accent});

  final Evaluation ev;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    final radius = BorderRadius.circular(11);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: IgnorePointer(
          child: EvaluationMediaThumbnail(
            imageUrl: ev.imageUrl,
            mediaType: ev.mediaType,
            memoryBytes: ev.images.isNotEmpty ? ev.images.first : null,
            width: size,
            height: size,
            fallbackIconColor: accent,
            fallbackIconSize: 22,
            storageRemoved: ev.storageRemoved,
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.percent,
    required this.pending,
    this.processing = false,
    this.compact = false,
  });

  final int percent;
  final bool pending;
  final bool processing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 42.0;
    final fontSize = compact ? 12.0 : 14.0;
    final iconSize = compact ? 15.0 : 18.0;

    if (processing) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 4 : 5),
        decoration: BoxDecoration(
          color: kSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(compact ? 9 : 11),
          border: Border.all(color: kAccent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                'Analyzing',
                style: TextStyle(color: kAccent, fontSize: fontSize - 2, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      );
    }

    if (pending) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: kSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(compact ? 9 : 11),
          border: Border.all(color: kEvalPrimary.withValues(alpha: 0.25)),
        ),
        child: Center(
          child: Icon(Icons.hourglass_top_rounded, color: kEvalPrimary, size: iconSize),
        ),
      );
    }

    final color = criterionPercentColor(percent);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(compact ? 9 : 11),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Center(
        child: Text(
          '$percent',
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w900, height: 1),
        ),
      ),
    );
  }
}
