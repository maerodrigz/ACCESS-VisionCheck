import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/schedule_time_utils.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/widgets/registration_success_dialog.dart';

/// Documentation request submission form for requestors.
class DocumentationRequestFormScreen extends StatefulWidget {
  const DocumentationRequestFormScreen({super.key, this.initialEventDate});

  /// Pre-fill event date when opened from the campus calendar.
  final DateTime? initialEventDate;

  @override
  State<DocumentationRequestFormScreen> createState() =>
      _DocumentationRequestFormScreenState();
}

class _DocumentationRequestFormScreenState extends State<DocumentationRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController();

  DateTime? _eventDate;
  bool _submitting = false;
  String? _error;

  bool get _eventSectionReady =>
      _eventNameCtrl.text.trim().isNotEmpty &&
      _eventDate != null &&
      _venueCtrl.text.trim().isNotEmpty &&
      _descriptionCtrl.text.trim().isNotEmpty;

  bool get _requirementsSectionReady => _requirementsCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEventDate;
    if (initial != null) {
      _eventDate = DateTime(initial.year, initial.month, initial.day);
      _dateCtrl.text = formatRequestDate(_eventDate!);
    }
    for (final c in [_eventNameCtrl, _venueCtrl, _descriptionCtrl, _requirementsCtrl]) {
      c.addListener(_onFieldsChanged);
    }
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_eventNameCtrl, _venueCtrl, _descriptionCtrl, _requirementsCtrl]) {
      c.removeListener(_onFieldsChanged);
    }
    _eventNameCtrl.dispose();
    _dateCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _venueCtrl.dispose();
    _descriptionCtrl.dispose();
    _requirementsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _eventDate = picked;
        _dateCtrl.text = formatRequestDate(picked);
      });
    }
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final ap = picked.period == DayPeriod.am ? 'AM' : 'PM';
      ctrl.text = '$hour:$minute $ap';
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null) {
      setState(() => _error = 'Please select the event date.');
      return;
    }

    final startTime = _startTimeCtrl.text.trim();
    final endTime = _endTimeCtrl.text.trim();
    final timeError = validateRequestTimeFields(startTime: startTime, endTime: endTime);
    if (timeError != null) {
      setState(() => _error = timeError);
      return;
    }

    final conflict = campusTimeConflictMessage(
      eventDate: _eventDate!,
      startTime: startTime,
      endTime: endTime,
      campusEvents: appState.events.map((event) {
        final day = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
        return (
          day: day,
          start: event.startDate,
          end: event.endDate,
          title: event.title,
        );
      }),
    );
    if (conflict != null) {
      setState(() => _error = conflict);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await memberDataController.createServiceRequest(
        title: _eventNameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        eventDate: _eventDate!,
        venue: _venueCtrl.text.trim(),
        startTime: startTime,
        endTime: endTime,
        requirements: _requirementsCtrl.text.trim(),
      );
      if (!mounted) return;
      await showRegistrationSuccessDialog(
        context,
        title: 'Request submitted',
        message:
            'Your documentation request has been sent to ACCESS. '
            'You will be notified when an administrator reviews it.',
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
          'New Documentation Request',
          style: TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: mobileScrollPadding(context),
            children: [
              _FormIntroHero(),
              const SizedBox(height: 14),
              _FormProgressRow(
                eventReady: _eventSectionReady,
                requirementsReady: _requirementsSectionReady,
              ),
              const SizedBox(height: 20),
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
                const SizedBox(height: 16),
              ],
              Text('Event Information', style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16)),
              const SizedBox(height: 10),
              MemberDashboardCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
              RegistrationFormField(
                label: 'Event Name',
                controller: _eventNameCtrl,
                hint: 'Leadership Seminar',
                icon: Icons.event_rounded,
                validator: (v) => RegistrationValidators.required(v, label: 'Event name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: RegistrationFormField(
                    label: 'Event Date',
                    controller: _dateCtrl,
                    hint: 'Select event date',
                    icon: Icons.calendar_month_rounded,
                    validator: (_) => _eventDate == null ? 'Event date is required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(_startTimeCtrl),
                      child: AbsorbPointer(
                        child: RegistrationFormField(
                          label: 'Start Time',
                          controller: _startTimeCtrl,
                          hint: '9:00 AM',
                          icon: Icons.schedule_rounded,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Start time is required' : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(_endTimeCtrl),
                      child: AbsorbPointer(
                        child: RegistrationFormField(
                          label: 'End Time',
                          controller: _endTimeCtrl,
                          hint: '5:00 PM',
                          icon: Icons.schedule_rounded,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'End time is required' : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RegistrationFormField(
                label: 'Venue / Location',
                controller: _venueCtrl,
                hint: 'Main Auditorium',
                icon: Icons.location_on_outlined,
                validator: (v) => RegistrationValidators.required(v, label: 'Venue'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              RegistrationFormField(
                label: 'Event Description',
                controller: _descriptionCtrl,
                hint: 'Describe the event, audience, and coverage expectations.',
                icon: Icons.notes_rounded,
                maxLines: 4,
                validator: (v) => RegistrationValidators.required(v, label: 'Event description'),
              ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Documentation Requirements',
                style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 10),
              MemberDashboardCard(
                padding: const EdgeInsets.all(16),
                child: RegistrationFormField(
                label: 'Photo / Video Coverage & Instructions',
                controller: _requirementsCtrl,
                hint: 'Requested photo/video coverage, special instructions, and other requirements.',
                icon: Icons.videocam_rounded,
                maxLines: 4,
                validator: (v) => RegistrationValidators.required(v, label: 'Documentation requirements'),
              ),
              ),
              const SizedBox(height: 28),
              _submitting
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
                      label: 'Submit Request',
                      icon: Icons.send_rounded,
                      onPressed: _submit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormIntroHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: kMemberDashboardAccentGradient,
        borderRadius: BorderRadius.circular(kMemberDashboardCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEW REQUEST',
            style: dashText(const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            )),
          ),
          const SizedBox(height: 8),
          Text(
            'Request event documentation',
            style: dashText(const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.15,
            )),
          ),
          const SizedBox(height: 6),
          Text(
            'Share event details so ACCESS can assign members for photo and video coverage. '
            'You may pick the same date as another campus event, but your start and end time must not overlap.',
            style: dashText(TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
            )),
          ),
        ],
      ),
    );
  }
}

class _FormProgressRow extends StatelessWidget {
  const _FormProgressRow({
    required this.eventReady,
    required this.requirementsReady,
  });

  final bool eventReady;
  final bool requirementsReady;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProgressStep(
            label: 'Event details',
            done: eventReady,
            active: !eventReady,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, size: 18, color: kIconInactive),
        const SizedBox(width: 8),
        Expanded(
          child: _ProgressStep(
            label: 'Requirements',
            done: requirementsReady,
            active: eventReady && !requirementsReady,
          ),
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done ? kGreen : (active ? kAccent : kIconInactive);
    final bg = done ? kGreenDim : (active ? kAccent.withValues(alpha: 0.08) : kSurfaceAlt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? kGreen.withValues(alpha: 0.35) : (active ? kAccent.withValues(alpha: 0.35) : kBorder),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: done || active ? kTextPrimary : kTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
