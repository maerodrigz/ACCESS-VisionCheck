import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/utils/schedule_time_utils.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';
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
  static const _inputRadius = 13.0;
  static const _cardRadius = 16.0;
  static const _fieldGap = 14.0;

  final _formKey = GlobalKey<FormState>();
  final _eventNameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _specialInstructionsCtrl = TextEditingController();

  DateTime? _eventDate;
  bool _submitting = false;
  String? _error;
  bool _photoCoverage = false;
  bool _videoCoverage = false;
  String? _coverageError;

  bool get _eventSectionReady =>
      _eventNameCtrl.text.trim().isNotEmpty &&
      _eventDate != null &&
      _startTimeCtrl.text.trim().isNotEmpty &&
      _endTimeCtrl.text.trim().isNotEmpty &&
      _venueCtrl.text.trim().isNotEmpty &&
      _descriptionCtrl.text.trim().isNotEmpty;

  bool get _requirementsComplete => _photoCoverage || _videoCoverage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEventDate;
    if (initial != null) {
      _eventDate = DateTime(initial.year, initial.month, initial.day);
      _dateCtrl.text = formatRequestDate(_eventDate!);
    }
    for (final c in [_eventNameCtrl, _venueCtrl, _descriptionCtrl, _specialInstructionsCtrl]) {
      c.addListener(_onFieldsChanged);
    }
    _startTimeCtrl.addListener(_onFieldsChanged);
    _endTimeCtrl.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_eventNameCtrl, _venueCtrl, _descriptionCtrl, _specialInstructionsCtrl]) {
      c.removeListener(_onFieldsChanged);
    }
    _startTimeCtrl.removeListener(_onFieldsChanged);
    _endTimeCtrl.removeListener(_onFieldsChanged);
    _eventNameCtrl.dispose();
    _dateCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _venueCtrl.dispose();
    _descriptionCtrl.dispose();
    _specialInstructionsCtrl.dispose();
    super.dispose();
  }

  String _composeRequirementsPayload() {
    final coverageParts = <String>[];
    if (_photoCoverage) coverageParts.add('Photo');
    if (_videoCoverage) coverageParts.add('Video');
    final buffer = StringBuffer('Coverage needed: ${coverageParts.join(' and ')}');
    final instructions = _specialInstructionsCtrl.text.trim();
    if (instructions.isNotEmpty) {
      buffer.writeln();
      buffer.write('Special instructions: $instructions');
    }
    return buffer.toString();
  }

  void _togglePhoto() {
    setState(() {
      _photoCoverage = !_photoCoverage;
      if (_photoCoverage || _videoCoverage) _coverageError = null;
    });
  }

  void _toggleVideo() {
    setState(() {
      _videoCoverage = !_videoCoverage;
      if (_photoCoverage || _videoCoverage) _coverageError = null;
    });
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
    if (!_photoCoverage && !_videoCoverage) {
      setState(() => _coverageError = 'Select at least one coverage type (Photo or Video).');
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_photoCoverage && !_videoCoverage) return;

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
        requirements: _composeRequirementsPayload(),
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
    final hPad = mobilePagePaddingOf(context);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextPrimary),
          onPressed: _submitting ? null : () => Navigator.pop(context),
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
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 28),
            children: [
              const _FormIntroStrip(),
              const SizedBox(height: 14),
              _TwoStepProgressIndicator(
                eventComplete: _eventSectionReady,
                requirementsComplete: _requirementsComplete,
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kRedDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kRed.withValues(alpha: 0.35)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              _FormSectionHeading(
                title: 'Event Information',
                icon: Icons.event_rounded,
                iconColor: kAccent,
              ),
              const SizedBox(height: 10),
              _FormSectionCard(
                radius: _cardRadius,
                child: Column(
                  children: [
                    _DocRequestFormField(
                      label: 'Event Name',
                      controller: _eventNameCtrl,
                      hint: 'Leadership Seminar',
                      icon: Icons.event_rounded,
                      iconColor: kAccent,
                      radius: _inputRadius,
                      validator: (v) => RegistrationValidators.required(v, label: 'Event name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: _fieldGap),
                    GestureDetector(
                      onTap: _pickDate,
                      child: AbsorbPointer(
                        child: _DocRequestFormField(
                          label: 'Event Date',
                          controller: _dateCtrl,
                          hint: 'Select event date',
                          icon: Icons.calendar_month_rounded,
                          iconColor: kAccent,
                          radius: _inputRadius,
                          validator: (_) => _eventDate == null ? 'Event date is required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: _fieldGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(_startTimeCtrl),
                            child: AbsorbPointer(
                              child: _DocRequestFormField(
                                label: 'Start Time',
                                controller: _startTimeCtrl,
                                hint: '9:00 AM',
                                icon: Icons.schedule_rounded,
                                iconColor: kYellow,
                                radius: _inputRadius,
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
                              child: _DocRequestFormField(
                                label: 'End Time',
                                controller: _endTimeCtrl,
                                hint: '5:00 PM',
                                icon: Icons.schedule_rounded,
                                iconColor: kYellow,
                                radius: _inputRadius,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'End time is required' : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _fieldGap),
                    _DocRequestFormField(
                      label: 'Venue / Location',
                      controller: _venueCtrl,
                      hint: 'Main Auditorium',
                      icon: Icons.location_on_outlined,
                      iconColor: kCyan,
                      radius: _inputRadius,
                      validator: (v) => RegistrationValidators.required(v, label: 'Venue'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: _fieldGap),
                    _DocRequestFormField(
                      label: 'Event Description',
                      controller: _descriptionCtrl,
                      hint: 'Describe the event and its purpose...',
                      icon: Icons.notes_rounded,
                      iconColor: kAccent,
                      maxLines: 4,
                      minLines: 3,
                      alignTop: true,
                      radius: _inputRadius,
                      validator: (v) => RegistrationValidators.required(v, label: 'Event description'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FormSectionHeading(
                title: 'Documentation Requirements',
                icon: Icons.assignment_outlined,
                iconColor: kGreen,
              ),
              const SizedBox(height: 10),
              _FormSectionCard(
                radius: _cardRadius,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Coverage Needed',
                      style: TextStyle(
                        color: kTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _CoverageOptionCard(
                            label: 'Photo',
                            icon: Icons.photo_camera_rounded,
                            accentColor: kAccent,
                            accentDim: kBlueDim,
                            selected: _photoCoverage,
                            onTap: _togglePhoto,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CoverageOptionCard(
                            label: 'Video',
                            icon: Icons.videocam_rounded,
                            accentColor: kCyan,
                            accentDim: kCyanDim,
                            selected: _videoCoverage,
                            onTap: _toggleVideo,
                          ),
                        ),
                      ],
                    ),
                    if (_coverageError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _coverageError!,
                        style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                    const SizedBox(height: _fieldGap),
                    _DocRequestFormField(
                      label: 'Special Instructions (Optional)',
                      controller: _specialInstructionsCtrl,
                      hint:
                          'e.g. Capture keynote speakers, audience participation, awarding ceremonies, group photos, and event highlights.',
                      icon: Icons.tips_and_updates_outlined,
                      iconColor: kYellow,
                      maxLines: 4,
                      minLines: 3,
                      alignTop: true,
                      radius: _inputRadius,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _submitting
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: kAccent),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text(
                          'Submit Request',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: kMemberButtonPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_cardRadius),
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

class _FormSectionHeading extends StatelessWidget {
  const _FormSectionHeading({
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _FormIntroStrip extends StatelessWidget {
  const _FormIntroStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kBlueDim,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder.withValues(alpha: 0.9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAccent.withValues(alpha: 0.22)),
            ),
            child: const Icon(Icons.event_note_rounded, color: kAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request Event Coverage',
                  style: memberDashboardSectionTitleStyle.copyWith(fontSize: 15, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  'Provide your event details and documentation requirements.',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    height: 1.35,
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

class _TwoStepProgressIndicator extends StatelessWidget {
  const _TwoStepProgressIndicator({
    required this.eventComplete,
    required this.requirementsComplete,
  });

  final bool eventComplete;
  final bool requirementsComplete;

  @override
  Widget build(BuildContext context) {
    final step2Active = eventComplete && !requirementsComplete;
    final step2Done = requirementsComplete;

    final step1State = eventComplete
        ? _StepVisualState.done
        : _StepVisualState.active;

    return Row(
      children: [
        Expanded(child: _StepNode(stepIndex: 1, label: 'Event Details', state: step1State)),
        _StepConnector(filled: eventComplete),
        Expanded(
          child: _StepNode(
            stepIndex: 2,
            label: 'Requirements',
            state: step2Done
                ? _StepVisualState.done
                : (step2Active ? _StepVisualState.active : _StepVisualState.upcoming),
          ),
        ),
      ],
    );
  }
}

enum _StepVisualState { done, active, upcoming }

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.stepIndex,
    required this.label,
    required this.state,
  });

  final int stepIndex;
  final String label;
  final _StepVisualState state;

  @override
  Widget build(BuildContext context) {
    final labelColor = switch (state) {
      _StepVisualState.done => kTextPrimary,
      _StepVisualState.active => kAccent,
      _StepVisualState.upcoming => kTextSecondary,
    };

    Widget dot;
    if (state == _StepVisualState.done) {
      dot = Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      );
    } else {
      final isActive = state == _StepVisualState.active;
      dot = Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? kAccent : kSurfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: isActive ? kAccent : kBorder),
        ),
        child: Text(
          '$stepIndex',
          style: TextStyle(
            color: isActive ? Colors.white : kIconInactive,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: state == _StepVisualState.active || state == _StepVisualState.done
                ? FontWeight.w700
                : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
      child: SizedBox(
        width: 32,
        child: Divider(
          height: 2,
          thickness: 2,
          color: filled ? kAccent : kBorder,
        ),
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({required this.child, required this.radius});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kBorder.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DocRequestFormField extends StatelessWidget {
  const _DocRequestFormField({
    required this.label,
    required this.controller,
    required this.radius,
    this.hint,
    this.icon,
    this.iconColor = kTextSecondary,
    this.maxLines = 1,
    this.minLines = 1,
    this.alignTop = false,
    this.validator,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final Color iconColor;
  final int maxLines;
  final int minLines;
  final bool alignTop;
  final double radius;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: kTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          validator: validator,
          textInputAction: textInputAction,
          textAlignVertical: alignTop ? TextAlignVertical.top : TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: kTextSecondary.withValues(alpha: 0.85), fontSize: 14),
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(icon, color: iconColor, size: 21),
                  )
                : null,
            prefixIconConstraints: icon != null
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : null,
            filled: true,
            fillColor: kSurface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: multiline ? 12 : 14,
            ),
            constraints: multiline ? null : const BoxConstraints(minHeight: 52),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: kBorder.withValues(alpha: 0.95)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: kBorder.withValues(alpha: 0.95)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: const BorderSide(color: kAccent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: const BorderSide(color: kRed),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverageOptionCard extends StatelessWidget {
  const _CoverageOptionCard({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.accentDim,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final Color accentDim;
  final bool selected;
  final VoidCallback onTap;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accentColor.withValues(alpha: 0.08) : kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accentColor : kBorder.withValues(alpha: 0.95),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentDim,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: accentColor.withValues(alpha: 0.22)),
                    ),
                    child: Icon(icon, size: 22, color: accentColor),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: selected ? 1 : 0,
                    child: Icon(Icons.check_circle_rounded, size: 18, color: accentColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? kTextPrimary : kTextSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
