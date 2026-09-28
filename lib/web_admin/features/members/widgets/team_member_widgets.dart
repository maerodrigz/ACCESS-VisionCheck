import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/members/team_member_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class TeamAvailabilityIndicator extends StatelessWidget {
  const TeamAvailabilityIndicator({
    super.key,
    required this.member,
    this.compact = false,
  });

  final TeamMemberProfile member;
  final bool compact;

  Color get _dotColor => switch (member.availability) {
        TeamAvailability.available => AdminTheme.success,
        TeamAvailability.assigned => AdminTheme.warning,
        TeamAvailability.unavailable => AdminTheme.danger,
      };

  Widget _statusPill(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _dotColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            member.availabilityTitle,
            style: TextStyle(
              fontSize: compact ? 11 : 11,
              fontWeight: FontWeight.w600,
              color: _dotColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = member.availabilitySubtitle;
    final showSubtitle = !compact && subtitle != member.availabilityTitle;

    if (compact) {
      return _statusPill(context);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        _statusPill(context),
        if (showSubtitle)
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary, height: 1.35),
          ),
      ],
    );
  }
}

class TeamMemberAvatar extends StatelessWidget {
  const TeamMemberAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 28,
    this.fontSize,
  });

  final String name;
  final String? avatarUrl;
  final double radius;
  final double? fontSize;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final fs = fontSize ?? radius * 0.64;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(_initials, style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, color: AdminTheme.accentBlue))
          : null,
    );
  }
}

class TeamCoverageBadge extends StatelessWidget {
  const TeamCoverageBadge({super.key, required this.role});

  final TeamCoverageRole role;

  @override
  Widget build(BuildContext context) {
    if (role == TeamCoverageRole.unassigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AdminTheme.contentBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AdminTheme.border),
        ),
        child: const Text('Role pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AdminTheme.textSecondary)),
      );
    }
    final isPhoto = role == TeamCoverageRole.photographer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AdminTheme.accentBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPhoto ? Icons.photo_camera_outlined : Icons.videocam_outlined, size: 12, color: AdminTheme.accentBlue),
          const SizedBox(width: 4),
          Text(
            isPhoto ? 'Photographer' : 'Videographer',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AdminTheme.accentBlue),
          ),
        ],
      ),
    );
  }
}

class TeamPerformanceBar extends StatelessWidget {
  const TeamPerformanceBar({super.key, required this.label, required this.value, required this.max, this.suffix = ''});

  final String label;
  final double value;
  final double max;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary))),
            Text(
              '${value.round()}$suffix',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AdminTheme.border,
            color: AdminTheme.accentBlue,
          ),
        ),
      ],
    );
  }
}
