import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/web_admin/features/member_rankings/member_ranking_models.dart';
import 'package:access_mobile/web_admin/features/members/team_member_models.dart';

class TeamMembersRepository {
  Future<List<TeamMemberProfile>> loadTeam() async {
    final users = await adminApi.allUsers();
    final tasks = await adminApi.allTasks();
    final events = await adminApi.allEvents();
    final rankings = await adminApi.rankings();
    final media = await adminApi.allMedia();
    final evaluations = await adminApi.allEvaluations();

    final rankingByUser = {for (final r in rankings) r['user_id'] as int? ?? r['id'] as int? ?? -1: r};
    final eventsByRequest = <int, Map<String, dynamic>>{};
    for (final e in events) {
      final rid = e['documentation_request_id'] as int? ?? e['request_id'] as int?;
      if (rid != null) eventsByRequest[rid] = e;
    }

    final activeTasksByMember = <int, Map<String, dynamic>>{};
    for (final t in tasks) {
      final mid = t['member_id'] as int?;
      if (mid == null) continue;
      final status = (t['status'] as String? ?? '').toLowerCase();
      if (status == 'completed' || status == 'cancelled') continue;
      activeTasksByMember[mid] = t;
    }

    final evalByMedia = <int, double>{};
    for (final e in evaluations) {
      final mid = e['media_id'] as int?;
      final score = (e['overall_score'] as num?)?.toDouble() ?? 0;
      if (mid != null) evalByMedia[mid] = score * 100;
    }

    final mediaByMember = <int, List<Map<String, dynamic>>>{};
    for (final m in media) {
      final uid = m['uploader_id'] as int? ?? m['member_id'] as int?;
      if (uid == null) continue;
      mediaByMember.putIfAbsent(uid, () => []).add(m);
    }

    final profiles = <TeamMemberProfile>[];
    for (final u in users) {
      if ((u['role'] as String? ?? '').toLowerCase() != 'member') continue;

      final id = u['user_id'] as int? ?? -1;
      final status = (u['status'] as String? ?? 'pending').toLowerCase();
      final isActive = u['is_active'] as bool? ?? true;
      final assigned = u['assigned_tasks'] as int? ?? 0;
      final completed = u['completed_tasks'] as int? ?? 0;
      final mediaScore = (u['media_eval_score'] as num?)?.toDouble() ?? (u['avg_score'] as num?)?.toDouble() ?? 0;
      final skillRaw = u['skill_level'] as String?;
      final skillTier = _skillTier(skillRaw);
      final coverageRole = coverageRoleFromTaskRole(u['primary_task_role'] as String?);

      final ranking = rankingByUser[id];
      final aiRating = (ranking?['ai_authenticity_score'] as num?)?.toDouble() ??
          (ranking?['admin_evaluation_score'] as num?)?.toDouble() ??
          mediaScore;

      final onTime = assigned > 0 ? (completed / assigned * 100).clamp(0, 100).toDouble() : (completed > 0 ? 100.0 : 0.0);
      final performance = (mediaScore * 0.5 + onTime * 0.3 + aiRating * 0.2).clamp(0, 100).toDouble();

      CurrentAssignmentInfo? assignment;
      TeamAvailability availability;
      if (!isActive || status == 'rejected' || status == 'inactive' || status == 'pending') {
        availability = TeamAvailability.unavailable;
      } else if (activeTasksByMember.containsKey(id)) {
        availability = TeamAvailability.assigned;
        final t = activeTasksByMember[id]!;
        final rid = t['request_id'] as int?;
        final ev = rid != null ? eventsByRequest[rid] : null;
        final eventDate = _parseDate(t['event_date'] ?? ev?['event_date']);
        assignment = CurrentAssignmentInfo(
          eventName: t['request_title'] as String? ?? ev?['title'] as String? ?? 'Documentation event',
          assignmentRole: _roleLabel(t['task_role'] as String?),
          status: _titleCase((t['status'] as String? ?? 'assigned').replaceAll('_', ' ')),
          scheduleLabel: formatScheduleLabel(eventDate, ev?['start_time'] as String?),
        );
      } else {
        availability = TeamAvailability.available;
      }

      final portfolio = _buildPortfolio(mediaByMember[id] ?? [], evalByMedia);
      final profileImage = u['profile_image'] as String?;
      final avatarUrl = profileImage != null && profileImage.isNotEmpty ? ApiConfig.mediaUrl(profileImage) : null;

      final profile = TeamMemberProfile(
        id: id,
        name: u['name'] as String? ?? '',
        email: u['email'] as String? ?? '',
        contactNumber: u['contact_number'] as String?,
        coverageRole: coverageRole,
        availability: availability,
        accountStatus: status,
        isActiveAccount: isActive,
        skillLevel: skillRaw,
        skillTier: skillTier,
        performanceScore: performance,
        completedTasks: completed,
        assignedTasks: assigned,
        averageQualityScore: mediaScore,
        onTimeRate: onTime,
        aiRating: aiRating,
        currentAssignment: assignment,
        portfolio: portfolio,
        dateJoined: _parseDate(u['approved_at'] ?? u['created_at']),
        aiRecommendation: '',
        avatarUrl: avatarUrl,
      );

      profiles.add(TeamMemberProfile(
        id: profile.id,
        name: profile.name,
        email: profile.email,
        contactNumber: profile.contactNumber,
        coverageRole: profile.coverageRole,
        availability: profile.availability,
        accountStatus: profile.accountStatus,
        isActiveAccount: profile.isActiveAccount,
        skillLevel: profile.skillLevel,
        skillTier: profile.skillTier,
        performanceScore: profile.performanceScore,
        completedTasks: profile.completedTasks,
        assignedTasks: profile.assignedTasks,
        averageQualityScore: profile.averageQualityScore,
        onTimeRate: profile.onTimeRate,
        aiRating: profile.aiRating,
        currentAssignment: profile.currentAssignment,
        portfolio: profile.portfolio,
        dateJoined: profile.dateJoined,
        aiRecommendation: buildAiRecommendation(profile),
        avatarUrl: avatarUrl,
      ));
    }

    profiles.sort((a, b) => a.name.compareTo(b.name));
    return profiles;
  }

  List<TeamMemberProfile> filterAndSort({
    required List<TeamMemberProfile> members,
    required TeamFilterChip chip,
    required String search,
    required TeamSortOption sort,
  }) {
    var list = members.where((m) {
      if (!m.matchesChip(chip)) return false;
      if (search.isEmpty) return true;
      final q = search.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.email.toLowerCase().contains(q) ||
          m.coverageRoleLabel.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      switch (sort) {
        case TeamSortOption.name:
          return a.name.compareTo(b.name);
        case TeamSortOption.performance:
          return b.performanceScore.compareTo(a.performanceScore);
        case TeamSortOption.tasksCompleted:
          return b.completedTasks.compareTo(a.completedTasks);
        case TeamSortOption.qualityScore:
          return b.averageQualityScore.compareTo(a.averageQualityScore);
        case TeamSortOption.skillLevel:
          return b.skillTier.index.compareTo(a.skillTier.index);
      }
    });
    return list;
  }

  List<PortfolioWorkItem> _buildPortfolio(List<Map<String, dynamic>> files, Map<int, double> evalByMedia) {
    final byEvent = <String, List<Map<String, dynamic>>>{};
    for (final f in files) {
      final key = f['event_title'] as String? ?? f['request_title'] as String? ?? 'Documentation';
      byEvent.putIfAbsent(key, () => []).add(f);
    }

    final items = <PortfolioWorkItem>[];
    for (final entry in byEvent.entries) {
      var photos = 0, videos = 0;
      var scoreSum = 0.0;
      var scoreCount = 0;
      DateTime? latest;
      for (final f in entry.value) {
        final type = (f['file_type'] as String? ?? '').toLowerCase();
        if (type.contains('video')) {
          videos++;
        } else {
          photos++;
        }
        final mid = f['id'] as int?;
        if (mid != null && evalByMedia.containsKey(mid)) {
          scoreSum += evalByMedia[mid]!;
          scoreCount++;
        }
        final d = _parseDate(f['uploaded_at'] ?? f['created_at']);
        if (d != null && (latest == null || d.isAfter(latest))) latest = d;
      }
      items.add(
        PortfolioWorkItem(
          eventName: entry.key,
          dateLabel: formatTeamDate(latest),
          photoCount: photos,
          videoCount: videos,
          qualityScore: scoreCount > 0 ? scoreSum / scoreCount : 0,
        ),
      );
    }
    items.sort((a, b) => b.dateLabel.compareTo(a.dateLabel));
    return items.take(5).toList();
  }

  SkillLevelTier _skillTier(String? raw) {
    if (raw == null || raw.isEmpty) return SkillLevelTier.beginner;
    if (raw.toLowerCase().contains('novice')) return SkillLevelTier.beginner;
    return skillLevelFromString(raw);
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  String _roleLabel(String? raw) {
    final r = coverageRoleFromTaskRole(raw);
    return switch (r) {
      TeamCoverageRole.photographer => 'Photographer',
      TeamCoverageRole.videographer => 'Videographer',
      TeamCoverageRole.unassigned => 'Coverage',
    };
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
  }
}
