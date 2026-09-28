import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/registration_success_dialog.dart';

/// Review rescheduled event details before resubmitting to admin.
class RescheduleReviewScreen extends StatefulWidget {
  const RescheduleReviewScreen({
    super.key,
    required this.request,
    required this.newDate,
    required this.startTime,
    required this.endTime,
    required this.slotLabel,
  });

  final ServiceRequest request;
  final DateTime newDate;
  final String startTime;
  final String endTime;
  final String slotLabel;

  @override
  State<RescheduleReviewScreen> createState() => _RescheduleReviewScreenState();
}

class _RescheduleReviewScreenState extends State<RescheduleReviewScreen> {
  bool _submitting = false;
  String? _error;

  bool get _wasApproved => widget.request.requestStatus == RequestStatus.approved;
  bool get _wasRejected => widget.request.requestStatus == RequestStatus.rejected;

  Future<void> _resubmit() async {
    if (_submitting) return;
    final id = widget.request.requestId;
    if (id == null) {
      setState(() => _error = 'Invalid request ID.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await memberDataController.rescheduleServiceRequest(
        requestId: id,
        eventDate: widget.newDate,
        startTime: widget.startTime,
        endTime: widget.endTime,
      );
      if (!mounted) return;
      await showRegistrationSuccessDialog(
        context,
        title: 'Request resubmitted',
        message:
            'Your updated schedule has been sent to ACCESS for review. '
            'You will be notified once an administrator responds.',
        confirmLabel: 'OK',
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final originalDate = req.originalEventDate ?? req.eventDate;
    final originalTime = req.startTime != null && req.startTime!.isNotEmpty
        ? '${req.startTime}${req.endTime != null ? ' – ${req.endTime}' : ''}'
        : null;

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
          'Review & Resubmit',
          style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 17),
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
          _RescheduleComparisonHero(
            eventName: req.eventName,
            originalDate: formatRequestDate(originalDate),
            originalTime: originalTime,
            newDate: formatRequestDate(widget.newDate),
            newTime: '${widget.startTime} – ${widget.endTime}',
            slotLabel: widget.slotLabel,
          ),
          const SizedBox(height: 16),
          Text(
            'Confirm your updated event schedule before resubmitting.',
            style: memberDashboardSectionSubtitleStyle,
          ),
          if (_wasApproved) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kYellowDim,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kYellow.withValues(alpha: 0.35)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: kYellow, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This request was previously approved. Rescheduling will reset it to '
                      'Pending and requires administrator approval again.',
                      style: TextStyle(color: kTextPrimary, fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kRedDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kRed.withValues(alpha: 0.35)),
              ),
              child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 13)),
            ),
            const SizedBox(height: 14),
          ],
          MemberDashboardCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Original Schedule', style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16)),
                const SizedBox(height: 12),
                _ReviewRow('Event', req.eventName),
                _ReviewRow('Date', formatRequestDate(originalDate)),
                if (req.startTime != null && req.startTime!.isNotEmpty)
                  _ReviewRow('Time', '${req.startTime}${req.endTime != null ? ' – ${req.endTime}' : ''}'),
                if (_wasRejected) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Rejection reason',
                    style: TextStyle(color: kTextSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    req.rejectionReason?.trim().isNotEmpty == true
                        ? req.rejectionReason!.trim()
                        : 'No reason provided.',
                    style: const TextStyle(color: kRed, fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          MemberDashboardCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('New Schedule', style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Pending review',
                        style: TextStyle(color: kAccent, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ReviewRow('Date', formatRequestDate(widget.newDate)),
                _ReviewRow('Coverage window', widget.slotLabel),
                _ReviewRow('Time', '${widget.startTime} – ${widget.endTime}'),
                if (req.location != null && req.location!.isNotEmpty)
                  _ReviewRow('Venue', req.location!),
              ],
            ),
          ),
          const SizedBox(height: 28),
          MemberDashboardPrimaryButton(
            label: _submitting ? 'Submitting…' : 'Resubmit Request',
            icon: _submitting ? null : Icons.send_rounded,
            onPressed: _submitting ? null : _resubmit,
          ),
          if (_submitting)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kMemberPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RescheduleComparisonHero extends StatelessWidget {
  const _RescheduleComparisonHero({
    required this.eventName,
    required this.originalDate,
    required this.originalTime,
    required this.newDate,
    required this.newTime,
    required this.slotLabel,
  });

  final String eventName;
  final String originalDate;
  final String? originalTime;
  final String newDate;
  final String newTime;
  final String slotLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: kMemberDarkHeroGradient,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eventName,
            style: dashText(const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.2,
            )),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScheduleColumn(
                  label: 'Current',
                  date: originalDate,
                  time: originalTime,
                  muted: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              Expanded(
                child: _ScheduleColumn(
                  label: 'New',
                  date: newDate,
                  time: newTime,
                  subtitle: slotLabel,
                  muted: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleColumn extends StatelessWidget {
  const _ScheduleColumn({
    required this.label,
    required this.date,
    required this.muted,
    this.time,
    this.subtitle,
  });

  final String label;
  final String date;
  final String? time;
  final String? subtitle;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: muted ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: muted ? 0.12 : 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: dashText(TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            )),
          ),
          const SizedBox(height: 6),
          Text(
            date,
            style: dashText(TextStyle(
              color: Colors.white.withValues(alpha: muted ? 0.85 : 1),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            )),
          ),
          if (time != null && time!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              time!,
              style: dashText(TextStyle(
                color: Colors.white.withValues(alpha: muted ? 0.7 : 0.9),
                fontSize: 12,
              )),
            ),
          ],
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: dashText(TextStyle(
                color: kAccent.withValues(alpha: 0.95),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);

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
            style: const TextStyle(color: kTextSecondary, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: kTextPrimary, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
