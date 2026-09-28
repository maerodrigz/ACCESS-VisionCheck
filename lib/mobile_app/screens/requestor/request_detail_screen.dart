import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/requestor/reschedule_calendar_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/models/reschedule_models.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Detailed documentation request view for requestors.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({
    super.key,
    required this.request,
    this.onViewGallery,
    this.onViewFeedback,
  });

  final ServiceRequest request;
  final VoidCallback? onViewGallery;
  final void Function({int? requestId})? onViewFeedback;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  ServiceRequest get _request {
    final match = appState.serviceRequests.where((r) => r.id == widget.request.id);
    return match.isNotEmpty ? match.first : widget.request;
  }

  bool get _canReschedule {
    final s = _request.requestStatus;
    return s == RequestStatus.rejected || s == RequestStatus.approved;
  }

  Future<void> _openReschedule() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RescheduleCalendarScreen(request: _request),
      ),
    );
    if (ok == true && mounted) {
      await memberDataController.refreshAll();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final status = request.requestStatus;
    final style = RequestStatusStyle.forStatus(status);

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
        title: Text(
          request.eventName,
          style: const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          kMemberDashboardPagePadding,
          12,
          kMemberDashboardPagePadding,
          32,
        ),
        children: [
          _RequestDetailHero(request: request, status: status, style: style),
          const SizedBox(height: 16),
          if (status == RequestStatus.rejected) _RejectionSection(request: request),
          if (status == RequestStatus.approved)
            _ApprovedCallout(
              request: request,
              onViewGallery: widget.onViewGallery,
              onViewFeedback: widget.onViewFeedback,
            ),
          if (status == RequestStatus.completed)
            _CompletedSection(
              request: request,
              onViewGallery: widget.onViewGallery,
              onViewFeedback: widget.onViewFeedback,
            ),
          _EventInformationCard(
            request: request,
            canReschedule: _canReschedule,
            onReschedule: _openReschedule,
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Request Information',
            rows: [
              _InfoRow('Request ID', request.id),
              _InfoRow('Requestor', request.requesterName),
              _InfoRow('Request Type', request.requestType),
              if (request.submissionDate != null)
                _InfoRow('Submission Date', formatRequestDate(request.submissionDate!)),
              if (request.lastRescheduledAt != null)
                _InfoRow('Last Rescheduled', formatRequestDate(request.lastRescheduledAt!)),
              _InfoRow('Current Status', status.label),
            ],
          ),
          if (request.requirements != null && request.requirements!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Documentation Requirements',
              rows: [
                _InfoRow('Coverage & Instructions', request.requirements!),
              ],
            ),
          ],
          if (request.rescheduleHistory.isNotEmpty) ...[
            const SizedBox(height: 14),
            _RescheduleHistoryCard(
              request: request,
              history: request.rescheduleHistory,
            ),
          ],
          const SizedBox(height: 14),
          _StatusHistoryCard(request: request),
        ],
      ),
    );
  }
}

class _EventInformationCard extends StatelessWidget {
  const _EventInformationCard({
    required this.request,
    required this.canReschedule,
    required this.onReschedule,
  });

  final ServiceRequest request;
  final bool canReschedule;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final original = request.originalEventDate;
    final showOriginal = original != null &&
        (original.year != request.eventDate.year ||
            original.month != request.eventDate.month ||
            original.day != request.eventDate.day);

    return MemberDashboardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event Information', style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          _InfoRow('Event Name', request.eventName),
          if (showOriginal) ...[
            _InfoRow('Original Date', formatRequestDate(original)),
            _InfoRow('Updated Date', formatRequestDate(request.eventDate)),
          ] else
            _InfoRow('Event Date', formatRequestDate(request.eventDate)),
          if (request.startTime != null && request.startTime!.isNotEmpty)
            _InfoRow('Start Time', request.startTime!),
          if (request.endTime != null && request.endTime!.isNotEmpty)
            _InfoRow('End Time', request.endTime!),
          if (request.location != null && request.location!.isNotEmpty)
            _InfoRow('Venue / Location', request.location!),
          if (request.description != null && request.description!.isNotEmpty)
            _InfoRow('Event Description', request.description!),
          if (canReschedule) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kMemberPrimary,
                  side: const BorderSide(color: kMemberPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                  ),
                ),
                onPressed: onReschedule,
                icon: const Icon(Icons.event_repeat_rounded, size: 20),
                label: const Text(
                  'Reschedule Request',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RescheduleHistoryCard extends StatelessWidget {
  const _RescheduleHistoryCard({required this.request, required this.history});

  final ServiceRequest request;
  final List<RescheduleHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reschedule History', style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          for (var i = 0; i < history.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _HistoryEntry(entry: history[i], index: i + 1),
          ],
        ],
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry, required this.index});

  final RescheduleHistoryEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reschedule #$index',
          style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
        ),
        if (entry.rescheduledAt != null) ...[
          const SizedBox(height: 4),
          Text(
            formatRequestShortDate(entry.rescheduledAt!),
            style: memberDashboardBodyStyle.copyWith(fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        if (entry.fromEventDate != null)
          _InfoRow('Previous date', formatRequestDate(entry.fromEventDate!)),
        if (entry.toEventDate != null)
          _InfoRow('New date', formatRequestDate(entry.toEventDate!)),
        if (entry.fromStartTime != null && entry.fromStartTime!.isNotEmpty)
          _InfoRow(
            'Previous time',
            '${entry.fromStartTime}${entry.fromEndTime != null ? ' – ${entry.fromEndTime}' : ''}',
          ),
        if (entry.toStartTime != null && entry.toStartTime!.isNotEmpty)
          _InfoRow(
            'New time',
            '${entry.toStartTime}${entry.toEndTime != null ? ' – ${entry.toEndTime}' : ''}',
          ),
        if (entry.previousStatus != null)
          _InfoRow('Previous status', entry.previousStatus!),
        if (entry.rejectionReason != null && entry.rejectionReason!.trim().isNotEmpty)
          _InfoRow('Rejection reason', entry.rejectionReason!.trim()),
        const SizedBox(height: 4),
        const _InfoRow('Resubmission status', 'Pending admin review'),
      ],
    );
  }
}

class _RequestDetailHero extends StatelessWidget {
  const _RequestDetailHero({
    required this.request,
    required this.status,
    required this.style,
  });

  final ServiceRequest request;
  final RequestStatus status;
  final RequestStatusStyle style;

  @override
  Widget build(BuildContext context) {
    final location = request.location?.trim();
    final start = request.startTime?.trim();
    final end = request.endTime?.trim();
    final timeLabel = start != null && start.isNotEmpty
        ? (end != null && end.isNotEmpty ? '$start – $end' : start)
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: style.color.withValues(alpha: 0.35)),
                ),
                child: Icon(style.icon, color: style.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          color: style.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status.description,
                      style: dashText(TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.4,
                      )),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _HeroMetaRow(icon: Icons.event_rounded, label: formatRequestDate(request.eventDate)),
          if (timeLabel != null) ...[
            const SizedBox(height: 6),
            _HeroMetaRow(icon: Icons.schedule_rounded, label: timeLabel),
          ],
          if (location != null && location.isNotEmpty) ...[
            const SizedBox(height: 6),
            _HeroMetaRow(icon: Icons.location_on_outlined, label: location),
          ],
        ],
      ),
    );
  }
}

class _HeroMetaRow extends StatelessWidget {
  const _HeroMetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.88)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: dashText(TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            )),
          ),
        ),
      ],
    );
  }
}

class _ApprovedCallout extends StatelessWidget {
  const _ApprovedCallout({
    required this.request,
    this.onViewGallery,
    this.onViewFeedback,
  });

  final ServiceRequest request;
  final VoidCallback? onViewGallery;
  final void Function({int? requestId})? onViewFeedback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MemberDashboardCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kGreenDim,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: kGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Approved for documentation',
                        style: memberDashboardCardTitleStyle.copyWith(color: kGreen, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ACCESS will coordinate member coverage for this event.',
                        style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onViewGallery != null || onViewFeedback != null) ...[
              const SizedBox(height: 14),
              if (onViewGallery != null)
                MemberDashboardPrimaryButton(
                  label: 'View event gallery',
                  icon: Icons.photo_library_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    onViewGallery!();
                  },
                ),
              if (onViewFeedback != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onViewFeedback!(requestId: request.requestId);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAccent,
                      side: const BorderSide(color: kAccent),
                      minimumSize: Size.fromHeight(kMobileMinTouch),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                      ),
                    ),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text(
                      'Rate coverage',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RejectionSection extends StatelessWidget {
  const _RejectionSection({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MemberDashboardCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Rejected',
              style: memberDashboardCardTitleStyle.copyWith(color: kRed),
            ),
            const SizedBox(height: 10),
            const Text(
              'Reason:',
              style: TextStyle(
                color: kTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              request.rejectionReason?.trim().isNotEmpty == true
                  ? request.rejectionReason!.trim()
                  : 'No rejection reason was provided by the administrator.',
              style: memberDashboardBodyStyle.copyWith(color: kTextPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedSection extends StatelessWidget {
  const _CompletedSection({
    required this.request,
    this.onViewGallery,
    this.onViewFeedback,
  });

  final ServiceRequest request;
  final VoidCallback? onViewGallery;
  final void Function({int? requestId})? onViewFeedback;

  @override
  Widget build(BuildContext context) {
    final completion = request.updatedAt ?? request.eventDate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MemberDashboardCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.task_alt_rounded, color: kAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documentation completed',
                        style: memberDashboardCardTitleStyle.copyWith(color: kAccent, fontSize: 14),
                      ),
                      Text(
                        formatRequestDate(completion),
                        style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (onViewGallery != null)
              MemberDashboardPrimaryButton(
                label: 'View event gallery',
                icon: Icons.photo_library_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  onViewGallery!();
                },
              ),
            if (onViewFeedback != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onViewFeedback!(requestId: request.requestId);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccent,
                    side: const BorderSide(color: kAccent),
                    minimumSize: Size.fromHeight(kMobileMinTouch),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                    ),
                  ),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text(
                    'Rate coverage',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return MemberDashboardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHistoryCard extends StatelessWidget {
  const _StatusHistoryCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final submitted = request.submissionDate;
    final updated = request.updatedAt;
    final status = request.requestStatus;

    final steps = <(String, DateTime?, Color)>[
      ('Submitted', submitted, kAccent),
      if (request.rescheduleHistory.isNotEmpty)
        ('Rescheduled & resubmitted', request.lastRescheduledAt, kYellow),
      if (status == RequestStatus.approved || status == RequestStatus.completed)
        ('Approved', updated, kGreen)
      else if (status == RequestStatus.rejected)
        ('Rejected', updated, kRed),
      if (status == RequestStatus.completed) ('Completed', updated, kCyan),
      if (status == RequestStatus.pending)
        ('Awaiting admin review', null, kYellow),
    ];

    return MemberDashboardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status History', style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16)),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: steps[i].$2 != null || i < steps.length - 1
                            ? steps[i].$3
                            : kBorder,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 2,
                        height: 28,
                        color: steps[i + 1].$2 != null
                            ? steps[i + 1].$3.withValues(alpha: 0.35)
                            : kBorder,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 18 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$1,
                          style: TextStyle(
                            color: steps[i].$2 != null || i < steps.length - 1
                                ? kTextPrimary
                                : kTextSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (steps[i].$2 != null)
                          Text(
                            formatRequestShortDate(steps[i].$2!),
                            style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                          )
                        else if (i == steps.length - 1)
                          Text(
                            'In progress',
                            style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
