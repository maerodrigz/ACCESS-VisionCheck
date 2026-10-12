import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_meta_icon_color.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Member documentation assignments — accept or decline only.
class MyAssignmentsScreen extends StatefulWidget {
  const MyAssignmentsScreen({super.key, this.highlightAssignmentId});

  final int? highlightAssignmentId;

  @override
  State<MyAssignmentsScreen> createState() => _MyAssignmentsScreenState();
}

class _MyAssignmentsScreenState extends State<MyAssignmentsScreen> {
  bool _busy = false;
  bool _didScrollToHighlight = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlightIfNeeded(List<Challenge> tasks) {
    if (_didScrollToHighlight) return;
    final targetId = widget.highlightAssignmentId;
    if (targetId == null) return;
    final index = tasks.indexWhere((t) => t.assignmentId == targetId);
    if (index < 0) return;
    _didScrollToHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      const itemExtent = 220.0;
      final offset = (index * itemExtent).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _refresh() => memberDataController.refreshAll();

  Future<void> _accept(Challenge task) async {
    final id = task.assignmentId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await memberDataController.respondToAssignment(id, action: 'accept');
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(Challenge task) async {
    final id = task.assignmentId;
    if (id == null) return;
    final result = await showModalBottomSheet<(String code, String? text)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _DeclineFormSheet(),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await memberDataController.respondToAssignment(
        id,
        action: 'decline',
        declineReasonCode: result.$1,
        declineReason: result.$2,
      );
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kRed),
    );
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
          icon: const Icon(Icons.arrow_back_rounded, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Assignments',
          style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([appState, memberDataController]),
        builder: (_, __) {
          final tasks = [...appState.challenges];
          _scrollToHighlightIfNeeded(tasks);
          return RefreshIndicator(
            color: kMemberPrimary,
            onRefresh: _refresh,
            child: tasks.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(kMemberDashboardPagePadding),
                    children: [
                      MemberDashboardCard(
                        child: Column(
                          children: [
                            Icon(Icons.assignment_outlined, size: 48, color: kMemberCyan.withValues(alpha: 0.8)),
                            const SizedBox(height: 12),
                            Text('No assignments yet', style: memberDashboardCardTitleStyle),
                            const SizedBox(height: 6),
                            Text(
                              'When ACCESS assigns you to cover an event, it will show here so you can accept or decline.',
                              style: memberDashboardBodyStyle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      kMemberDashboardPagePadding,
                      12,
                      kMemberDashboardPagePadding,
                      32,
                    ),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _AssignmentCard(
                      task: tasks[i],
                      busy: _busy,
                      highlighted: tasks[i].assignmentId == widget.highlightAssignmentId,
                      onAccept: () => _accept(tasks[i]),
                      onDecline: () => _decline(tasks[i]),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.task,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    this.highlighted = false,
  });

  final Challenge task;
  final bool busy;
  final bool highlighted;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(task.status);
    final timeLabel = task.eventTimeRange ?? task.eventTime ?? 'Time TBA';

    final card = MemberDashboardCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: memberDashboardCardTitleStyle.copyWith(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      formatTaskRole(task.taskRole ?? 'member'),
                      style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: style.color.withValues(alpha: 0.25)),
                ),
                child: Text(
                  style.label,
                  style: TextStyle(color: style.color, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Meta(Icons.event_rounded, task.eventDate ?? 'Date TBA'),
          _Meta(Icons.schedule_rounded, timeLabel),
          _Meta(Icons.location_on_outlined, task.venue ?? 'Location TBA'),
          const SizedBox(height: 12),
          if (_isPending(task.status)) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kRed,
                      side: BorderSide(color: kRed.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: busy ? null : onDecline,
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMemberPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: busy ? null : onAccept,
                    child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ] else if (_isAccepted(task.status)) ...[
            Text(
              'You confirmed coverage for this event. Event media will appear in Gallery when the team publishes it.',
              style: memberDashboardBodyStyle.copyWith(fontSize: 12, color: kGreen),
            ),
          ],
        ],
      ),
    );
    if (!highlighted) return card;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
        border: Border.all(color: kMemberPrimary, width: 2),
      ),
      child: card,
    );
  }

  bool _isPending(String status) {
    final s = status.toLowerCase();
    return s == 'pending_acceptance' || s == 'assigned';
  }

  bool _isAccepted(String status) {
    final s = status.toLowerCase();
    return s == 'accepted' || s == 'in_progress' || s == 'completed' || s == 'done';
  }

  _StatusVisual _statusStyle(String status) {
    final s = status.toLowerCase();
    if (s == 'pending_acceptance' || s == 'assigned') {
      return _StatusVisual('Pending Acceptance', kYellow, kYellowDim, Icons.hourglass_top_rounded);
    }
    if (s == 'accepted' || s == 'in_progress' || s == 'completed' || s == 'done') {
      return _StatusVisual('Confirmed', kGreen, kGreenDim, Icons.check_circle_rounded);
    }
    if (s == 'declined') {
      return _StatusVisual('Declined', kRed, kRedDim, Icons.cancel_rounded);
    }
    return _StatusVisual(status, kTextSecondary, kSurfaceAlt, Icons.assignment_rounded);
  }
}

class _StatusVisual {
  const _StatusVisual(this.label, this.color, this.background, this.icon);
  final String label;
  final Color color;
  final Color background;
  final IconData icon;
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: requestorMetaIconColor(icon)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: memberDashboardBodyStyle.copyWith(fontSize: 12))),
        ],
      ),
    );
  }
}

class _DeclineFormSheet extends StatefulWidget {
  const _DeclineFormSheet();

  @override
  State<_DeclineFormSheet> createState() => _DeclineFormSheetState();
}

class _DeclineFormSheetState extends State<_DeclineFormSheet> {
  String? _code;
  final _otherCtrl = TextEditingController();

  static const _reasons = [
    ('schedule_conflict', 'Schedule conflict'),
    ('academic_obligation', 'Academic obligation'),
    ('already_assigned', 'Already assigned to another event'),
    ('unable_to_attend', 'Unable to attend'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why are you declining?', style: memberDashboardCardTitleStyle.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          ..._reasons.map(
            (r) => RadioListTile<String>(
              value: r.$1,
              groupValue: _code,
              onChanged: (v) => setState(() => _code = v),
              title: Text(r.$2, style: const TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (_code == 'other') ...[
            TextField(
              controller: _otherCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Brief explanation (required)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kMemberPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                if (_code == null) return;
                if (_code == 'other' && _otherCtrl.text.trim().length < 8) return;
                Navigator.pop(context, (_code!, _code == 'other' ? _otherCtrl.text.trim() : null));
              },
              child: const Text('Submit Decline', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
