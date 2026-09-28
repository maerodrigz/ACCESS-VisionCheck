import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────────
        const Text('How VisionCheck Works', style: TextStyle(
          color: kTextPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('System architecture: Advanced Media Analysis & Reporting.',
          style: TextStyle(color: kTextSecondary, fontSize: 13)),
        const SizedBox(height: 24),

        // ── Flow overview banner ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2B4A), Color(0xFF1E3A5F)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            const Text('VisionCheck System Architecture',
              style: TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _FlowPill(icon: Icons.person_outline, label: 'Member', color: kCyan),
              const _Arrow(),
              _FlowPill(icon: Icons.cloud_upload_rounded, label: 'Upload', color: kAccent),
              const _Arrow(),
              _FlowPill(icon: Icons.auto_awesome_rounded, label: 'AI Core', color: kAccent),
              const _Arrow(),
              _FlowPill(icon: Icons.verified_outlined, label: 'Result', color: kGreen),
            ]),
          ]),
        ),
        const SizedBox(height: 28),

        // ── Steps ────────────────────────────────────────────────────────────
        const Text('Step-by-Step Workflow', style: TextStyle(
          color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),

        _Step(
          number: 1,
          color: kAccent,
          icon: Icons.upload_file_outlined,
          title: 'Media Upload',
          subtitle: 'Member uploads photos or videos',
          bullets: [
            'Photos: JPG, PNG, GIF',
            'Videos: MP4, MOV, AVI (up to 3 min, 350 MB)',
            'System checks file type; videos go through FFmpeg/OpenCV keyframe extraction',
            'Photos are normalized to 224×224 for AI processing',
          ],
        ),

        _Step(
          number: 2,
          color: kCyan,
          icon: Icons.tune_outlined,
          title: 'Preprocessing',
          subtitle: 'FFmpeg / OpenCV pipeline',
          bullets: [
            'Videos: keyframes extracted at regular intervals',
            'Photos: resized and normalized to 224×224',
            'Both paths converge before AI analysis',
          ],
        ),

        _Step(
          number: 3,
          color: kAccent,
          icon: Icons.psychology_outlined,
          title: 'AI Core: EfficientNet-B0',
          subtitle: 'Technical quality + authenticity analysis',
          bullets: [
            'Technical Quality Score: measures sharpness, lighting, composition, resolution',
            'AI Detection Probability: detects AI-generated or manipulated content',
            'Both scores fed into the Results Aggregator',
          ],
          highlight: true,
          highlightLabel: 'EfficientNet-B0 Model',
        ),

        _Step(
          number: 4,
          color: kGreen,
          icon: Icons.bar_chart_rounded,
          title: 'Score Computation',
          subtitle: 'Weighted algorithm',
          bullets: [
            'Media quality (70%) + Media integrity (30%)',
            'Combined into your skill score on a 0–100 scale',
            'Beginner / Intermediate / Advanced / Expert tiers use this score',
          ],
        ),

        _Step(
          number: 5,
          color: kYellow,
          icon: Icons.warning_amber_outlined,
          title: 'Risk Classification',
          subtitle: 'Low / Medium / High',
          bullets: [
            'Low risk → Standard Quality path',
            'Medium risk → Advisory flag added to report',
            'High AI probability → Flagged "For Review" by admin',
          ],
        ),

        _Step(
          number: 6,
          color: kRed,
          icon: Icons.admin_panel_settings_outlined,
          title: 'Admin Review',
          subtitle: 'Manual decision for high-risk submissions',
          bullets: [
            'High-risk submissions appear on the Admin Review Dashboard',
            'Admin makes a manual decision: Approve or Reject',
            'Automated email alert sent to member upon decision',
          ],
        ),

        _Step(
          number: 7,
          color: kAccent,
          icon: Icons.emoji_events_outlined,
          title: 'Skill Classification',
          subtitle: 'Competency-based rule system',
          bullets: [
            'Requires 3–5 completed evaluations to earn a title',
            'Title based on average score quality',
            'Novice → Beginner → Intermediate → Advanced → Expert → Master',
            'Badge updates automatically as more evaluations are completed',
          ],
        ),

        _Step(
          number: 8,
          color: const Color(0xFF4285F4),
          icon: Icons.chat_bubble_outline,
          title: 'Gemini Feedback Generation',
          subtitle: 'Google Gemini API, LLM natural language feedback',
          bullets: [
            'Rubric scores sent to Gemini 1.5 Flash',
            'Generates a personalized 3–5 sentence feedback paragraph',
            'Highlights strengths and gives actionable improvement advice',
            'Falls back to rule-based feedback if API is unavailable',
          ],
          highlight: true,
          highlightLabel: 'Google Gemini API',
        ),

        _Step(
          number: 9,
          color: kGreen,
          icon: Icons.storage_outlined,
          title: 'Profile & Database Update',
          subtitle: 'PostgreSQL persistent storage',
          bullets: [
            'Evaluation result saved to member profile',
            'Badge and title updated based on new score',
            'Approved status reflected in documentation archive',
            'Analytics dashboard updated in real time',
          ],
          isLast: true,
        ),

        const SizedBox(height: 28),

        // ── Key components ───────────────────────────────────────────────────
        const Text('Key System Components', style: TextStyle(
          color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _ComponentCard(
          icon: Icons.auto_awesome_rounded,
          color: kAccent,
          title: 'AI Core (EfficientNet-B0)',
          desc: 'Deep learning model that analyzes visual characteristics, measures technical clarity, and detects AI-generated or manipulated content.'),
        _ComponentCard(
          icon: Icons.chat_bubble_outline,
          color: const Color(0xFF4285F4),
          title: 'LLM Gemini (Google Gemini API)',
          desc: 'Generates human-like, natural language feedback reports based on evaluation scores and rubric criteria.'),
        _ComponentCard(
          icon: Icons.analytics_outlined,
          color: kAccent,
          title: 'Analytics Dashboard',
          desc: 'Shows statistical data and visual reports of multimedia documentation activities for admin monitoring and decision-making.'),
        _ComponentCard(
          icon: Icons.calendar_month_outlined,
          color: kGreen,
          title: 'Automated Event Calendar',
          desc: 'Displays all approved documentation requests and scheduled events so users can monitor upcoming activities.'),
        _ComponentCard(
          icon: Icons.folder_outlined,
          color: kCyan,
          title: 'Centralized Multimedia Repository',
          desc: 'Secure, organized storage for all photos and videos captured during events, accessible to authorized members.'),
        _ComponentCard(
          icon: Icons.send_outlined,
          color: kOrange,
          title: 'Service Request Workflow',
          desc: 'Digital process for organizations to submit documentation requests, reviewed and approved or rejected by administrators.'),

        const SizedBox(height: 16),
      ]),
    );
  }
}

// ── Step widget ───────────────────────────────────────────────────────────────
class _Step extends StatelessWidget {
  final int number;
  final Color color;
  final IconData icon;
  final String title, subtitle;
  final List<String> bullets;
  final bool highlight;
  final String? highlightLabel;
  final bool isLast;

  const _Step({
    required this.number, required this.color, required this.icon,
    required this.title, required this.subtitle, required this.bullets,
    this.highlight = false, this.highlightLabel, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Timeline
      Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: Text('$number',
            style: const TextStyle(color: Colors.white,
              fontSize: 14, fontWeight: FontWeight.w800)))),
        if (!isLast)
          Container(width: 2, height: 20, color: kBorder),
      ]),
      const SizedBox(width: 14),
      // Content
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: highlight ? color.withOpacity(0.05) : kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: highlight ? color.withOpacity(0.3) : kBorder,
                width: highlight ? 1.5 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 16)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: kTextPrimary,
                    fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(color: kTextSecondary, fontSize: 11)),
                ])),
                if (highlight && highlightLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text(highlightLabel!, style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 10),
              ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 5, right: 8),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  Expanded(child: Text(b, style: const TextStyle(
                    color: kTextSecondary, fontSize: 12, height: 1.4))),
                ]),
              )),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ── Component card ────────────────────────────────────────────────────────────
class _ComponentCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  const _ComponentCard({required this.icon, required this.color,
    required this.title, required this.desc});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: kTextPrimary,
          fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(desc, style: const TextStyle(color: kTextSecondary,
          fontSize: 12, height: 1.4)),
      ])),
    ]),
  );
}

// ── Flow pill ─────────────────────────────────────────────────────────────────
class _FlowPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FlowPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: 40, height: 40,
      decoration: BoxDecoration(color: color.withOpacity(0.2),
        shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
      child: Icon(icon, color: color, size: 20)),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(color: color,
      fontSize: 9, fontWeight: FontWeight.w700)),
  ]);
}

class _Arrow extends StatelessWidget {
  const _Arrow();
  @override
  Widget build(BuildContext context) => const Icon(
    Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 16);
}
