import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/navigation/requestor_shell_navigation.dart';
import 'package:access_mobile/mobile_app/screens/requestor/reschedule_calendar_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_progress_tracker.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_meta_icon_color.dart';
import 'package:access_mobile/shared/api/member_api_service.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/models/reschedule_models.dart';
import 'package:access_mobile/shared/themes/theme.dart';

const _kCardRadius = 14.0;

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
  bool _archiveBusy = false;

  ServiceRequest get _request {
    final match =
        appState.serviceRequests.where((r) => r.id == widget.request.id);
    return match.isNotEmpty ? match.first : widget.request;
  }

  bool get _canReschedule {
    final s = _request.requestStatus;
    return s == RequestStatus.rejected || s == RequestStatus.approved;
  }

  bool get _showArchiveMenu =>
      _request.canRequestorArchive || _request.isRequestorArchived;

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

  Future<void> _confirmArchive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Archive this request?',
          style: dashText(const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          )),
        ),
        content: Text(
          'This request will be hidden from your active requests. You can restore it anytime from Archived Requests.',
          style: dashText(const TextStyle(
            color: kTextSecondary,
            fontSize: 14,
            height: 1.4,
          )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: dashText(const TextStyle(
                color: kTextSecondary,
                fontWeight: FontWeight.w600,
              )),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Archive Request',
              style: dashText(const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _runArchive();
  }

  Future<void> _confirmRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Restore this request?',
          style: dashText(const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          )),
        ),
        content: Text(
          'This request will return to your active My Requests list with its original status.',
          style: dashText(const TextStyle(
            color: kTextSecondary,
            fontSize: 14,
            height: 1.4,
          )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: dashText(const TextStyle(
                color: kTextSecondary,
                fontWeight: FontWeight.w600,
              )),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Restore Request',
              style: dashText(const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _runRestore();
  }

  Future<void> _runArchive() async {
    final id = _request.requestId;
    if (id == null || _archiveBusy) return;
    setState(() => _archiveBusy = true);
    try {
      final raw = await memberApiService.archiveServiceRequestForRequestor(id);
      final updated = memberDataController.serviceRequestFromApi(raw);
      appState.upsertServiceRequest(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request archived.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to archive this request. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _archiveBusy = false);
    }
  }

  Future<void> _runRestore() async {
    final id = _request.requestId;
    if (id == null || _archiveBusy) return;
    setState(() => _archiveBusy = true);
    try {
      final raw = await memberApiService.restoreServiceRequestForRequestor(id);
      final updated = memberDataController.serviceRequestFromApi(raw);
      appState.upsertServiceRequest(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request restored.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to restore this request. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _archiveBusy = false);
    }
  }

  VoidCallback? get _openGallery =>
      widget.onViewGallery ?? RequestorShellNavigation.openGallery;

  void Function({int? requestId})? get _openFeedback =>
      widget.onViewFeedback ?? RequestorShellNavigation.openFeedback;

  void _goToGallery(BuildContext context) {
    final action = _openGallery;
    if (action == null) {
      _showNavUnavailable(context);
      return;
    }
    Navigator.pop(context);
    action();
  }

  void _goToFeedback(BuildContext context, int? requestId) {
    final action = _openFeedback;
    if (action == null) {
      _showNavUnavailable(context);
      return;
    }
    Navigator.pop(context);
    action(requestId: requestId);
  }

  void _showNavUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open this screen from the requestor home tab.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _supportLine(RequestStatus status) {
    return switch (status) {
      RequestStatus.pending =>
        'An administrator will approve or decline this request. You will be notified in the app.',
      RequestStatus.approved =>
        'ACCESS will assign members to cover this event. Gallery and feedback unlock after completion.',
      RequestStatus.rejected => null,
      RequestStatus.completed => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final status = request.requestStatus;
    final style = RequestStatusStyle.forStatus(status);
    final support = _supportLine(status);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request Details',
          style: dashText(const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          )),
        ),
        actions: [
          if (_showArchiveMenu)
            PopupMenuButton<String>(
              enabled: !_archiveBusy,
              icon: const Icon(Icons.more_vert_rounded, color: kTextPrimary),
              onSelected: (value) {
                if (value == 'archive') {
                  _confirmArchive();
                } else if (value == 'restore') {
                  _confirmRestore();
                }
              },
              itemBuilder: (context) {
                if (request.isRequestorArchived) {
                  return const [
                    PopupMenuItem(
                      value: 'restore',
                      child: Text('Restore Request'),
                    ),
                  ];
                }
                return const [
                  PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive Request'),
                  ),
                ];
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _EventSummaryCard(request: request, status: status, style: style),
          const SizedBox(height: 10),
          _ProgressCard(
            request: request,
            supportLine: support,
          ),
          if (status == RequestStatus.rejected) ...[
            const SizedBox(height: 10),
            _RejectionCard(request: request),
          ],
          if (status == RequestStatus.completed) ...[
            const SizedBox(height: 10),
            _CompletedActionsCard(
              request: request,
              onViewGallery: () => _goToGallery(context),
              onViewFeedback: () => _goToFeedback(context, request.requestId),
            ),
          ],
          const SizedBox(height: 10),
          _DetailsCard(
            request: request,
            status: status,
            canReschedule: _canReschedule,
            onReschedule: _openReschedule,
          ),
          if (request.description != null &&
              request.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExpandableTextCard(
              title: 'Event Description',
              body: request.description!.trim(),
            ),
          ],
          if (request.requirements != null &&
              request.requirements!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExpandableTextCard(
              title: 'Documentation Requirements',
              body: request.requirements!.trim(),
              initiallyExpanded: true,
            ),
          ],
          if (request.rescheduleHistory.isNotEmpty) ...[
            const SizedBox(height: 10),
            _RescheduleHistoryCard(
              history: request.rescheduleHistory,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSurface extends StatelessWidget {
  const _DetailSurface({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    required this.request,
    required this.status,
    required this.style,
  });

  final ServiceRequest request;
  final RequestStatus status;
  final RequestStatusStyle style;

  @override
  Widget build(BuildContext context) {
    final location = request.location?.trim() ?? '';
    final start = request.startTime?.trim();
    final end = request.endTime?.trim();
    final timeLabel = (start != null && start.isNotEmpty)
        ? ((end != null && end.isNotEmpty) ? '$start – $end' : start)
        : null;
    final requestNo = request.requestId != null
        ? 'Request #${request.requestId}'
        : request.id;

    return _DetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.eventName,
                      style: dashText(const TextStyle(
                        color: kTextPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.2,
                      )),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      requestNo,
                      style: memberDashboardMetaStyle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(label: status.label, style: style),
            ],
          ),
          if (request.isRequestorArchived) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: kAccent.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  'Archived',
                  style: memberDashboardMetaStyle.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: kAccent,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: Icons.event_rounded,
                text: formatRequestDate(request.eventDate),
              ),
              if (timeLabel != null)
                _MetaChip(icon: Icons.schedule_rounded, text: timeLabel),
              if (location.isNotEmpty)
                _MetaChip(icon: Icons.location_on_outlined, text: location),
              _MetaChip(
                icon: Icons.description_outlined,
                text: request.requestType,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.style});

  final String label;
  final RequestStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: dashText(TextStyle(
          color: style.color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        )),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: requestorMetaIconColor(icon)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: memberDashboardMetaStyle.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.request,
    this.supportLine,
  });

  final ServiceRequest request;
  final String? supportLine;

  @override
  Widget build(BuildContext context) {
    final track = RequestTrack.forRequest(request);

    return _DetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Progress',
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            )),
          ),
          if (supportLine != null) ...[
            const SizedBox(height: 4),
            Text(
              supportLine!,
              style: memberDashboardBodyStyle.copyWith(
                fontSize: 12,
                height: 1.35,
                color: kTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _HorizontalProgress(track: track),
        ],
      ),
    );
  }
}

class _HorizontalProgress extends StatelessWidget {
  const _HorizontalProgress({required this.track});

  final RequestTrack track;

  String _label(String raw) {
    if (raw.toLowerCase() == 'in review') return 'In Review';
    return raw;
  }

  String? _dateLabel(DateTime? date) {
    if (date == null) return null;
    return formatRequestShortDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final steps = track.steps;

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _ProgressDot(step: steps[i]),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: steps[i].state == RequestTrackStepState.complete ||
                              steps[i].state == RequestTrackStepState.current
                          ? steps[i].accent.withValues(alpha: 0.5)
                          : kBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _label(steps[i].label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: memberDashboardMetaStyle.copyWith(
                        fontSize: 10.5,
                        fontWeight: steps[i].state ==
                                    RequestTrackStepState.current ||
                                steps[i].state == RequestTrackStepState.declined
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: switch (steps[i].state) {
                          RequestTrackStepState.declined => kRed,
                          RequestTrackStepState.current => kTextPrimary,
                          RequestTrackStepState.complete => kTextSecondary,
                          RequestTrackStepState.upcoming => kIconInactive,
                        },
                      ),
                    ),
                    if (_dateLabel(steps[i].date) != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _dateLabel(steps[i].date)!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: memberDashboardMetaStyle.copyWith(
                          fontSize: 9.5,
                          color: kIconInactive,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.step});

  final RequestTrackStep step;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.state) {
      RequestTrackStepState.complete => step.accent,
      RequestTrackStepState.current => step.accent,
      RequestTrackStepState.declined => kRed,
      RequestTrackStepState.upcoming => kBorder,
    };
    final filled = step.state != RequestTrackStepState.upcoming;

    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? color : kBorder,
          width: filled ? 0 : 1.5,
        ),
      ),
      child: filled
          ? Icon(
              step.state == RequestTrackStepState.declined
                  ? Icons.close_rounded
                  : Icons.check_rounded,
              size: 11,
              color: Colors.white,
            )
          : null,
    );
  }
}

class _RejectionCard extends StatelessWidget {
  const _RejectionCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final reason = request.rejectionReason?.trim().isNotEmpty == true
        ? request.rejectionReason!.trim()
        : 'No rejection reason was provided by the administrator.';

    return _DetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Declined',
            style: dashText(const TextStyle(
              color: kRed,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            )),
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: memberDashboardBodyStyle.copyWith(
              fontSize: 13,
              height: 1.4,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedActionsCard extends StatelessWidget {
  const _CompletedActionsCard({
    required this.request,
    required this.onViewGallery,
    required this.onViewFeedback,
  });

  final ServiceRequest request;
  final VoidCallback onViewGallery;
  final VoidCallback onViewFeedback;

  @override
  Widget build(BuildContext context) {
    final completion = request.updatedAt ?? request.eventDate;

    return _DetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentation completed',
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            )),
          ),
          const SizedBox(height: 2),
          Text(
            formatRequestDate(completion),
            style: memberDashboardMetaStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onViewGallery,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text(
                    'Gallery',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewFeedback,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccent,
                    side: const BorderSide(color: kAccent),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text(
                    'Rate',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.request,
    required this.status,
    required this.canReschedule,
    required this.onReschedule,
  });

  final ServiceRequest request;
  final RequestStatus status;
  final bool canReschedule;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final original = request.originalEventDate;
    final showOriginal = original != null &&
        (original.year != request.eventDate.year ||
            original.month != request.eventDate.month ||
            original.day != request.eventDate.day);

    return _DetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            )),
          ),
          const SizedBox(height: 10),
          _CompactInfoRow('Requestor', request.requesterName),
          _CompactInfoRow('Request type', request.requestType),
          if (request.submissionDate != null)
            _CompactInfoRow(
              'Submitted',
              formatRequestDate(request.submissionDate!),
            ),
          if (showOriginal) ...[
            _CompactInfoRow('Original date', formatRequestDate(original)),
            _CompactInfoRow(
              'Updated date',
              formatRequestDate(request.eventDate),
            ),
          ],
          if (request.lastRescheduledAt != null)
            _CompactInfoRow(
              'Last rescheduled',
              formatRequestDate(request.lastRescheduledAt!),
            ),
          _CompactInfoRow('Status', status.label),
          if (canReschedule) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: const BorderSide(color: kAccent),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: onReschedule,
                icon: const Icon(Icons.event_repeat_rounded, size: 18),
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

class _CompactInfoRow extends StatelessWidget {
  const _CompactInfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: memberDashboardMetaStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: dashText(const TextStyle(
                color: kTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableTextCard extends StatefulWidget {
  const _ExpandableTextCard({
    required this.title,
    required this.body,
    this.initiallyExpanded = false,
  });

  final String title;
  final String body;
  final bool initiallyExpanded;

  @override
  State<_ExpandableTextCard> createState() => _ExpandableTextCardState();
}

class _ExpandableTextCardState extends State<_ExpandableTextCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return _DetailSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: widget.initiallyExpanded,
            onExpansionChanged: (v) => setState(() => _expanded = v),
            tilePadding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            title: Text(
              widget.title,
              style: dashText(const TextStyle(
                color: kTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              )),
            ),
            trailing: Icon(
              _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: kTextSecondary,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.body,
                  style: memberDashboardBodyStyle.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: kTextPrimary,
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

class _RescheduleHistoryCard extends StatelessWidget {
  const _RescheduleHistoryCard({required this.history});

  final List<RescheduleHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return _DetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reschedule History',
            style: dashText(const TextStyle(
              color: kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            )),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < history.length; i++) ...[
            if (i > 0) const Divider(height: 18),
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
          style: dashText(const TextStyle(
            color: kTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          )),
        ),
        if (entry.rescheduledAt != null) ...[
          const SizedBox(height: 2),
          Text(
            formatRequestShortDate(entry.rescheduledAt!),
            style: memberDashboardMetaStyle.copyWith(fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 6),
        if (entry.fromEventDate != null)
          _CompactInfoRow(
            'Previous date',
            formatRequestDate(entry.fromEventDate!),
          ),
        if (entry.toEventDate != null)
          _CompactInfoRow('New date', formatRequestDate(entry.toEventDate!)),
        if (entry.fromStartTime != null && entry.fromStartTime!.isNotEmpty)
          _CompactInfoRow(
            'Previous time',
            '${entry.fromStartTime}${entry.fromEndTime != null ? ' – ${entry.fromEndTime}' : ''}',
          ),
        if (entry.toStartTime != null && entry.toStartTime!.isNotEmpty)
          _CompactInfoRow(
            'New time',
            '${entry.toStartTime}${entry.toEndTime != null ? ' – ${entry.toEndTime}' : ''}',
          ),
        if (entry.previousStatus != null)
          _CompactInfoRow('Previous status', entry.previousStatus!),
        if (entry.rejectionReason != null &&
            entry.rejectionReason!.trim().isNotEmpty)
          _CompactInfoRow('Rejection reason', entry.rejectionReason!.trim()),
        const _CompactInfoRow('Resubmission', 'Pending admin review'),
      ],
    );
  }
}
