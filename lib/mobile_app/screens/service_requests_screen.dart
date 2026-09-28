import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/widgets/access_branding.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';

class ServiceRequestsScreen extends StatefulWidget {
  final String requesterName;
  const ServiceRequestsScreen({super.key, this.requesterName = 'Organization'});
  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Hero header ──────────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kSidebar, kSidebar.withValues(alpha: 0.92)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(kMobilePagePadding, 16, kMobilePagePadding, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AccessBrandMark(
            logoSize: 40,
            theme: AccessBrandTheme.dark,
            showTagline: true,
          ),
          const SizedBox(height: 20),
          const Text('Book Our Services', style: TextStyle(color: Colors.white,
            fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Professional event coverage by ACCESS student photographers.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(height: 20),
          ListenableBuilder(
            listenable: appState,
            builder: (_, __) {
              final mine = appState.serviceRequests
                .where((r) => r.requesterName == widget.requesterName).toList();
              final pending  = mine.where((r) => r.status == 'Pending').length;
              final approved = mine.where((r) => r.status == 'Approved').length;
              return Row(children: [
                _HeroStat(value: '${mine.length}', label: 'Total'),
                _HeroStat(value: '$pending',  label: 'Pending',  color: kYellow),
                _HeroStat(value: '$approved', label: 'Approved', color: kGreen),
              ]);
            },
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: kAccent,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: const [Tab(text: 'New Request'), Tab(text: 'My Requests')]),
        ]),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            _NewRequestTab(requesterName: widget.requesterName),
            _MyRequestsTab(requesterName: widget.requesterName),
          ],
        ),
      ),
    ]);
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeroStat({required this.value, required this.label, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
  ]));
}

// ── New Request Tab ───────────────────────────────────────────────────────────
class _NewRequestTab extends StatefulWidget {
  final String requesterName;
  const _NewRequestTab({required this.requesterName});
  @override
  State<_NewRequestTab> createState() => _NewRequestTabState();
}

class _NewRequestTabState extends State<_NewRequestTab> {
  final _detailsCtrl = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _eventCtrl   = TextEditingController();
  final _dateCtrl    = TextEditingController();
  final _venueCtrl   = TextEditingController();
  String _type = '';
  bool _submitted = false;
  bool _submitting = false;
  DateTime? _pickedDate;

  @override
  void initState() { super.initState(); _nameCtrl.text = widget.requesterName; }

  @override
  void dispose() {
    _detailsCtrl.dispose(); _nameCtrl.dispose();
    _eventCtrl.dispose(); _dateCtrl.dispose(); _venueCtrl.dispose();
    super.dispose();
  }

  // All service-type tiles share the primary accent — no per-service color.
  static const _services = [
    (Icons.assignment_rounded,           'Event Documentation',   'Full photo & video coverage',  kAccent),
    (Icons.camera_alt_rounded,           'Event Photography',     'Professional photography',     kAccent),
    (Icons.person_rounded,               'Portrait / ID Photos',  'Individual or group sessions', kAccent),
    (Icons.movie_creation_rounded,       'Video Production',      'Highlight video or short film',kAccent),
    (Icons.photo_library_rounded,        'Photo Printing',        'Print in various sizes',       kAccent),
    (Icons.cloud_upload_rounded,         'Photo Archive Request', 'Access archived photos',       kAccent),
    (Icons.auto_awesome_rounded,         'Photo Editing',         'Editing & retouching',         kAccent),
    (Icons.calendar_month_rounded,       'Coverage Booking',      'Book ACCESS for your event',   kAccent),
  ];

  void _snack(String msg, {Color color = kRed}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _pickedDate = picked;
        const months = [
          'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec',
        ];
        _dateCtrl.text = '${months[picked.month - 1]} ${picked.day}, ${picked.year}';
      });
    }
  }

  Future<void> _submit() async {
    if (_type.isEmpty)                    { _snack('Please select a service type'); return; }
    if (_eventCtrl.text.trim().isEmpty)   { _snack('Please enter the event name'); return; }
    if (_pickedDate == null)              { _snack('Please pick the event date'); return; }
    if (_detailsCtrl.text.trim().isEmpty) { _snack('Please describe your request'); return; }

    setState(() => _submitting = true);
    try {
      await memberDataController.createServiceRequest(
        title: '$_type — ${_eventCtrl.text.trim()}',
        description: _detailsCtrl.text.trim(),
        eventDate: _pickedDate!,
        venue: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    _detailsCtrl.clear(); _eventCtrl.clear(); _dateCtrl.clear(); _venueCtrl.clear();
    setState(() {
      _submitted = false;
      _type = '';
      _pickedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SuccessView(onReset: _reset);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: mobileScrollPadding(context, top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionLabel('Organization / Requester Name'),
        const SizedBox(height: 8),
        _Field(ctrl: _nameCtrl, hint: 'e.g. CS Organization',
          label: 'Name', icon: Icons.business_outlined),
        const SizedBox(height: 24),
        _SectionLabel('Select Service'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.6, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _services.map((s) {
            final sel = _type == s.$2;
            return GestureDetector(
              onTap: () => setState(() => _type = s.$2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? s.$4.withOpacity(0.08) : kSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? s.$4 : kBorder, width: sel ? 2 : 1),
                  boxShadow: sel ? [BoxShadow(color: s.$4.withOpacity(0.15),
                    blurRadius: 8, offset: const Offset(0, 2))] : null),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: s.$4.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                    child: Icon(s.$1, color: s.$4, size: 18)),
                  const Spacer(),
                  Text(s.$2, style: TextStyle(color: sel ? s.$4 : kTextPrimary,
                    fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(s.$3, style: const TextStyle(color: kTextSecondary, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          }).toList()),
        const SizedBox(height: 24),
        _SectionLabel('Event Information'),
        const SizedBox(height: 12),
        _Field(ctrl: _eventCtrl, hint: 'e.g. Foundation Day 2025',
          label: 'Event Name *', icon: Icons.event_outlined),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: _Field(ctrl: _dateCtrl, hint: 'Tap to pick a date',
                label: 'Event Date *', icon: Icons.calendar_today_outlined),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: _Field(ctrl: _venueCtrl, hint: 'e.g. Main Gymnasium',
            label: 'Venue', icon: Icons.location_on_outlined)),
        ]),
        const SizedBox(height: 24),
        _SectionLabel('Additional Details'),
        const SizedBox(height: 8),
        TextField(
          controller: _detailsCtrl, maxLines: 4,
          style: const TextStyle(color: kTextPrimary),
          decoration: InputDecoration(
            hintText: 'Number of attendees, special requirements, preferred style...',
            hintStyle: const TextStyle(color: kTextSecondary),
            filled: true, fillColor: kSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAccent, width: 1.5)))),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _submitting ? 'Submitting…' : 'Submit Request',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ── Success view ──────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onReset;
  const _SuccessView({required this.onReset});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kGreen, Color(0xFF16A34A)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: kGreen.withOpacity(0.3),
              blurRadius: 20, offset: const Offset(0, 8))]),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40)),
        const SizedBox(height: 24),
        const Text('Request Submitted!', style: TextStyle(color: kTextPrimary,
          fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Your request has been sent to ACCESS.\nOur team will review and respond shortly.',
          style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccent,
              side: const BorderSide(color: kAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: onReset,
            child: const Text('Submit Another Request',
              style: TextStyle(fontWeight: FontWeight.w700)))),
      ]),
    ),
  );
}

// ── My Requests Tab ───────────────────────────────────────────────────────────
class _MyRequestsTab extends StatelessWidget {
  final String requesterName;
  const _MyRequestsTab({required this.requesterName});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (_, __) {
        final all = appState.serviceRequests;
        // Backend already filters by user; show everything returned from the API.
        if (memberDataController.isLoading && all.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: kAccent));
        }
        if (memberDataController.error != null && all.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.cloud_off_outlined, color: kRed, size: 48),
              const SizedBox(height: 12),
              const Text('Could not load your requests',
                style: TextStyle(color: kTextPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(memberDataController.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => memberDataController.refreshAll(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry')),
            ]),
          ));
        }
        if (all.isEmpty) {
          return RefreshIndicator(
            color: kAccent,
            onRefresh: () => memberDataController.refreshAll(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 80),
                  Container(width: 72, height: 72,
                    decoration: BoxDecoration(color: kSurfaceAlt, shape: BoxShape.circle,
                      border: Border.all(color: kBorder)),
                    child: const Icon(Icons.inbox_outlined, color: kTextSecondary, size: 32)),
                  const SizedBox(height: 16),
                  const Text('No requests yet', style: TextStyle(color: kTextPrimary,
                    fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Submit your first request from the New Request tab.',
                    style: TextStyle(color: kTextSecondary, fontSize: 12)),
                ])),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: kAccent,
          onRefresh: () => memberDataController.refreshAll(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: all.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _RequestCard(req: all[i]),
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequest req;
  const _RequestCard({required this.req});

  Color get _sc => switch (req.status) {
    'Approved'  => kGreen, 'Rejected' => kRed,
    'In Review' => kYellow, _ => kTextSecondary };
  Color get _sb => switch (req.status) {
    'Approved'  => kGreenDim, 'Rejected' => kRedDim,
    'In Review' => kYellowDim, _ => kSurfaceAlt };
  IconData get _si => switch (req.status) {
    'Approved'  => Icons.check_circle_rounded, 'Rejected' => Icons.cancel_rounded,
    'In Review' => Icons.hourglass_top_rounded, _ => Icons.schedule_rounded };

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: kSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
        blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(color: kSurfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text(req.type, style: const TextStyle(color: kAccent,
              fontSize: 11, fontWeight: FontWeight.w700))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _sb, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_si, color: _sc, size: 12),
              const SizedBox(width: 4),
              Text(req.status, style: TextStyle(color: _sc,
                fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(req.details, style: const TextStyle(color: kTextPrimary,
            fontSize: 13, height: 1.5)),
          if (req.status == 'Rejected' &&
              req.rejectionReason != null &&
              req.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kRedDim,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kRed.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rejection reason',
                    style: TextStyle(color: kRed, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(req.rejectionReason!,
                    style: const TextStyle(color: kTextPrimary, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.tag_rounded, color: kTextSecondary, size: 13),
            const SizedBox(width: 4),
            Text(req.id, style: const TextStyle(color: kTextSecondary, fontSize: 11)),
            const SizedBox(width: 16),
            const Icon(Icons.calendar_today_outlined, color: kTextSecondary, size: 13),
            const SizedBox(width: 4),
            Text(req.date, style: const TextStyle(color: kTextSecondary, fontSize: 11)),
          ]),
        ]),
      ),
    ]),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint, label;
  final IconData icon;
  const _Field({required this.ctrl, required this.hint,
    required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: const TextStyle(color: kTextPrimary),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      hintStyle: const TextStyle(color: kTextSecondary),
      prefixIcon: Icon(icon, color: kTextSecondary, size: 16),
      filled: true, fillColor: kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccent, width: 1.5))),
  );
}

// ── Public Gallery Tab ────────────────────────────────────────────────────────
class _PublicGalleryTab extends StatefulWidget {
  const _PublicGalleryTab();
  @override
  State<_PublicGalleryTab> createState() => _PublicGalleryTabState();
}

class _PublicGalleryTabState extends State<_PublicGalleryTab> {
  String _filter = 'All';
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (_, __) {
        final categories = ['All', ...{for (final g in appState.gallery) g.category}];
        final filtered = _filter == 'All'
          ? appState.gallery
          : appState.gallery.where((g) => g.category == _filter).toList();
        return Column(children: [
          Container(color: kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final active = cat == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? kAccent : kSurfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? kAccent : kBorder)),
                      child: Text(cat, style: TextStyle(
                        color: active ? Colors.white : kTextSecondary,
                        fontSize: 12, fontWeight: FontWeight.w600))),
                  );
                },
              ))),
          Expanded(
            child: filtered.isEmpty
              ? const Center(child: Text('No photos in this category',
                  style: TextStyle(color: kTextSecondary)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10,
                    mainAxisSpacing: 10, childAspectRatio: 1.0),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(backgroundColor: Colors.black,
                            foregroundColor: Colors.white, title: Text(item.title)),
                          body: Center(child: item.imageBytes != null
                            ? InteractiveViewer(child: Image.memory(item.imageBytes!))
                            : Icon(Icons.photo_library, color: item.color, size: 80))))),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(fit: StackFit.expand, children: [
                          item.imageBytes != null
                            ? Image.memory(item.imageBytes!, fit: BoxFit.cover)
                            : Container(
                                decoration: BoxDecoration(gradient: LinearGradient(
                                  colors: [item.color, item.color.withOpacity(0.6)],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
                                child: Center(child: Icon(Icons.photo_library,
                                  color: Colors.white.withOpacity(0.6), size: 36))),
                          Positioned(bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(gradient: LinearGradient(
                                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
                              child: Text(item.title,
                                style: const TextStyle(color: Colors.white,
                                  fontSize: 11, fontWeight: FontWeight.w600),
                                maxLines: 1, overflow: TextOverflow.ellipsis))),
                        ]),
                      ),
                    );
                  },
                ),
          ),
        ]);
      },
    );
  }
}
