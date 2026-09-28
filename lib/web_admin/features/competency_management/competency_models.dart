import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/members/team_member_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

/// Three-tier competency scale for documentation team members.
enum CompetencyLevel {
  beginner,
  intermediate,
  advanced;

  String get label => switch (this) {
        CompetencyLevel.beginner => 'Beginner',
        CompetencyLevel.intermediate => 'Intermediate',
        CompetencyLevel.advanced => 'Advanced',
      };

  Color get color => switch (this) {
        CompetencyLevel.beginner => AdminTheme.textSecondary,
        CompetencyLevel.intermediate => AdminTheme.accentCyan,
        CompetencyLevel.advanced => AdminTheme.accentBlue,
      };
}

enum EventScaleRecommendation {
  smallEvents,
  mediumEvents,
  largeEvents;

  String get label => switch (this) {
        EventScaleRecommendation.smallEvents => 'Small Events',
        EventScaleRecommendation.mediumEvents => 'Medium Events',
        EventScaleRecommendation.largeEvents => 'Large Events',
      };
}

enum CompetencyFilterChip {
  all,
  photographers,
  videographers,
  beginner,
  intermediate,
  advanced,
  available,
  assigned;

  String get label => switch (this) {
        CompetencyFilterChip.all => 'All',
        CompetencyFilterChip.photographers => 'Photographers',
        CompetencyFilterChip.videographers => 'Videographers',
        CompetencyFilterChip.beginner => 'Beginner',
        CompetencyFilterChip.intermediate => 'Intermediate',
        CompetencyFilterChip.advanced => 'Advanced',
        CompetencyFilterChip.available => 'Available',
        CompetencyFilterChip.assigned => 'Assigned',
      };
}

enum CompetencySortOption {
  name,
  performance,
  competency,
  tasksCompleted,
  acceptanceRate;

  String get label => switch (this) {
        CompetencySortOption.name => 'Name',
        CompetencySortOption.performance => 'Performance score',
        CompetencySortOption.competency => 'Competency level',
        CompetencySortOption.tasksCompleted => 'Tasks completed',
        CompetencySortOption.acceptanceRate => 'Acceptance rate',
      };
}

class CompetencyOverviewStats {
  const CompetencyOverviewStats({
    required this.totalMembers,
    required this.advancedCount,
    required this.intermediateCount,
    required this.beginnerCount,
  });

  final int totalMembers;
  final int advancedCount;
  final int intermediateCount;
  final int beginnerCount;
}

class CompetencyCriterion {
  const CompetencyCriterion({
    required this.label,
    required this.met,
    required this.detail,
  });

  final String label;
  final bool met;
  final String detail;
}

class CompetencyAssessment {
  const CompetencyAssessment({
    required this.recommendedLevel,
    required this.explanation,
    required this.criteria,
    required this.skillScore,
  });

  final CompetencyLevel recommendedLevel;
  final String explanation;
  final List<CompetencyCriterion> criteria;
  final double skillScore;
}

class CompetencyMember {
  const CompetencyMember({
    required this.profile,
    required this.currentLevel,
    required this.recommendedLevel,
    required this.assessment,
    required this.eventRecommendation,
    required this.strengths,
    required this.areasForImprovement,
    required this.trainingRecommendations,
    required this.featuredMediaCount,
    required this.mediaAcceptanceRate,
    required this.eventsCovered,
    required this.integritySummary,
    required this.integrityViolations,
    required this.integrityWarnings,
    this.adminNotes,
    this.levelOverridden = false,
  });

  final TeamMemberProfile profile;
  final CompetencyLevel currentLevel;
  final CompetencyLevel recommendedLevel;
  final CompetencyAssessment assessment;
  final EventScaleRecommendation eventRecommendation;
  final List<String> strengths;
  final List<String> areasForImprovement;
  final List<String> trainingRecommendations;
  final int featuredMediaCount;
  final double mediaAcceptanceRate;
  final int eventsCovered;
  final String integritySummary;
  final int integrityViolations;
  final int integrityWarnings;
  final String? adminNotes;
  final bool levelOverridden;

  int get id => profile.id;
  String get name => profile.name;
  String get roleLabel => profile.coverageRoleLabel;
  double get performanceScore => profile.performanceScore;
  String? get avatarUrl => profile.avatarUrl;
  String get initials => profile.initials;

  bool matchesChip(CompetencyFilterChip chip) {
    return switch (chip) {
      CompetencyFilterChip.all => true,
      CompetencyFilterChip.photographers => profile.coverageRole == TeamCoverageRole.photographer,
      CompetencyFilterChip.videographers => profile.coverageRole == TeamCoverageRole.videographer,
      CompetencyFilterChip.beginner => currentLevel == CompetencyLevel.beginner,
      CompetencyFilterChip.intermediate => currentLevel == CompetencyLevel.intermediate,
      CompetencyFilterChip.advanced => currentLevel == CompetencyLevel.advanced,
      CompetencyFilterChip.available => profile.availability == TeamAvailability.available,
      CompetencyFilterChip.assigned => profile.availability == TeamAvailability.assigned,
    };
  }

  CompetencyMember copyWith({String? adminNotes}) => CompetencyMember(
        profile: profile,
        currentLevel: currentLevel,
        recommendedLevel: recommendedLevel,
        assessment: assessment,
        eventRecommendation: eventRecommendation,
        strengths: strengths,
        areasForImprovement: areasForImprovement,
        trainingRecommendations: trainingRecommendations,
        featuredMediaCount: featuredMediaCount,
        mediaAcceptanceRate: mediaAcceptanceRate,
        eventsCovered: eventsCovered,
        integritySummary: integritySummary,
        integrityViolations: integrityViolations,
        integrityWarnings: integrityWarnings,
        adminNotes: adminNotes ?? this.adminNotes,
        levelOverridden: levelOverridden,
      );
}

class CompetencyDashboardData {
  const CompetencyDashboardData({
    required this.members,
    required this.stats,
  });

  final List<CompetencyMember> members;
  final CompetencyOverviewStats stats;
}

CompetencyLevel competencyFromScore(double score) {
  if (score >= 75) return CompetencyLevel.advanced;
  if (score >= 60) return CompetencyLevel.intermediate;
  return CompetencyLevel.beginner;
}

CompetencyLevel competencyFromLabel(String? raw) {
  final n = (raw ?? '').toLowerCase();
  if (n.contains('advanced') || n.contains('expert')) return CompetencyLevel.advanced;
  if (n.contains('intermediate')) return CompetencyLevel.intermediate;
  return CompetencyLevel.beginner;
}
