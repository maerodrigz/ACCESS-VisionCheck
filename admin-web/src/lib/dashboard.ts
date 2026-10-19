import {
  fetchAiDetectionList,
  fetchDashboardStats,
  fetchEvaluations,
  fetchEvents,
  fetchMedia,
  fetchRankings,
  fetchServiceRequests,
  fetchTasks,
} from '../api/admin'
import type { AiDetectionRow } from '../api/media'
import {
  aiReviewRiskTier,
  isProbeSmokeTestRow,
  matchesIntegrityInbox,
  parseAiDetectionRow,
  sortDetectionRows,
  type AiReviewRiskTier,
} from './aiDetection'
import { fetchNotifications } from '../api/notifications'
import type { DashboardStats } from '../types/auth'
import { formatTimeAgo, parseNotification, type AdminNotification } from './notifications'
import { isGoodQualityScore, scoreToPercent } from './mediaEvaluationScores'

export interface HomeOverviewStats {
  pendingRequests: number
  todayEvents: number
  mediaPendingEvaluation: number
  activeMembers: number
  unreadNotifications: number
}

export interface PendingRequestItem {
  id: number
  eventTitle: string
  requestor: string
  requestedDate: string
  status: string
}

export interface TodayScheduleItem {
  timeLabel: string
  eventName: string
  assignedMembers: string
  status: string
}

export interface UpcomingEventItem {
  id: number
  monthLabel: string
  dayLabel: string
  eventName: string
  requestorName: string
  timeRange: string
  location: string
  memberNames: string[]
  memberCount: number
}

export interface ActivityItem {
  kind: 'request' | 'media' | 'member' | 'task' | 'feedback'
  title: string
  subtitle: string
  status: string
  time: string
}

export interface MediaQueueSnapshot {
  pendingCount: number
  completedToday: number
}

export interface AnnouncementItem {
  title: string
  body: string
  dateLabel: string
}

export type ActionCenterKind = 'request' | 'integrity' | 'media'

export interface ActionCenterItem {
  id: number
  title: string
  subtitle: string
  timeLabel: string
  kind: ActionCenterKind
  count: number
}

export interface EvalOverviewStats {
  evaluated: number
  goodQuality: number
  needsImprovement: number
  aiFlagged: number
  evaluatedTrend: number
  goodQualityTrend: number
  needsImprovementTrend: number
  aiFlaggedTrend: number
}

export interface EvaluationTrendPoint {
  dateLabel: string
  evaluated: number
  goodQuality: number
  needsImprovement: number
  aiFlagged: number
}

export interface CompetencyBreakdown {
  label: string
  count: number
  percent: number
}

export interface ActiveDocumenterSnapshot {
  totalActive: number
  breakdown: CompetencyBreakdown[]
}

export interface AiReviewQueueRecentItem {
  id: number
  mediaId: number
  fileName: string
  timeAgo: string
  riskTier: AiReviewRiskTier
}

export type { AiReviewRiskTier }

export interface AiReviewQueueSnapshot {
  highRisk: number
  suspicious: number
  lowRisk: number
  totalForReview: number
  recentItems: AiReviewQueueRecentItem[]
  available: boolean
}

export interface HomeDashboardSnapshot {
  overview: HomeOverviewStats
  pendingRequests: PendingRequestItem[]
  todaySchedule: TodayScheduleItem[]
  upcomingEvents: UpcomingEventItem[]
  recentActivity: ActivityItem[]
  notifications: AdminNotification[]
  mediaQueue: MediaQueueSnapshot
  announcements: AnnouncementItem[]
  pendingMembers: number
  stats: DashboardStats
  actionCenterItems: ActionCenterItem[]
  evalOverview: EvalOverviewStats
  evalTrend: EvaluationTrendPoint[]
  aiReviewQueue: AiReviewQueueSnapshot
  activeDocumenters: ActiveDocumenterSnapshot
}

function parseDate(raw: unknown): Date | null {
  if (raw == null) return null
  const d = new Date(String(raw))
  return Number.isNaN(d.getTime()) ? null : d
}

function formatDate(raw: unknown): string {
  const d = parseDate(raw)
  if (!d) return 'N/A'
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`
}

function formatTime(raw: string): string {
  const d = new Date(`1970-01-01T${raw}`)
  if (!Number.isNaN(d.getTime())) {
    const h = d.getHours() % 12 || 12
    const m = d.getMinutes().toString().padStart(2, '0')
    const ap = d.getHours() >= 12 ? 'PM' : 'AM'
    return `${h}:${m} ${ap}`
  }
  if (raw.includes(':')) return raw
  return raw
}

function titleCase(s: string): string {
  if (!s) return s
  return s
    .split(' ')
    .map((w) => (w ? `${w[0].toUpperCase()}${w.slice(1).toLowerCase()}` : w))
    .join(' ')
}

function buildAiReviewQueue(rows: AiDetectionRow[]): AiReviewQueueSnapshot {
  const pending = rows.filter(
    (r) => !isProbeSmokeTestRow(r) && matchesIntegrityInbox(r, 'needs_action'),
  )
  let highRisk = 0
  let suspicious = 0
  let lowRisk = 0
  for (const r of pending) {
    const tier = aiReviewRiskTier(r)
    if (tier === 'high') highRisk++
    else if (tier === 'suspicious') suspicious++
    else lowRisk++
  }
  const recentItems = sortDetectionRows(pending)
    .slice(0, 3)
    .map((r) => ({
      id: r.id,
      mediaId: r.media_id,
      fileName: r.media_name,
      timeAgo: formatTimeAgo(r.scanned_at),
      riskTier: aiReviewRiskTier(r),
    }))

  return {
    highRisk,
    suspicious,
    lowRisk,
    totalForReview: pending.length,
    recentItems,
    available: true,
  }
}

const EMPTY_AI_REVIEW_QUEUE: AiReviewQueueSnapshot = {
  highRisk: 0,
  suspicious: 0,
  lowRisk: 0,
  totalForReview: 0,
  recentItems: [],
  available: false,
}

function mapPendingRequest(r: Record<string, unknown>): PendingRequestItem {
  return {
    id: Number(r.request_id ?? r.id ?? 0),
    eventTitle: String(r.event_name ?? r.title ?? 'Documentation request'),
    requestor: String(r.requester_name ?? r.requestor_name ?? r.organization_name ?? 'Unknown'),
    requestedDate: formatDate(r.created_at),
    status: String(r.status ?? 'Pending'),
  }
}

const MONTH_LABELS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC']

function formatTimeRange(startRaw: unknown, endRaw: unknown): string {
  const startStr = startRaw != null ? String(startRaw) : ''
  const endStr = endRaw != null ? String(endRaw) : ''
  const start = startStr ? formatTime(startStr.includes('T') ? startStr.split('T')[1] ?? startStr : startStr) : ''
  const end = endStr ? formatTime(endStr.includes('T') ? endStr.split('T')[1] ?? endStr : endStr) : ''
  if (start && end && start !== end) return `${start} – ${end}`
  if (start) return start
  return 'All day'
}

function assignedMemberNames(eventId: number, tasks: Record<string, unknown>[]): string[] {
  return tasks
    .filter((t) => Number(t.event_id) === eventId)
    .map((t) => String(t.member_name ?? t.assignee_name ?? '').trim())
    .filter(Boolean)
}

function isUpcomingApprovedEvent(e: Record<string, unknown>, today: Date): boolean {
  const d = parseDate(e.event_date)
  if (!d) return false
  const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  if (day.getTime() < today.getTime()) return false
  const status = String(e.status ?? '').toLowerCase()
  if (status === 'cancelled' || status === 'canceled') return false
  const reqStatus = String(e.request_status ?? '').toLowerCase()
  if (reqStatus && reqStatus !== 'approved') return false
  return true
}

function resolveEventRequestorName(
  e: Record<string, unknown>,
  requestorByRequestId: Map<number, string>,
): string {
  const fromEvent = String(e.requester_name ?? e.requestor_name ?? '').trim()
  if (fromEvent) return fromEvent
  const reqId = Number(e.request_id ?? e.documentation_request_id ?? 0)
  if (reqId > 0) {
    const fromRequest = requestorByRequestId.get(reqId)
    if (fromRequest) return fromRequest
  }
  return 'N/A'
}

function buildRequestorByRequestId(requests: Record<string, unknown>[]): Map<number, string> {
  const map = new Map<number, string>()
  for (const r of requests) {
    const id = Number(r.request_id ?? r.id ?? 0)
    const name = String(r.requester_name ?? r.requestor_name ?? r.organization_name ?? '').trim()
    if (id > 0 && name) map.set(id, name)
  }
  return map
}

function mapUpcomingEvent(
  e: Record<string, unknown>,
  tasks: Record<string, unknown>[],
  requestorByRequestId: Map<number, string>,
): UpcomingEventItem {
  const eventId = Number(e.id)
  const members = assignedMemberNames(eventId, tasks)
  const d = parseDate(e.event_date)!
  const location = String(e.location ?? e.venue ?? '').trim()

  return {
    id: eventId,
    monthLabel: MONTH_LABELS[d.getMonth()] ?? 'N/A',
    dayLabel: String(d.getDate()),
    eventName: String(e.title ?? e.event_name ?? 'Event'),
    requestorName: resolveEventRequestorName(e, requestorByRequestId),
    timeRange: formatTimeRange(e.start_time ?? e.event_time, e.end_time),
    location: location || 'N/A',
    memberNames: members,
    memberCount: members.length,
  }
}

function mapTodayEvent(e: Record<string, unknown>, tasks: Record<string, unknown>[]): TodayScheduleItem {
  const eventId = Number(e.id)
  const assigned = tasks
    .filter((t) => Number(t.event_id) === eventId)
    .map((t) => String(t.member_name ?? t.assignee_name ?? ''))
    .filter(Boolean)

  const start = (e.start_time ?? e.event_time) as string | undefined
  const timeLabel = start && start.length > 0 ? formatTime(start) : 'All day'

  return {
    timeLabel,
    eventName: String(e.title ?? e.event_name ?? 'Event'),
    assignedMembers: assigned.length === 0 ? 'Unassigned' : assigned.join(', '),
    status: titleCase(String(e.status ?? 'Upcoming').replaceAll('_', ' ')),
  }
}

function activityTitleForRequest(status: string, r: Record<string, unknown>): string {
  const title = String(r.event_name ?? r.title ?? 'Documentation request')
  const s = status.toLowerCase()
  if (s.includes('approv')) return `Request approved: ${title}`
  if (s.includes('reject')) return `Request rejected: ${title}`
  return `New request: ${title}`
}

function buildRecentActivity(
  requests: Record<string, unknown>[],
  media: Record<string, unknown>[],
  evaluations: Record<string, unknown>[],
  notifications: Record<string, unknown>[],
): ActivityItem[] {
  const items: { date: Date | null; item: ActivityItem }[] = []

  for (const r of requests) {
    const d = parseDate(r.created_at)
    const status = String(r.status ?? 'Pending')
    items.push({
      date: d,
      item: {
        kind: 'request',
        title: activityTitleForRequest(status, r),
        subtitle: String(r.requester_name ?? ''),
        status,
        time: formatTimeAgo(r.created_at),
      },
    })
  }

  for (const n of notifications.slice(0, 20)) {
    const cat = String(n.category ?? '').toLowerCase()
    const title = String(n.title ?? '')
    if (cat === 'ai_detection') {
      items.push({
        date: parseDate(n.created_at),
        item: {
          kind: 'media',
          title,
          subtitle: String(n.message ?? n.body ?? ''),
          status: 'Integrity',
          time: formatTimeAgo(n.created_at),
        },
      })
      continue
    }
    if (cat === 'documentation_request' || cat === 'task_assignment' || cat === 'feedback') {
      items.push({
        date: parseDate(n.created_at),
        item: {
          kind: cat === 'documentation_request' ? 'request' : 'media',
          title,
          subtitle: String(n.message ?? n.body ?? ''),
          status: titleCase(cat.replaceAll('_', ' ')),
          time: formatTimeAgo(n.created_at),
        },
      })
      continue
    }
    if (cat.includes('facebook') || title.toLowerCase().includes('facebook')) {
      items.push({
        date: parseDate(n.created_at),
        item: {
          kind: 'media',
          title,
          subtitle: String(n.message ?? n.body ?? ''),
          status: 'Published',
          time: formatTimeAgo(n.created_at),
        },
      })
    }
  }

  for (const e of evaluations.slice(0, 30)) {
    const label = String(e.detection_result ?? e.ai_result ?? '').toLowerCase()
    if (label !== 'suspicious' && label !== 'ai_generated' && !label.includes('generated')) continue
    const scorePct = scoreToPercent(Number(e.overall_score ?? 0))
    items.push({
      date: parseDate(e.evaluated_at ?? e.created_at),
      item: {
        kind: 'media',
        title: `Media integrity flag: ${String(e.file_name ?? e.media_name ?? 'file')}`,
        subtitle: `${String(e.member_name ?? '')} · ${Math.round(scorePct)}% quality`,
        status: 'Integrity',
        time: formatTimeAgo(e.evaluated_at ?? e.created_at),
      },
    })
  }

  for (const m of media.slice(0, 15)) {
    const label = String(m.detection_result ?? m.ai_result ?? '').toLowerCase()
    if (label !== 'suspicious' && label !== 'ai_generated' && !label.includes('generated')) continue
    items.push({
      date: parseDate(m.uploaded_at ?? m.created_at),
      item: {
        kind: 'media',
        title: `Integrity review needed: ${String(m.file_name ?? m.title ?? 'file')}`,
        subtitle: String(m.uploader_name ?? m.member_name ?? ''),
        status: 'Integrity',
        time: formatTimeAgo(m.uploaded_at ?? m.created_at),
      },
    })
  }

  for (const r of requests
    .filter((x) => {
      const s = String(x.status ?? '').toLowerCase()
      return s.includes('approv') || s.includes('reject')
    })
    .slice(0, 10)) {
    const status = String(r.status ?? '')
    items.push({
      date: parseDate(r.updated_at ?? r.created_at),
      item: {
        kind: 'request',
        title: `Request ${status.toLowerCase()}: ${String(r.event_name ?? r.title ?? 'Documentation')}`,
        subtitle: String(r.requester_name ?? ''),
        status,
        time: formatTimeAgo(r.updated_at ?? r.created_at),
      },
    })
  }

  items.sort((a, b) => (b.date?.getTime() ?? 0) - (a.date?.getTime() ?? 0))
  return items.slice(0, 8).map((e) => e.item)
}

function buildAnnouncements(notifications: AdminNotification[]): AnnouncementItem[] {
  const system = notifications
    .filter(
      (n) => n.category === 'system_alert' || n.title.toLowerCase().includes('announce'),
    )
    .slice(0, 3)
    .map((n) => ({ title: n.title, body: n.message, dateLabel: n.timeAgo }))

  if (system.length > 0) return system

  return [
    {
      title: 'Welcome to ACCESS VisionCheck',
      body: 'Review pending documentation requests daily and assign members before event dates.',
      dateLabel: 'System',
    },
    {
      title: 'Media integrity reminder',
      body: 'Potentially AI-generated uploads are queued for review. Open Media Integrity to verify flagged submissions.',
      dateLabel: 'Operations',
    },
  ]
}

function trendPct(current: number, previous: number): number {
  if (previous === 0) return current > 0 ? 100 : 0
  return Math.round(((current - previous) / previous) * 100)
}

function buildEvalOverview(
  evaluations: Record<string, unknown>[],
  today: Date,
): EvalOverviewStats {
  const last7Start = new Date(today)
  last7Start.setDate(last7Start.getDate() - 7)
  const prev7Start = new Date(today)
  prev7Start.setDate(prev7Start.getDate() - 14)

  let evalCurrent = 0
  let goodCurrent = 0
  let needsCurrent = 0
  let aiCurrent = 0
  let evalPrev = 0
  let goodPrev = 0
  let needsPrev = 0
  let aiPrev = 0

  const tomorrow = new Date(today)
  tomorrow.setDate(tomorrow.getDate() + 1)

  for (const e of evaluations) {
    const d = parseDate(e.evaluated_at ?? e.created_at)
    if (!d) continue
    const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())

    const score = Number(e.overall_score ?? 0)
    const detection = String(e.detection_result ?? '').toLowerCase()
    const isFlagged = detection === 'ai_generated' || detection === 'suspicious'
    const isGood = !isFlagged && isGoodQualityScore(score)
    const isNeeds = !isFlagged && !isGoodQualityScore(score)

    if (day >= last7Start && day < tomorrow) {
      evalCurrent++
      if (isFlagged) aiCurrent++
      else if (isGood) goodCurrent++
      else if (isNeeds) needsCurrent++
    } else if (day >= prev7Start && day < last7Start) {
      evalPrev++
      if (isFlagged) aiPrev++
      else if (isGood) goodPrev++
      else if (isNeeds) needsPrev++
    }
  }

  return {
    evaluated: evalCurrent,
    goodQuality: goodCurrent,
    needsImprovement: needsCurrent,
    aiFlagged: aiCurrent,
    evaluatedTrend: trendPct(evalCurrent, evalPrev),
    goodQualityTrend: trendPct(goodCurrent, goodPrev),
    needsImprovementTrend: trendPct(needsCurrent, needsPrev),
    aiFlaggedTrend: trendPct(aiCurrent, aiPrev),
  }
}

function buildEvalTrend(evaluations: Record<string, unknown>[], today: Date): EvaluationTrendPoint[] {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  const points: EvaluationTrendPoint[] = []

  for (let i = 6; i >= 0; i--) {
    const day = new Date(today)
    day.setDate(day.getDate() - i)
    const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate())
    const dayEnd = new Date(dayStart)
    dayEnd.setDate(dayEnd.getDate() + 1)
    const label = `${months[dayStart.getMonth()]} ${dayStart.getDate()}`

    let evaluated = 0
    let good = 0
    let needs = 0
    let ai = 0

    for (const e of evaluations) {
      const d = parseDate(e.evaluated_at ?? e.created_at)
      if (!d || d < dayStart || d >= dayEnd) continue

      const score = Number(e.overall_score ?? 0)
      const detection = String(e.detection_result ?? '').toLowerCase()
      const isFlagged = detection === 'ai_generated' || detection === 'suspicious'

      evaluated++
      if (isFlagged) ai++
      else if (isGoodQualityScore(score)) good++
      else needs++
    }

    points.push({ dateLabel: label, evaluated, goodQuality: good, needsImprovement: needs, aiFlagged: ai })
  }

  return points
}

function buildActiveDocumenters(
  rankings: Record<string, unknown>[],
  stats: DashboardStats,
): ActiveDocumenterSnapshot {
  let advanced = 0
  let developing = 0
  let amateur = 0

  for (const r of rankings) {
    const level = String(r.skill_level ?? r.competency_level ?? '').toLowerCase()
    if (level.includes('advanced') || level.includes('expert')) advanced++
    else if (level.includes('developing') || level.includes('intermediate')) developing++
    else amateur++
  }

  const total = advanced + developing + amateur
  const pct = (n: number) => (total > 0 ? Math.round((n / total) * 100) : 0)

  if (total === 0) {
    const active = stats.active_members ?? 0
    return {
      totalActive: active,
      breakdown:
        active === 0
          ? []
          : [
              { label: 'Advanced', count: 0, percent: 0 },
              { label: 'Developing', count: 0, percent: 0 },
              { label: 'Amateur', count: active, percent: 100 },
            ],
    }
  }

  return {
    totalActive: total,
    breakdown: [
      { label: 'Advanced', count: advanced, percent: pct(advanced) },
      { label: 'Developing', count: developing, percent: pct(developing) },
      { label: 'Amateur', count: amateur, percent: pct(amateur) },
    ],
  }
}

function buildActionCenterItems(input: {
  pendingRequests: PendingRequestItem[]
  pendingMedia: number
  evaluations: Record<string, unknown>[]
  media: Record<string, unknown>[]
}): ActionCenterItem[] {
  const items: ActionCenterItem[] = []

  if (input.pendingRequests.length > 0) {
    const org = input.pendingRequests[0].requestor
    const n = input.pendingRequests.length
    items.push({
      id: input.pendingRequests[0].id,
      title: `${n} documentation request${n === 1 ? '' : 's'} need${n === 1 ? 's' : ''} approval`,
      subtitle: `New request from ${org}`,
      timeLabel: 'Just now',
      kind: 'request',
      count: n,
    })
  }

  const flaggedCount =
    input.evaluations.filter((e) => {
      const d = String(e.detection_result ?? '').toLowerCase()
      return d === 'suspicious' || d === 'ai_generated'
    }).length +
    input.media.filter((m) => {
      const d = String(m.detection_result ?? m.ai_result ?? '').toLowerCase()
      return d === 'suspicious' || d === 'ai_generated'
    }).length

  if (flaggedCount > 0) {
    items.push({
      id: -1,
      title: `${flaggedCount} media item${flaggedCount === 1 ? '' : 's'} flagged for integrity review`,
      subtitle: 'Suspicious content detected by AI',
      timeLabel: 'Recent',
      kind: 'integrity',
      count: flaggedCount,
    })
  }

  if (input.pendingMedia > 0) {
    items.push({
      id: -2,
      title: `${input.pendingMedia} media item${input.pendingMedia === 1 ? '' : 's'} awaiting evaluation`,
      subtitle: 'Recently uploaded by team members',
      timeLabel: 'Recent',
      kind: 'media',
      count: input.pendingMedia,
    })
  }

  return items
}

export function buildDailySummary(snap: HomeDashboardSnapshot): string {
  const parts: string[] = []
  const o = snap.overview

  if (o.pendingRequests > 0) {
    parts.push(
      `${o.pendingRequests} documentation request${o.pendingRequests === 1 ? '' : 's'} need${o.pendingRequests === 1 ? 's' : ''} your review.`,
    )
  }
  if (o.todayEvents > 0) {
    parts.push(
      `${o.todayEvents} event${o.todayEvents === 1 ? '' : 's'} scheduled today — confirm assignments and coverage.`,
    )
  }
  if (o.mediaPendingEvaluation > 0) {
    parts.push(
      `${o.mediaPendingEvaluation} media item${o.mediaPendingEvaluation === 1 ? '' : 's'} await AI evaluation.`,
    )
  }
  if (snap.pendingMembers > 0) {
    parts.push(
      `${snap.pendingMembers} member registration${snap.pendingMembers === 1 ? '' : 's'} pending approval.`,
    )
  }
  if (o.unreadNotifications > 0) {
    parts.push(
      `You have ${o.unreadNotifications} unread notification${o.unreadNotifications === 1 ? '' : 's'}.`,
    )
  }
  if (parts.length === 0) {
    return "Operations look clear today. Check Today's Schedule and Recent Activity for anything that may need a follow-up."
  }
  return parts.join(' ')
}

function estimatePendingMediaCount(stats: DashboardStats): number {
  const uploads = stats.media_uploads ?? 0
  const evaluated = stats.total_evaluations ?? 0
  return Math.max(0, uploads - evaluated)
}

function buildHomeDashboardSnapshot(input: {
  stats: DashboardStats
  requests: Record<string, unknown>[]
  events: Record<string, unknown>[]
  tasks: Record<string, unknown>[]
  notificationsRaw: Record<string, unknown>[]
  evaluations: Record<string, unknown>[]
  media: Record<string, unknown>[]
  rankings: Record<string, unknown>[]
  aiDetectionRaw: Record<string, unknown>[] | null
  today: Date
}): HomeDashboardSnapshot {
  const {
    stats,
    requests,
    events,
    tasks,
    notificationsRaw,
    evaluations,
    media,
    rankings,
    aiDetectionRaw,
    today,
  } = input

  const requestorByRequestId = buildRequestorByRequestId(requests)

  const pendingRequests = requests
    .filter((r) => String(r.status ?? 'Pending').toLowerCase() === 'pending')
    .map(mapPendingRequest)
    .sort((a, b) => b.requestedDate.localeCompare(a.requestedDate))

  const todayEvents = events
    .filter((e) => {
      const d = parseDate(e.event_date)
      if (!d) return false
      const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
      if (day.getTime() !== today.getTime()) return false
      const status = String(e.status ?? '').toLowerCase()
      return status !== 'cancelled' && status !== 'canceled'
    })
    .map((e) => mapTodayEvent(e, tasks))
    .sort((a, b) => a.timeLabel.localeCompare(b.timeLabel))

  const upcomingEvents = events
    .filter((e) => isUpcomingApprovedEvent(e, today))
    .sort((a, b) => {
      const da = parseDate(a.event_date)?.getTime() ?? 0
      const db = parseDate(b.event_date)?.getTime() ?? 0
      if (da !== db) return da - db
      const ta = String(a.start_time ?? a.event_time ?? '')
      const tb = String(b.start_time ?? b.event_time ?? '')
      return ta.localeCompare(tb)
    })
    .slice(0, 4)
    .map((e) => mapUpcomingEvent(e, tasks, requestorByRequestId))

  const evaluatedMediaIds = new Set(
    evaluations.map((e) => Number(e.media_id)).filter((id) => id > 0),
  )
  const pendingMedia =
    media.length > 0 || evaluations.length > 0
      ? media.filter((m) => {
          const id = Number(m.id)
          return id > 0 && !evaluatedMediaIds.has(id)
        }).length
      : estimatePendingMediaCount(stats)

  const completedToday = evaluations.filter((e) => {
    const d = parseDate(e.evaluated_at ?? e.created_at)
    if (!d) return false
    const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    return day.getTime() === today.getTime()
  }).length

  const notifications = notificationsRaw
    .map(parseNotification)
    .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0))

  const unread = notifications.filter((n) => n.unread).length

  const aiReviewQueue =
    aiDetectionRaw == null
      ? EMPTY_AI_REVIEW_QUEUE
      : buildAiReviewQueue(aiDetectionRaw.map((m) => parseAiDetectionRow(m)))

  const overview: HomeOverviewStats = {
    pendingRequests: stats.pending_requests ?? pendingRequests.length,
    todayEvents: todayEvents.length,
    mediaPendingEvaluation: pendingMedia,
    activeMembers: stats.active_members ?? 0,
    unreadNotifications: unread,
  }

  return {
    overview,
    pendingRequests: pendingRequests.slice(0, 6),
    todaySchedule: todayEvents.slice(0, 5),
    upcomingEvents,
    recentActivity: buildRecentActivity(requests, media, evaluations, notificationsRaw),
    notifications: notifications.slice(0, 5),
    mediaQueue: { pendingCount: pendingMedia, completedToday },
    announcements: buildAnnouncements(notifications),
    pendingMembers: stats.pending_members ?? 0,
    stats,
    actionCenterItems: buildActionCenterItems({
      pendingRequests,
      pendingMedia,
      evaluations,
      media,
    }),
    evalOverview: buildEvalOverview(evaluations, today),
    evalTrend: buildEvalTrend(evaluations, today),
    aiReviewQueue,
    activeDocumenters: buildActiveDocumenters(rankings, stats),
  }
}

export type FetchHomeDashboardOptions = {
  /** Called after lightweight API wave so the home page can paint sooner. */
  onPartial?: (snap: HomeDashboardSnapshot) => void
}

export async function fetchHomeDashboard(
  options?: FetchHomeDashboardOptions,
): Promise<HomeDashboardSnapshot> {
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())

  const [stats, requests, events, notificationsRaw, tasks] = await Promise.all([
    fetchDashboardStats(),
    fetchServiceRequests(),
    fetchEvents(),
    fetchNotifications(),
    fetchTasks(),
  ])

  const partial = buildHomeDashboardSnapshot({
    stats,
    requests,
    events,
    tasks,
    notificationsRaw,
    evaluations: [],
    media: [],
    rankings: [],
    aiDetectionRaw: null,
    today,
  })
  options?.onPartial?.(partial)

  const [evaluations, media, rankings, aiDetectionRaw] = await Promise.all([
    fetchEvaluations(),
    fetchMedia(),
    fetchRankings(),
    fetchAiDetectionList().catch(() => null),
  ])

  return buildHomeDashboardSnapshot({
    stats,
    requests,
    events,
    tasks,
    notificationsRaw,
    evaluations,
    media,
    rankings,
    aiDetectionRaw,
    today,
  })
}
