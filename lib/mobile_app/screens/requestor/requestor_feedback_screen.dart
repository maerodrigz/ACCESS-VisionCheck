import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/requestor/requestor_feedback_status.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/member_team_rating_section.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_feature_purpose.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_feedback_header.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_list_skeleton.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';

const _kRequestorFeedbackTypes = [
  _FeedbackTypeOption(
    label: 'Documentation quality',
    subtitle: 'Photo and video clarity, framing, and editing',
    icon: Icons.photo_camera_rounded,
    accentColor: kAccent,
  ),
  _FeedbackTypeOption(
    label: 'Coverage completeness',
    subtitle: 'Key moments, angles, and deliverables covered',
    icon: Icons.checklist_rounded,
    accentColor: kGreen,
  ),
  _FeedbackTypeOption(
    label: 'Team responsiveness',
    subtitle: 'Communication, timeliness, and coordination',
    icon: Icons.groups_rounded,
    accentColor: kCyan,
  ),
  _FeedbackTypeOption(
    label: 'Suggestion',
    subtitle: 'Ideas to improve future documentation',
    icon: Icons.lightbulb_outline_rounded,
    accentColor: kYellow,
  ),
  _FeedbackTypeOption(
    label: 'Other',
    subtitle: 'General comments not listed above',
    icon: Icons.chat_bubble_outline_rounded,
    accentColor: kAccent,
  ),
];

class _FeedbackTypeOption {
  const _FeedbackTypeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  String get messageHint => switch (label) {
        'Documentation quality' =>
          'How was the photo and video quality for your event?',
        'Coverage completeness' =>
          'Did the team capture the important moments and deliverables?',
        'Team responsiveness' =>
          'How was communication and coordination with the ACCESS team?',
        'Suggestion' => 'What would you like us to improve next time?',
        _ => 'Share any other thoughts about the documentation service.',
      };

  static IconData iconForLabel(String label) {
    for (final opt in _kRequestorFeedbackTypes) {
      if (opt.label == label) return opt.icon;
    }
    return Icons.label_outline_rounded;
  }
}

/// Requestor feedback — rate documentation coverage for approved events.
class RequestorFeedbackScreen extends StatefulWidget {
  const RequestorFeedbackScreen({
    super.key,
    this.initialRequestId,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  /// Pre-select a documentation request when opened from request details.
  final int? initialRequestId;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  State<RequestorFeedbackScreen> createState() => _RequestorFeedbackScreenState();
}

class _RequestorFeedbackScreenState extends State<RequestorFeedbackScreen> {
  final _msgCtrl = TextEditingController();
  String _type = 'Documentation quality';
  String? _selectedKey;
  int _rating = 0;
  bool _sent = false;
  bool _submitting = false;
  List<Map<String, dynamic>> _memberRatingsMine = [];

  @override
  void initState() {
    super.initState();
    _applyInitialSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void didUpdateWidget(covariant RequestorFeedbackScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRequestId != widget.initialRequestId) {
      _applyInitialSelection();
    }
  }

  void _applyInitialSelection() {
    final completion = memberDataController.requestorFeedbackCompletion;
    final id = widget.initialRequestId;
    if (id != null) {
      final match = _rateableRequests(appState.serviceRequests)
          .where((r) => r.requestId == id)
          .firstOrNull;
      if (match != null) {
        _selectedKey = _requestKey(match);
        return;
      }
    }
    if (_selectedKey != null) return;
    final firstOpen = _rateableRequests(appState.serviceRequests)
        .where((r) => completion.pending(r))
        .firstOrNull;
    if (firstOpen != null) {
      _selectedKey = _requestKey(firstOpen);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await memberDataController.refreshAll();
    try {
      final rows = await memberApiService.getMemberRatings();
      if (!mounted) return;
      setState(() {
        _memberRatingsMine = rows;
        _applyInitialSelection();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _memberRatingsMine = [];
        _applyInitialSelection();
      });
    }
  }

  List<ServiceRequest> _rateableRequests(List<ServiceRequest> all) {
    return all
        .where(
          (r) => r.requestId != null && r.requestStatus == RequestStatus.completed,
        )
        .toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
  }

  String _requestKey(ServiceRequest r) => '${r.requestId}|${r.eventName}';

  ServiceRequest? _requestFromKey(String? key) {
    if (key == null) return null;
    final id = int.tryParse(key.split('|').first);
    if (id == null) return null;
    return appState.serviceRequests.where((r) => r.requestId == id).firstOrNull;
  }

  (String type, String message) _parseComment(String raw) {
    final comment = raw.trim();
    final match = RegExp(r'^([^:]+):\s*(.+)$', dotAll: true).firstMatch(comment);
    if (match != null) {
      return (match.group(1)!.trim(), match.group(2)!.trim());
    }
    return ('Feedback', comment);
  }

  List<_TeamRatingGroup> _groupMemberRatingsByRequest(List<Map<String, dynamic>> rows) {
    final byRequest = <int, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final rid = (row['request_id'] as num?)?.toInt();
      if (rid == null) continue;
      byRequest.putIfAbsent(rid, () => []).add(row);
    }
    final groups = <_TeamRatingGroup>[];
    for (final entry in byRequest.entries) {
      final requestId = entry.key;
      final eventTitle = entry.value.first['event_title'] as String? ??
          appState.serviceRequests
              .where((r) => r.requestId == requestId)
              .map((r) => r.eventName)
              .firstOrNull ??
          'Request #$requestId';
      String? dateLabel;
      for (final row in entry.value) {
        final raw = row['created_at'] as String?;
        if (raw != null && raw.isNotEmpty) {
          dateLabel = _formatRatingDate(raw);
          break;
        }
      }
      groups.add(_TeamRatingGroup(
        requestId: requestId,
        eventTitle: eventTitle,
        dateLabel: dateLabel,
        rows: entry.value,
      ));
    }
    groups.sort((a, b) => b.requestId.compareTo(a.requestId));
    return groups;
  }

  String _formatRatingDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  EventFeedback _displayFeedback(EventFeedback fb) {
    final parsed = _parseComment(fb.message);
    final type = fb.type != 'Service rating' ? fb.type : parsed.$1;
    final message = fb.type != 'Service rating' ? fb.message : parsed.$2;

    var title = fb.eventTitle;
    if (title.startsWith('Request #')) {
      final id = int.tryParse(title.replaceFirst('Request #', ''));
      if (id != null) {
        title = appState.serviceRequests
                .where((r) => r.requestId == id)
                .map((r) => r.eventName)
                .firstOrNull ??
            title;
      }
    }
    return EventFeedback(
      eventTitle: title,
      type: type,
      message: message,
      rating: fb.rating,
      date: fb.date,
      requestId: fb.requestId,
      adminResponse: fb.adminResponse,
      reviewStatus: fb.reviewStatus,
    );
  }


  void _reset() {
    _msgCtrl.clear();
    setState(() {
      _sent = false;
      _selectedKey = null;
      _rating = 0;
      _type = 'Documentation quality';
      _applyInitialSelection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RequestorBrandAppBar(
            onNotifications: widget.onNotificationsTap,
            onProfileTap: widget.onProfileTap,
          ),
          Expanded(
            child: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (context, _) {
          final rateable = _rateableRequests(appState.serviceRequests);
          final completion = memberDataController.requestorFeedbackCompletion;
          final past = appState.feedbacks.map(_displayFeedback).toList();
          final teamRatingGroups = _groupMemberRatingsByRequest(_memberRatingsMine);
          final selected = _requestFromKey(_selectedKey);
          final selectedRequestId = selected?.requestId ??
              int.tryParse(_selectedKey?.split('|').first ?? '');
          final submittedOverall = selectedRequestId == null
              ? null
              : appState.feedbacks
                  .where((fb) => fb.requestId == selectedRequestId)
                  .firstOrNull;
          final loading = memberDataController.isLoading && appState.serviceRequests.isEmpty;
          final syncing = memberDataController.isLoading && appState.serviceRequests.isNotEmpty;
          final deepLinkMiss = widget.initialRequestId != null &&
              !_sent &&
              rateable.isNotEmpty &&
              selected == null;

          if (loading) {
            return const FeedbackFormSkeleton();
          }

          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return RefreshIndicator(
            color: kMemberPrimary,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                0,
                0,
                0,
                56 + bottomInset,
              ),
              children: [
                const RequestorFeedbackIllustratedHeader(
                  includeTopActions: false,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kMemberDashboardPagePadding,
                    6,
                    kMemberDashboardPagePadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                if (syncing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: kRequestorPrimaryAction,
                      backgroundColor: kBorder,
                    ),
                  ),
                if (_sent) ...[
                  _SuccessBanner(onNew: _reset),
                  const SizedBox(height: 20),
                ] else if (rateable.isEmpty)
                  _NoEventsCard(onRefresh: _reload)
                else ...[
                  if (deepLinkMiss)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DeepLinkMissCard(requestId: widget.initialRequestId!),
                    ),
                  if (widget.initialRequestId != null && selected != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PreselectedEventBanner(eventName: selected.eventName),
                    ),
                  _FeedbackFormCard(
                    msgCtrl: _msgCtrl,
                    type: _type,
                    types: _kRequestorFeedbackTypes,
                    selectedKey: _selectedKey,
                    rating: _rating,
                    submittedOverall: submittedOverall,
                    selectedRequest: selected,
                    rateable: rateable,
                    completion: completion,
                    onTypeChanged: (t) => setState(() => _type = t),
                    onEventChanged: (k) {
                      setState(() {
                        _selectedKey = k;
                        _rating = 0;
                        _type = 'Documentation quality';
                        _msgCtrl.clear();
                      });
                    },
                    onRatingChanged: (r) => setState(() => _rating = r),
                    submitting: _submitting,
                    requestKey: _requestKey,
                    onSubmitted: () async {
                      setState(() => _sent = true);
                      await _reload();
                    },
                    onSubmittingChanged: (v) => setState(() => _submitting = v),
                  ),
                ],
                const SizedBox(height: 16),
                _YourSubmissionsHeader(
                  count: past.length + teamRatingGroups.length,
                ),
                const SizedBox(height: 10),
                if (past.isEmpty && teamRatingGroups.isEmpty)
                  const _SubmissionsEmptyState()
                else ...[
                  ...teamRatingGroups.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PastTeamRatingsCard(group: g),
                    ),
                  ),
                  ...past.map(
                    (fb) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PastFeedbackCard(feedback: fb),
                    ),
                  ),
                ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

const _kHistoryCyan = Color(0xFF079FC6);
const _kHistorySky = Color(0xFFEAF7FC);
const _kHistoryBorder = Color(0xFFD0EBF5);
const _kHistoryStar = Color(0xFFF5B400);
const _kHistoryStarMuted = Color(0xFFB0BEC8);
const _kHistoryNavy = Color(0xFF173650);
const _kHistoryMeta = Color(0xFF617F91);

class _YourSubmissionsHeader extends StatelessWidget {
  const _YourSubmissionsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Your Submissions',
            style: memberDashboardSectionTitleStyle.copyWith(
              fontSize: 16,
              color: _kHistoryNavy,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _kHistorySky,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kHistoryBorder),
          ),
          child: Text(
            '$count',
            style: memberDashboardMetaStyle.copyWith(
              color: _kHistoryCyan,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmissionsEmptyState extends StatelessWidget {
  const _SubmissionsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kHistoryBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 28,
            color: _kHistoryCyan.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 8),
          Text(
            'No feedback submitted yet.',
            textAlign: TextAlign.center,
            style: memberDashboardBodyStyle.copyWith(
              color: _kHistoryMeta,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kGreenDim,
              borderRadius: BorderRadius.circular(kMemberDashboardIconRadius),
            ),
            child: const Icon(Icons.check_circle_rounded, color: kGreen, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Feedback submitted',
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 15, color: kGreen),
                ),
                const SizedBox(height: 2),
                Text(
                  'Thank you. Your rating helps us improve documentation services.',
                  style: memberDashboardMetaStyle,
                ),
              ],
            ),
          ),
          MemberDashboardTextButton(label: 'New', onPressed: onNew),
        ],
      ),
    );
  }
}

class _NoEventsCard extends StatelessWidget {
  const _NoEventsCard({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(kMemberDashboardIconRadius),
                ),
                child: const Icon(Icons.rate_review_outlined, color: kAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nothing to rate yet',
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'After documentation is completed for your event, you can rate the team and share feedback here.',
            style: memberDashboardBodyStyle,
          ),
          const SizedBox(height: 16),
          MemberDashboardPrimaryButton(
            label: 'Refresh',
            icon: Icons.refresh_rounded,
            onPressed: () => onRefresh(),
          ),
          if (RequestorShellNavigation.openRequests != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: RequestorShellNavigation.openRequests,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('View my requests'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRequestorPrimaryAction,
                  side: BorderSide(color: kRequestorPrimaryAction),
                  minimumSize: Size.fromHeight(kMobileMinTouch),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreselectedEventBanner extends StatelessWidget {
  const _PreselectedEventBanner({required this.eventName});

  final String eventName;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, color: kAccent.withValues(alpha: 0.9), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Rating coverage for $eventName',
              style: memberDashboardBodyStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeepLinkMissCard extends StatelessWidget {
  const _DeepLinkMissCard({required this.requestId});

  final int requestId;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: kYellow.withValues(alpha: 0.95), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Request #$requestId is not completed yet, or feedback was already submitted. '
              'Choose a completed event below.',
              style: memberDashboardBodyStyle.copyWith(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackFormCard extends StatefulWidget {
  const _FeedbackFormCard({
    required this.msgCtrl,
    required this.type,
    required this.types,
    required this.selectedKey,
    required this.rating,
    required this.submittedOverall,
    required this.selectedRequest,
    required this.rateable,
    required this.completion,
    required this.onTypeChanged,
    required this.onEventChanged,
    required this.onRatingChanged,
    required this.submitting,
    required this.requestKey,
    required this.onSubmitted,
    required this.onSubmittingChanged,
  });

  final TextEditingController msgCtrl;
  final String type;
  final List<_FeedbackTypeOption> types;
  final String? selectedKey;
  final int rating;
  final EventFeedback? submittedOverall;
  final ServiceRequest? selectedRequest;
  final List<ServiceRequest> rateable;
  final RequestorFeedbackCompletion completion;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String?> onEventChanged;
  final ValueChanged<int> onRatingChanged;
  final bool submitting;
  final String Function(ServiceRequest) requestKey;
  final Future<void> Function() onSubmitted;
  final ValueChanged<bool> onSubmittingChanged;

  @override
  State<_FeedbackFormCard> createState() => _FeedbackFormCardState();
}

class _FeedbackFormCardState extends State<_FeedbackFormCard> {
  List<MemberTeamRatingTarget> _teamTargets = [];
  final Map<int, int> _memberRatings = {};
  final Map<int, TextEditingController> _memberCommentCtrls = {};
  bool _loadingTeam = false;
  int? _loadedRequestId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeamTargets(widget.selectedRequest?.requestId);
    });
  }

  @override
  void dispose() {
    for (final c in _memberCommentCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FeedbackFormCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rid = widget.selectedRequest?.requestId;
    if (rid != _loadedRequestId) {
      _loadTeamTargets(rid);
    }
  }

  Future<void> _loadTeamTargets(int? requestId) async {
    for (final c in _memberCommentCtrls.values) {
      c.dispose();
    }
    _memberCommentCtrls.clear();
    _memberRatings.clear();
    _teamTargets = [];
    _loadedRequestId = requestId;

    if (requestId == null) {
      if (mounted) setState(() => _loadingTeam = false);
      return;
    }

    setState(() => _loadingTeam = true);
    try {
      final rows = await memberApiService.getAssignmentRatingTargets(requestId);
      final targets = rows.map(MemberTeamRatingTarget.fromMap).toList();
      for (final t in targets) {
        _memberCommentCtrls[t.assignmentId] = TextEditingController(text: t.existingComment ?? '');
        if (t.existingRating != null && t.existingRating! > 0) {
          _memberRatings[t.assignmentId] = t.existingRating!;
        }
      }
      if (mounted) {
        setState(() {
          _teamTargets = targets;
          _loadingTeam = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTeam = false);
    }
  }

  Future<void> _submit() async {
    if (widget.submitting) return;
    if (widget.selectedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event'), backgroundColor: kRed),
      );
      return;
    }
    final requestId = widget.selectedRequest?.requestId ??
        int.tryParse(widget.selectedKey!.split('|').first);
    if (requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid event selection'), backgroundColor: kRed),
      );
      return;
    }

    final eventDone = widget.completion.eventDone(requestId);
    final teamDone = widget.completion.teamDone(requestId);
    if (eventDone && teamDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This event is already complete.'),
          backgroundColor: kRed,
        ),
      );
      return;
    }

    final needsTeam = !teamDone && _teamTargets.isNotEmpty;
    if (needsTeam) {
      for (final t in _teamTargets) {
        final stars = _memberRatings[t.assignmentId] ?? 0;
        if (stars == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please rate ${t.memberName} (${t.roleLabel})'),
              backgroundColor: kRed,
            ),
          );
          return;
        }
      }
    }

    final needsEvent = !eventDone;
    final hasOverall = widget.rating > 0;
    if (needsEvent && !hasOverall && !needsTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an overall star rating for this event'),
          backgroundColor: kRed,
        ),
      );
      return;
    }
    if (!needsEvent && !needsTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing left to submit for this event'),
          backgroundColor: kRed,
        ),
      );
      return;
    }

    widget.onSubmittingChanged(true);
    try {
      var didSubmit = false;
      if (needsTeam) {
        await memberApiService.submitMemberRatings(
          requestId: requestId,
          ratings: _teamTargets.map((t) {
            final assignmentId = t.assignmentId;
            return {
              'assignment_id': assignmentId,
              'rating': _memberRatings[assignmentId],
              'comment': _memberCommentCtrls[assignmentId]?.text.trim(),
            };
          }).toList(),
        );
        didSubmit = true;
        await memberDataController.syncRequestorTeamRatingCompletion();
      }
      if (needsEvent && hasOverall) {
        final msg = widget.msgCtrl.text.trim();
        final comment = msg.isEmpty ? widget.type : '${widget.type}: $msg';
        await memberDataController.submitFeedback(
          requestId: requestId,
          rating: widget.rating,
          comment: comment,
        );
        didSubmit = true;
      }
      if (!didSubmit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add team ratings or overall service feedback to submit'),
              backgroundColor: kRed,
            ),
          );
        }
        return;
      }
      await widget.onSubmitted();
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : 'Could not submit feedback. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: kRed),
        );
      }
    } finally {
      widget.onSubmittingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestId = widget.selectedRequest?.requestId ??
        int.tryParse(widget.selectedKey?.split('|').first ?? '');
    final eventDone = requestId != null &&
        (widget.completion.eventDone(requestId) || widget.submittedOverall != null);
    final teamDone = requestId != null && widget.completion.teamDone(requestId);
    final overallRequired = requestId != null && !eventDone && teamDone;
    final lockedParts = widget.submittedOverall == null
        ? null
        : _submittedOverallParts(widget.submittedOverall!);
    final shownRating = eventDone
        ? (widget.submittedOverall?.rating ?? widget.rating)
        : widget.rating;
    final shownType = eventDone ? (lockedParts?.$1 ?? widget.type) : widget.type;
    final lockedMessage = lockedParts?.$2 ?? '';

    return MemberDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate an event', style: memberDashboardCardTitleStyle.copyWith(fontSize: 15)),
          const SizedBox(height: 14),
          Text('Select event', style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _EventPickerList(
            rateable: widget.rateable,
            selectedKey: widget.selectedKey,
            completion: widget.completion,
            requestKey: widget.requestKey,
            onEventChanged: widget.onEventChanged,
          ),
          if (widget.selectedRequest != null) ...[
            const SizedBox(height: 10),
            _SelectedEventPreview(request: widget.selectedRequest!),
            const SizedBox(height: 20),
            MemberTeamRatingSection(
              targets: _teamTargets,
              ratings: _memberRatings,
              commentControllers: _memberCommentCtrls,
              onRatingChanged: (assignmentId, rating) {
                setState(() => _memberRatings[assignmentId] = rating);
              },
              loading: _loadingTeam,
            ),
          ],
          if (widget.selectedRequest == null) ...[
            const SizedBox(height: 16),
            Text(
              'Select an event to rate.',
              style: memberDashboardMetaStyle,
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              eventDone
                  ? 'Overall event feedback'
                  : overallRequired
                      ? 'Overall event feedback'
                      : 'Overall event feedback (optional)',
              style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 3),
            Text(
              eventDone
                  ? 'Locked. This rating was already submitted.'
                  : overallRequired
                      ? 'Required once team ratings are done.'
                      : 'Optional comments about this event.',
              style: memberDashboardMetaStyle.copyWith(
                fontSize: 11,
                color: eventDone ? kTextSecondary : null,
                fontWeight: eventDone ? FontWeight.w600 : null,
              ),
            ),
            const SizedBox(height: 10),
            if (eventDone)
              _LockedOverallFeedback(
                typeLabel: shownType,
                rating: shownRating,
                ratingLabel: shownRating > 0 ? _ratingLabel(shownRating) : null,
                ratingColor: shownRating > 0 ? _ratingColor(shownRating) : kTextSecondary,
                message: lockedMessage,
              )
            else ...[
              _FeedbackTypePicker(
                types: widget.types,
                selected: shownType,
                onChanged: widget.onTypeChanged,
              ),
              const SizedBox(height: 12),
              Text(
                'Overall rating',
                style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _OverallStarRatingRow(
                rating: shownRating,
                onChanged: widget.onRatingChanged,
                ratingLabel: shownRating > 0 ? _ratingLabel(shownRating) : null,
                ratingColor:
                    shownRating > 0 ? _ratingColor(shownRating) : kTextSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Your message',
                style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: widget.msgCtrl,
                minLines: 3,
                maxLines: 6,
                style: memberDashboardBodyStyle.copyWith(
                  color: kTextPrimary,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Tell us about your experience...',
                  hintStyle: memberDashboardMetaStyle.copyWith(
                    color: const Color(0xFF8AA0B0),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7FBFD),
                  contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD0EBF5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD0EBF5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF079FC6),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (requestId != null && !(eventDone && teamDone)) ...[
          const SizedBox(height: 14),
          widget.submitting
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF079FC6),
                      ),
                    ),
                  ),
                )
              : MemberDashboardPrimaryButton(
                  label: 'Submit Feedback',
                  icon: Icons.send_rounded,
                  color: const Color(0xFF079FC6),
                  minHeight: 48,
                  onPressed: _submit,
                ),
          ],
        ],
      ),
    );
  }

  (String, String) _submittedOverallParts(EventFeedback fb) {
    final comment = fb.message.trim();
    for (final opt in _kRequestorFeedbackTypes) {
      if (comment == opt.label) return (opt.label, '');
      final prefix = '${opt.label}: ';
      if (comment.startsWith(prefix)) {
        return (opt.label, comment.substring(prefix.length).trim());
      }
    }
    if (fb.type != 'Service rating' && fb.type.trim().isNotEmpty) {
      return (fb.type.trim(), comment);
    }
    return ('Other', comment);
  }

  String _ratingLabel(int r) => switch (r) {
        5 => 'Excellent',
        4 => 'Good',
        3 => 'Average',
        2 => 'Poor',
        _ => 'Very poor',
      };

  Color _ratingColor(int r) => r >= 4 ? kGreen : r == 3 ? kYellow : kRed;
}

class _LockedOverallFeedback extends StatelessWidget {
  const _LockedOverallFeedback({
    required this.typeLabel,
    required this.rating,
    required this.ratingLabel,
    required this.ratingColor,
    required this.message,
  });

  final String typeLabel;
  final int rating;
  final String? ratingLabel;
  final Color ratingColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded, size: 16, color: kTextSecondary),
              const SizedBox(width: 6),
              Text(
                'Locked',
                style: memberDashboardMetaStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            typeLabel,
            style: memberDashboardBodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < rating ? kYellow : kTextSecondary,
                    size: 28,
                  ),
                ),
              ),
              if (ratingLabel != null) ...[
                const SizedBox(width: 6),
                Text(
                  ratingLabel!,
                  style: memberDashboardMetaStyle.copyWith(
                    color: ratingColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.isEmpty ? 'No written comment.' : message,
            style: memberDashboardBodyStyle.copyWith(
              color: message.isEmpty ? kTextSecondary : kTextPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

const _kFeedbackFormCyan = Color(0xFF079FC6);
const _kFeedbackFormSky = Color(0xFFEAF7FC);
const _kFeedbackFormBorder = Color(0xFFD0EBF5);
const _kFeedbackFormStar = Color(0xFFF5B400);
const _kFeedbackFormStarMuted = Color(0xFFB0BEC8);

class _OverallStarRatingRow extends StatelessWidget {
  const _OverallStarRatingRow({
    required this.rating,
    required this.onChanged,
    this.ratingLabel,
    this.ratingColor = kTextSecondary,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final String? ratingLabel;
  final Color ratingColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final narrow = maxW < 360;
        final tapSize = narrow ? 36.0 : 44.0;
        final iconSize = narrow ? 26.0 : 32.0;
        final gap = narrow ? 1.0 : 4.0;

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final selected = i < rating;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: gap),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onChanged(i + 1),
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: tapSize,
                            height: tapSize,
                            child: Icon(
                              selected
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: selected
                                  ? _kFeedbackFormStar
                                  : _kFeedbackFormStarMuted,
                              size: iconSize,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (ratingLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                ratingLabel!,
                style: memberDashboardMetaStyle.copyWith(
                  color: ratingColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FeedbackTypePicker extends StatelessWidget {
  const _FeedbackTypePicker({
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  final List<_FeedbackTypeOption> types;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep two columns on typical phones (card width is often ~300–340 after
        // page + card padding). Fall back to one column only on very narrow widths.
        final columns = constraints.maxWidth < 260 ? 1 : 2;
        final gap = 8.0;
        final tileWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final option in types)
              SizedBox(
                width: tileWidth,
                child: _FeedbackTypeTile(
                  option: option,
                  selected: selected == option.label,
                  onTap: () => onChanged(option.label),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeedbackTypeTile extends StatelessWidget {
  const _FeedbackTypeTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _FeedbackTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  IconData get _outlineIcon {
    return switch (option.label) {
      'Documentation quality' => Icons.photo_camera_outlined,
      'Coverage completeness' => Icons.checklist_outlined,
      'Team responsiveness' => Icons.groups_outlined,
      'Suggestion' => Icons.lightbulb_outline_rounded,
      _ => Icons.chat_bubble_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: selected ? _kFeedbackFormSky : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _kFeedbackFormCyan : _kFeedbackFormBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _outlineIcon,
                    size: 18,
                    color: _kFeedbackFormCyan,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    option.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      height: 1.2,
                      color: selected
                          ? const Color(0xFF173650)
                          : kTextPrimary,
                    )),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(const TextStyle(
                      fontSize: 10.5,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF617F91),
                    )),
                  ),
                ],
              ),
              if (selected)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: _kFeedbackFormCyan,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventPickerList extends StatelessWidget {
  const _EventPickerList({
    required this.rateable,
    required this.selectedKey,
    required this.completion,
    required this.requestKey,
    required this.onEventChanged,
  });

  final List<ServiceRequest> rateable;
  final String? selectedKey;
  final RequestorFeedbackCompletion completion;
  final String Function(ServiceRequest) requestKey;
  final ValueChanged<String?> onEventChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rateable.map((r) {
        final key = requestKey(r);
        final selected = selectedKey == key;
        final rid = r.requestId;
        final fullyDone = completion.fullyDone(r);
        final statusLabel = rid == null ? r.requestStatus.label : completion.statusLabel(rid);
        final style = RequestStatusStyle.forStatus(r.requestStatus);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onEventChanged(key),
              borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
              child: Opacity(
                opacity: fullyDone ? 0.55 : 1,
                child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? kAccent.withValues(alpha: 0.08) : kSurfaceAlt,
                  borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                  border: Border.all(
                    color: selected ? kAccent : kBorder,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      size: 20,
                      color: selected ? kAccent : kIconInactive,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.eventName,
                            style: memberDashboardBodyStyle.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatRequestShortDate(r.eventDate),
                            style: memberDashboardMetaStyle.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: fullyDone
                              ? kGreenDim
                              : statusLabel.contains('due')
                                  ? kYellow.withValues(alpha: 0.15)
                                  : style.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            color: fullyDone
                                ? kGreen
                                : statusLabel.contains('due')
                                    ? kYellow
                                    : style.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SelectedEventPreview extends StatelessWidget {
  const _SelectedEventPreview({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final style = RequestStatusStyle.forStatus(request.requestStatus);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: style.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(style.icon, size: 18, color: style.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatRequestShortDate(request.eventDate),
                  style: memberDashboardMetaStyle.copyWith(color: kTextPrimary),
                ),
                if (request.location != null && request.location!.trim().isNotEmpty)
                  Text(request.location!, style: memberDashboardMetaStyle),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              request.requestStatus.label,
              style: memberDashboardMetaStyle.copyWith(
                color: style.color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamRatingGroup {
  const _TeamRatingGroup({
    required this.requestId,
    required this.eventTitle,
    required this.rows,
    this.dateLabel,
  });

  final int requestId;
  final String eventTitle;
  final List<Map<String, dynamic>> rows;
  final String? dateLabel;
}

class _PastTeamRatingsCard extends StatefulWidget {
  const _PastTeamRatingsCard({required this.group});

  final _TeamRatingGroup group;

  @override
  State<_PastTeamRatingsCard> createState() => _PastTeamRatingsCardState();
}

class _PastTeamRatingsCardState extends State<_PastTeamRatingsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final previewName = group.rows.isEmpty
        ? 'Team member ratings'
        : (group.rows.first['member_name'] as String? ?? 'Team member');
    final previewRating =
        group.rows.isEmpty ? 0 : (group.rows.first['rating'] as num?)?.toInt() ?? 0;

    return _HistoryCardShell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  group.eventTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardCardTitleStyle.copyWith(
                    fontSize: 13.5,
                    color: _kHistoryNavy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 22,
                color: _kHistoryCyan,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.groups_outlined, size: 14, color: _kHistoryCyan),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Team member ratings · ${group.rows.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardMetaStyle.copyWith(
                    color: _kHistoryCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              if (group.dateLabel != null && group.dateLabel!.trim().isNotEmpty)
                Text(
                  group.dateLabel!,
                  style: memberDashboardMetaStyle.copyWith(
                    color: _kHistoryMeta,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (!_expanded) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    previewName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: memberDashboardBodyStyle.copyWith(
                      fontSize: 12.5,
                      color: kTextPrimary,
                    ),
                  ),
                ),
                _CompactStarRow(rating: previewRating, size: 13),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'View details',
              style: memberDashboardMetaStyle.copyWith(
                color: _kHistoryCyan,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            for (final row in group.rows) ...[
              _PastMemberRatingRow(row: row),
              if (row != group.rows.last) const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            Text(
              'Hide details',
              style: memberDashboardMetaStyle.copyWith(
                color: _kHistoryCyan,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PastMemberRatingRow extends StatelessWidget {
  const _PastMemberRatingRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final name = row['member_name'] as String? ?? 'Team member';
    final rating = (row['rating'] as num?)?.toInt() ?? 0;
    final comment = (row['comment'] as String?)?.trim() ?? '';
    final role = row['task_role'] as String? ?? '';
    final roleLabel = role.toLowerCase().contains('video')
        ? 'Videographer'
        : role.toLowerCase().contains('photo')
            ? 'Photographer'
            : 'Documentation member';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kHistoryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: memberDashboardBodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: _kHistoryNavy,
                  ),
                ),
              ),
              Text(
                roleLabel,
                style: memberDashboardMetaStyle.copyWith(
                  fontSize: 10,
                  color: _kHistoryMeta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _CompactStarRow(rating: rating, size: 14),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comment,
              style: memberDashboardBodyStyle.copyWith(
                fontSize: 12,
                color: kTextPrimary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PastFeedbackCard extends StatefulWidget {
  const _PastFeedbackCard({required this.feedback});

  final EventFeedback feedback;

  @override
  State<_PastFeedbackCard> createState() => _PastFeedbackCardState();
}

class _PastFeedbackCardState extends State<_PastFeedbackCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final message = feedback.message.trim();
    final hasAdmin = feedback.adminResponse != null &&
        feedback.adminResponse!.trim().isNotEmpty;
    final canExpand = message.isNotEmpty || hasAdmin;

    return _HistoryCardShell(
      onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  feedback.eventTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardCardTitleStyle.copyWith(
                    fontSize: 13.5,
                    color: _kHistoryNavy,
                  ),
                ),
              ),
              if (canExpand) ...[
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 22,
                  color: _kHistoryCyan,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _FeedbackTypeOption.iconForLabel(feedback.type),
                size: 14,
                color: _kHistoryCyan,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  feedback.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardMetaStyle.copyWith(
                    color: _kHistoryCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              if (feedback.date.trim().isNotEmpty)
                Text(
                  feedback.date,
                  style: memberDashboardMetaStyle.copyWith(
                    color: _kHistoryMeta,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _CompactStarRow(rating: feedback.rating, size: 16),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: memberDashboardBodyStyle.copyWith(
                fontSize: 12.5,
                height: 1.35,
                color: kTextPrimary,
              ),
            ),
          ] else if (!_expanded) ...[
            const SizedBox(height: 6),
            Text(
              'No written comment.',
              style: memberDashboardMetaStyle.copyWith(
                color: _kHistoryMeta,
                fontSize: 11.5,
              ),
            ),
          ],
          if (_expanded && hasAdmin) ...[
            const SizedBox(height: 10),
            Text(
              'ACCESS team response',
              style: memberDashboardMetaStyle.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: _kHistoryNavy,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kGreenDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGreen.withValues(alpha: 0.25)),
              ),
              child: Text(
                feedback.adminResponse!.trim(),
                style: memberDashboardBodyStyle.copyWith(
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (canExpand) ...[
            const SizedBox(height: 6),
            Text(
              _expanded ? 'Hide details' : 'View details',
              style: memberDashboardMetaStyle.copyWith(
                color: _kHistoryCyan,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCardShell extends StatelessWidget {
  const _HistoryCardShell({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kHistoryBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CompactStarRow extends StatelessWidget {
  const _CompactStarRow({
    required this.rating,
    this.size = 14,
  });

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Padding(
          padding: EdgeInsets.only(right: i == 4 ? 0 : 1),
          child: Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i < rating ? _kHistoryStar : _kHistoryStarMuted,
            size: size,
          ),
        ),
      ),
    );
  }
}
