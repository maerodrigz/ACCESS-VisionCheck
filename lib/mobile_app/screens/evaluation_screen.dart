import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/utils/member_integrity_display.dart';
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
import 'package:access_mobile/mobile_app/widgets/eval_ai_chip_illustration.dart';
import 'package:access_mobile/mobile_app/utils/practice_evaluation_display.dart';
import 'package:access_mobile/mobile_app/utils/practice_storage_removal.dart';

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({super.key, this.onNotificationsTap, this.onProfileTap});

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(memberDataController.ensureEvaluationsTab());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kEvalBg,
      child: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (_, __) {
          final loading = memberDataController.evaluationsTabLoading &&
              appState.evaluations.isEmpty;
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

// ── 1. Greeting AI Hero Card ─────────────────────────────────────────────────

class _EvalAiHeroCard extends StatefulWidget {
  const _EvalAiHeroCard();

  @override
  State<_EvalAiHeroCard> createState() => _EvalAiHeroCardState();
}

class _EvalAiHeroCardState extends State<_EvalAiHeroCard> with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
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
        final resetLabel = evaluationDailyLimitResetLabel(appState.evaluationDailyTimezone);
        final quotaConfirmed = appState.evaluationsTodayQuotaConfirmed;
        final quotaSyncing = memberDataController.participationQuotaSyncing;
        final quotaSyncError = memberDataController.participationQuotaSyncError;

        return FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              kMemberDashboardPagePadding,
              8,
              kMemberDashboardPagePadding,
              0,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: kEvalHeroGradient,
                borderRadius: BorderRadius.circular(kEvalHeroRadius),
                boxShadow: evalHeroShadows,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    top: -24,
                    right: -18,
                    child: IgnorePointer(
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: -28,
                    child: IgnorePointer(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Evaluate your media',
                                    style: dashText(const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                      letterSpacing: -0.35,
                                    )),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload photos or videos to check quality and get feedback.',
                                    style: dashText(TextStyle(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.45,
                                    )),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Builder(
                              builder: (context) {
                                final chipSize = MediaQuery.sizeOf(context).width < 360 ? 62.0 : 84.0;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: EvalAiChipIllustration(size: chipSize),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      _EvalHeroDailyFooter(
                        done: done,
                        limit: limit,
                        remaining: remaining,
                        dailyResetLabel: resetLabel,
                        quotaConfirmed: quotaConfirmed,
                        quotaSyncing: quotaSyncing,
                        quotaSyncError: quotaSyncError,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EvalHeroDailyFooter extends StatelessWidget {
  const _EvalHeroDailyFooter({
    required this.done,
    required this.limit,
    required this.remaining,
    required this.dailyResetLabel,
    required this.quotaConfirmed,
    required this.quotaSyncing,
    this.quotaSyncError,
    this.onRetrySync,
  });

  final int done;
  final int limit;
  final int remaining;
  final String dailyResetLabel;
  final bool quotaConfirmed;
  final bool quotaSyncing;
  final String? quotaSyncError;
  final VoidCallback? onRetrySync;

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
        ? 'Syncing quota…'
        : (quotaSyncError != null
            ? 'Tap to sync quota'
            : (atLimit ? 'Limit reached' : (quotaConfirmed ? '$remaining left' : 'Sync quota')));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: quotaSyncError != null && !quotaSyncing ? onRetrySync : null,
        child: Container(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.14))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            atLimit ? Icons.hourglass_disabled_rounded : Icons.speed_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice evaluations today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  )),
                ),
                const SizedBox(height: 2),
                Text(
                  'Resets at midnight ($dailyResetLabel)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dashText(TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  )),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        atLimit
                            ? const Color(0xFFFCA5A5)
                            : (low ? const Color(0xFFFDE68A) : Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Column(
              children: [
                if (quotaSyncing)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  )
                else
                  Text(
                    countLabel,
                    style: dashText(const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    )),
                  ),
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  style: dashText(TextStyle(
                    color: atLimit
                        ? const Color(0xFFFCA5A5)
                        : (quotaSyncError != null
                            ? const Color(0xFFFDE68A)
                            : (low
                                ? const Color(0xFFFDE68A)
                                : Colors.white.withValues(alpha: 0.88))),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  )),
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

// ── 2. Evaluation Options ────────────────────────────────────────────────────

class _EvalOptionsSection extends StatelessWidget {
  const _EvalOptionsSection({required this.onPhoto, required this.onVideo});

  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
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
          Text('What would you like to evaluate?', style: evalSectionTitleStyle.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Expanded(
                child: _EvalSelectionCard(
                  icon: Icons.photo_camera_rounded,
                  title: 'Photo',
                  description: 'Quality analysis & feedback',
                  accent: kMemberCyan,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kCyanDim,
                      Color(0xFFF0FAFF),
                      kSurface,
                    ],
                  ),
                  onTap: onPhoto,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EvalSelectionCard(
                  icon: Icons.videocam_rounded,
                  title: 'Video',
                  description: 'Quality analysis & feedback',
                  accent: kMemberPrimary,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kBlueDim,
                      Color(0xFFF0F6FF),
                      kSurface,
                    ],
                  ),
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
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  State<_EvalSelectionCard> createState() => _EvalSelectionCardState();
}

class _EvalSelectionCardState extends State<_EvalSelectionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed
                ? widget.accent.withValues(alpha: 0.45)
                : widget.accent.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.08 : 0.05),
              blurRadius: _pressed ? 12 : 8,
              offset: Offset(0, _pressed ? 4 : 2),
            ),
            BoxShadow(
              color: widget.accent.withValues(alpha: _pressed ? 0.12 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
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
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: widget.accent.withValues(alpha: 0.28)),
                  ),
                  child: Icon(widget.icon, color: widget.accent, size: 21),
                ),
                const Spacer(),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accent,
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              widget.title,
              style: dashText(TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: widget.accent,
                height: 1.1,
              )),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  widget.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardMetaStyle.copyWith(fontSize: 11, height: 1.35),
                ),
              ),
            ),
          ],
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

List<Evaluation> _evaluationsExcluding(
  List<Evaluation> all,
  Iterable<Evaluation> exclude,
) {
  final ids = exclude.map((e) => e.id).toSet();
  if (ids.isEmpty) return _evaluationsNewestFirst(all);
  return _evaluationsNewestFirst(all.where((e) => !ids.contains(e.id)).toList());
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

class _RecentEvaluationsSection extends StatelessWidget {
  const _RecentEvaluationsSection({
    required this.evaluations,
    required this.onTap,
  });

  final List<Evaluation> evaluations;
  final ValueChanged<Evaluation> onTap;

  @override
  Widget build(BuildContext context) {
    final recent = _pickRecentEvaluations(evaluations);
    final catalog = _evaluationsExcluding(evaluations, recent);
    final showRecentRow = recent.isNotEmpty;
    final showCatalog = catalog.isNotEmpty;

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
          if (evaluations.isEmpty) ...[
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
              SizedBox(
                height: 206,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final ev = recent[index];
                    return Align(
                      alignment: Alignment.topCenter,
                      child: _RecentEvalHorizontalCard(
                        ev: ev,
                        onTap: () => onTap(ev),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (showCatalog) ...[
              SizedBox(height: showRecentRow ? 20 : 0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showRecentRow ? 'All Evaluations' : 'Recent Evaluations',
                          style: evalSectionTitleStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${catalog.length} submission${catalog.length == 1 ? '' : 's'}',
                          style: evalSectionSubtitleStyle,
                        ),
                      ],
                    ),
                  ),
                  if (!showRecentRow && evaluations.isNotEmpty)
                    TextButton(
                      onPressed: () => onTap(_evaluationsNewestFirst(evaluations).first),
                      style: TextButton.styleFrom(foregroundColor: kEvalSecondary),
                      child: Text(
                        'Latest',
                        style: dashText(const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...catalog.asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(bottom: entry.key < catalog.length - 1 ? 8 : 0),
                      child: _RecentEvalCard(ev: entry.value, onTap: () => onTap(entry.value)),
                    ),
                  ),
            ] else if (showRecentRow)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  'All evaluations from the last 30 days are shown above.',
                  style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.4),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecentEvalHorizontalCard extends StatelessWidget {
  const _RecentEvalHorizontalCard({
    required this.ev,
    required this.onTap,
  });

  static const _cardWidth = 188.0;

  final Evaluation ev;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = ev.displayPercent;
    final bucket = qualityDisplayBucket(ev.qualityLevel);
    final accent = qualityBucketColor(bucket);

    return SizedBox(
      width: _cardWidth,
      child: MemberDashboardTapScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 132,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _EvalMediaPreview(ev: ev, accent: accent, height: 132),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (ev.mediaType == 'video')
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
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
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _ScoreBadge(
                        percent: pct,
                        pending: ev.isPending,
                        processing: ev.isAnalysisInProgress,
                        compact: true,
                      ),
                    ),
                    if (ev.canRemovePracticeStorage)
                      Positioned(
                        right: 4,
                        bottom: 6,
                        child: _PracticeEvalOverflowMenu(evaluation: ev),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: evalCardTitleStyle.copyWith(fontSize: 12.5, height: 1.15),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.swipe_rounded, size: 11, color: kEvalSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            ev.date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: memberDashboardMetaStyle.copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _EvaluationResultPills(
                      qualityLabel: bucket,
                      qualityColor: accent,
                      integrityLabel: _integrityTierFor(ev),
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
    return EvaluationMediaThumbnail(
      imageUrl: ev.imageUrl,
      mediaType: ev.mediaType,
      memoryBytes: ev.images.isNotEmpty ? ev.images.first : null,
      height: height,
      fallbackIconColor: accent,
      fallbackIconSize: 36,
      storageRemoved: ev.storageRemoved,
    );
  }
}

class _RecentEvalCard extends StatelessWidget {
  const _RecentEvalCard({required this.ev, required this.onTap});

  final Evaluation ev;
  final VoidCallback onTap;

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
                  if (ev.canRemovePracticeStorage) ...[
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
            Icon(Icons.chevron_right_rounded, size: 20, color: kDashTextSecondary.withValues(alpha: 0.55)),
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
  });

  final String qualityLabel;
  final Color qualityColor;
  final String integrityLabel;

  @override
  Widget build(BuildContext context) {
    final integrityColor = memberIntegrityTierColor(integrityLabel);
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _QualityPill(label: qualityLabel, color: qualityColor),
        _IntegrityTierPill(label: integrityLabel, color: integrityColor),
      ],
    );
  }
}

class _IntegrityTierPill extends StatelessWidget {
  const _IntegrityTierPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _QualityPill extends StatelessWidget {
  const _QualityPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
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
