import 'dart:convert';

import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/api/backend_health.dart';
import 'package:access_mobile/web_admin/features/competency_management/competency_models.dart';
import 'package:access_mobile/web_admin/features/member_rankings/member_ranking_models.dart';
import 'package:access_mobile/web_admin/features/members/team_member_models.dart';
import 'package:access_mobile/web_admin/features/members/team_members_repository.dart';
import 'package:access_mobile/web_admin/utils/skill_scoring.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompetencyRepository {
  static const _adminNotesKey = 'competency_admin_notes';
  static const _integrityStatusKey = 'integrity_alert_status';
  static const _integrityWarningsKey = 'integrity_member_warnings';

  final _teamRepo = TeamMembersRepository();

  Future<CompetencyDashboardData> loadAll() async {
    final online = await BackendHealth.isReachable();
    if (!online) {
      throw Exception('Backend offline. Run: cd access_backend && python manage.py runserver');
    }

    final results = await Future.wait([
      _teamRepo.loadTeam(),
      adminApi.rankings(),
      adminApi.allMedia(),
    ]);

    final profiles = results[0] as List<TeamMemberProfile>;
    final rankings = results[1] as List<Map<String, dynamic>>;
    final media = results[2] as List<Map<String, dynamic>>;

    final rankingByUser = <int, MemberRankingRow>{};
    for (final r in rankings) {
      final row = MemberRankingRow.fromMap(r);
      if (row.id > 0) rankingByUser[row.id] = row;
    }

    final notesMap = await _loadAdminNotes();
    final integrityCounts = await _loadIntegrityCounts(media);

    final members = <CompetencyMember>[];
    for (final profile in profiles) {
      if (profile.accountStatus != 'approved' || !profile.isActiveAccount) continue;
      if (profile.coverageRole == TeamCoverageRole.unassigned) continue;

      final ranking = rankingByUser[profile.id];
      final integrity = integrityCounts[profile.id] ?? (violations: 0, warnings: 0);
      final assessment = _buildAssessment(profile, ranking, integrity.violations, integrity.warnings);
      final levelOverride = ranking?.competencyLevelOverride;
      final overridden = levelOverride?.trim().isNotEmpty == true;
      final currentLevel = competencyFromLabel(
        ranking?.skillLevel ??
            profile.skillLevel ??
            (overridden
                ? levelOverride
                : ranking?.competencyRecommendedLevel ?? assessment.recommendedLevel.label),
      );

      members.add(
        CompetencyMember(
          profile: profile,
          currentLevel: currentLevel,
          recommendedLevel: assessment.recommendedLevel,
          assessment: assessment,
          eventRecommendation: _eventRecommendation(currentLevel, profile.performanceScore),
          strengths: _strengths(profile, ranking),
          areasForImprovement: _improvements(profile, ranking),
          trainingRecommendations: _training(profile, ranking),
          featuredMediaCount: _featuredCount(profile),
          mediaAcceptanceRate: _acceptanceRate(ranking, profile),
          eventsCovered: profile.portfolio.length,
          integritySummary: _integritySummary(integrity.violations, integrity.warnings),
          integrityViolations: integrity.violations,
          integrityWarnings: integrity.warnings,
      adminNotes: ranking?.adminRemarks ?? notesMap['${profile.id}'],
      levelOverridden: overridden,
        ),
      );
    }

    members.sort((a, b) => a.name.compareTo(b.name));
    return CompetencyDashboardData(
      members: members,
      stats: _computeStats(members),
    );
  }

  List<CompetencyMember> filterAndSort({
    required List<CompetencyMember> members,
    required CompetencyFilterChip chip,
    required String search,
    required CompetencySortOption sort,
  }) {
    var list = members.where((m) {
      if (!m.matchesChip(chip)) return false;
      if (search.trim().isEmpty) return true;
      final q = search.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.roleLabel.toLowerCase().contains(q) ||
          m.currentLevel.label.toLowerCase().contains(q) ||
          m.profile.availabilityTitle.toLowerCase().contains(q) ||
          (m.profile.currentAssignment?.eventName.toLowerCase().contains(q) ?? false);
    }).toList();

    list.sort((a, b) {
      switch (sort) {
        case CompetencySortOption.name:
          return a.name.compareTo(b.name);
        case CompetencySortOption.performance:
          return b.performanceScore.compareTo(a.performanceScore);
        case CompetencySortOption.competency:
          return b.currentLevel.index.compareTo(a.currentLevel.index);
        case CompetencySortOption.tasksCompleted:
          return b.profile.completedTasks.compareTo(a.profile.completedTasks);
        case CompetencySortOption.acceptanceRate:
          return b.mediaAcceptanceRate.compareTo(a.mediaAcceptanceRate);
      }
    });
    return list;
  }

  Future<void> setLevelOverride(int memberId, CompetencyLevel level) async {
    await adminApi.updateCompetencyLevel(memberId, competencyLevel: level.label);
  }

  Future<void> clearLevelOverride(int memberId) async {
    await adminApi.updateCompetencyLevel(memberId, competencyLevel: null);
  }

  Future<void> setAdminNotes(int memberId, String notes) async {
    final map = await _loadAdminNotes();
    if (notes.trim().isEmpty) {
      map.remove('$memberId');
    } else {
      map['$memberId'] = notes;
    }
    await _saveMap(_adminNotesKey, map);
    try {
      await adminApi.updateRankingRemarks(memberId, notes);
    } catch (_) {}
  }

  String buildExportReport(CompetencyDashboardData data) {
    final buf = StringBuffer('ACCESS VisionCheck — Competency Management Report\n');
    buf.writeln('Generated: ${DateTime.now().toLocal()}\n');
    buf.writeln('Overview');
    buf.writeln('  Total members: ${data.stats.totalMembers}');
    buf.writeln('  Advanced: ${data.stats.advancedCount}');
    buf.writeln('  Intermediate: ${data.stats.intermediateCount}');
    buf.writeln('  Beginner: ${data.stats.beginnerCount}\n');
    for (final m in data.members) {
      buf.writeln('${m.name} (${m.roleLabel})');
      buf.writeln('  Current: ${m.currentLevel.label}${m.levelOverridden ? ' (admin override)' : ''}');
      buf.writeln('  Recommended: ${m.recommendedLevel.label}');
      buf.writeln('  Performance: ${m.performanceScore.round()}%');
      buf.writeln('  Acceptance rate: ${m.mediaAcceptanceRate.round()}%');
      buf.writeln('  Recommended for: ${m.eventRecommendation.label}');
      if (m.adminNotes?.isNotEmpty == true) buf.writeln('  Notes: ${m.adminNotes}');
      buf.writeln('');
    }
    return buf.toString();
  }

  CompetencyAssessment _buildAssessment(
    TeamMemberProfile profile,
    MemberRankingRow? ranking,
    int violations,
    int warnings,
  ) {
    final completed = ranking?.completedTasks ?? profile.completedTasks;
    final approved = ranking?.approvedUploads ?? 0;
    final total = ranking?.totalUploads ?? 0;
    final acceptance = total > 0 ? approved / total * 100 : 0.0;
    final mediaQ = ranking?.mediaQualityScore ?? profile.averageQualityScore;
    final taskPart = ranking?.taskParticipationScore ?? 0.0;
    final portfolioCount = profile.portfolio.length;
    final skillScore = ranking?.skillScore ??
        computeSkillScore(
          mediaQualityScore: mediaQ,
          aiAuthenticityScore: ranking?.aiAuthenticityScore ?? 100,
        );

    final criteria = <CompetencyCriterion>[
      CompetencyCriterion(
        label: 'Completed 25+ documentation requests',
        met: completed >= 25,
        detail: '$completed completed',
      ),
      CompetencyCriterion(
        label: 'High media acceptance rate',
        met: acceptance >= 75 || (ranking?.approvedUploadsScore ?? 0) >= 75,
        detail: total > 0 ? '${acceptance.round()}% accepted' : 'No uploads yet',
      ),
      CompetencyCriterion(
        label: 'No integrity violations',
        met: violations == 0,
        detail: violations == 0 ? 'Clean integrity record' : '$violations confirmed violation${violations == 1 ? '' : 's'}',
      ),
      CompetencyCriterion(
        label: 'Consistent participation',
        met: taskPart >= 70 || (profile.assignedTasks > 0 && completed / profile.assignedTasks >= 0.7),
        detail: profile.assignedTasks > 0
            ? '${((completed / profile.assignedTasks) * 100).round()}% task completion'
            : '$completed tasks completed',
      ),
      CompetencyCriterion(
        label: 'Strong documentation portfolio',
        met: portfolioCount >= 3 && mediaQ >= 70,
        detail: '$portfolioCount event${portfolioCount == 1 ? '' : 's'} · ${mediaQ.round()}% avg quality',
      ),
    ];

    final metCount = criteria.where((c) => c.met).length;
    var level = competencyFromScore(skillScore);
    if (violations > 0 && level == CompetencyLevel.advanced) {
      level = CompetencyLevel.intermediate;
    }
    if (violations >= 2) level = CompetencyLevel.beginner;

    final explanation = switch (level) {
      CompetencyLevel.advanced =>
        'This member consistently submits complete event documentation, maintains a high media acceptance rate, and has successfully covered multiple university-wide events.',
      CompetencyLevel.intermediate =>
        'This member shows reliable documentation performance with room to grow into larger campus events after additional portfolio depth.',
      CompetencyLevel.beginner =>
        'This member is building experience — assign smaller events first while monitoring acceptance rates and integrity indicators.',
    };

    if (metCount < 3 && level == CompetencyLevel.advanced) {
      return CompetencyAssessment(
        recommendedLevel: CompetencyLevel.intermediate,
        explanation:
            'Performance indicators suggest intermediate competency — several advanced criteria are not yet consistently met.',
        criteria: criteria,
        skillScore: skillScore,
      );
    }

    return CompetencyAssessment(
      recommendedLevel: level,
      explanation: explanation,
      criteria: criteria,
      skillScore: skillScore,
    );
  }

  EventScaleRecommendation _eventRecommendation(CompetencyLevel level, double performance) {
    if (level == CompetencyLevel.advanced && performance >= 78) {
      return EventScaleRecommendation.largeEvents;
    }
    if (level == CompetencyLevel.intermediate || (level == CompetencyLevel.advanced && performance >= 65)) {
      return EventScaleRecommendation.mediumEvents;
    }
    return EventScaleRecommendation.smallEvents;
  }

  List<String> _strengths(TeamMemberProfile p, MemberRankingRow? r) {
    final out = <String>[];
    final q = p.averageQualityScore;
    final isPhoto = p.coverageRole == TeamCoverageRole.photographer;

    if (p.completedTasks >= 3) out.add(isPhoto ? 'Event Photography' : 'Event Videography');
    if (q >= 72) out.add('Composition');
    if (q >= 68) out.add(isPhoto ? 'Lighting' : 'Storytelling');
    if ((r?.approvedUploadsScore ?? 0) >= 70 || p.onTimeRate >= 75) {
      out.add('Timely Submissions');
    }
    if (p.portfolio.length >= 2) out.add('Documentation Portfolio');
    if (out.isEmpty) out.add(isPhoto ? 'Developing photography fundamentals' : 'Developing videography fundamentals');
    return out.take(5).toList();
  }

  List<String> _improvements(TeamMemberProfile p, MemberRankingRow? r) {
    final out = <String>[];
    final isPhoto = p.coverageRole == TeamCoverageRole.photographer;

    if (p.averageQualityScore < 70) out.add(isPhoto ? 'Lighting consistency' : 'Video stabilization');
    if (p.onTimeRate < 70) out.add('Submission timelines');
    if ((r?.totalUploads ?? 0) < 5) out.add('Portfolio depth');
    if (!isPhoto && p.averageQualityScore < 75) out.add('Camera movement');
    if (isPhoto && p.averageQualityScore < 75) out.add('Night photography');
    if ((r?.aiAuthenticityScore ?? 100) < 90) out.add('Media authenticity practices');
    if (out.isEmpty) out.add('Continue refining advanced event coverage techniques');
    return out.take(4).toList();
  }

  List<String> _training(TeamMemberProfile p, MemberRankingRow? r) {
    final out = <String>[];
    final isPhoto = p.coverageRole == TeamCoverageRole.photographer;

    if (p.averageQualityScore < 70) {
      out.add(isPhoto ? 'Improve low-light photography.' : 'Improve video stabilization and camera movement.');
    }
    if (p.completedTasks < 5) {
      out.add('Participate in the next practical documentation workshop.');
    }
    if (competencyFromLabel(p.skillLevel).index >= CompetencyLevel.intermediate.index && p.portfolio.length < 4) {
      out.add('Gain additional experience in large-scale campus events.');
    }
    if ((r?.approvedUploadsScore ?? 0) < 65) {
      out.add('Review ACCESS documentation quality guidelines before the next assignment.');
    }
    if (out.isEmpty) {
      out.add('Maintain current standards and mentor newer ${isPhoto ? 'photographers' : 'videographers'}.');
    }
    return out.take(3).toList();
  }

  int _featuredCount(TeamMemberProfile p) {
    var count = 0;
    for (final item in p.portfolio) {
      if (item.qualityScore >= 80) count += item.photoCount + item.videoCount;
    }
    return count;
  }

  double _acceptanceRate(MemberRankingRow? r, TeamMemberProfile p) {
    if (r != null && r.totalUploads > 0) {
      return (r.approvedUploads / r.totalUploads * 100).clamp(0, 100);
    }
    return p.averageQualityScore.clamp(0, 100);
  }

  String _integritySummary(int violations, int warnings) {
    if (violations > 0) return '$violations confirmed violation${violations == 1 ? '' : 's'} on record';
    if (warnings > 0) return '$warnings integrity warning${warnings == 1 ? '' : 's'} — no confirmed violations';
    return 'Clean integrity record';
  }

  CompetencyOverviewStats _computeStats(List<CompetencyMember> members) {
    var adv = 0, inter = 0, beg = 0;
    for (final m in members) {
      switch (m.currentLevel) {
        case CompetencyLevel.advanced:
          adv++;
        case CompetencyLevel.intermediate:
          inter++;
        case CompetencyLevel.beginner:
          beg++;
      }
    }
    return CompetencyOverviewStats(
      totalMembers: members.length,
      advancedCount: adv,
      intermediateCount: inter,
      beginnerCount: beg,
    );
  }

  Future<Map<String, String>> _loadAdminNotes() => _loadMap(_adminNotesKey);

  Future<Map<int, ({int violations, int warnings})>> _loadIntegrityCounts(List<Map<String, dynamic>> media) async {
    final prefs = await SharedPreferences.getInstance();
    final statusRaw = prefs.getString(_integrityStatusKey);
    final warningsRaw = prefs.getString(_integrityWarningsKey);

    final mediaOwner = <int, int>{};
    for (final m in media) {
      final id = m['id'] as int?;
      final uid = m['uploader_id'] as int? ?? m['member_id'] as int? ?? m['uploaded_by'] as int?;
      if (id != null && uid != null) mediaOwner[id] = uid;
    }

    final violationsByMember = <int, int>{};
    if (statusRaw != null) {
      final map = Map<String, dynamic>.from(jsonDecode(statusRaw) as Map);
      for (final entry in map.entries) {
        if (entry.value != 'confirmedViolation') continue;
        final key = entry.key.toString();
        if (!key.startsWith('alert_')) continue;
        final mediaId = int.tryParse(key.replaceFirst('alert_', ''));
        final memberId = mediaId != null ? mediaOwner[mediaId] : null;
        if (memberId != null) {
          violationsByMember[memberId] = (violationsByMember[memberId] ?? 0) + 1;
        }
      }
    }

    final warningsByMember = <int, int>{};
    if (warningsRaw != null) {
      final map = Map<String, dynamic>.from(jsonDecode(warningsRaw) as Map);
      for (final entry in map.entries) {
        final memberId = int.tryParse(entry.key);
        if (memberId == null) continue;
        final list = entry.value;
        if (list is List) warningsByMember[memberId] = list.length;
      }
    }

    final ids = {...violationsByMember.keys, ...warningsByMember.keys};
    return {
      for (final id in ids)
        id: (
          violations: violationsByMember[id] ?? 0,
          warnings: warningsByMember[id] ?? 0,
        ),
    };
  }

  Future<Map<String, String>> _loadMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((k, v) => MapEntry('$k', '$v'));
  }

  Future<void> _saveMap(String key, Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(map));
  }
}
