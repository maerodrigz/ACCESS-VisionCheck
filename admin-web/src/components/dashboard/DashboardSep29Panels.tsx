import type { LucideIcon } from 'lucide-react'
import {
  AlertTriangle,
  Bot,
  Calendar,
  CheckCircle2,
  ChevronRight,
  FileText,
  MapPin,
  ImageIcon,
  LineChart,
  Shield,
  TrendingDown,
  TrendingUp,
  Users,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { adminMediaStreamUrl } from '../../api/media'
import { AdminCard } from '../AdminCard'
import { aiReviewRiskLabel, type AiReviewRiskTier } from '../../lib/aiDetection'
import type {
  ActiveDocumenterSnapshot,
  AiReviewQueueSnapshot,
  EvalOverviewStats,
  EvaluationTrendPoint,
  PendingRequestItem,
  UpcomingEventItem,
} from '../../lib/dashboard'
import { DashboardSectionHeader } from './DashboardPanels'

const ROW_HEIGHT = 'min-h-[320px]'
const BOTTOM_ROW_HEIGHT = 'min-h-[300px]'
/** Dashboard cards: content height, no forced min-height stretch */
const COMPACT_PANEL = 'flex h-auto flex-col overflow-hidden'

/** AdminCard's body is a plain flex child, so panels that stretch must opt into growing. */
const FILL_BODY = 'flex min-h-0 flex-1 flex-col'

function TextLink({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="inline-flex shrink-0 items-center gap-0.5 text-xs font-semibold text-[var(--color-accent-blue)] hover:underline"
    >
      {label}
      <ChevronRight size={14} />
    </button>
  )
}

function PendingStatusBadge({ label }: { label: string }) {
  const pending = label.toLowerCase().includes('pending')
  if (pending) {
    return (
      <span className="inline-flex rounded-md bg-amber-50 px-2.5 py-1 text-[11px] font-semibold text-amber-700">
        {label}
      </span>
    )
  }
  const s = label.toLowerCase()
  const color = s.includes('reject')
    ? 'var(--color-danger)'
    : s.includes('approv')
      ? 'var(--color-success)'
      : 'var(--color-accent-blue)'
  return (
    <span
      className="inline-flex rounded-md px-2.5 py-1 text-[11px] font-semibold"
      style={{ color, backgroundColor: `color-mix(in srgb, ${color} 12%, transparent)` }}
    >
      {label}
    </span>
  )
}

const TABLE_HEAD_CELL =
  'px-3 py-2.5 text-[11px] font-semibold leading-snug text-[var(--color-text-primary)]'

const TABLE_BODY_CELL = 'px-3 py-3.5 align-middle'

/** Pending service requests table (replaces legacy Action Center list). */
export function ActionCenterPanel({ requests }: { requests: PendingRequestItem[] }) {
  const navigate = useNavigate()
  const rows = requests.slice(0, 5)

  const openRequest = (id: number) => {
    navigate(id > 0 ? `/documentation-requests?request=${id}` : '/documentation-requests')
  }

  return (
    <AdminCard as="section" padding="none" className={`flex h-full ${ROW_HEIGHT} flex-col overflow-hidden`}>
      <div className="px-4 pb-1 pt-3.5 sm:px-5">
        <DashboardSectionHeader
          icon={FileText}
          color="var(--color-accent-blue)"
          title="Pending Service Requests"
          trailing={<TextLink label="View All" onClick={() => navigate('/documentation-requests')} />}
        />
      </div>

      <div className="flex min-h-0 flex-1 flex-col">
        {rows.length === 0 ? (
          <div className="flex flex-1 flex-col items-center justify-center px-4 py-10 text-center">
            <CheckCircle2 size={28} className="text-[var(--color-success)] opacity-80" />
            <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">No pending requests</p>
            <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
              All documentation requests have been reviewed.
            </p>
          </div>
        ) : (
          <div className="min-h-0 flex-1 overflow-hidden px-4 pb-4 pt-1 sm:px-5">
            <table className="w-full table-fixed border-collapse text-left">
              <colgroup>
                <col style={{ width: '28%' }} />
                <col style={{ width: '24%' }} />
                <col style={{ width: '22%' }} />
                <col style={{ width: '14%' }} />
                <col style={{ width: '5.5rem' }} />
              </colgroup>
              <thead>
                <tr className="bg-[color-mix(in_srgb,var(--color-accent-blue)_8%,var(--color-surface-muted))]">
                  <th className={TABLE_HEAD_CELL}>Event Name</th>
                  <th className={TABLE_HEAD_CELL}>Requestor</th>
                  <th className={TABLE_HEAD_CELL}>Date Requested</th>
                  <th className={TABLE_HEAD_CELL}>Status</th>
                  <th className={`${TABLE_HEAD_CELL} text-center`}>Action</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr
                    key={r.id}
                    className="border-b border-[var(--color-border)] last:border-b-0 transition hover:bg-[var(--color-surface-hover)]/50"
                  >
                    <td className={TABLE_BODY_CELL}>
                      <p className="line-clamp-2 text-[11px] font-bold leading-snug text-[var(--color-text-primary)] sm:text-xs">
                        {r.eventTitle}
                      </p>
                    </td>
                    <td className={TABLE_BODY_CELL}>
                      <p className="line-clamp-2 text-[11px] leading-snug text-[var(--color-text-secondary)] sm:text-xs">
                        {r.requestor}
                      </p>
                    </td>
                    <td className={TABLE_BODY_CELL}>
                      <p className="text-[11px] leading-snug text-[var(--color-text-secondary)] sm:text-xs">
                        {r.requestedDate}
                      </p>
                    </td>
                    <td className={TABLE_BODY_CELL}>
                      <PendingStatusBadge label={r.status} />
                    </td>
                    <td className={`${TABLE_BODY_CELL} text-center`}>
                      <button
                        type="button"
                        onClick={() => openRequest(r.id)}
                        className="inline-flex rounded-lg bg-[var(--color-accent-blue)] px-3 py-1.5 text-[11px] font-semibold text-white hover:opacity-95 sm:text-xs"
                      >
                        Review
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </AdminCard>
  )
}

const UPCOMING_DATE_THEMES = [
  { bg: 'bg-blue-50', month: 'text-blue-600', day: 'text-blue-700' },
  { bg: 'bg-violet-50', month: 'text-violet-600', day: 'text-violet-700' },
  { bg: 'bg-rose-50', month: 'text-rose-500', day: 'text-rose-700' },
  { bg: 'bg-emerald-50', month: 'text-emerald-600', day: 'text-emerald-700' },
] as const

function memberInitial(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return '?'
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase()
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase()
}

function AssignedMemberAvatars({ names }: { names: string[] }) {
  const shown = names.slice(0, 3)
  if (shown.length === 0) {
    return <span className="text-[10px] text-[var(--color-text-muted)]">No members assigned</span>
  }
  return (
    <div className="flex items-center gap-1.5">
      <div className="flex -space-x-1.5">
        {shown.map((name) => (
          <span
            key={name}
            title={name}
            className="flex h-6 w-6 items-center justify-center rounded-full border-2 border-[var(--color-surface)] bg-[var(--color-surface-muted)] text-[9px] font-bold text-[var(--color-text-secondary)]"
          >
            {memberInitial(name)}
          </span>
        ))}
      </div>
      <span className="text-[10px] text-[var(--color-text-secondary)]">
        {names.length} member{names.length === 1 ? '' : 's'} assigned
      </span>
    </div>
  )
}

/** @deprecated use upcomingEvents — kept export name for dashboard page */
export function TodayScheduleTimelinePanel({ items }: { items: UpcomingEventItem[] }) {
  const navigate = useNavigate()

  return (
    <AdminCard as="section" padding="none" className={`flex h-full ${ROW_HEIGHT} flex-col overflow-hidden`}>
      <div className="px-4 pb-1 pt-3.5 sm:px-5">
        <DashboardSectionHeader
          icon={Calendar}
          color="var(--color-accent-blue)"
          title="Upcoming Events"
          trailing={<TextLink label="View Calendar" onClick={() => navigate('/event-calendar')} />}
        />
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto px-4 pb-4 pt-1 sm:px-5">
        {items.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center py-8 text-center">
            <Calendar size={26} className="text-[var(--color-text-secondary)] opacity-50" />
            <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">No upcoming events</p>
            <p className="mt-1 text-xs text-[var(--color-text-secondary)]">Approved events will appear here.</p>
          </div>
        ) : (
          <ul className="divide-y divide-[var(--color-border)]">
            {items.map((item, i) => {
              const theme = UPCOMING_DATE_THEMES[i % UPCOMING_DATE_THEMES.length]
              return (
                <li key={item.id || `${item.eventName}-${i}`}>
                  <button
                    type="button"
                    onClick={() => navigate('/event-calendar')}
                    className="flex w-full items-start gap-3 py-3.5 text-left transition hover:bg-[var(--color-surface-hover)]/40"
                  >
                    <div
                      className={`flex h-[52px] w-[52px] shrink-0 flex-col items-center justify-center rounded-xl ${theme.bg}`}
                    >
                      <span className={`text-[10px] font-bold leading-none ${theme.month}`}>{item.monthLabel}</span>
                      <span className={`mt-1 text-lg font-extrabold leading-none ${theme.day}`}>{item.dayLabel}</span>
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="line-clamp-2 text-sm font-bold leading-snug text-[var(--color-text-primary)]">
                        {item.eventName}
                      </p>
                      <p className="mt-1 flex flex-wrap items-center gap-1 text-[11px] text-[var(--color-text-secondary)]">
                        <span>{item.timeRange}</span>
                        <span className="text-[var(--color-text-muted)]">|</span>
                        <MapPin size={11} className="shrink-0 opacity-70" aria-hidden />
                        <span className="truncate">{item.location}</span>
                      </p>
                      <div className="mt-2">
                        <AssignedMemberAvatars names={item.memberNames} />
                      </div>
                    </div>
                    <ChevronRight size={18} className="mt-2 shrink-0 text-[var(--color-text-muted)]" aria-hidden />
                  </button>
                </li>
              )
            })}
          </ul>
        )}
      </div>
    </AdminCard>
  )
}

function EvalMiniTile({
  icon: Icon,
  color,
  label,
  value,
  trend,
  invertTrend,
}: {
  icon: LucideIcon
  color: string
  label: string
  value: number
  trend: number
  invertTrend?: boolean
}) {
  const up = trend >= 0
  const good = invertTrend ? !up : up
  const TrendIcon = up ? TrendingUp : TrendingDown

  return (
    <div className="flex min-h-[90px] flex-col justify-between rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2.5">
      <div className="flex items-center justify-between gap-2">
        <span
          className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md"
          style={{ backgroundColor: `color-mix(in srgb, ${color} 14%, transparent)`, color }}
        >
          <Icon size={16} />
        </span>
        <span className="text-xl font-extrabold tabular-nums leading-none text-[var(--color-text-primary)]">
          {value}
        </span>
      </div>
      <div className="mt-2 min-w-0">
        <div className="truncate text-[11px] font-semibold leading-tight text-[var(--color-text-primary)]">
          {label}
        </div>
        <div
          className={`mt-1 flex items-center gap-1 text-[10px] font-semibold ${good ? 'text-emerald-600' : 'text-red-500'}`}
        >
          <TrendIcon size={11} className="shrink-0" />
          <span className="truncate">
            {up ? '+' : ''}
            {trend}% vs last week
          </span>
        </div>
      </div>
    </div>
  )
}

export function MediaEvaluationOverviewPanel({ stats }: { stats: EvalOverviewStats }) {
  const navigate = useNavigate()

  return (
    <AdminCard
      as="section"
      padding="sm"
      className={`h-full ${BOTTOM_ROW_HEIGHT}`}
      bodyClassName={FILL_BODY}
    >
      <DashboardSectionHeader
        icon={LineChart}
        color="var(--color-accent-blue)"
        title="Media Evaluation Overview"
        subtitle="Last 7 days vs the week before."
        trailing={<TextLink label="Analytics" onClick={() => navigate('/analytics')} />}
      />
      <div className="mt-3 grid min-h-0 flex-1 auto-rows-fr grid-cols-1 gap-2 sm:grid-cols-2">
        <EvalMiniTile
          icon={ImageIcon}
          color="var(--color-accent-blue)"
          label="Evaluated"
          value={stats.evaluated}
          trend={stats.evaluatedTrend}
        />
        <EvalMiniTile
          icon={CheckCircle2}
          color="var(--color-success)"
          label="Good Quality"
          value={stats.goodQuality}
          trend={stats.goodQualityTrend}
        />
        <EvalMiniTile
          icon={AlertTriangle}
          color="var(--color-warning)"
          label="Needs Improvement"
          value={stats.needsImprovement}
          trend={stats.needsImprovementTrend}
          invertTrend
        />
        <EvalMiniTile
          icon={Bot}
          color="var(--color-danger)"
          label="AI Risk Flagged"
          value={stats.aiFlagged}
          trend={stats.aiFlaggedTrend}
          invertTrend
        />
      </div>
    </AdminCard>
  )
}

const TREND_SERIES = [
  { key: 'evaluated' as const, color: 'var(--color-accent-blue)', label: 'Evaluated' },
  { key: 'goodQuality' as const, color: 'var(--color-success)', label: 'Good' },
  { key: 'needsImprovement' as const, color: 'var(--color-warning)', label: 'Needs work' },
  { key: 'aiFlagged' as const, color: 'var(--color-danger)', label: 'AI flagged' },
]

/** Normalised 0..100 coordinates; the SVG stretches to fill whatever box it lands in. */
function seriesPoints(points: EvaluationTrendPoint[], key: keyof EvaluationTrendPoint, max: number) {
  const n = points.length
  if (n === 0) return ''

  return points
    .map((p, i) => {
      const x = n <= 1 ? 50 : (i / (n - 1)) * 100
      const y = 100 - (Number(p[key] ?? 0) / max) * 100
      return `${x.toFixed(2)},${y.toFixed(2)}`
    })
    .join(' ')
}

export function EvaluationTrendPanel({ points }: { points: EvaluationTrendPoint[] }) {
  const peak = points.reduce(
    (m, p) => Math.max(m, p.evaluated, p.goodQuality, p.needsImprovement, p.aiFlagged),
    0,
  )
  const max = Math.max(1, peak)
  const yTicks = Array.from(new Set([max, Math.round(max / 2), 0]))
  const xTicks =
    points.length > 2
      ? [points[0], points[Math.floor((points.length - 1) / 2)], points[points.length - 1]]
      : points

  return (
    <AdminCard
      as="section"
      padding="sm"
      className={`h-full ${BOTTOM_ROW_HEIGHT}`}
      bodyClassName={FILL_BODY}
    >
      <DashboardSectionHeader
        icon={LineChart}
        color="var(--color-accent-blue)"
        title="Evaluation Trend"
        subtitle="Daily evaluation count, last 7 days."
      />
      {peak === 0 ? (
        <div className="flex flex-1 flex-col items-center justify-center py-6 text-center">
          <LineChart size={28} className="text-[var(--color-text-secondary)] opacity-50" />
          <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">
            No evaluations yet
          </p>
          <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
            Nothing recorded in the last 7 days.
          </p>
        </div>
      ) : (
        <>
          <div className="mt-3 flex min-h-[120px] flex-1 gap-2">
            <div className="flex w-7 shrink-0 flex-col justify-between text-right text-[10px] leading-none tabular-nums text-[var(--color-text-muted)]">
              {yTicks.map((v) => (
                <span key={v}>{v}</span>
              ))}
            </div>
            <div className="relative min-w-0 flex-1">
              {yTicks.map((v, i) => (
                <span
                  key={v}
                  className="pointer-events-none absolute inset-x-0 h-px bg-[var(--color-border-subtle)]"
                  style={{ top: `${(i / Math.max(1, yTicks.length - 1)) * 100}%` }}
                />
              ))}
              <svg
                viewBox="0 0 100 100"
                preserveAspectRatio="none"
                className="absolute inset-0 h-full w-full overflow-visible"
                role="img"
                aria-label={`Evaluation trend over the last ${points.length} days, peaking at ${peak} per day.`}
              >
                {TREND_SERIES.map(({ key, color }) => (
                  <polyline
                    key={key}
                    fill="none"
                    stroke={color}
                    strokeWidth="1.75"
                    strokeLinejoin="round"
                    strokeLinecap="round"
                    vectorEffect="non-scaling-stroke"
                    points={seriesPoints(points, key, max)}
                  />
                ))}
              </svg>
            </div>
          </div>
          <div className="mt-2 flex justify-between pl-9 text-[10px] text-[var(--color-text-muted)]">
            {xTicks.map((p) => (
              <span key={p.dateLabel}>{p.dateLabel}</span>
            ))}
          </div>
          <div className="mt-3 grid grid-cols-2 gap-x-3 gap-y-1.5 text-[10px] text-[var(--color-text-secondary)] sm:grid-cols-4">
            {TREND_SERIES.map(({ color, label }) => (
              <span key={label} className="inline-flex min-w-0 items-center gap-1.5">
                <span
                  className="h-1.5 w-1.5 shrink-0 rounded-full"
                  style={{ backgroundColor: color }}
                />
                <span className="truncate">{label}</span>
              </span>
            ))}
          </div>
        </>
      )}
    </AdminCard>
  )
}

const DOC_COLORS = ['#00c4e8', '#6366f1', '#0052d4']

function DocumentersDonut({
  segments,
  total,
  compact = false,
}: {
  segments: { label: string; value: number; color: string; pct: number }[]
  total: number
  compact?: boolean
}) {
  const size = compact ? 104 : 120
  const cx = size / 2
  const cy = size / 2
  const r = compact ? 36 : 42
  const stroke = compact ? 14 : 16
  const circ = 2 * Math.PI * r
  let offset = 0
  const safeTotal = total > 0 ? total : segments.reduce((s, x) => s + x.value, 0)

  return (
    <div
      className={
        compact
          ? 'flex w-full flex-col items-center gap-2'
          : 'mt-3 flex min-h-0 w-full flex-1 flex-col items-center gap-3'
      }
    >
      <div className={compact ? 'relative shrink-0' : 'relative flex min-h-0 flex-1 items-center justify-center'}>
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden>
          <circle cx={cx} cy={cy} r={r} fill="none" stroke="var(--color-border-subtle)" strokeWidth={stroke} />
          {segments.map((seg) => {
            if (seg.value <= 0 || safeTotal <= 0) return null
            const len = (seg.value / safeTotal) * circ
            const el = (
              <circle
                key={seg.label}
                cx={cx}
                cy={cy}
                r={r}
                fill="none"
                stroke={seg.color}
                strokeWidth={stroke}
                strokeDasharray={`${len} ${circ - len}`}
                strokeDashoffset={-offset}
                transform={`rotate(-90 ${cx} ${cy})`}
              />
            )
            offset += len
            return el
          })}
        </svg>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center text-center">
          <div className="text-lg font-extrabold tabular-nums leading-none text-[var(--color-text-primary)]">
            {safeTotal}
          </div>
          <div className="mt-0.5 text-[10px] font-medium text-[var(--color-text-secondary)]">Total</div>
        </div>
      </div>
      <ul className={`w-full space-y-1.5 ${compact ? 'pb-0.5' : ''}`}>
        {segments.map((seg) => (
          <li
            key={seg.label}
            className="grid grid-cols-[8px_minmax(0,1fr)_auto] items-center gap-x-2 text-[11px] leading-tight"
          >
            <span className="h-2 w-2 rounded-full" style={{ backgroundColor: seg.color }} />
            <span className="truncate font-medium text-[var(--color-text-secondary)]">{seg.label}</span>
            <span className="whitespace-nowrap tabular-nums text-[var(--color-text-primary)]">
              <span className="font-bold">{seg.pct.toFixed(1)}%</span>
              <span className="ml-1 text-[var(--color-text-secondary)]">({seg.value})</span>
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}

const AI_QUEUE_COLORS = {
  high: '#ef4444',
  suspicious: '#f59e0b',
  low: '#94a3b8',
} as const

function AiReviewRiskBadge({ tier }: { tier: AiReviewRiskTier }) {
  if (tier === 'high') {
    return (
      <span className="shrink-0 rounded-md bg-red-50 px-2 py-0.5 text-[10px] font-semibold text-red-700">
        {aiReviewRiskLabel(tier)}
      </span>
    )
  }
  if (tier === 'suspicious') {
    return (
      <span className="shrink-0 rounded-md bg-amber-50 px-2 py-0.5 text-[10px] font-semibold text-amber-700">
        {aiReviewRiskLabel(tier)}
      </span>
    )
  }
  return (
    <span className="shrink-0 rounded-md bg-slate-100 px-2 py-0.5 text-[10px] font-semibold text-slate-600">
      {aiReviewRiskLabel(tier)}
    </span>
  )
}

function AiReviewQueueDonut({
  highRisk,
  suspicious,
  lowRisk,
  total,
}: {
  highRisk: number
  suspicious: number
  lowRisk: number
  total: number
}) {
  const size = 112
  const cx = size / 2
  const cy = size / 2
  const r = 38
  const stroke = 12
  const circ = 2 * Math.PI * r
  const segments = [
    { key: 'high' as const, value: highRisk, color: AI_QUEUE_COLORS.high },
    { key: 'suspicious' as const, value: suspicious, color: AI_QUEUE_COLORS.suspicious },
    { key: 'low' as const, value: lowRisk, color: AI_QUEUE_COLORS.low },
  ].filter((s) => s.value > 0)
  const safeTotal = total > 0 ? total : segments.reduce((s, x) => s + x.value, 0)
  let offset = 0
  /** Inner clear area inside the stroke (px), with a little inset so labels never touch the ring */
  const innerLabelSize = Math.floor((r - stroke / 2) * 2 - 10)

  return (
    <div className="flex min-w-0 flex-1 items-center gap-4">
      <div className="relative shrink-0" style={{ width: size, height: size }}>
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden>
          <circle cx={cx} cy={cy} r={r} fill="none" stroke="var(--color-border-subtle)" strokeWidth={stroke} />
          {segments.map((seg) => {
            const len = safeTotal > 0 ? (seg.value / safeTotal) * circ : 0
            const el = (
              <circle
                key={seg.key}
                cx={cx}
                cy={cy}
                r={r}
                fill="none"
                stroke={seg.color}
                strokeWidth={stroke}
                strokeDasharray={`${len} ${circ - len}`}
                strokeDashoffset={-offset}
                transform={`rotate(-90 ${cx} ${cy})`}
              />
            )
            offset += len
            return el
          })}
        </svg>
        <div
          className="pointer-events-none absolute left-1/2 top-1/2 flex -translate-x-1/2 -translate-y-1/2 flex-col items-center justify-center text-center"
          style={{ width: innerLabelSize, height: innerLabelSize }}
        >
          <div className="text-lg font-extrabold tabular-nums leading-none text-[var(--color-text-primary)]">
            {total}
          </div>
          <p className="mt-0.5 text-[8px] font-medium leading-[1.15] text-[var(--color-text-secondary)]">
            <span className="block">Items for</span>
            <span className="block">Review</span>
          </p>
        </div>
      </div>
      <ul className="min-w-0 flex-1 space-y-1.5">
        {(
          [
            { key: 'high' as const, label: 'High Risk', count: highRisk, color: AI_QUEUE_COLORS.high },
            { key: 'suspicious' as const, label: 'Suspicious', count: suspicious, color: AI_QUEUE_COLORS.suspicious },
            { key: 'low' as const, label: 'Low Risk', count: lowRisk, color: AI_QUEUE_COLORS.low },
          ] as const
        ).map((row) => (
          <li key={row.key} className="flex items-center justify-between gap-2 text-[11px]">
            <span className="flex min-w-0 items-center gap-2">
              <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: row.color }} />
              <span className="font-medium text-[var(--color-text-secondary)]">{row.label}</span>
            </span>
            <span className="shrink-0 font-bold tabular-nums text-[var(--color-text-primary)]">{row.count}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}

export function AiReviewQueuePanel({ snapshot }: { snapshot: AiReviewQueueSnapshot }) {
  const navigate = useNavigate()

  return (
    <AdminCard
      as="section"
      padding="none"
      className={COMPACT_PANEL}
    >
      <div className="px-4 pb-0 pt-2.5 sm:px-5">
        <DashboardSectionHeader
          icon={Shield}
          color="var(--color-accent-blue)"
          title="AI Review Queue"
          trailing={<TextLink label="View All" onClick={() => navigate('/media-integrity')} />}
        />
      </div>
      <div className="flex flex-col gap-2 overflow-hidden px-4 pb-2.5 pt-0.5 sm:flex-row sm:gap-0 sm:px-5">
        <div className="flex min-h-0 min-w-0 flex-1 flex-col justify-center sm:max-w-[52%] sm:pr-3">
          {!snapshot.available ? (
            <p className="py-4 text-center text-xs text-[var(--color-text-secondary)]">
              Could not load AI review data.
            </p>
          ) : snapshot.totalForReview === 0 ? (
            <div className="flex flex-col items-center py-4 text-center">
              <CheckCircle2 size={28} className="text-[var(--color-success)] opacity-80" />
              <p className="mt-2 text-sm font-semibold text-[var(--color-text-primary)]">Queue is clear</p>
              <p className="mt-1 text-xs text-[var(--color-text-secondary)]">No items need manual review.</p>
            </div>
          ) : (
            <AiReviewQueueDonut
              highRisk={snapshot.highRisk}
              suspicious={snapshot.suspicious}
              lowRisk={snapshot.lowRisk}
              total={snapshot.totalForReview}
            />
          )}
        </div>
        <div className="hidden w-px shrink-0 self-stretch bg-[var(--color-border)] sm:block" aria-hidden />
        <div className="flex min-w-0 flex-1 flex-col overflow-hidden sm:pl-3">
          <h3 className="shrink-0 text-sm font-bold text-[var(--color-text-primary)]">Recent Items</h3>
          {snapshot.recentItems.length === 0 ? (
            <p className="mt-2 text-xs text-[var(--color-text-secondary)]">No recent flagged media.</p>
          ) : (
            <ul className="mt-1 divide-y divide-[var(--color-border)]">
              {snapshot.recentItems.map((item) => {
                const thumb = item.mediaId ? adminMediaStreamUrl(item.mediaId) : ''
                return (
                  <li key={item.id}>
                    <button
                      type="button"
                      onClick={() =>
                        navigate(
                          item.mediaId > 0
                            ? `/media-integrity?media=${item.mediaId}`
                            : '/media-integrity',
                        )
                      }
                      className="flex w-full items-center gap-2.5 py-1.5 text-left transition hover:bg-[var(--color-surface-hover)]/40"
                    >
                      {thumb ? (
                        <img
                          src={thumb}
                          alt=""
                          className="h-9 w-9 shrink-0 rounded-lg border border-[var(--color-border)] object-cover"
                        />
                      ) : (
                        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[var(--color-surface-muted)]">
                          <ImageIcon size={14} className="text-[var(--color-text-muted)]" />
                        </span>
                      )}
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-xs font-bold text-[var(--color-text-primary)]">{item.fileName}</p>
                        <p className="text-[10px] text-[var(--color-text-secondary)]">{item.timeAgo}</p>
                      </div>
                      <AiReviewRiskBadge tier={item.riskTier} />
                      <ChevronRight size={16} className="shrink-0 text-[var(--color-text-muted)]" aria-hidden />
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
      </div>
    </AdminCard>
  )
}

export function ActiveDocumentersPanel({ snapshot }: { snapshot: ActiveDocumenterSnapshot }) {
  const navigate = useNavigate()
  const segments = snapshot.breakdown.map((b, i) => ({
    label: b.label,
    value: b.count,
    color: DOC_COLORS[i % DOC_COLORS.length],
    pct: b.percent,
  }))

  return (
    <AdminCard as="section" padding="none" className={COMPACT_PANEL}>
      <div className="px-4 pb-0 pt-2.5 sm:px-5">
        <DashboardSectionHeader
          icon={Users}
          color="var(--color-accent-purple)"
          title="Active Documenters"
          subtitle="Competency mix of members."
          trailing={<TextLink label="Members" onClick={() => navigate('/members')} />}
        />
      </div>
      <div className="px-4 pb-2.5 pt-0.5 sm:px-5">
      {snapshot.totalActive === 0 ? (
        <div className="flex flex-col items-center py-4 text-center">
          <Users size={28} className="text-[var(--color-text-secondary)] opacity-50" />
          <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">
            No active members yet
          </p>
          <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
            Competency appears once members start uploading.
          </p>
        </div>
      ) : (
        <DocumentersDonut compact segments={segments} total={snapshot.totalActive} />
      )}
      </div>
    </AdminCard>
  )
}
