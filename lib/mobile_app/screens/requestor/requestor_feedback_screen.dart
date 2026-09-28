import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/member_team_rating_section.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_list_skeleton.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
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
  ),
  _FeedbackTypeOption(
    label: 'Coverage completeness',
    subtitle: 'Key moments, angles, and deliverables covered',
    icon: Icons.checklist_rounded,
  ),
  _FeedbackTypeOption(
    label: 'Team responsiveness',
    subtitle: 'Communication, timeliness, and coordination',
    icon: Icons.groups_rounded,
  ),
  _FeedbackTypeOption(
    label: 'Suggestion',
    subtitle: 'Ideas to improve future documentation',
    icon: Icons.lightbulb_outline_rounded,
  ),
  _FeedbackTypeOption(
    label: 'Other',
    subtitle: 'General comments not listed above',
    icon: Icons.chat_bubble_outline_rounded,
  ),
];

class _FeedbackTypeOption {
  const _FeedbackTypeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final IconData icon;

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

  _FeedbackTypeOption get _selectedTypeOption =>
      _kRequestorFeedbackTypes.firstWhere((t) => t.label == _type, orElse: () => _kRequestorFeedbackTypes.first);

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
    final id = widget.initialRequestId;
    if (id == null) return;
    final match = _rateableRequests(appState.serviceRequests)
        .where((r) => r.requestId == id)
        .firstOrNull;
    if (match != null) {
      _selectedKey = _requestKey(match);
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
      if (mounted) setState(() => _memberRatingsMine = rows);
    } catch (_) {
      if (mounted) setState(() => _memberRatingsMine = []);
    }
  }

  List<ServiceRequest> _rateableRequests(List<ServiceRequest> all) {
    return all
        .where(
          (r) =>
              r.requestId != null &&
              (r.requestStatus == RequestStatus.approved ||
                  r.requestStatus == RequestStatus.completed),
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

  Set<int> _ratedRequestIds(List<EventFeedback> feedbacks) {
    final ids = <int>{};
    for (final req in appState.serviceRequests) {
      final rid = req.requestId;
      if (rid == null) continue;
      final title = req.eventName;
      if (feedbacks.any((f) => f.eventTitle == title || f.eventTitle == 'Request #$rid')) {
        ids.add(rid);
      }
    }
    for (final fb in feedbacks) {
      final match = RegExp(r'Request #(\d+)').firstMatch(fb.eventTitle);
      if (match != null) {
        ids.add(int.parse(match.group(1)!));
      }
    }
    for (final row in _memberRatingsMine) {
      final rid = (row['request_id'] as num?)?.toInt();
      if (rid != null) ids.add(rid);
    }
    return ids;
  }

  (String type, String message) _parseComment(String raw) {
    final comment = raw.trim();
    final match = RegExp(r'^([^:]+):\s*(.+)$', dotAll: true).firstMatch(comment);
    if (match != null) {
      return (match.group(1)!.trim(), match.group(2)!.trim());
    }
    return ('Feedback', comment);
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
    );
  }


  void _reset() {
    _msgCtrl.clear();
    setState(() {
      _sent = false;
      _selectedKey = null;
      _rating = 0;
      _type = 'Documentation quality';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RequestorTabHero(
            title: 'Feedback',
            subtitle:
                'Rate each photographer and videographer assigned to your event, then share overall feedback.',
            onNotifications: widget.onNotificationsTap,
            onProfileTap: widget.onProfileTap,
            mini: true,
          ),
          Expanded(
            child: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (context, _) {
          final rateable = _rateableRequests(appState.serviceRequests);
          final ratedIds = _ratedRequestIds(appState.feedbacks);
          final past = appState.feedbacks.map(_displayFeedback).toList();
          final selected = _requestFromKey(_selectedKey);
          final loading = memberDataController.isLoading && appState.serviceRequests.isEmpty;

          if (loading) {
            return const FeedbackFormSkeleton();
          }

          return RefreshIndicator(
            color: kMemberPrimary,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                kMemberDashboardPagePadding,
                14,
                kMemberDashboardPagePadding,
                56,
              ),
              children: [
                if (_sent) ...[
                  _SuccessBanner(onNew: _reset),
                  const SizedBox(height: 20),
                ] else if (rateable.isEmpty)
                  _NoEventsCard(onRefresh: _reload)
                else
                  _FeedbackFormCard(
                    msgCtrl: _msgCtrl,
                    type: _type,
                    types: _kRequestorFeedbackTypes,
                    messageHint: _selectedTypeOption.messageHint,
                    selectedKey: _selectedKey,
                    rating: _rating,
                    selectedRequest: selected,
                    rateable: rateable,
                    ratedIds: ratedIds,
                    onTypeChanged: (t) => setState(() => _type = t),
                    onEventChanged: (k) => setState(() => _selectedKey = k),
                    onRatingChanged: (r) => setState(() => _rating = r),
                    submitting: _submitting,
                    requestKey: _requestKey,
                    onSubmitted: () async {
                      setState(() => _sent = true);
                      await _reload();
                    },
                    onSubmittingChanged: (v) => setState(() => _submitting = v),
                  ),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Your submissions',
                    style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ratings you have sent for past documentation events.',
                    style: memberDashboardSectionSubtitleStyle,
                  ),
                  const SizedBox(height: 12),
                  ...past.map(
                    (fb) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PastFeedbackCard(feedback: fb),
                    ),
                  ),
                ],
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
            'Once a documentation request is approved or completed, you can rate the coverage here.',
            style: memberDashboardBodyStyle,
          ),
          const SizedBox(height: 16),
          MemberDashboardPrimaryButton(
            label: 'Refresh',
            icon: Icons.refresh_rounded,
            onPressed: () => onRefresh(),
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
    required this.messageHint,
    required this.selectedKey,
    required this.rating,
    required this.selectedRequest,
    required this.rateable,
    required this.ratedIds,
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
  final String messageHint;
  final String? selectedKey;
  final int rating;
  final ServiceRequest? selectedRequest;
  final List<ServiceRequest> rateable;
  final Set<int> ratedIds;
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
    final requestId = int.tryParse(widget.selectedKey!.split('|').first);
    if (requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid event selection'), backgroundColor: kRed),
      );
      return;
    }

    if (_teamTargets.isNotEmpty) {
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

    final hasOverall = widget.rating > 0 && widget.msgCtrl.text.trim().isNotEmpty;
    if (_teamTargets.isEmpty && !hasOverall) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rate your assigned team or submit overall event feedback'),
          backgroundColor: kRed,
        ),
      );
      return;
    }

    widget.onSubmittingChanged(true);
    try {
      if (_teamTargets.isNotEmpty) {
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
      }
      if (hasOverall) {
        await memberDataController.submitFeedback(
          requestId: requestId,
          rating: widget.rating,
          comment: '${widget.type}: ${widget.msgCtrl.text.trim()}',
        );
      }
      await widget.onSubmitted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kRed),
        );
      }
    } finally {
      widget.onSubmittingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ratedIds: widget.ratedIds,
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
          const SizedBox(height: 20),
          Text(
            'Overall event feedback (optional)',
            style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Share general comments about the documentation service for this event.',
            style: memberDashboardMetaStyle.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 10),
          _FeedbackTypePicker(
            types: widget.types,
            selected: widget.type,
            onChanged: widget.onTypeChanged,
          ),
          const SizedBox(height: 16),
          Text('Overall rating', style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => widget.onRatingChanged(i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      i < widget.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: i < widget.rating ? kYellow : kTextSecondary,
                      size: 34,
                    ),
                  ),
                ),
              ),
              if (widget.rating > 0) ...[
                const SizedBox(width: 6),
                Text(
                  _ratingLabel(widget.rating),
                  style: memberDashboardMetaStyle.copyWith(
                    color: _ratingColor(widget.rating),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Text('Your message', style: memberDashboardMetaStyle.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: widget.msgCtrl,
            maxLines: 4,
            style: memberDashboardBodyStyle.copyWith(color: kTextPrimary),
            decoration: InputDecoration(
              hintText: widget.messageHint,
              hintStyle: memberDashboardMetaStyle,
              filled: true,
              fillColor: kSurfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
                borderSide: const BorderSide(color: kAccent),
              ),
            ),
          ),
          const SizedBox(height: 18),
          widget.submitting
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: kAccent),
                    ),
                  ),
                )
              : MemberDashboardPrimaryButton(
                  label: 'Submit feedback',
                  icon: Icons.send_rounded,
                  onPressed: _submit,
                ),
        ],
      ),
    );
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
    return Column(
      children: [
        for (var i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _FeedbackTypeTile(
            option: types[i],
            selected: selected == types[i].label,
            onTap: () => onChanged(types[i].label),
          ),
        ],
      ],
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: selected ? kAccent.withValues(alpha: 0.08) : kSurfaceAlt,
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            border: Border.all(
              color: selected ? kAccent : kBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? kAccent.withValues(alpha: 0.14) : kSurface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: selected ? kAccent.withValues(alpha: 0.35) : kBorder,
                  ),
                ),
                child: Icon(
                  option.icon,
                  size: 20,
                  color: selected ? kAccent : kIconInactive,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: memberDashboardBodyStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected ? kAccent : kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: memberDashboardMetaStyle.copyWith(
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22,
                color: selected ? kAccent : kIconInactive,
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
    required this.ratedIds,
    required this.requestKey,
    required this.onEventChanged,
  });

  final List<ServiceRequest> rateable;
  final String? selectedKey;
  final Set<int> ratedIds;
  final String Function(ServiceRequest) requestKey;
  final ValueChanged<String?> onEventChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rateable.map((r) {
        final key = requestKey(r);
        final selected = selectedKey == key;
        final alreadyRated = ratedIds.contains(r.requestId);
        final style = RequestStatusStyle.forStatus(r.requestStatus);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onEventChanged(key),
              borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
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
                    if (alreadyRated)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kGreenDim,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Rated',
                          style: TextStyle(color: kGreen, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: style.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          r.requestStatus.label,
                          style: TextStyle(
                            color: style.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
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

class _PastFeedbackCard extends StatelessWidget {
  const _PastFeedbackCard({required this.feedback});

  final EventFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  feedback.eventTitle,
                  style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < feedback.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < feedback.rating ? kYellow : kBorder,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAccent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(_FeedbackTypeOption.iconForLabel(feedback.type), size: 16, color: kAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedback.type,
                    style: memberDashboardMetaStyle.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(feedback.date, style: memberDashboardMetaStyle.copyWith(fontSize: 11)),
              ],
            ),
          ),
          if (feedback.message.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(feedback.message, style: memberDashboardBodyStyle.copyWith(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
