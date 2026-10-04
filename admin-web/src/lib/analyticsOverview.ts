import type { AnalyticsSnapshot } from './analytics'

export interface DateRange {
  start: Date
  end: Date
}

export interface KpiMetric {
  label: string
  value: string
  valueSuffix?: string
  growthPct: number | null
  growthLabel: string
}

export interface TimeSeriesPoint {
  label: string
  value: number
  date: Date
}

export interface QualityBucket {
  key: string
  label: string
  count: number
  color: string
}

export interface OrgRank {
  rank: number
  name: string
  score: number
}

export interface ActivityItem {
  id: string
  icon: 'check' | 'integrity' | 'upload' | 'user' | 'star' | 'request'
  accentColor?: string
  title: string
  subtitle?: string
  timeAgo: string
  at: Date
}

export interface AnalyticsOverviewModel {
  kpis: KpiMetric[]
  evaluationsSeries: TimeSeriesPoint[]
  qualityBuckets: QualityBucket[]
  qualityTotal: number
  topMembers: OrgRank[]
  mediaPhotos: number
  mediaVideos: number
  mediaTotal: number
  recentActivity: ActivityItem[]
}

const QUALITY_COLORS = {
  excellent: '#3b82f6',
  good: '#06b6d4',
  fair: '#8b5cf6',
  poor: '#d946ef',
}

export function defaultDateRange(): DateRange {
  const end = new Date()
  end.setHours(23, 59, 59, 999)
  const start = new Date(end)
  start.setDate(start.getDate() - 29)
  start.setHours(0, 0, 0, 0)
  return { start, end }
}

export function formatDateRangeLabel(range: DateRange): string {
  const fmt = (d: Date, withYear: boolean) =>
    d.toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      ...(withYear ? { year: 'numeric' } : {}),
    })
  const sameYear = range.start.getFullYear() === range.end.getFullYear()
  return `${fmt(range.start, !sameYear)} – ${fmt(range.end, true)}`
}

function parseDate(raw: unknown): Date | null {
  if (raw == null) return null
  const d = new Date(String(raw))
  return Number.isNaN(d.getTime()) ? null : d
}

function inRange(d: Date, range: DateRange): boolean {
  return d >= range.start && d <= range.end
}

function previousRange(range: DateRange): DateRange {
  const days = Math.max(1, Math.ceil((range.end.getTime() - range.start.getTime()) / 86400000))
  const end = new Date(range.start)
  end.setMilliseconds(-1)
  const start = new Date(end)
  start.setDate(start.getDate() - (days - 1))
  start.setHours(0, 0, 0, 0)
  return { start, end }
}

function growthPct(current: number, previous: number): number | null {
  if (previous <= 0) return current > 0 ? 100 : null
  return Math.round(((current - previous) / previous) * 1000) / 10
}

function countInRanges(dates: Date[], range: DateRange, prev: DateRange): { current: number; previous: number } {
  let current = 0
  let previous = 0
  for (const d of dates) {
    if (inRange(d, range)) current++
    else if (inRange(d, prev)) previous++
  }
  return { current, previous }
}

function scoreToPercent(raw: number): number {
  if (raw <= 0) return 0
  if (raw <= 1) return raw * 100
  return raw
}

function qualityBucket(scorePct: number): keyof typeof QUALITY_COLORS {
  if (scorePct >= 90) return 'excellent'
  if (scorePct >= 75) return 'good'
  if (scorePct >= 60) return 'fair'
  return 'poor'
}

function integrityAccentColor(label: string): string {
  const s = label.toLowerCase()
  if (s.includes('suspicious')) return '#06b6d4'
  if (s.includes('generated') || s.includes('ai')) return '#d946ef'
  return '#8b5cf6'
}

function formatTimeAgo(d: Date): string {
  const sec = Math.floor((Date.now() - d.getTime()) / 1000)
  if (sec < 60) return `${Math.max(1, sec)} sec ago`
  const min = Math.floor(sec / 60)
  if (min < 60) return `${min} min${min === 1 ? '' : 's'} ago`
  const hr = Math.floor(min / 60)
  if (hr < 48) return `${hr} hour${hr === 1 ? '' : 's'} ago`
  const day = Math.floor(hr / 24)
  return `${day} day${day === 1 ? '' : 's'} ago`
}

export function buildAnalyticsOverview(
  data: AnalyticsSnapshot,
  range: DateRange,
  options?: { seriesGranularity?: 'daily' | 'weekly' },
): AnalyticsOverviewModel {
  const prev = previousRange(range)
  const s = data.stats

  const evalDates = data.evaluations
    .map((e) => parseDate(e.evaluated_at ?? e.created_at))
    .filter(Boolean) as Date[]
  const mediaDates = data.media.map((m) => parseDate(m.uploaded_at ?? m.created_at)).filter(Boolean) as Date[]

  const requestDates = data.requests
    .map((r) => parseDate(r.created_at))
    .filter(Boolean) as Date[]
  const requestCounts = countInRanges(requestDates, range, prev)

  const eventsInRange = data.events.filter((e) => {
    const d = parseDate(e.event_date)
    return d && inRange(d, range)
  })
  const completedInRange = eventsInRange.filter(
    (e) => String(e.status ?? '').toLowerCase() === 'completed',
  ).length
  const eventsPrev = data.events.filter((e) => {
    const d = parseDate(e.event_date)
    return d && inRange(d, prev)
  })
  const completedPrev = eventsPrev.filter(
    (e) => String(e.status ?? '').toLowerCase() === 'completed',
  ).length

  const mediaCounts = countInRanges(mediaDates, range, prev)

  const scoresInRange = data.evaluations
    .filter((e) => {
      const d = parseDate(e.evaluated_at ?? e.created_at)
      return d && inRange(d, range)
    })
    .map((e) => scoreToPercent(Number(e.overall_score ?? 0)))
  const scoresPrev = data.evaluations
    .filter((e) => {
      const d = parseDate(e.evaluated_at ?? e.created_at)
      return d && inRange(d, prev)
    })
    .map((e) => scoreToPercent(Number(e.overall_score ?? 0)))
  const avgQuality =
    scoresInRange.length > 0 ? scoresInRange.reduce((a, b) => a + b, 0) / scoresInRange.length : 0
  const avgQualityPrev =
    scoresPrev.length > 0 ? scoresPrev.reduce((a, b) => a + b, 0) / scoresPrev.length : 0
  const qualityGrowth =
    growthPct(Math.round(avgQuality * 10), Math.round(avgQualityPrev * 10)) ??
    (avgQuality > 0 ? 100 : 0)

  const activeMembers = Number(s.active_members ?? data.rankings.length ?? 0)
  const newMembers30d = Number(s.new_members_30d ?? 0)
  const newMembersPrev30d = Number(s.new_members_prev_30d ?? 0)
  const memberGrowth =
    newMembers30d > 0 || newMembersPrev30d > 0
      ? growthPct(newMembers30d, newMembersPrev30d)
      : null

  const kpis: KpiMetric[] = [
    {
      label: 'Total Requests',
      value: String(requestCounts.current),
      growthPct: growthPct(requestCounts.current, requestCounts.previous),
      growthLabel: '',
    },
    {
      label: 'Completed Events',
      value: String(completedInRange),
      growthPct: growthPct(completedInRange, completedPrev),
      growthLabel: '',
    },
    {
      label: 'Media Uploaded',
      value: String(mediaCounts.current || Number(s.media_uploads ?? 0)),
      growthPct: growthPct(mediaCounts.current, mediaCounts.previous),
      growthLabel: '',
    },
    {
      label: 'Avg. Quality Score',
      value: avgQuality.toFixed(1),
      valueSuffix: '/100',
      growthPct: qualityGrowth,
      growthLabel: '',
    },
    {
      label: 'Active Members',
      value: String(activeMembers),
      growthPct: memberGrowth,
      growthLabel: memberGrowth != null ? 'new approvals (30d)' : '',
    },
  ]

  const evaluationsSeries = buildDailySeries(
    evalDates.filter((d) => inRange(d, range)),
    range,
    options?.seriesGranularity ?? 'daily',
  )

  const bucketCounts = { excellent: 0, good: 0, fair: 0, poor: 0 }
  for (const e of data.evaluations) {
    const d = parseDate(e.evaluated_at ?? e.created_at)
    if (!d || !inRange(d, range)) continue
    const pct = scoreToPercent(Number(e.overall_score ?? 0))
    bucketCounts[qualityBucket(pct)]++
  }
  const qualityTotal = Object.values(bucketCounts).reduce((a, b) => a + b, 0)
  const qualityBuckets: QualityBucket[] = [
    { key: 'excellent', label: 'Excellent (90-100)', count: bucketCounts.excellent, color: QUALITY_COLORS.excellent },
    { key: 'good', label: 'Good (75-89)', count: bucketCounts.good, color: QUALITY_COLORS.good },
    { key: 'fair', label: 'Fair (60-74)', count: bucketCounts.fair, color: QUALITY_COLORS.fair },
    { key: 'poor', label: 'Poor (0-59)', count: bucketCounts.poor, color: QUALITY_COLORS.poor },
  ]

  const topMembers: OrgRank[] = data.rankings
    .map((r) => {
      const raw = Number(r.avg_score ?? r.media_eval_score ?? r.participation_score ?? r.total_points ?? 0)
      const score = raw <= 1 && raw > 0 ? raw * 100 : raw
      return {
        name: String(r.fullname ?? r.name ?? 'Member'),
        score,
      }
    })
    .filter((m) => m.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, 5)
    .map((m, i) => ({ rank: i + 1, name: m.name, score: Math.round(m.score * 10) / 10 }))

  let mediaPhotos = 0
  let mediaVideos = 0
  for (const m of data.media) {
    const d = parseDate(m.uploaded_at ?? m.created_at)
    if (d && !inRange(d, range)) continue
    const type = String(m.file_type ?? '').toLowerCase()
    if (type.includes('video')) mediaVideos++
    else mediaPhotos++
  }
  if (mediaPhotos + mediaVideos === 0) {
    for (const m of data.media) {
      const type = String(m.file_type ?? '').toLowerCase()
      if (type.includes('video')) mediaVideos++
      else mediaPhotos++
    }
  }

  const recentActivity = buildRecentActivity(data)

  return {
    kpis,
    evaluationsSeries,
    qualityBuckets,
    qualityTotal: qualityTotal || Number(s.total_evaluations ?? 0),
    topMembers,
    mediaPhotos,
    mediaVideos,
    mediaTotal: mediaPhotos + mediaVideos || Number(s.media_uploads ?? 0),
    recentActivity,
  }
}

function buildDailySeries(dates: Date[], range: DateRange, granularity: 'daily' | 'weekly' = 'daily'): TimeSeriesPoint[] {
  const dayMs = 86400000
  const days = Math.max(1, Math.ceil((range.end.getTime() - range.start.getTime()) / dayMs))
  const step = granularity === 'weekly' ? 7 : days > 14 ? Math.ceil(days / 7) : 1
  const points: TimeSeriesPoint[] = []

  for (let i = 0; i < days; i += step) {
    const dayStart = new Date(range.start)
    dayStart.setDate(dayStart.getDate() + i)
    dayStart.setHours(0, 0, 0, 0)
    const dayEnd = new Date(dayStart)
    dayEnd.setDate(dayEnd.getDate() + step)
    dayEnd.setMilliseconds(-1)
    const count = dates.filter((d) => d >= dayStart && d <= dayEnd).length
    points.push({
      label: dayStart.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
      value: count,
      date: dayStart,
    })
  }
  return points
}

function buildRecentActivity(data: AnalyticsSnapshot, limit = 4): ActivityItem[] {
  const items: ActivityItem[] = []

  for (const r of data.requests) {
    const d = parseDate(r.created_at)
    if (!d) continue
    const st = String(r.status ?? '').toLowerCase()
    const title = String(r.title ?? r.event_name ?? 'Documentation request')
    if (st === 'approved' || st === 'completed') {
      items.push({
        id: `req-${r.request_id ?? r.id}`,
        icon: 'check',
        accentColor: '#3b82f6',
        title: `Documentation request "${title}" approved`,
        subtitle: `by ${String(r.approved_by ?? r.reviewer_name ?? 'Admin User')}`,
        timeAgo: formatTimeAgo(d),
        at: d,
      })
    }
  }

  for (const e of data.evaluations.slice(0, 30)) {
    const d = parseDate(e.evaluated_at ?? e.created_at)
    if (!d) continue
    const label = String(e.detection_result ?? e.ai_result ?? '').toLowerCase()
    if (label !== 'suspicious' && label !== 'ai_generated' && !label.includes('generated')) continue
    const member = String(e.member_name ?? 'member')
    const fileName = String(e.file_name ?? e.media_name ?? 'upload')
    items.push({
      id: `integrity-${e.id}`,
      icon: 'integrity',
      accentColor: integrityAccentColor(label),
      title: `Media integrity flag on "${fileName}"`,
      subtitle: `Submitted by ${member}`,
      timeAgo: formatTimeAgo(d),
      at: d,
    })
  }

  for (const r of data.rankings.slice(0, 15)) {
    const d = parseDate(r.created_at ?? r.updated_at ?? r.joined_at)
    if (!d) continue
    const name = String(r.fullname ?? r.name ?? 'New member')
    items.push({
      id: `member-${r.id ?? r.user_id ?? name}`,
      icon: 'user',
      accentColor: '#8b5cf6',
      title: 'New member registered',
      subtitle: name,
      timeAgo: formatTimeAgo(d),
      at: d,
    })
  }

  for (const r of data.requests.slice(0, 15)) {
    const d = parseDate(r.created_at)
    if (!d) continue
    const org = String(r.requester_name ?? r.requestor ?? '')
    if (!org) continue
    items.push({
      id: `org-${r.request_id ?? r.id}`,
      icon: 'star',
      accentColor: '#6366f1',
      title: `New organization "${org}" added`,
      subtitle: 'by Admin User',
      timeAgo: formatTimeAgo(d),
      at: d,
    })
  }

  return items.sort((a, b) => b.at.getTime() - a.at.getTime()).slice(0, limit)
}

export function buildRecentActivityList(data: AnalyticsSnapshot, limit = 50): ActivityItem[] {
  return buildRecentActivity(data, limit)
}

export interface MonthlyRequestPoint {
  month: number
  label: string
  requests: number
  requesters: number
}

function requestSubmittedAt(r: Record<string, unknown>): Date | null {
  return parseDate(r.created_at ?? r.submitted_at ?? r.request_date)
}

function requesterKey(r: Record<string, unknown>): string {
  return String(r.requester_id ?? r.requester_name ?? r.organization_name ?? 'unknown')
}

/** Years that have at least one request, newest first; always includes the current year. */
export function requestYears(requests: Record<string, unknown>[]): number[] {
  const years = new Set<number>([new Date().getFullYear()])
  for (const r of requests) {
    const d = requestSubmittedAt(r)
    if (d) years.add(d.getFullYear())
  }
  return [...years].sort((a, b) => b - a)
}

export function buildRequestsByMonth(
  requests: Record<string, unknown>[],
  year: number,
): { points: MonthlyRequestPoint[]; totalRequests: number; totalRequesters: number } {
  const perMonth = Array.from({ length: 12 }, () => ({ requests: 0, requesters: new Set<string>() }))
  const allRequesters = new Set<string>()
  for (const r of requests) {
    const d = requestSubmittedAt(r)
    if (!d || d.getFullYear() !== year) continue
    const bucket = perMonth[d.getMonth()]
    bucket.requests++
    bucket.requesters.add(requesterKey(r))
    allRequesters.add(requesterKey(r))
  }
  const points = perMonth.map((b, month) => ({
    month,
    label: new Date(year, month, 1).toLocaleDateString(undefined, { month: 'short' }),
    requests: b.requests,
    requesters: b.requesters.size,
  }))
  return {
    points,
    totalRequests: points.reduce((sum, p) => sum + p.requests, 0),
    totalRequesters: allRequesters.size,
  }
}
