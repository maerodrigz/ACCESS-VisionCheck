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

export function downloadTextFile(filename: string, content: string, mime = 'text/csv;charset=utf-8') {
  const blob = new Blob([content], { type: mime })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = filename
  anchor.click()
  URL.revokeObjectURL(url)
}

import type { DateRange } from './analyticsOverview'
import {
  buildAnalyticsOverview,
  buildRecentActivityList,
  defaultDateRange,
  formatDateRangeLabel,
} from './analyticsOverview'

export async function fetchAnalyticsSnapshot(): Promise<AnalyticsSnapshot> {
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

  const [stats, rankings, rankingsSummary, events, feedback, media, requests, evaluations] =
    await Promise.all([
      fetchDashboardStats(),
      fetchRankings(),
      fetchRankingsSummary(),
      fetchEvents(),
      fetchFeedback(),
      fetchMedia(),
      fetchServiceRequests(),
      fetchEvaluations(),
    ])

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

function csvCell(value: string | number | null | undefined): string {
  if (value == null) return ''
  const s = String(value)
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`
  return s
}

function formatGrowthPct(pct: number | null): string {
  if (pct == null) return '—'
  const sign = pct > 0 ? '+' : ''
  return `${sign}${pct}%`
}

function formatIsoDate(d: Date): string {
  return d.toISOString().slice(0, 10)
}

function pushSection(
  lines: string[],
  title: string,
  headers: string[],
  rows: (string | number | null | undefined)[][],
) {
  lines.push('', title, headers.map(csvCell).join(','))
  for (const row of rows) {
    lines.push(row.map(csvCell).join(','))
  }
}

function pushKeyValues(lines: string[], title: string, pairs: [string, string | number][]) {
  pushSection(
    lines,
    title,
    ['Metric', 'Value'],
    pairs.map(([k, v]) => [k, v]),
  )
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
    ] as [string, string | number][],
    table: events.slice(0, 100).map((e) => [
      String(e.title ?? e.event_name ?? 'Event'),
      String(e.event_date ?? '—').slice(0, 10),
      String(e.status ?? '—'),
      String(e.assigned_count ?? e.assignments_count ?? '—'),
      String(e.location ?? e.venue ?? '—'),
    ]),
  }
}

export function buildAnalyticsCsv(
  data: AnalyticsSnapshot,
  range?: DateRange,
  tab?: AnalyticsTab,
): string {
  const s = data.stats
  const effectiveRange = range ?? defaultDateRange()
  const tabLabel = tab ? ANALYTICS_TABS.find((t) => t.id === tab)?.label : undefined
  const lines = [
    'ACCESS VisionCheck Analytics Report',
    `Generated,${new Date().toISOString()}`,
    `Period,${formatDateRangeLabel(effectiveRange)}`,
  ]
  if (tabLabel && tab !== 'overview') {
    lines.push(`View context,${tabLabel}`)
  }

  const model = buildAnalyticsOverview(data, effectiveRange)

  pushSection(
    lines,
    'Overview KPIs',
    ['Metric', 'Value', 'Trend vs prior period'],
    model.kpis.map((kpi) => [
      kpi.label,
      `${kpi.value}${kpi.valueSuffix ?? ''}`,
      formatGrowthPct(kpi.growthPct),
    ]),
  )

  pushSection(
    lines,
    'Documentation requests (all time)',
    ['Status', 'Count'],
    [
      ['Pending', Number(s.pending_requests ?? 0)],
      ['Approved', Number(s.approved_requests ?? 0)],
      ['Rejected', Number(s.rejected_requests ?? 0)],
      ['Completed', Number(s.completed_requests ?? 0)],
      ['Total', Number(s.total_requests ?? data.requests.length ?? 0)],
    ],
  )

  pushSection(
    lines,
    'Member assignments (all time)',
    ['Status', 'Count'],
    [
      ['Awaiting acceptance', Number(s.pending_assignments ?? 0)],
      ['Accepted', Number(s.accepted_assignments ?? s.completed_tasks ?? 0)],
      ['Declined', Number(s.declined_assignments ?? 0)],
    ],
  )

  pushSection(
    lines,
    'Evaluation quality (selected period)',
    ['Quality level', 'Count'],
    model.qualityBuckets.map((b) => [b.label, b.count]),
  )

  if (model.evaluationsSeries.some((p) => p.value > 0)) {
    pushSection(
      lines,
      'Evaluations over time (selected period)',
      ['Date', 'Evaluations'],
      model.evaluationsSeries.map((p) => [formatIsoDate(p.date), p.value]),
    )
  }

  pushSection(lines, 'Media in selected period', ['Type', 'Count'], [
    ['Photos', model.mediaPhotos],
    ['Videos', model.mediaVideos],
    ['Total', model.mediaTotal],
  ])

  const rs = data.rankingsSummary
  pushKeyValues(lines, 'Rankings summary', [
    ['Total ranked', Number(rs.total_ranked ?? 0)],
    ['Top performer', String(rs.top_performer_name ?? '—')],
    ['Top performer points', Number(rs.top_performer_points ?? 0)],
    ['Needs improvement', Number(rs.needs_improvement_count ?? 0)],
    ['Most active uploader', String(rs.most_active_uploader_name ?? '—')],
    ['Most uploads', Number(rs.most_active_uploads ?? 0)],
  ])

  pushSection(
    lines,
    'Top members by score',
    ['Rank', 'Member', 'Score'],
    model.topMembers.map((m) => [m.rank, m.name, m.score]),
  )

  const participation = participationRows(data.rankings).slice(0, 50)
  pushSection(
    lines,
    'Member participation',
    ['Member', 'Tasks completed', 'Uploads', 'Points', 'Avg quality %', 'Skill level'],
    participation.map((row) => [
      row.name,
      row.tasks,
      row.uploads,
      row.participation,
      row.quality > 0 ? Math.round(row.quality) : '—',
      row.status,
    ]),
  )

  const avgRating =
    s.avg_feedback_rating != null ? Number(s.avg_feedback_rating).toFixed(1) : '—'
  pushKeyValues(lines, 'Requester feedback', [
    ['Total feedback records', data.feedback.length],
    ['Average rating', avgRating],
    ['Feedback count (dashboard)', Number(s.feedback_count ?? 0)],
  ])
  pushSection(
    lines,
    'Feedback rating distribution',
    ['Rating', 'Count'],
    [5, 4, 3, 2, 1].map((star) => [
      `${star} stars`,
      data.feedback.filter((f) => Math.round(Number(f.rating ?? 0)) === star).length,
    ]),
  )

  const eventsExport = buildEventsExportRows(data.events)
  pushKeyValues(lines, 'Events summary', eventsExport.summary)
  if (eventsExport.table.length > 0) {
    pushSection(lines, 'Event schedule', ['Event', 'Date', 'Status', 'Assigned', 'Location'], eventsExport.table)
  }

  const ai = data.aiSummary as Record<string, unknown>
  if (Object.keys(ai).length > 0) {
    pushKeyValues(lines, 'Media integrity (AI detection)', [
      ['Total scanned', Number(ai.total_scanned ?? 0)],
      ['Human verified', Number(ai.human_count ?? 0)],
      ['AI generated flagged', Number(ai.ai_generated_count ?? 0)],
      ['Suspicious', Number(ai.suspicious_count ?? 0)],
      ['Pending admin review', Number(ai.pending_review_count ?? 0)],
    ])
  }

  pushSection(
    lines,
    'Insights',
    ['Note'],
    buildInsights(data).map((note) => [note]),
  )

  const activity = buildRecentActivityList(data, 50)
  pushSection(
    lines,
    'Recent activity',
    ['Date', 'Event', 'Detail'],
    activity.map((a) => [formatIsoDate(a.at), a.title, a.subtitle ?? '']),
  )

  return lines.join('\n')
}

export function exportAnalyticsReport(data: AnalyticsSnapshot, range: DateRange, tab?: AnalyticsTab) {
  const start = range.start.toISOString().slice(0, 10)
  const end = range.end.toISOString().slice(0, 10)
  const tabSuffix = tab && tab !== 'overview' ? `-${tab}` : ''
  downloadTextFile(
    `access-analytics-${start}_to_${end}${tabSuffix}.csv`,
    buildAnalyticsCsv(data, range, tab),
  )
}
