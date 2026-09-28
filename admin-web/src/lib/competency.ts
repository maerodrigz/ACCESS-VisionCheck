import {
  approvedUploadsPercent,
  computeSkillScore,
  mediaQualityPercent,
  taskParticipationPercent,
} from './skillScoring'
import { buildTeamProfiles, coverageRoleLabel, memberInitials, type TeamMemberProfile } from './teamMembers'

export type CompetencyLevel = 'beginner' | 'intermediate' | 'advanced'

export type EventScaleRecommendation = 'smallEvents' | 'mediumEvents' | 'largeEvents'

export type CompetencyFilterChip =
  | 'all'
  | 'needsReview'
  | 'photographers'
  | 'videographers'
  | 'beginner'
  | 'intermediate'
  | 'advanced'
  | 'available'
  | 'assigned'

export type CompetencySortOption = 'name' | 'performance' | 'competency' | 'tasksCompleted' | 'acceptanceRate'

export interface CompetencyCriterion {
  label: string
  met: boolean
  detail: string
}

export interface CompetencyAssessment {
  recommendedLevel: CompetencyLevel
  explanation: string
  criteria: CompetencyCriterion[]
  skillScore: number
}

export interface CompetencyMember {
  profile: TeamMemberProfile
  currentLevel: CompetencyLevel
  recommendedLevel: CompetencyLevel
  assessment: CompetencyAssessment
  eventRecommendation: EventScaleRecommendation
  strengths: string[]
  areasForImprovement: string[]
  trainingRecommendations: string[]
  featuredMediaCount: number
  mediaAcceptanceRate: number
  eventsCovered: number
  integritySummary: string
  integrityViolations: number
  integrityWarnings: number
  adminNotes: string | null
  levelOverridden: boolean
}

export interface CompetencyOverviewStats {
  totalMembers: number
  advancedCount: number
  intermediateCount: number
  beginnerCount: number
  needsReview: number
}

export interface CompetencyDashboardData {
  members: CompetencyMember[]
  stats: CompetencyOverviewStats
}

export interface RankingRow {
  id: number
  skillLevel: string
  completedTasks: number
  approvedUploads: number
  totalUploads: number
  skillScore: number
  mediaQualityScore: number
  approvedUploadsScore: number
  taskParticipationScore: number
  adminEvaluationScore: number
  aiAuthenticityScore: number
  adminRemarks: string | null
  competencyLevelOverride: string | null
  competencyRecommendedLevel: string | null
  integrityViolations: number
  integrityWarnings: number
}

const LEVEL_LABELS: Record<CompetencyLevel, string> = {
  beginner: 'Beginner',
  intermediate: 'Intermediate',
  advanced: 'Advanced',
}

export const FILTER_CHIPS: { id: CompetencyFilterChip; label: string }[] = [
  { id: 'needsReview', label: 'Needs review' },
  { id: 'all', label: 'All' },
  { id: 'photographers', label: 'Photographers' },
  { id: 'videographers', label: 'Videographers' },
  { id: 'beginner', label: 'Beginner' },
  { id: 'intermediate', label: 'Intermediate' },
  { id: 'advanced', label: 'Advanced' },
  { id: 'available', label: 'Available' },
  { id: 'assigned', label: 'Assigned' },
]

export const SORT_OPTIONS: { id: CompetencySortOption; label: string }[] = [
  { id: 'name', label: 'Name' },
  { id: 'performance', label: 'Highest ranked' },
  { id: 'competency', label: 'Competency level' },
  { id: 'tasksCompleted', label: 'Tasks completed' },
  { id: 'acceptanceRate', label: 'Acceptance rate' },
]

const EVENT_LABELS: Record<EventScaleRecommendation, string> = {
  smallEvents: 'Small Events',
  mediumEvents: 'Medium Events',
  largeEvents: 'Large Events',
}

export function competencyLevelLabel(level: CompetencyLevel): string {
  return LEVEL_LABELS[level]
}

export function eventRecommendationLabel(rec: EventScaleRecommendation): string {
  return EVENT_LABELS[rec]
}

export function competencyFromScore(score: number): CompetencyLevel {
  if (score >= 75) return 'advanced'
  if (score >= 60) return 'intermediate'
  return 'beginner'
}

export function competencyFromLabel(raw: string | null | undefined): CompetencyLevel {
  const n = (raw ?? '').toLowerCase()
  if (n.includes('advanced') || n.includes('expert')) return 'advanced'
  if (n.includes('intermediate')) return 'intermediate'
  return 'beginner'
}

export function competencyLevelToApiLabel(level: CompetencyLevel): 'Beginner' | 'Intermediate' | 'Advanced' {
  return LEVEL_LABELS[level] as 'Beginner' | 'Intermediate' | 'Advanced'
}

export function memberNeedsReview(member: CompetencyMember): boolean {
  if (member.integrityViolations > 0) return true
  if (member.currentLevel !== member.recommendedLevel) return true
  if (member.integrityWarnings > 0 && !member.levelOverridden) return true
  return false
}

export function parseRankingRow(m: Record<string, unknown>): RankingRow {
  const avgRaw = Number(m.average_quality_score ?? m.avg_score ?? 0)
  const approved = Number(m.approved_uploads ?? 0)
  const totalUp = Number(m.total_uploads ?? m.uploads ?? 0)
  const completed = Number(m.completed_tasks ?? 0)
  const assigned = Number(m.assigned_tasks ?? 0)
  const adminEval = Number(m.admin_evaluation_score ?? 0)
  const human = Number(m.ai_human_count ?? 0)
  const flagged = Number(m.ai_flagged_count ?? 0)
  const totalChecked = human + flagged

  let skillScore = Number(m.skill_score ?? 0)
  let mediaQ = Number(m.media_quality_score ?? mediaQualityPercent(avgRaw))
  let approvedQ = Number(m.approved_uploads_score ?? approvedUploadsPercent(approved, totalUp))
  let taskQ = Number(m.task_participation_score ?? taskParticipationPercent(completed, assigned))
  let aiQ = Number(m.ai_authenticity_score ?? (totalChecked > 0 ? (human / totalChecked) * 100 : 100))

  if (!m.skill_score) {
    skillScore = computeSkillScore({
      mediaQualityScore: mediaQ,
      aiAuthenticityScore: aiQ,
    })
  }

  return {
    id: Number(m.user_id ?? m.id ?? 0),
    skillLevel: String(m.skill_level ?? ''),
    completedTasks: completed,
    approvedUploads: approved,
    totalUploads: totalUp,
    skillScore,
    mediaQualityScore: mediaQ,
    approvedUploadsScore: approvedQ,
    taskParticipationScore: taskQ,
    adminEvaluationScore: adminEval,
    aiAuthenticityScore: aiQ,
    adminRemarks: m.admin_remarks != null ? String(m.admin_remarks) : null,
    competencyLevelOverride:
      m.competency_level_override != null ? String(m.competency_level_override) : null,
    competencyRecommendedLevel:
      m.competency_recommended_level != null
        ? String(m.competency_recommended_level)
        : competencyLevelToApiLabel(competencyFromScore(skillScore)),
    integrityViolations: Number(m.integrity_violations ?? 0),
    integrityWarnings: Number(m.integrity_warnings ?? 0),
  }
}

function buildAssessment(
  profile: TeamMemberProfile,
  ranking: RankingRow | undefined,
  violations: number,
  _warnings: number,
): CompetencyAssessment {
  const completed = ranking?.completedTasks ?? profile.completedTasks
  const approved = ranking?.approvedUploads ?? 0
  const total = ranking?.totalUploads ?? 0
  const acceptance = total > 0 ? (approved / total) * 100 : 0
  const mediaQ = ranking?.mediaQualityScore ?? profile.averageQualityScore
  const taskPart = ranking?.taskParticipationScore ?? 0
  const portfolioCount = profile.portfolio.length

  const skillScore =
    ranking?.skillScore ??
    computeSkillScore({
      mediaQualityScore: mediaQ,
      aiAuthenticityScore: ranking?.aiAuthenticityScore ?? 100,
    })

  const criteria: CompetencyCriterion[] = [
    {
      label: 'Completed 25+ documentation requests',
      met: completed >= 25,
      detail: `${completed} completed`,
    },
    {
      label: 'High media acceptance rate',
      met: acceptance >= 75 || (ranking?.approvedUploadsScore ?? 0) >= 75,
      detail: total > 0 ? `${Math.round(acceptance)}% accepted` : 'No uploads yet',
    },
    {
      label: 'No integrity violations',
      met: violations === 0,
      detail: violations === 0 ? 'Clean integrity record' : `${violations} confirmed violation${violations === 1 ? '' : 's'}`,
    },
    {
      label: 'Consistent participation',
      met: taskPart >= 70 || (profile.assignedTasks > 0 && completed / profile.assignedTasks >= 0.7),
      detail:
        profile.assignedTasks > 0
          ? `${Math.round((completed / profile.assignedTasks) * 100)}% task completion`
          : `${completed} tasks completed`,
    },
    {
      label: 'Strong documentation portfolio',
      met: portfolioCount >= 3 && mediaQ >= 70,
      detail: `${portfolioCount} event${portfolioCount === 1 ? '' : 's'} · ${Math.round(mediaQ)}% avg quality`,
    },
  ]

  const metCount = criteria.filter((c) => c.met).length
  let level = competencyFromScore(skillScore)
  if (violations > 0 && level === 'advanced') level = 'intermediate'
  if (violations >= 2) level = 'beginner'

  let explanation: string
  switch (level) {
    case 'advanced':
      explanation =
        'This member consistently submits complete event documentation, maintains a high media acceptance rate, and has successfully covered multiple university-wide events.'
      break
    case 'intermediate':
      explanation =
        'This member shows reliable documentation performance with room to grow into larger campus events after additional portfolio depth.'
      break
    default:
      explanation =
        'This member is building experience — assign smaller events first while monitoring acceptance rates and integrity indicators.'
  }

  if (metCount < 3 && level === 'advanced') {
    return {
      recommendedLevel: 'intermediate',
      explanation:
        'Performance indicators suggest intermediate competency — several advanced criteria are not yet consistently met.',
      criteria,
      skillScore,
    }
  }

  return { recommendedLevel: level, explanation, criteria, skillScore }
}

function eventRecommendation(level: CompetencyLevel, performance: number): EventScaleRecommendation {
  if (level === 'advanced' && performance >= 78) return 'largeEvents'
  if (level === 'intermediate' || (level === 'advanced' && performance >= 65)) return 'mediumEvents'
  return 'smallEvents'
}

function strengths(profile: TeamMemberProfile, ranking: RankingRow | undefined): string[] {
  const out: string[] = []
  const q = profile.averageQualityScore
  const isPhoto = profile.coverageRole === 'photographer'

  if (profile.completedTasks >= 3) out.push(isPhoto ? 'Event Photography' : 'Event Videography')
  if (q >= 72) out.push('Composition')
  if (q >= 68) out.push(isPhoto ? 'Lighting' : 'Storytelling')
  if ((ranking?.approvedUploadsScore ?? 0) >= 70 || profile.onTimeRate >= 75) out.push('Timely Submissions')
  if (profile.portfolio.length >= 2) out.push('Documentation Portfolio')
  if (out.length === 0) out.push(isPhoto ? 'Developing photography fundamentals' : 'Developing videography fundamentals')
  return out.slice(0, 5)
}

function improvements(profile: TeamMemberProfile, ranking: RankingRow | undefined): string[] {
  const out: string[] = []
  const isPhoto = profile.coverageRole === 'photographer'

  if (profile.averageQualityScore < 70) out.push(isPhoto ? 'Lighting consistency' : 'Video stabilization')
  if (profile.onTimeRate < 70) out.push('Submission timelines')
  if ((ranking?.totalUploads ?? 0) < 5) out.push('Portfolio depth')
  if (!isPhoto && profile.averageQualityScore < 75) out.push('Camera movement')
  if (isPhoto && profile.averageQualityScore < 75) out.push('Night photography')
  if ((ranking?.aiAuthenticityScore ?? 100) < 90) out.push('Media authenticity practices')
  if (out.length === 0) out.push('Continue refining advanced event coverage techniques')
  return out.slice(0, 4)
}

function training(profile: TeamMemberProfile, ranking: RankingRow | undefined): string[] {
  const out: string[] = []
  const isPhoto = profile.coverageRole === 'photographer'

  if (profile.averageQualityScore < 70) {
    out.push(isPhoto ? 'Improve low-light photography.' : 'Improve video stabilization and camera movement.')
  }
  if (profile.completedTasks < 5) out.push('Participate in the next practical documentation workshop.')
  const skill = competencyFromLabel(profile.skillLevel)
  if ((skill === 'intermediate' || skill === 'advanced') && profile.portfolio.length < 4) {
    out.push('Gain additional experience in large-scale campus events.')
  }
  if ((ranking?.approvedUploadsScore ?? 0) < 65) {
    out.push('Review ACCESS documentation quality guidelines before the next assignment.')
  }
  if (out.length === 0) {
    out.push(`Maintain current standards and mentor newer ${isPhoto ? 'photographers' : 'videographers'}.`)
  }
  return out.slice(0, 3)
}

function featuredCount(profile: TeamMemberProfile): number {
  let count = 0
  for (const item of profile.portfolio) {
    if (item.qualityScore >= 80) count += item.photoCount + item.videoCount
  }
  return count
}

function acceptanceRate(ranking: RankingRow | undefined, profile: TeamMemberProfile): number {
  if (ranking && ranking.totalUploads > 0) {
    return Math.min(100, Math.max(0, (ranking.approvedUploads / ranking.totalUploads) * 100))
  }
  return Math.min(100, Math.max(0, profile.averageQualityScore))
}

function integritySummary(violations: number, warnings: number): string {
  if (violations > 0) return `${violations} confirmed violation${violations === 1 ? '' : 's'} on record`
  if (warnings > 0) return `${warnings} integrity warning${warnings === 1 ? '' : 's'} — no confirmed violations`
  return 'Clean integrity record'
}

function computeStats(members: CompetencyMember[]): CompetencyOverviewStats {
  let advancedCount = 0
  let intermediateCount = 0
  let beginnerCount = 0
  let needsReview = 0
  for (const m of members) {
    switch (m.currentLevel) {
      case 'advanced':
        advancedCount++
        break
      case 'intermediate':
        intermediateCount++
        break
      default:
        beginnerCount++
    }
    if (memberNeedsReview(m)) needsReview++
  }
  return { totalMembers: members.length, advancedCount, intermediateCount, beginnerCount, needsReview }
}

export function buildCompetencyDashboard(input: {
  users: Record<string, unknown>[]
  tasks: Record<string, unknown>[]
  events: Record<string, unknown>[]
  rankings: Record<string, unknown>[]
  media: Record<string, unknown>[]
  evaluations: Record<string, unknown>[]
  memberRatingSummaries?: Record<string, { count: number; average_rating: number | null }>
}): CompetencyDashboardData {
  const profiles = buildTeamProfiles(input)
  const rankingByUser = new Map<number, RankingRow>()
  for (const r of input.rankings) {
    const row = parseRankingRow(r)
    if (row.id > 0) rankingByUser.set(row.id, row)
  }

  const members: CompetencyMember[] = []
  for (const profile of profiles) {
    if (profile.accountStatus !== 'approved' || !profile.isActiveAccount) continue
    if (profile.coverageRole === 'unassigned') continue

    const ranking = rankingByUser.get(profile.id)
    const violations = ranking?.integrityViolations ?? 0
    const warnings = ranking?.integrityWarnings ?? 0
    const assessment = buildAssessment(profile, ranking, violations, warnings)
    const levelOverride = ranking?.competencyLevelOverride ?? null
    const levelOverridden = Boolean(levelOverride?.trim())
    const currentLevel = competencyFromLabel(
      ranking?.skillLevel ||
        profile.skillLevel ||
        (levelOverridden
          ? levelOverride
          : ranking?.competencyRecommendedLevel ?? LEVEL_LABELS[assessment.recommendedLevel]),
    )

    members.push({
      profile,
      currentLevel,
      recommendedLevel: assessment.recommendedLevel,
      assessment,
      eventRecommendation: eventRecommendation(currentLevel, profile.performanceScore),
      strengths: strengths(profile, ranking),
      areasForImprovement: improvements(profile, ranking),
      trainingRecommendations: training(profile, ranking),
      featuredMediaCount: featuredCount(profile),
      mediaAcceptanceRate: acceptanceRate(ranking, profile),
      eventsCovered: profile.portfolio.length,
      integritySummary: integritySummary(violations, warnings),
      integrityViolations: violations,
      integrityWarnings: warnings,
      adminNotes: ranking?.adminRemarks ?? null,
      levelOverridden,
    })
  }

  members.sort((a, b) => a.profile.name.localeCompare(b.profile.name))
  return { members, stats: computeStats(members) }
}

const levelRank: Record<CompetencyLevel, number> = { beginner: 0, intermediate: 1, advanced: 2 }

export function matchesChip(member: CompetencyMember, chip: CompetencyFilterChip): boolean {
  const p = member.profile
  switch (chip) {
    case 'all':
      return true
    case 'needsReview':
      return memberNeedsReview(member)
    case 'photographers':
      return p.coverageRole === 'photographer'
    case 'videographers':
      return p.coverageRole === 'videographer'
    case 'beginner':
      return member.currentLevel === 'beginner'
    case 'intermediate':
      return member.currentLevel === 'intermediate'
    case 'advanced':
      return member.currentLevel === 'advanced'
    case 'available':
      return p.availability === 'available'
    case 'assigned':
      return p.availability === 'assigned'
    default:
      return true
  }
}

export function filterAndSortCompetency(
  members: CompetencyMember[],
  opts: { chip: CompetencyFilterChip; search: string; sort: CompetencySortOption },
): CompetencyMember[] {
  const q = opts.search.trim().toLowerCase()
  let list = members.filter((m) => {
    if (!matchesChip(m, opts.chip)) return false
    if (!q) return true
    return (
      m.profile.name.toLowerCase().includes(q) ||
      coverageRoleLabel(m.profile.coverageRole).toLowerCase().includes(q) ||
      competencyLevelLabel(m.currentLevel).toLowerCase().includes(q) ||
      m.profile.availability.toLowerCase().includes(q) ||
      (m.profile.currentAssignment?.eventName.toLowerCase().includes(q) ?? false)
    )
  })

  list = [...list].sort((a, b) => {
    switch (opts.sort) {
      case 'name':
        return a.profile.name.localeCompare(b.profile.name)
      case 'performance':
        return b.profile.performanceScore - a.profile.performanceScore
      case 'competency':
        return levelRank[b.currentLevel] - levelRank[a.currentLevel]
      case 'tasksCompleted':
        return b.profile.completedTasks - a.profile.completedTasks
      case 'acceptanceRate':
        return b.mediaAcceptanceRate - a.mediaAcceptanceRate
      default:
        return 0
    }
  })

  return list
}

export function countByChip(members: CompetencyMember[], chip: CompetencyFilterChip): number {
  return members.filter((m) => matchesChip(m, chip)).length
}

export function buildExportReport(data: CompetencyDashboardData): string {
  const lines: string[] = [
    'ACCESS VisionCheck — Competency Management Report',
    `Generated: ${new Date().toLocaleString()}`,
    '',
    'Overview',
    `  Total members: ${data.stats.totalMembers}`,
    `  Advanced: ${data.stats.advancedCount}`,
    `  Intermediate: ${data.stats.intermediateCount}`,
    `  Beginner: ${data.stats.beginnerCount}`,
    `  Needs review: ${data.stats.needsReview}`,
    '',
  ]
  for (const m of data.members) {
    lines.push(`${m.profile.name} (${coverageRoleLabel(m.profile.coverageRole)})`)
    lines.push(`  Current: ${competencyLevelLabel(m.currentLevel)}${m.levelOverridden ? ' (admin override)' : ''}`)
    lines.push(`  Recommended: ${competencyLevelLabel(m.recommendedLevel)}`)
    lines.push(`  Performance: ${Math.round(m.profile.performanceScore)}%`)
    lines.push(`  Acceptance rate: ${Math.round(m.mediaAcceptanceRate)}%`)
    lines.push(`  Recommended for: ${eventRecommendationLabel(m.eventRecommendation)}`)
    if (m.adminNotes) lines.push(`  Notes: ${m.adminNotes}`)
    lines.push('')
  }
  return lines.join('\n')
}

export function memberDisplayName(m: CompetencyMember): string {
  return m.profile.name
}

export function memberInitialsFromCompetency(m: CompetencyMember): string {
  return memberInitials(m.profile.name)
}
