import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/screens/requestor/reschedule_review_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/request_list_skeleton.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/models/reschedule_models.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Pick an available documentation coverage date and time slot.
class RescheduleCalendarScreen extends StatefulWidget {
  const RescheduleCalendarScreen({super.key, required this.request});

  final ServiceRequest request;

  @override
  State<RescheduleCalendarScreen> createState() => _RescheduleCalendarScreenState();
}

class _RescheduleCalendarScreenState extends State<RescheduleCalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  CoverageTimeSlot? _selectedSlot;
  List<CoverageDay> _days = [];
  List<CoverageTimeSlot> _slots = [];
  bool _loadingMonth = true;
  bool _loadingSlots = false;
  String? _error;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  int? get _requestId => widget.request.requestId;

  bool get _wasApproved => widget.request.requestStatus == RequestStatus.approved;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _loadMonth();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  CoverageDay? _dayInfo(DateTime day) {
    for (final d in _days) {
      if (_sameDay(d.date, day)) return d;
    }
    return null;
  }

  Future<void> _loadMonth() async {
    setState(() {
      _loadingMonth = true;
      _error = null;
      _selectedSlot = null;
      _slots = [];
    });
    try {
      final days = await memberDataController.fetchCoverageAvailability(
        year: _focusedMonth.year,
        month: _focusedMonth.month,
        excludeRequestId: _requestId,
      );
      if (!mounted) return;
      setState(() {
        _days = days;
        _loadingMonth = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMonth = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _selectDay(DateTime day) async {
    final info = _dayInfo(day);
    if (info == null || !info.selectable) return;
    setState(() {
      _selectedDay = day;
      _selectedSlot = null;
      _loadingSlots = true;
      _slots = [];
    });
    try {
      final slots = await memberDataController.fetchCoverageSlots(
        date: day,
        excludeRequestId: _requestId,
      );
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _continueToReview() async {
    final day = _selectedDay;
    final slot = _selectedSlot;
    if (day == null || slot == null) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RescheduleReviewScreen(
          request: widget.request,
          newDate: day,
          startTime: slot.startTime,
          endTime: slot.endTime,
          slotLabel: slot.label,
        ),
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = (firstDay.weekday + 6) % 7;
    final rows = ((startWeekday + daysInMonth) / 7).ceil();

    final canContinue = _selectedDay != null && _selectedSlot != null;

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
          'Select New Schedule',
          style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          kMemberDashboardPagePadding,
          12,
          kMemberDashboardPagePadding,
          120,
        ),
        children: [
          _RescheduleCalendarHero(
            eventName: widget.request.eventName,
            wasApproved: _wasApproved,
          ),
          const SizedBox(height: 16),
          Text(
            'Choose an available date and time for documentation coverage.',
            style: memberDashboardSectionSubtitleStyle,
          ),
          if (_wasApproved) ...[
            const SizedBox(height: 12),
            _WarningBanner(
              message:
                  'Rescheduling an approved request requires administrator review again. '
                  'Your request will return to Pending status.',
            ),
          ],
          const SizedBox(height: 14),
          _LegendRow(),
          const SizedBox(height: 14),
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          _loadingMonth
              ? const RescheduleCalendarSkeleton()
              : MemberDashboardCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
                    children: [
                      Row(
                        children: [
                          _MonthNavButton(
                            icon: Icons.chevron_left_rounded,
                            onTap: () {
                              setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month - 1,
                                );
                              });
                              _loadMonth();
                            },
                          ),
                          Expanded(
                            child: Text(
                              '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                              style: memberDashboardCardTitleStyle.copyWith(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          _MonthNavButton(
                            icon: Icons.chevron_right_rounded,
                            onTap: () {
                              setState(() {
                                _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month + 1,
                                );
                              });
                              _loadMonth();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: _weekdays
                            .map(
                              (d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: memberDashboardMetaStyle.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(rows, (row) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: List.generate(7, (col) {
                              final dayNum = row * 7 + col - startWeekday + 1;
                              if (dayNum < 1 || dayNum > daysInMonth) {
                                return const Expanded(child: SizedBox(height: 46));
                              }
                              final date = DateTime(
                                _focusedMonth.year,
                                _focusedMonth.month,
                                dayNum,
                              );
                              final info = _dayInfo(date);
                              final level = info?.level ?? CoverageLevel.unavailable;
                              final selectable = info?.selectable ?? false;
                              final isSelected =
                                  _selectedDay != null && _sameDay(_selectedDay!, date);
                              final isToday = _sameDay(today, date);
                              return Expanded(
                                child: _AvailabilityDayCell(
                                  day: dayNum,
                                  level: level,
                                  isSelected: isSelected,
                                  isToday: isToday,
                                  selectable: selectable,
                                  onTap: selectable ? () => _selectDay(date) : null,
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
          if (_selectedDay != null) ...[
            const SizedBox(height: 18),
            Text('Time Slots', style: memberDashboardSectionTitleStyle.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              formatRequestDate(_selectedDay!),
              style: memberDashboardBodyStyle,
            ),
            const SizedBox(height: 12),
            MemberDashboardCard(
              padding: const EdgeInsets.all(12),
              child: _loadingSlots
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: kMemberPrimary, strokeWidth: 2.5),
                        ),
                      ),
                    )
                  : _slots.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: kYellow.withValues(alpha: 0.95), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No time slots available for this date. Try another day.',
                                  style: memberDashboardBodyStyle.copyWith(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: _slots
                              .map(
                                (slot) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _SlotTile(
                                    slot: slot,
                                    selected: _selectedSlot?.id == slot.id,
                                    onTap: slot.selectable
                                        ? () => setState(() => _selectedSlot = slot)
                                        : null,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            kMemberDashboardPagePadding,
            10,
            kMemberDashboardPagePadding,
            12,
          ),
          decoration: BoxDecoration(
            color: kSurface,
            border: Border(top: BorderSide(color: kBorder.withValues(alpha: 0.8))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canContinue) ...[
                Text(
                  '${formatRequestShortDate(_selectedDay!)} · ${_selectedSlot!.label}',
                  style: memberDashboardMetaStyle.copyWith(
                    color: kTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              MemberDashboardPrimaryButton(
                label: 'Review Schedule',
                icon: Icons.arrow_forward_rounded,
                onPressed: canContinue ? _continueToReview : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RescheduleCalendarHero extends StatelessWidget {
  const _RescheduleCalendarHero({
    required this.eventName,
    required this.wasApproved,
  });

  final String eventName;
  final bool wasApproved;

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
            'RESCHEDULE',
            style: dashText(const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            )),
          ),
          const SizedBox(height: 8),
          Text(
            eventName,
            style: dashText(const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            )),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            wasApproved
                ? 'Pick a new date. Your request will return to Pending for admin review.'
                : 'Pick a new coverage date and time slot, then confirm before resubmitting.',
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

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _LegendChip(label: 'Available', color: kGreen, background: kGreenDim),
        _LegendChip(label: 'Limited', color: kYellow, background: kYellowDim),
        _LegendChip(label: 'Unavailable', color: kTextSecondary, background: kSurfaceAlt),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AvailabilityDayCell extends StatelessWidget {
  const _AvailabilityDayCell({
    required this.day,
    required this.level,
    required this.isSelected,
    required this.isToday,
    required this.selectable,
    this.onTap,
  });

  final int day;
  final CoverageLevel level;
  final bool isSelected;
  final bool isToday;
  final bool selectable;
  final VoidCallback? onTap;

  Color get _accent => switch (level) {
        CoverageLevel.available => kGreen,
        CoverageLevel.limited => kYellow,
        CoverageLevel.unavailable => kTextSecondary,
      };

  Color get _background => switch (level) {
        CoverageLevel.available => kGreenDim,
        CoverageLevel.limited => kYellowDim,
        CoverageLevel.unavailable => kSurfaceAlt,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? kMemberPrimary : _background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? kMemberPrimary
                  : isToday
                      ? kAccent.withValues(alpha: 0.5)
                      : _accent.withValues(alpha: selectable ? 0.3 : 0.15),
            ),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected ? Colors.white : (selectable ? kTextPrimary : kTextSecondary),
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.selected, this.onTap});

  final CoverageTimeSlot slot;
  final bool selected;
  final VoidCallback? onTap;

  Color get _accent => switch (slot.level) {
        CoverageLevel.available => kGreen,
        CoverageLevel.limited => kYellow,
        CoverageLevel.unavailable => kTextSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = slot.selectable && onTap != null;
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            border: Border.all(
              color: selected ? kMemberPrimary : kBorder,
              width: selected ? 1.5 : 1,
            ),
            color: selected ? kMemberPrimary.withValues(alpha: 0.06) : null,
          ),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, color: enabled ? kAccent : kIconInactive, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slot.label, style: memberDashboardCardTitleStyle.copyWith(fontSize: 14)),
                    Text(
                      '${slot.startTime} – ${slot.endTime}',
                      style: memberDashboardBodyStyle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  slot.level.label,
                  style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded, color: kMemberPrimary, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurfaceAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 36, height: 36, child: Icon(icon, color: kTextPrimary, size: 22)),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kYellowDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kYellow.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: kYellow, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: kTextPrimary, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kRedDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRed.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: const TextStyle(color: kRed, fontSize: 13)),
    );
  }
}
