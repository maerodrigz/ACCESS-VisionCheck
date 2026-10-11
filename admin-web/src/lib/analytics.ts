import {
  fetchAiDetectionSummary,
  fetchDashboardStats,
  fetchEvaluationSummary,
  fetchEvaluations,
  fetchEvents,
  fetchFeedback,
  fetchMedia,
  fetchRankings,
  fetchRankingsSummary,
  fetchServiceRequests,
} from '../api/admin'
import type { AiDetectionSummary } from '../api/media'
import type { DashboardStats } from '../types/auth'

export type AnalyticsTab =
  | 'overview'
  | 'participation'
  | 'rankings'
  | 'feedback'
  | 'media'
  | 'events'
  | 'activity'

export interface AnalyticsSnapshot {
  stats: DashboardStats & Record<string, unknown>
  rankings: Record<string, unknown>[]
  rankingsSummary: Record<string, unknown>
  events: Record<string, unknown>[]
  feedback: Record<string, unknown>[]
  media: Record<string, unknown>[]
  requests: Record<string, unknown>[]
  evaluations: Record<string, unknown>[]
  evaluationSummary: Record<string, unknown>
  aiSummary: AiDetectionSummary | Record<string, unknown>
}

export const ANALYTICS_TABS: { id: AnalyticsTab; label: string }[] = [
  { id: 'overview', label: 'Overview' },
  { id: 'participation', label: 'Participation' },
  { id: 'rankings', label: 'Rankings' },
  { id: 'feedback', label: 'Feedback' },
  { id: 'media', label: 'Media' },
  { id: 'events', label: 'Events' },
  { id: 'activity', label: 'Activity' },
]

const VALID_TABS = new Set<string>(ANALYTICS_TABS.map((t) => t.id))

export function parseAnalyticsTab(raw: string | null): AnalyticsTab {
  if (raw && VALID_TABS.has(raw)) return raw as AnalyticsTab
  return 'overview'
}

import type { DateRange } from './analyticsOverview'
import {
  buildAnalyticsOverview,
  buildRecentActivityList,
  buildRequestsByMonth,
  requestYears,
} from './analyticsOverview'

export type FetchAnalyticsSnapshotOptions = {
  onPartial?: (snap: AnalyticsSnapshot) => void
}

export async function fetchAnalyticsSnapshot(
  options?: FetchAnalyticsSnapshotOptions,
): Promise<AnalyticsSnapshot> {
  let evaluationSummary: Record<string, unknown> = {}
  let aiSummary: AiDetectionSummary | Record<string, unknown> = {}
  try {
    evaluationSummary = await fetchEvaluationSummary()
  } catch {
    /* optional */
  }
  try {
    aiSummary = await fetchAiDetectionSummary()
  } catch {
    /* optional */
  }

  const [stats, rankings, rankingsSummary, events, feedback, requests] = await Promise.all([
    fetchDashboardStats(),
    fetchRankings(),
    fetchRankingsSummary(),
    fetchEvents(),
    fetchFeedback(),
    fetchServiceRequests(),
  ])

  const partial: AnalyticsSnapshot = {
    stats: stats as DashboardStats & Record<string, unknown>,
    rankings,
    rankingsSummary,
    events,
    feedback,
    media: [],
    requests,
    evaluations: [],
    evaluationSummary,
    aiSummary,
  }
  options?.onPartial?.(partial)

  const [media, evaluations] = await Promise.all([fetchMedia(), fetchEvaluations()])

  return {
    stats: stats as DashboardStats & Record<string, unknown>,
    rankings,
    rankingsSummary,
    events,
    feedback,
    media,
    requests,
    evaluations,
    evaluationSummary,
    aiSummary,
  }
}

export function avgFeedbackRating(stats: Record<string, unknown>): number {
  const v = stats.avg_feedback_rating
  if (v == null) return 0
  return Number(v)
}

/** Rankings API may return quality as 0–100 (average_quality_score) or 0–1 (avg_score). */
export function qualityPercentFromRanking(r: Record<string, unknown>): number {
  const scaled = r.average_quality_score ?? r.media_quality_score
  if (scaled != null) return Number(scaled)
  const raw = r.avg_score ?? r.media_eval_score
  if (raw == null) return 0
  const n = Number(raw)
  return n <= 1 ? n * 100 : n
}

export function participationRows(rankings: Record<string, unknown>[]) {
  return rankings.map((r) => ({
    name: String(r.member_name ?? r.fullname ?? r.name ?? 'Member'),
    tasks: Number(r.completed_tasks ?? r.tasks_completed ?? 0),
    uploads: Number(r.uploads ?? r.total_uploads ?? r.media_uploads ?? r.upload_count ?? 0),
    participation: Number(r.points ?? r.total_points ?? r.good_evaluations ?? r.participation_score ?? 0),
    quality: qualityPercentFromRanking(r),
    status: String(r.skill_level ?? r.status ?? '—'),
  }))
}

export function buildInsights(data: AnalyticsSnapshot): string[] {
  const rs = data.rankingsSummary
  return [
    `${rs.total_ranked ?? 0} members ranked on participation and quality scores.`,
    `Most active uploader: ${rs.most_active_uploader_name ?? '—'} (${rs.most_active_uploads ?? 0} uploads).`,
    `${rs.needs_improvement_count ?? 0} members flagged for improvement or inactive participation.`,
    `${data.events.length} events on calendar · ${data.feedback.length} feedback records · ${data.media.length} media files tracked.`,
  ]
}

export type ReportCell = string | number
export interface ReportSection {
  title: string
  headers: string[]
  rows: ReportCell[][]
}

function formatGrowthPct(pct: number | null): string {
  if (pct == null) return 'N/A'
  const sign = pct > 0 ? '+' : ''
  return `${sign}${pct}%`
}

function formatIsoDate(d: Date): string {
  return d.toISOString().slice(0, 10)
}

function orNA(value: unknown): string {
  if (value == null || value === '' || value === '—') return 'N/A'
  return String(value)
}

function keyValues(title: string, pairs: [string, ReportCell][]): ReportSection {
  return { title, headers: ['Metric', 'Value'], rows: pairs }
}

function buildEventsExportRows(events: Record<string, unknown>[]) {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  let upcoming = 0
  let completed = 0
  for (const e of events) {
    const status = String(e.status ?? '').toLowerCase()
    if (status === 'completed') completed++
    const d = new Date(String(e.event_date ?? ''))
    if (!Number.isNaN(d.getTime()) && d >= today && status !== 'completed' && status !== 'cancelled') {
      upcoming++
    }
  }
  return {
    summary: [
      ['All events', events.length],
      ['Upcoming', upcoming],
      ['Completed', completed],
    ] as [string, ReportCell][],
    table: events.slice(0, 100).map((e) => [
      String(e.title ?? e.event_name ?? 'Event'),
      orNA(e.event_date).slice(0, 10),
      orNA(e.status),
      orNA(e.assigned_count ?? e.assignments_count),
      orNA(e.location ?? e.venue),
    ]),
  }
}

export function buildAnalyticsReportSections(data: AnalyticsSnapshot, range: DateRange): ReportSection[] {
  const s = data.stats
  const model = buildAnalyticsOverview(data, range)
  const sections: ReportSection[] = []

  sections.push({
    title: 'Overview KPIs',
    headers: ['Metric', 'Value', 'Trend vs prior period'],
    rows: model.kpis.map((kpi) => [
      kpi.label,
      `${kpi.value}${kpi.valueSuffix ?? ''}`,
      formatGrowthPct(kpi.growthPct),
    ]),
  })

  sections.push({
    title: 'Documentation requests (all time)',
    headers: ['Status', 'Count'],
    rows: [
      ['Pending', Number(s.pending_requests ?? 0)],
      ['Approved', Number(s.approved_requests ?? 0)],
      ['Rejected', Number(s.rejected_requests ?? 0)],
      ['Completed', Number(s.completed_requests ?? 0)],
      ['Total', Number(s.total_requests ?? data.requests.length ?? 0)],
    ],
  })

  sections.push({
    title: 'Evaluation quality (selected period)',
    headers: ['Quality level', 'Count'],
    rows: model.qualityBuckets.map((b) => [b.label, b.count]),
  })

  const monthlyRequests = requestYears(data.requests)
    .sort((a, b) => a - b)
    .flatMap((year) =>
      buildRequestsByMonth(data.requests, year)
        .points.filter((p) => p.requests > 0)
        .map((p): ReportCell[] => [`${p.label} ${year}`, p.requests, p.requesters]),
    )
  if (monthlyRequests.length > 0) {
    sections.push({
      title: 'Event requests by month (submission date)',
      headers: ['Month', 'Requests', 'Requesters'],
      rows: monthlyRequests,
    })
  }

  sections.push({
    title: 'Media in selected period',
    headers: ['Type', 'Count'],
    rows: [
      ['Photos', model.mediaPhotos],
      ['Videos', model.mediaVideos],
      ['Total', model.mediaTotal],
    ],
  })

  const rs = data.rankingsSummary
  sections.push(
    keyValues('Rankings summary', [
      ['Total ranked', Number(rs.total_ranked ?? 0)],
      ['Top performer', orNA(rs.top_performer_name)],
      ['Top performer points', Number(rs.top_performer_points ?? 0)],
      ['Needs improvement', Number(rs.needs_improvement_count ?? 0)],
      ['Most active uploader', orNA(rs.most_active_uploader_name)],
      ['Most uploads', Number(rs.most_active_uploads ?? 0)],
    ]),
  )

  sections.push({
    title: 'Top members by score',
    headers: ['Rank', 'Member', 'Score'],
    rows: model.topMembers.map((m) => [m.rank, m.name, m.score]),
  })

  sections.push({
    title: 'Member participation',
    headers: ['Member', 'Tasks completed', 'Uploads', 'Points', 'Avg quality %', 'Skill level'],
    rows: participationRows(data.rankings)
      .slice(0, 50)
      .map((row) => [
        row.name,
        row.tasks,
        row.uploads,
        row.participation,
        row.quality > 0 ? Math.round(row.quality) : 'N/A',
        orNA(row.status),
      ]),
  })

  sections.push(
    keyValues('Requester feedback', [
      ['Total feedback records', data.feedback.length],
      ['Average rating', s.avg_feedback_rating != null ? Number(s.avg_feedback_rating).toFixed(1) : 'N/A'],
      ['Feedback count (dashboard)', Number(s.feedback_count ?? 0)],
    ]),
  )
  sections.push({
    title: 'Feedback rating distribution',
    headers: ['Rating', 'Count'],
    rows: [5, 4, 3, 2, 1].map((star) => [
      `${star} ${star === 1 ? 'star' : 'stars'}`,
      data.feedback.filter((f) => Math.round(Number(f.rating ?? 0)) === star).length,
    ]),
  })

  const eventsExport = buildEventsExportRows(data.events)
  sections.push(keyValues('Events summary', eventsExport.summary))
  if (eventsExport.table.length > 0) {
    sections.push({
      title: 'Event schedule',
      headers: ['Event', 'Date', 'Status', 'Assigned', 'Location'],
      rows: eventsExport.table,
    })
  }

  const ai = data.aiSummary as Record<string, unknown>
  if (Object.keys(ai).length > 0) {
    sections.push(
      keyValues('Media integrity (AI detection)', [
        ['Total scanned', Number(ai.total_scanned ?? 0)],
        ['Human verified', Number(ai.human_count ?? 0)],
        ['AI generated flagged', Number(ai.ai_generated_count ?? 0)],
        ['Suspicious', Number(ai.suspicious_count ?? 0)],
        ['Pending admin review', Number(ai.pending_review_count ?? 0)],
      ]),
    )
  }

  sections.push({
    title: 'Insights',
    headers: ['Note'],
    rows: buildInsights(data).map((note) => [note]),
  })

  sections.push({
    title: 'Recent activity',
    headers: ['Date', 'Event', 'Detail'],
    rows: buildRecentActivityList(data, 50).map((a) => [formatIsoDate(a.at), a.title, a.subtitle ?? '']),
  })

  return sections
}
