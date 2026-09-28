import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/mobile_app/widgets/score_ring.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (_, __) {
        final evals        = appState.evaluations;
        final scored       = evals.where((e) => e.score > 0).toList();
        final avgScore     = scored.isEmpty ? 0.0
          : scored.fold(0.0, (s, e) => s + e.score) / scored.length;
        final goodEvals    = scored.where((e) => e.score >= 0.70).length;
        final pendingEvals = evals.where((e) => e.score == 0).length;
        final totalMedia   = appState.gallery.length;
        final totalVideos  = appState.gallery.where((g) => g.isVideo).length;
        final aiDetected   = appState.gallery.where((g) => g.aiDetected).length;
        final requests     = appState.serviceRequests;
        final pendingReq   = requests.where((r) => r.status == 'Pending').length;
        final approvedReq  = requests.where((r) => r.status == 'Approved').length;
        final rejectedReq  = requests.where((r) => r.status == 'Rejected').length;
        final inReviewReq  = requests.where((r) => r.status == 'In Review').length;
        final members      = appState.members;
        final badgeCounts  = <String, int>{};
        for (final m in members) {
          badgeCounts[m.badge.label] = (badgeCounts[m.badge.label] ?? 0) + 1;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Analytics Dashboard', style: TextStyle(
              color: kTextPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('System performance overview for ACCESS VisionCheck.',
              style: TextStyle(color: kTextSecondary, fontSize: 13)),
            const SizedBox(height: 24),

            // ── KPI row ──────────────────────────────────────────────────
            Row(children: [
              _KpiCard(icon: Icons.photo_camera, color: kAccent,
                value: '${evals.length}', label: 'Total Submissions'),
              const SizedBox(width: 12),
              _KpiCard(icon: Icons.check_circle_outline, color: kGreen,
                value: '$goodEvals', label: 'Good Evaluations'),
              const SizedBox(width: 12),
              _KpiCard(icon: Icons.hourglass_top, color: kYellow,
                value: '$pendingEvals', label: 'Pending Review'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _KpiCard(icon: Icons.photo_library_outlined, color: kCyan,
                value: '$totalMedia', label: 'Media Files'),
              const SizedBox(width: 12),
              _KpiCard(icon: Icons.smart_toy_outlined, color: kRed,
                value: '$aiDetected', label: 'AI Detected'),
              const SizedBox(width: 12),
              _KpiCard(icon: Icons.people_outline, color: kOrange,
                value: '${members.length}', label: 'Members'),
            ]),
            const SizedBox(height: 28),

            // ── Media Quality ────────────────────────────────────────────
            _SectionTitle('Media Quality Evaluation'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder)),
              child: Row(children: [
                SizedBox(width: 90, height: 90,
                  child: ScoreRing(score: avgScore,
                    label: scored.isEmpty ? 'N/A' : '${(avgScore * 100).round()}%')),
                const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Average Quality Score', style: TextStyle(
                    color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Based on ${scored.length} evaluated submission${scored.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  _MiniBar(label: 'Good (≥70%)',
                    value: scored.isEmpty ? 0 : goodEvals / scored.length, color: kGreen),
                  const SizedBox(height: 6),
                  _MiniBar(label: 'Needs Work',
                    value: scored.isEmpty ? 0 : (scored.length - goodEvals) / scored.length,
                    color: kYellow),
                ])),
              ]),
            ),
            const SizedBox(height: 28),

            // ── AI Detection ─────────────────────────────────────────────
            _SectionTitle('AI Detection Summary'),
            const SizedBox(height: 12),
            Row(children: [
              _RepoCard(icon: Icons.verified_outlined, color: kGreen,
                value: '${totalMedia - aiDetected}', label: 'Authentic'),
              const SizedBox(width: 12),
              _RepoCard(icon: Icons.smart_toy_outlined, color: kRed,
                value: '$aiDetected', label: 'AI Detected'),
              const SizedBox(width: 12),
              _RepoCard(icon: Icons.videocam_outlined, color: kAccent,
                value: '$totalVideos', label: 'Videos'),
            ]),
            const SizedBox(height: 28),

            // ── Service Requests ─────────────────────────────────────────
            _SectionTitle('Service Request Workflow'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder)),
              child: Column(children: [
                _WorkflowRow(label: 'Pending',   count: pendingReq,  total: requests.length, color: kYellow),
                const SizedBox(height: 10),
                _WorkflowRow(label: 'Approved',  count: approvedReq, total: requests.length, color: kGreen),
                const SizedBox(height: 10),
                _WorkflowRow(label: 'In Review', count: inReviewReq, total: requests.length, color: kAccent),
                const SizedBox(height: 10),
                _WorkflowRow(label: 'Rejected',  count: rejectedReq, total: requests.length, color: kRed),
              ]),
            ),
            const SizedBox(height: 28),

            // ── Skill Classification ──────────────────────────────────────
            _SectionTitle('Competency-Based Skill Classification'),
            const SizedBox(height: 4),
            const Text('Member distribution by badge (based on good evaluations).',
              style: TextStyle(color: kTextSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder)),
              child: Column(children: [
                for (final entry in [
                  ('Master',       kAccent,              '15+ good evals'),
                  ('Expert',       kBlue,                '10–14 good evals'),
                  ('Advanced',     kGreen,               '6–9 good evals'),
                  ('Intermediate', kYellow,              '3–5 good evals'),
                  ('Beginner',     const Color(0xFFCD7C2F), '1–2 good evals'),
                  ('Novice',       kTextSecondary,       '0 good evals'),
                ]) ...[
                  _SkillRow(
                    label: entry.$1, color: entry.$2, hint: entry.$3,
                    count: badgeCounts[entry.$1] ?? 0, total: members.length),
                  if (entry.$1 != 'Novice') const SizedBox(height: 8),
                ],
              ]),
            ),
            const SizedBox(height: 28),

            // ── Event Calendar ────────────────────────────────────────────
            _SectionTitle('Automated Event Calendar'),
            const SizedBox(height: 12),
            ...appState.events.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder)),
              child: Row(children: [
                Container(width: 4, height: 40,
                  decoration: BoxDecoration(color: e.statusColor,
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, style: const TextStyle(color: kTextPrimary,
                    fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(e.date, style: const TextStyle(color: kTextSecondary, fontSize: 11)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: e.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(e.status, style: TextStyle(color: e.statusColor,
                    fontSize: 10, fontWeight: FontWeight.w700))),
              ]),
            )),
            const SizedBox(height: 16),
          ]),
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.w700));
}

class _KpiCard extends StatelessWidget {
  final IconData icon; final Color color; final String value, label;
  const _KpiCard({required this.icon, required this.color, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kSurface,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 10)),
      ]),
    ),
  );
}

class _RepoCard extends StatelessWidget {
  final IconData icon; final Color color; final String value, label;
  const _RepoCard({required this.icon, required this.color, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 11)),
      ]),
    ),
  );
}

class _MiniBar extends StatelessWidget {
  final String label; final double value; final Color color;
  const _MiniBar({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 90, child: Text(label,
      style: const TextStyle(color: kTextSecondary, fontSize: 10))),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: value, minHeight: 6,
        backgroundColor: kBorder, valueColor: AlwaysStoppedAnimation(color)))),
    const SizedBox(width: 8),
    Text('${(value * 100).round()}%',
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  ]);
}

class _WorkflowRow extends StatelessWidget {
  final String label; final int count, total; final Color color;
  const _WorkflowRow({required this.label, required this.count, required this.total, required this.color});
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      SizedBox(width: 80, child: Text(label,
        style: const TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: pct, minHeight: 10,
          backgroundColor: kBorder, valueColor: AlwaysStoppedAnimation(color)))),
      const SizedBox(width: 10),
      Text('$count', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _SkillRow extends StatelessWidget {
  final String label, hint; final Color color; final int count, total;
  const _SkillRow({required this.label, required this.hint, required this.color,
    required this.count, required this.total});
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      SizedBox(width: 90, child: Text(label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: pct, minHeight: 8,
          backgroundColor: kBorder,
          valueColor: AlwaysStoppedAnimation(color.withOpacity(0.7))))),
      const SizedBox(width: 10),
      Text('$count', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      const SizedBox(width: 4),
      Text(hint, style: const TextStyle(color: kTextSecondary, fontSize: 9)),
    ]);
  }
}
