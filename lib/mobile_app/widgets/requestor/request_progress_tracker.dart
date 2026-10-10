import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Visual lifecycle tracker for a documentation request (frontend-only).
class RequestTrackStep {
  const RequestTrackStep({
    required this.label,
    this.date,
    required this.state,
    this.accent = kAccent,
  });

  final String label;
  final DateTime? date;
  final RequestTrackStepState state;
  final Color accent;
}

enum RequestTrackStepState { complete, current, upcoming, declined }

class RequestTrack {
  RequestTrack({required this.steps, this.currentLabel, this.declined = false});

  final List<RequestTrackStep> steps;
  final String? currentLabel;
  final bool declined;

  static RequestTrack forRequest(ServiceRequest request) {
    final status = request.requestStatus;
    final submitted = request.submissionDate;
    final updated = request.updatedAt;

    if (status == RequestStatus.rejected) {
      return RequestTrack(
        declined: true,
        currentLabel: 'Declined',
        steps: [
          RequestTrackStep(
            label: 'Submitted',
            date: submitted,
            state: RequestTrackStepState.complete,
          ),
          RequestTrackStep(
            label: 'Reviewed',
            date: updated ?? submitted,
            state: RequestTrackStepState.complete,
            accent: kYellow,
          ),
          RequestTrackStep(
            label: 'Declined',
            date: updated,
            state: RequestTrackStepState.declined,
            accent: kRed,
          ),
        ],
      );
    }

    final steps = <RequestTrackStep>[
      RequestTrackStep(
        label: 'Submitted',
        date: submitted,
        state: _stateForIndex(0, status),
      ),
      RequestTrackStep(
        label: 'In review',
        date: status == RequestStatus.pending ? null : (updated ?? submitted),
        state: _stateForIndex(1, status),
        accent: kYellow,
      ),
      RequestTrackStep(
        label: 'Approved',
        date: status == RequestStatus.approved || status == RequestStatus.completed
            ? updated
            : null,
        state: _stateForIndex(2, status),
        accent: kGreen,
      ),
      RequestTrackStep(
        label: 'Completed',
        date: status == RequestStatus.completed ? updated : null,
        state: _stateForIndex(3, status),
        accent: kCyan,
      ),
    ];

    return RequestTrack(
      currentLabel: status.label,
      steps: steps,
    );
  }

  static RequestTrackStepState _stateForIndex(int index, RequestStatus status) {
    if (status == RequestStatus.completed) {
      return RequestTrackStepState.complete;
    }
    final active = switch (status) {
      RequestStatus.pending => 1,
      RequestStatus.approved => 2,
      RequestStatus.completed => 3,
      RequestStatus.rejected => 1,
    };
    if (index < active) return RequestTrackStepState.complete;
    if (index == active) return RequestTrackStepState.current;
    return RequestTrackStepState.upcoming;
  }
}

class RequestProgressTracker extends StatelessWidget {
  const RequestProgressTracker({
    super.key,
    required this.request,
    this.compact = false,
  });

  final ServiceRequest request;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final track = RequestTrack.forRequest(request);
    if (compact) {
      return _CompactRequestTrack(track: track);
    }
    return _ExpandedRequestTrack(track: track);
  }
}

class _CompactRequestTrack extends StatelessWidget {
  const _CompactRequestTrack({required this.track});

  final RequestTrack track;

  @override
  Widget build(BuildContext context) {
    final steps = track.steps;
    final current = steps.cast<RequestTrackStep?>().firstWhere(
          (s) => s!.state == RequestTrackStepState.current ||
              s.state == RequestTrackStepState.declined,
          orElse: () => steps.isNotEmpty ? steps.last : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _Dot(step: steps[i], size: 8),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: steps[i].state == RequestTrackStepState.complete ||
                            steps[i].state == RequestTrackStepState.current
                        ? steps[i].accent.withValues(alpha: 0.45)
                        : kBorder,
                  ),
                ),
            ],
          ],
        ),
        if (current != null) ...[
          const SizedBox(height: 6),
          Text(
            track.declined
                ? 'Request declined'
                : 'Tracking: ${current.label}',
            style: memberDashboardMetaStyle.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: current.state == RequestTrackStepState.declined
                  ? kRed
                  : kTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.step, this.size = 10});

  final RequestTrackStep step;
  final double size;

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
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? color : kBorder,
          width: filled ? 0 : 1.5,
        ),
      ),
    );
  }
}

class _ExpandedRequestTrack extends StatelessWidget {
  const _ExpandedRequestTrack({required this.track});

  final RequestTrack track;

  @override
  Widget build(BuildContext context) {
    final steps = track.steps;

    return MemberDashboardCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Request tracking',
                  style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
                ),
              ),
              if (track.currentLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    track.currentLabel!,
                    style: const TextStyle(
                      color: kAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Follow your request from submission through approval and completion.',
            style: memberDashboardMetaStyle.copyWith(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              isLast: i == steps.length - 1,
              connectorActive: i < steps.length - 1 &&
                  steps[i + 1].state != RequestTrackStepState.upcoming,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.connectorActive,
  });

  final RequestTrackStep step;
  final bool isLast;
  final bool connectorActive;

  @override
  Widget build(BuildContext context) {
    final active = step.state == RequestTrackStepState.current ||
        step.state == RequestTrackStepState.declined;
    final done = step.state == RequestTrackStepState.complete ||
        step.state == RequestTrackStepState.declined;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done
                    ? step.accent.withValues(alpha: 0.15)
                    : kSurfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? step.accent : kBorder,
                  width: active ? 2 : 1,
                ),
              ),
              child: Center(
                child: done
                    ? Icon(
                        step.state == RequestTrackStepState.declined
                            ? Icons.close_rounded
                            : Icons.check_rounded,
                        size: 13,
                        color: step.accent,
                      )
                    : active
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: step.accent,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: connectorActive
                    ? step.accent.withValues(alpha: 0.35)
                    : kBorder,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: TextStyle(
                    color: done || active ? kTextPrimary : kTextSecondary,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.date != null
                      ? formatRequestShortDate(step.date!)
                      : switch (step.state) {
                          RequestTrackStepState.current => 'In progress',
                          RequestTrackStepState.upcoming => 'Not started yet',
                          RequestTrackStepState.declined => 'See details below',
                          RequestTrackStepState.complete => 'Done',
                        },
                  style: memberDashboardMetaStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
