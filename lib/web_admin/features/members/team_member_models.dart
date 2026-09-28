import 'package:access_mobile/web_admin/features/member_rankings/member_ranking_models.dart';

enum TeamFilterChip { all, photographers, videographers, available, assigned, inactive }

enum TeamCoverageRole { photographer, videographer, unassigned }

enum TeamAvailability { available, assigned, unavailable }

enum TeamSortOption { name, performance, tasksCompleted, qualityScore, skillLevel }

class CurrentAssignmentInfo {
  const CurrentAssignmentInfo({
    required this.eventName,
    required this.assignmentRole,
    required this.status,
    required this.scheduleLabel,
  });

  final String eventName;
  final String assignmentRole;
  final String status;
  final String scheduleLabel;
}

class PortfolioWorkItem {
  const PortfolioWorkItem({
    required this.eventName,
    required this.dateLabel,
    required this.photoCount,
    required this.videoCount,
    required this.qualityScore,
  });

  final String eventName;
  final String dateLabel;
  final int photoCount;
  final int videoCount;
  final double qualityScore;
}

class TeamMemberProfile {
  const TeamMemberProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.contactNumber,
    required this.coverageRole,
    required this.availability,
    required this.accountStatus,
    required this.isActiveAccount,
    required this.skillLevel,
    required this.skillTier,
    required this.performanceScore,
    required this.completedTasks,
    required this.assignedTasks,
    required this.averageQualityScore,
    required this.onTimeRate,
    required this.aiRating,
    required this.currentAssignment,
    required this.portfolio,
    required this.dateJoined,
    required this.aiRecommendation,
    this.avatarUrl,
  });

  final int id;
  final String name;
  final String email;
  final String? contactNumber;
  final TeamCoverageRole coverageRole;
  final TeamAvailability availability;
  final String accountStatus;
  final bool isActiveAccount;
  final String? skillLevel;
  final SkillLevelTier skillTier;
  final double performanceScore;
  final int completedTasks;
  final int assignedTasks;
  final double averageQualityScore;
  final double onTimeRate;
  final double aiRating;
  final CurrentAssignmentInfo? currentAssignment;
  final List<PortfolioWorkItem> portfolio;
  final DateTime? dateJoined;
  final String aiRecommendation;
  final String? avatarUrl;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get coverageRoleLabel => switch (coverageRole) {
        TeamCoverageRole.photographer => 'Photographer',
        TeamCoverageRole.videographer => 'Videographer',
        TeamCoverageRole.unassigned => 'Unassigned',
      };

  String get skillLevelLabel {
    final raw = skillLevel ?? '';
    if (raw.isEmpty) return skillTier.name[0].toUpperCase() + skillTier.name.substring(1);
    return raw;
  }

  String get availabilityTitle => switch (availability) {
        TeamAvailability.available => 'Available',
        TeamAvailability.assigned => 'Assigned',
        TeamAvailability.unavailable => 'Unavailable',
      };

  String get availabilitySubtitle => switch (availability) {
        TeamAvailability.available => 'No current assignments.',
        TeamAvailability.assigned =>
          currentAssignment != null
              ? '${currentAssignment!.eventName} (${currentAssignment!.scheduleLabel})'
              : 'Active documentation assignment',
        TeamAvailability.unavailable => 'On leave / Inactive',
      };

  bool matchesChip(TeamFilterChip chip) {
    final approved = accountStatus == 'approved' && isActiveAccount;
    return switch (chip) {
      TeamFilterChip.all => approved,
      TeamFilterChip.photographers => approved && coverageRole == TeamCoverageRole.photographer,
      TeamFilterChip.videographers => approved && coverageRole == TeamCoverageRole.videographer,
      TeamFilterChip.available => approved && availability == TeamAvailability.available,
      TeamFilterChip.assigned => approved && availability == TeamAvailability.assigned,
      TeamFilterChip.inactive => availability == TeamAvailability.unavailable,
    };
  }
}

TeamCoverageRole coverageRoleFromTaskRole(String? raw) {
  final r = (raw ?? '').toLowerCase();
  if (r.contains('video')) return TeamCoverageRole.videographer;
  if (r.contains('photo')) return TeamCoverageRole.photographer;
  return TeamCoverageRole.unassigned;
}

String formatTeamDate(DateTime? d) {
  if (d == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String formatScheduleLabel(DateTime? date, String? startTime) {
  if (date == null) return 'TBD';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final datePart = '${months[date.month - 1]} ${date.day}';
  if (startTime == null || startTime.isEmpty) return datePart;
  final parsed = DateTime.tryParse('1970-01-01T$startTime');
  if (parsed != null) {
    final h = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final m = parsed.minute.toString().padLeft(2, '0');
    final ap = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$datePart, $h:$m $ap';
  }
  return '$datePart, $startTime';
}

String buildAiRecommendation(TeamMemberProfile m) {
  if (m.availability == TeamAvailability.unavailable) {
    return 'This member is currently inactive. Reactivate their account before assigning documentation work.';
  }
  if (m.averageQualityScore >= 85 && m.completedTasks >= 5) {
    return 'This member consistently produces high-quality documentation and is recommended for major campus events.';
  }
  if (m.averageQualityScore >= 70 && m.onTimeRate >= 80) {
    return 'Reliable contributor with solid quality scores — suitable for standard event coverage.';
  }
  if (m.completedTasks < 3) {
    return 'Newer team member — assign smaller events first to build portfolio and evaluation history.';
  }
  if (m.onTimeRate < 60) {
    return 'Review submission timelines with this member; consider pairing with a senior photographer or videographer.';
  }
  return 'Monitor upcoming assignments and media evaluations to refine role placement for future events.';
}
