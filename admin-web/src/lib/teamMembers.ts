import { isVideoMediaPath, mediaUrl } from '../api/media'
import { scoreToPercent } from './mediaEvaluationScores'

export type TeamFilterChip =
  | 'all'
  | 'photographers'
  | 'videographers'
  | 'available'
  | 'assigned'
  | 'inactive'

export type TeamCoverageRole = 'photographer' | 'videographer' | 'unassigned'

export type TeamAvailability = 'available' | 'assigned' | 'unavailable'

export type TeamSortOption = 'name' | 'performance' | 'tasksCompleted' | 'qualityScore' | 'skillLevel'

export type SkillLevelTier = 'beginner' | 'intermediate' | 'advanced' | 'expert'

export interface CurrentAssignmentInfo {
  requestId: number | null
  eventName: string
  assignmentRole: string
  status: string
  scheduleLabel: string
}

export interface PortfolioWorkItem {
  eventName: string
  dateLabel: string
  photoCount: number
  videoCount: number
  qualityScore: number
}

export interface MemberUploadPreview {
  id: number
  fileName: string
  thumbnailUrl: string
  isVideo: boolean
  eventName: string
  sourceLabel: string
  uploadDateLabel: string
  overallScore: number | null
  mediaCategory: 'event_documentation' | 'member_evaluation'
}

export interface TeamMemberProfile {
  id: number
  name: string
  email: string
  contactNumber: string | null
  coverageRole: TeamCoverageRole
  availability: TeamAvailability
  accountStatus: string
  isActiveAccount: boolean
  skillLevel: string | null
  skillTier: SkillLevelTier
  performanceScore: number
  completedTasks: number
  assignedTasks: number
  averageQualityScore: number
  onTimeRate: number
  aiRating: number
  requesterRatingAvg: number | null
  requesterRatingCount: number
  currentAssignment: CurrentAssignmentInfo | null
  portfolio: PortfolioWorkItem[]
  recentUploads: MemberUploadPreview[]
  uploadCount: number
  dateJoined: Date | null
  aiRecommendation: string
  avatarUrl: string | null
}

export interface PendingRegistration {
  id: number
  name: string
  email: string
  studentId: string | null
  contactNumber: string | null
  skillLevel: string | null
  dateRegistered: Date | null
  avatarUrl: string | null
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

export function skillLevelFromString(raw: string | null | undefined): SkillLevelTier {
  const n = (raw ?? '').toLowerCase()
  if (n.includes('expert')) return 'expert'
  if (n.includes('advanced')) return 'advanced'
  if (n.includes('intermediate')) return 'intermediate'
  return 'beginner'
}

export function coverageRoleFromTaskRole(raw: string | null | undefined): TeamCoverageRole {
  const r = (raw ?? '').toLowerCase()
  if (r.includes('video')) return 'videographer'
  if (r.includes('photo')) return 'photographer'
  return 'unassigned'
}

export function formatTeamDate(d: Date | null): string {
  if (!d) return '—'
  return `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`
}

export function formatScheduleLabel(date: Date | null, startTime?: string | null): string {
  if (!date) return 'TBD'
  const datePart = `${MONTHS[date.getMonth()]} ${date.getDate()}`
  if (!startTime) return datePart
  const parsed = new Date(`1970-01-01T${startTime}`)
  if (!Number.isNaN(parsed.getTime())) {
    const h = parsed.getHours() % 12 || 12
    const m = parsed.getMinutes().toString().padStart(2, '0')
    const ap = parsed.getHours() >= 12 ? 'PM' : 'AM'
    return `${datePart}, ${h}:${m} ${ap}`
  }
  return `${datePart}, ${startTime}`
}

export function memberInitials(name: string): string {
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase()
  return name.length > 0 ? name[0].toUpperCase() : '?'
}

export function coverageRoleLabel(role: TeamCoverageRole): string {
  switch (role) {
    case 'photographer':
      return 'Photographer'
    case 'videographer':
      return 'Videographer'
    default:
      return 'Unassigned'
  }
}

export function skillLevelLabel(member: TeamMemberProfile): string {
  const raw = member.skillLevel ?? ''
  if (raw) return raw
  return member.skillTier.charAt(0).toUpperCase() + member.skillTier.slice(1)
}

export type MemberAccountLabel = 'Active' | 'Inactive' | 'Pending'

export function memberAccountLabel(member: TeamMemberProfile): MemberAccountLabel {
  const status = member.accountStatus.toLowerCase()
  if (status === 'pending') return 'Pending'
  if (status === 'rejected' || !member.isActiveAccount) return 'Inactive'
  if (status === 'approved' || status === 'active') return 'Active'
  return member.isActiveAccount ? 'Active' : 'Inactive'
}

export function availabilityTitle(availability: TeamAvailability): string {
  switch (availability) {
    case 'available':
      return 'Available'
    case 'assigned':
      return 'Assigned'
    default:
      return 'Unavailable'
  }
}

export function availabilitySubtitle(member: TeamMemberProfile): string {
  switch (member.availability) {
    case 'available':
      return 'No current assignments.'
    case 'assigned':
      return member.currentAssignment
        ? `${member.currentAssignment.eventName} (${member.currentAssignment.scheduleLabel})`
        : 'Active documentation assignment'
    default:
      return 'On leave / Inactive'
  }
}

export function matchesChip(member: TeamMemberProfile, chip: TeamFilterChip): boolean {
  const approved = member.accountStatus === 'approved' && member.isActiveAccount
  switch (chip) {
    case 'all':
      return approved
    case 'photographers':
      return approved && member.coverageRole === 'photographer'
    case 'videographers':
      return approved && member.coverageRole === 'videographer'
    case 'available':
      return approved && member.availability === 'available'
    case 'assigned':
      return approved && member.availability === 'assigned'
    case 'inactive':
      return member.availability === 'unavailable'
    default:
      return true
  }
}

export function buildAiRecommendation(m: TeamMemberProfile): string {
  if (m.availability === 'unavailable') {
    return 'This member is currently inactive. Reactivate their account before assigning documentation work.'
  }
  if (m.averageQualityScore >= 85 && m.completedTasks >= 5) {
    return 'This member consistently produces high-quality documentation and is recommended for major campus events.'
  }
  if (m.averageQualityScore >= 70 && m.onTimeRate >= 80) {
    return 'Reliable contributor with solid quality scores — suitable for standard event coverage.'
  }
  if (m.completedTasks < 3) {
    return 'Newer team member — assign smaller events first to build portfolio and evaluation history.'
  }
  if (m.onTimeRate < 60) {
    return 'Review submission timelines with this member; consider pairing with a senior photographer or videographer.'
  }
  return 'Monitor upcoming assignments and media evaluations to refine role placement for future events.'
}

function resolveAvatarUrl(raw: unknown): string | null {
  const path = raw as string | null | undefined
  if (!path) return null
  const url = mediaUrl(path)
  return url || null
}

export function parseDate(raw: unknown): Date | null {
  if (raw == null) return null
  const d = new Date(String(raw))
  return Number.isNaN(d.getTime()) ? null : d
}

function titleCase(s: string): string {
  if (!s) return s
  return s
    .split(' ')
    .map((w) => (w ? `${w[0].toUpperCase()}${w.slice(1).toLowerCase()}` : w))
    .join(' ')
}

function roleLabel(raw: string | null | undefined): string {
  const r = coverageRoleFromTaskRole(raw)
  switch (r) {
    case 'photographer':
      return 'Photographer'
    case 'videographer':
      return 'Videographer'
    default:
      return 'Coverage'
  }
}

function skillTier(raw: string | null | undefined): SkillLevelTier {
  if (!raw) return 'beginner'
  if (raw.toLowerCase().includes('novice')) return 'beginner'
  return skillLevelFromString(raw)
}

function buildPortfolio(
  files: Record<string, unknown>[],
  evalByMedia: Map<number, number>,
): PortfolioWorkItem[] {
  const byEvent = new Map<string, Record<string, unknown>[]>()
  for (const f of files) {
    const key = String(f.event_title ?? f.request_title ?? 'Documentation')
    if (!byEvent.has(key)) byEvent.set(key, [])
    byEvent.get(key)!.push(f)
  }

  const items: PortfolioWorkItem[] = []
  for (const [eventName, group] of byEvent) {
    let photos = 0
    let videos = 0
    let scoreSum = 0
    let scoreCount = 0
    let latest: Date | null = null
    for (const f of group) {
      const type = String(f.file_type ?? '').toLowerCase()
      if (type.includes('video')) videos++
      else photos++
      const mid = Number(f.id)
      if (evalByMedia.has(mid)) {
        scoreSum += evalByMedia.get(mid)!
        scoreCount++
      }
      const d = parseDate(f.uploaded_at ?? f.created_at)
      if (d && (!latest || d > latest)) latest = d
    }
    items.push({
      eventName,
      dateLabel: formatTeamDate(latest),
      photoCount: photos,
      videoCount: videos,
      qualityScore: scoreCount > 0 ? scoreSum / scoreCount : 0,
    })
  }
  items.sort((a, b) => b.dateLabel.localeCompare(a.dateLabel))
  return items.slice(0, 5)
}

function isVideoFile(fileType: string, fileName: string, fileUrl: string): boolean {
  if (fileType.toLowerCase().includes('video')) return true
  return isVideoMediaPath(fileName) || isVideoMediaPath(fileUrl)
}

function mediaUploaderId(row: Record<string, unknown>): number {
  return Number(row.uploaded_by ?? row.uploader_id ?? row.member_id ?? 0)
}

function buildRecentUploads(
  files: Record<string, unknown>[],
  evalByMedia: Map<number, number>,
  limit = 8,
): MemberUploadPreview[] {
  const sorted = [...files].sort((a, b) => {
    const da = parseDate(a.uploaded_at ?? a.created_at)?.getTime() ?? 0
    const db = parseDate(b.uploaded_at ?? b.created_at)?.getTime() ?? 0
    return db - da
  })

  return sorted.slice(0, limit).map((f) => {
    const id = Number(f.id ?? 0)
    const fileName = String(f.file_name ?? `Media #${id}`)
    const fileUrl = String(f.file_url ?? '')
    const fileType = String(f.file_type ?? 'image')
    const isVideo = isVideoFile(fileType, fileName, fileUrl)
    const uploadedAt = parseDate(f.uploaded_at ?? f.created_at)
    const requestId = f.request_id != null ? Number(f.request_id) : null
    const eventTitle = String(f.event_title ?? f.request_title ?? '')
    const sourceLabel = String(
      f.source_label ?? (requestId ? eventTitle || 'Event coverage' : 'Practice evaluation'),
    )
    const mediaCategory =
      (f.media_category as MemberUploadPreview['mediaCategory']) ??
      (requestId ? 'event_documentation' : 'member_evaluation')

    return {
      id,
      fileName,
      thumbnailUrl: mediaUrl(fileUrl),
      isVideo,
      eventName: eventTitle || sourceLabel,
      sourceLabel,
      uploadDateLabel: formatTeamDate(uploadedAt),
      overallScore: evalByMedia.has(id) ? evalByMedia.get(id)! : null,
      mediaCategory,
    }
  })
}

export function buildTeamProfiles(input: {
  users: Record<string, unknown>[]
  tasks: Record<string, unknown>[]
  events: Record<string, unknown>[]
  rankings: Record<string, unknown>[]
  media: Record<string, unknown>[]
  evaluations: Record<string, unknown>[]
  memberRatingSummaries?: Record<string, { count: number; average_rating: number | null }>
}): TeamMemberProfile[] {
  const { users, tasks, events, rankings, media, evaluations, memberRatingSummaries = {} } = input

  const rankingByUser = new Map<number, Record<string, unknown>>()
  for (const r of rankings) {
    const id = Number(r.user_id ?? r.id ?? -1)
    rankingByUser.set(id, r)
  }

  const eventsByRequest = new Map<number, Record<string, unknown>>()
  for (const e of events) {
    const rid = Number(e.documentation_request_id ?? e.request_id)
    if (rid) eventsByRequest.set(rid, e)
  }

  const activeTasksByMember = new Map<number, Record<string, unknown>>()
  for (const t of tasks) {
    const mid = Number(t.member_id)
    if (!mid) continue
    const status = String(t.status ?? '').toLowerCase()
    if (status === 'completed' || status === 'cancelled') continue
    activeTasksByMember.set(mid, t)
  }

  const evalByMedia = new Map<number, number>()
  for (const e of evaluations) {
    const mid = Number(e.media_id)
    const score = Number(e.overall_score ?? 0)
    if (mid) evalByMedia.set(mid, scoreToPercent(score))
  }

  const mediaByMember = new Map<number, Record<string, unknown>[]>()
  for (const m of media) {
    const uid = mediaUploaderId(m)
    if (!uid) continue
    if (!mediaByMember.has(uid)) mediaByMember.set(uid, [])
    mediaByMember.get(uid)!.push(m)
  }

  const profiles: TeamMemberProfile[] = []

  for (const u of users) {
    if (String(u.role ?? '').toLowerCase() !== 'member') continue

    const id = Number(u.user_id ?? -1)
    const status = String(u.status ?? 'pending').toLowerCase()
    const isActive = u.is_active !== false
    const assigned = Number(u.assigned_tasks ?? 0)
    const completed = Number(u.completed_tasks ?? 0)
    const mediaScore = Number(u.media_eval_score ?? u.avg_score ?? 0)
    const skillRaw = (u.skill_level as string | null) ?? null
    const coverageRole = coverageRoleFromTaskRole(u.primary_task_role as string | undefined)

    const ranking = rankingByUser.get(id)
    const aiRating = Number(
      ranking?.ai_authenticity_score ?? ranking?.admin_evaluation_score ?? mediaScore,
    )

    const onTime =
      assigned > 0 ? Math.min(100, Math.max(0, (completed / assigned) * 100)) : completed > 0 ? 100 : 0
    const ratingSummary = memberRatingSummaries[String(id)]
    const requesterRatingCount = ratingSummary?.count ?? 0
    const requesterRatingAvg = ratingSummary?.average_rating ?? null
    const requesterScore =
      requesterRatingAvg != null ? (requesterRatingAvg / 5) * 100 : 0
    const performance = Math.min(
      100,
      Math.max(
        0,
        mediaScore * 0.4 +
          onTime * 0.25 +
          aiRating * 0.15 +
          (requesterRatingCount > 0 ? requesterScore * 0.2 : 0),
      ),
    )

    let assignment: CurrentAssignmentInfo | null = null
    let availability: TeamAvailability
    if (!isActive || status === 'rejected' || status === 'inactive' || status === 'pending') {
      availability = 'unavailable'
    } else if (activeTasksByMember.has(id)) {
      availability = 'assigned'
      const t = activeTasksByMember.get(id)!
      const rid = Number(t.request_id)
      const ev = rid ? eventsByRequest.get(rid) : undefined
      const eventDate = parseDate(t.event_date ?? ev?.event_date)
      assignment = {
        requestId: rid > 0 ? rid : null,
        eventName: String(t.request_title ?? ev?.title ?? 'Documentation event'),
        assignmentRole: roleLabel(t.task_role as string | undefined),
        status: titleCase(String(t.status ?? 'assigned').replaceAll('_', ' ')),
        scheduleLabel: formatScheduleLabel(eventDate, ev?.start_time as string | undefined),
      }
    } else {
      availability = 'available'
    }

    const memberMedia = mediaByMember.get(id) ?? []
    const portfolio = buildPortfolio(memberMedia, evalByMedia)
    const recentUploads = buildRecentUploads(memberMedia, evalByMedia)
    const avatarUrl = resolveAvatarUrl(u.profile_image)

    const draft: TeamMemberProfile = {
      id,
      name: String(u.name ?? ''),
      email: String(u.email ?? ''),
      contactNumber: (u.contact_number as string | null) ?? null,
      coverageRole,
      availability,
      accountStatus: status,
      isActiveAccount: isActive,
      skillLevel: skillRaw,
      skillTier: skillTier(skillRaw),
      performanceScore: performance,
      completedTasks: completed,
      assignedTasks: assigned,
      averageQualityScore: mediaScore,
      onTimeRate: onTime,
      aiRating,
      requesterRatingAvg,
      requesterRatingCount,
      currentAssignment: assignment,
      portfolio,
      recentUploads,
      uploadCount: memberMedia.length,
      dateJoined: parseDate(u.approved_at ?? u.created_at),
      aiRecommendation: '',
      avatarUrl,
    }

    profiles.push({ ...draft, aiRecommendation: buildAiRecommendation(draft) })
  }

  profiles.sort((a, b) => a.name.localeCompare(b.name))
  return profiles
}

export function filterAndSortTeam(
  members: TeamMemberProfile[],
  opts: { chip: TeamFilterChip; search: string; sort: TeamSortOption },
): TeamMemberProfile[] {
  const q = opts.search.trim().toLowerCase()
  let list = members.filter((m) => {
    if (!matchesChip(m, opts.chip)) return false
    if (!q) return true
    return (
      m.name.toLowerCase().includes(q) ||
      m.email.toLowerCase().includes(q) ||
      coverageRoleLabel(m.coverageRole).toLowerCase().includes(q)
    )
  })

  const tierRank: Record<SkillLevelTier, number> = {
    beginner: 0,
    intermediate: 1,
    advanced: 2,
    expert: 3,
  }

  list = [...list].sort((a, b) => {
    switch (opts.sort) {
      case 'name':
        return a.name.localeCompare(b.name)
      case 'performance':
        return b.performanceScore - a.performanceScore
      case 'tasksCompleted':
        return b.completedTasks - a.completedTasks
      case 'qualityScore':
        return b.averageQualityScore - a.averageQualityScore
      case 'skillLevel':
        return tierRank[b.skillTier] - tierRank[a.skillTier]
      default:
        return 0
    }
  })

  return list
}

export function countByChip(members: TeamMemberProfile[], chip: TeamFilterChip): number {
  return members.filter((m) => matchesChip(m, chip)).length
}

export function parsePendingRegistration(raw: Record<string, unknown>): PendingRegistration {
  return {
    id: Number(raw.user_id ?? 0),
    name: String(raw.full_name ?? raw.name ?? ''),
    email: String(raw.email ?? ''),
    studentId: (raw.student_id as string | null) ?? null,
    contactNumber: (raw.contact_number as string | null) ?? null,
    skillLevel: (raw.skill_level as string | null) ?? null,
    dateRegistered: parseDate(raw.date_registered ?? raw.created_at),
    avatarUrl: resolveAvatarUrl(raw.profile_image),
  }
}
