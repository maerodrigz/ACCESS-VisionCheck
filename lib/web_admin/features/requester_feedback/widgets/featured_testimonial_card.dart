import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/requester_feedback_models.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/widgets/feedback_badges.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class FeaturedTestimonialCard extends StatefulWidget {
  const FeaturedTestimonialCard({super.key, required this.testimonial});

  final FeaturedTestimonial testimonial;

  @override
  State<FeaturedTestimonialCard> createState() => _FeaturedTestimonialCardState();
}

class _FeaturedTestimonialCardState extends State<FeaturedTestimonialCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.testimonial;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AdminTheme.accentBlue.withValues(alpha: _hovered ? 0.1 : 0.06),
              AdminTheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdminTheme.accentBlue.withValues(alpha: _hovered ? 0.35 : 0.18)),
          boxShadow: _hovered ? AdminTheme.cardShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.format_quote, color: AdminTheme.accentBlue, size: 22),
                const SizedBox(width: 8),
                const Text('Featured Feedback', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdminTheme.accentBlue)),
                const Spacer(),
                StarRatingDisplay(rating: t.rating, size: 20),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '"${t.quote}"',
              style: const TextStyle(fontSize: 15, height: 1.55, fontStyle: FontStyle.italic, color: AdminTheme.textPrimary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                  child: Text(
                    t.organization.isNotEmpty ? t.organization[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AdminTheme.accentBlue),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.organization, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(t.eventName, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
