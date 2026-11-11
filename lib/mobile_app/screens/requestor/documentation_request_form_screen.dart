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

const _kCardRadius = 14.0;
const _kInputRadius = 12.0;
const _kFieldGap = 12.0;

/// Documentation request submission form for requestors.
class DocumentationRequestFormScreen extends StatefulWidget {
  const DocumentationRequestFormScreen({super.key, this.initialEventDate});

  /// Pre-fill event date when opened from the campus calendar.
  final DateTime? initialEventDate;

  @override
  State<DocumentationRequestFormScreen> createState() =>
      _DocumentationRequestFormScreenState();
}

class _DocumentationRequestFormScreenState
    extends State<DocumentationRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _eventNameKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _startTimeKey = GlobalKey();
  final _endTimeKey = GlobalKey();
  final _venueKey = GlobalKey();
  final _coverageKey = GlobalKey();
  final _additionalKey = GlobalKey();
  final _descriptionKey = GlobalKey();

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
  bool _additionalExpanded = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEventDate;
    if (initial != null) {
      _eventDate = DateTime(initial.year, initial.month, initial.day);
      _dateCtrl.text = formatRequestDate(_eventDate!);
    }
    for (final c in [
      _eventNameCtrl,
      _venueCtrl,
      _descriptionCtrl,
      _specialInstructionsCtrl,
    ]) {
      c.addListener(_onFieldsChanged);
    }
    _startTimeCtrl.addListener(_onFieldsChanged);
    _endTimeCtrl.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    if (!mounted) return;
    // Keep Additional Details open once the user has typed into it.
    if (!_additionalExpanded &&
        (_descriptionCtrl.text.trim().isNotEmpty ||
            _specialInstructionsCtrl.text.trim().isNotEmpty)) {
      setState(() => _additionalExpanded = true);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _eventNameCtrl,
      _venueCtrl,
      _descriptionCtrl,
      _specialInstructionsCtrl,
    ]) {
      c.removeListener(_onFieldsChanged);
    }
    _startTimeCtrl.removeListener(_onFieldsChanged);
    _endTimeCtrl.removeListener(_onFieldsChanged);
    _scrollController.dispose();
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
    final buffer =
        StringBuffer('Coverage needed: ${coverageParts.join(' and ')}');
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

  Future<void> _ensureVisible(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  Future<void> _scrollToFirstIssue({
    required bool coverageMissing,
    required bool descriptionInvalid,
  }) async {
    if (_eventNameCtrl.text.trim().isEmpty) {
      await _ensureVisible(_eventNameKey);
      return;
    }
    if (_eventDate == null) {
      await _ensureVisible(_dateKey);
      return;
    }
    if (_startTimeCtrl.text.trim().isEmpty) {
      await _ensureVisible(_startTimeKey);
      return;
    }
    if (_endTimeCtrl.text.trim().isEmpty) {
      await _ensureVisible(_endTimeKey);
      return;
    }
    if (_venueCtrl.text.trim().isEmpty) {
      await _ensureVisible(_venueKey);
      return;
    }
    if (coverageMissing) {
      await _ensureVisible(_coverageKey);
      return;
    }
    if (descriptionInvalid) {
      if (!_additionalExpanded) {
        setState(() => _additionalExpanded = true);
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      await _ensureVisible(_descriptionKey);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final coverageMissing = !_photoCoverage && !_videoCoverage;
    if (coverageMissing) {
      setState(
        () => _coverageError =
            'Select at least one coverage type (Photo or Video).',
      );
    }

    final descriptionInvalid = _descriptionCtrl.text.trim().isEmpty;
    if (descriptionInvalid && !_additionalExpanded) {
      setState(() => _additionalExpanded = true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    final formOk = _formKey.currentState!.validate();
    if (!formOk || coverageMissing) {
      await _scrollToFirstIssue(
        coverageMissing: coverageMissing,
        descriptionInvalid: descriptionInvalid,
      );
      return;
    }

    if (_eventDate == null) {
      setState(() => _error = 'Please select the event date.');
      await _ensureVisible(_dateKey);
      return;
    }

    final startTime = _startTimeCtrl.text.trim();
    final endTime = _endTimeCtrl.text.trim();
    final timeError =
        validateRequestTimeFields(startTime: startTime, endTime: endTime);
    if (timeError != null) {
      setState(() => _error = timeError);
      await _ensureVisible(_startTimeKey);
      return;
    }

    final conflict = campusTimeConflictMessage(
      eventDate: _eventDate!,
      startTime: startTime,
      endTime: endTime,
      campusEvents: appState.events.map((event) {
        final day = DateTime(
          event.startDate.year,
          event.startDate.month,
          event.startDate.day,
        );
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
      await _ensureVisible(_dateKey);
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextPrimary),
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'New Documentation Request',
          style: dashText(const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          )),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20 + bottomInset),
            children: [
              Text(
                'Event Details',
                style: dashText(const TextStyle(
                  color: kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
              ),
              const SizedBox(height: 4),
              Text(
                'Tell us when and where your event will happen.',
                style: memberDashboardBodyStyle.copyWith(
                  fontSize: 13,
                  color: kTextSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kRedDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kRed.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: kRed, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyedSubtree(
                      key: _eventNameKey,
                      child: _DocRequestFormField(
                        label: 'Event Name',
                        requiredMark: true,
                        controller: _eventNameCtrl,
                        hint: 'Enter event name',
                        icon: Icons.event_rounded,
                        iconColor: kAccent,
                        validator: (v) => RegistrationValidators.required(
                          v,
                          label: 'Event name',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: _kFieldGap),
                    KeyedSubtree(
                      key: _dateKey,
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: _DocRequestFormField(
                            label: 'Event Date',
                            requiredMark: true,
                            controller: _dateCtrl,
                            hint: 'Select event date',
                            icon: Icons.calendar_month_rounded,
                            iconColor: kAccent,
                            validator: (_) => _eventDate == null
                                ? 'Event date is required'
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: _kFieldGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: KeyedSubtree(
                            key: _startTimeKey,
                            child: GestureDetector(
                              onTap: () => _pickTime(_startTimeCtrl),
                              child: AbsorbPointer(
                                child: _DocRequestFormField(
                                  label: 'Start Time',
                                  requiredMark: true,
                                  controller: _startTimeCtrl,
                                  hint: '9:00 AM',
                                  icon: Icons.schedule_rounded,
                                  iconColor: kYellow,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Start time is required'
                                          : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: KeyedSubtree(
                            key: _endTimeKey,
                            child: GestureDetector(
                              onTap: () => _pickTime(_endTimeCtrl),
                              child: AbsorbPointer(
                                child: _DocRequestFormField(
                                  label: 'End Time',
                                  requiredMark: true,
                                  controller: _endTimeCtrl,
                                  hint: '5:00 PM',
                                  icon: Icons.schedule_rounded,
                                  iconColor: kYellow,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'End time is required'
                                          : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _kFieldGap),
                    KeyedSubtree(
                      key: _venueKey,
                      child: _DocRequestFormField(
                        label: 'Venue / Location',
                        requiredMark: true,
                        controller: _venueCtrl,
                        hint: 'Enter event location',
                        icon: Icons.location_on_outlined,
                        iconColor: kCyan,
                        validator: (v) =>
                            RegistrationValidators.required(v, label: 'Venue'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: 14),
                    KeyedSubtree(
                      key: _coverageKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Coverage Needed',
                                style: dashText(const TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                )),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '*',
                                style: TextStyle(
                                  color: kRed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
                              style: const TextStyle(
                                color: kRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _additionalKey,
                child: _AdditionalDetailsSection(
                  expanded: _additionalExpanded,
                  onToggle: () =>
                      setState(() => _additionalExpanded = !_additionalExpanded),
                  descriptionKey: _descriptionKey,
                  descriptionCtrl: _descriptionCtrl,
                  specialInstructionsCtrl: _specialInstructionsCtrl,
                ),
              ),
              const SizedBox(height: 18),
              _submitting
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: kAccent,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'Submit Request',
                          style: dashText(const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white,
                          )),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: kCyan,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_kCardRadius),
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

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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

class _AdditionalDetailsSection extends StatelessWidget {
  const _AdditionalDetailsSection({
    required this.expanded,
    required this.onToggle,
    required this.descriptionKey,
    required this.descriptionCtrl,
    required this.specialInstructionsCtrl,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final GlobalKey descriptionKey;
  final TextEditingController descriptionCtrl;
  final TextEditingController specialInstructionsCtrl;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Additional Details (Optional)',
                        style: dashText(const TextStyle(
                          color: kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        )),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: kTextSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Keep fields mounted (preserves text + Form validation) without
          // occupying space while collapsed.
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: expanded ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !expanded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    KeyedSubtree(
                      key: descriptionKey,
                      child: _DocRequestFormField(
                        label: 'Event Description',
                        requiredMark: true,
                        controller: descriptionCtrl,
                        hint: 'Describe the event and its purpose...',
                        icon: Icons.notes_rounded,
                        iconColor: kAccent,
                        maxLines: 3,
                        minLines: 2,
                        alignTop: true,
                        validator: (v) => RegistrationValidators.required(
                          v,
                          label: 'Event description',
                        ),
                      ),
                    ),
                    const SizedBox(height: _kFieldGap),
                    _DocRequestFormField(
                      label: 'Special Instructions (Optional)',
                      controller: specialInstructionsCtrl,
                      hint:
                          'e.g. Capture keynote speakers, audience participation, awarding ceremonies.',
                      icon: Icons.tips_and_updates_outlined,
                      iconColor: kYellow,
                      maxLines: 3,
                      minLines: 2,
                      alignTop: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocRequestFormField extends StatelessWidget {
  const _DocRequestFormField({
    required this.label,
    required this.controller,
    this.requiredMark = false,
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
  final bool requiredMark;
  final String? hint;
  final IconData? icon;
  final Color iconColor;
  final int maxLines;
  final int minLines;
  final bool alignTop;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dashText(const TextStyle(
                  color: kTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
              ),
            ),
            if (requiredMark) ...[
              const SizedBox(width: 3),
              const Text(
                '*',
                style: TextStyle(color: kRed, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          validator: validator,
          textInputAction: textInputAction,
          textAlignVertical:
              alignTop ? TextAlignVertical.top : TextAlignVertical.center,
          style: dashText(const TextStyle(
            color: kTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          )),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: kTextSecondary.withValues(alpha: 0.85),
              fontSize: 13.5,
            ),
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(icon, color: iconColor, size: 20),
                  )
                : null,
            prefixIconConstraints: icon != null
                ? const BoxConstraints(minWidth: 42, minHeight: 42)
                : null,
            filled: true,
            fillColor: kSurface,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: multiline ? 10 : 12,
            ),
            constraints: multiline ? null : const BoxConstraints(minHeight: 46),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: const BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: const BorderSide(color: kAccent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: const BorderSide(color: kRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kInputRadius),
              borderSide: const BorderSide(color: kRed, width: 1.5),
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
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accentColor.withValues(alpha: 0.08) : kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accentColor : kBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentDim,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: dashText(TextStyle(
                    color: selected ? kTextPrimary : kTextSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  )),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: selected ? 1 : 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
