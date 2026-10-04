import type { LucideIcon } from 'lucide-react'
import {
  AlertTriangle,
  Bot,
  Calendar,
  CheckCircle2,
  ChevronRight,
  ClipboardCheck,
  ImageIcon,
  LineChart,
  TrendingDown,
  TrendingUp,
  Users,
  Zap,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { AdminCard } from '../AdminCard'
import type {
  ActionCenterItem,
  ActiveDocumenterSnapshot,
  EvalOverviewStats,
  EvaluationTrendPoint,
  TodayScheduleItem,
} from '../../lib/dashboard'
import { DashboardSectionHeader } from './DashboardPanels'

const ROW_HEIGHT = 'min-h-[320px]'
const BOTTOM_ROW_HEIGHT = 'min-h-[300px]'

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

function priorityAccent(kind: ActionCenterItem['kind']) {
  if (kind === 'request') return 'var(--color-danger)'
  if (kind === 'integrity') return 'var(--color-warning)'
  return 'var(--color-accent-cyan)'
}

export function ActionCenterPanel({
  items,
  pendingCount,
  mediaPendingCount,
}: {
  items: ActionCenterItem[]
  pendingCount: number
  mediaPendingCount: number
}) {
  const navigate = useNavigate()

  const openItem = (item: ActionCenterItem) => {
    if (item.kind === 'request') navigate('/documentation-requests')
    else if (item.kind === 'integrity') navigate('/media-integrity')
    else navigate('/media-integrity')
  }

  return (
    <AdminCard as="section" className={`flex h-full ${ROW_HEIGHT} flex-col`}>
      <DashboardSectionHeader
        icon={Zap}
        color="var(--color-warning)"
        title="Action Center"
        subtitle="Priority items that need your attention."
        trailing={<TextLink label="View all" onClick={() => navigate('/documentation-requests')} />}
      />
      <div className="mt-3 flex min-h-0 flex-1 flex-col">
        {items.length === 0 ? (
          <div className="flex flex-1 flex-col items-center justify-center py-6 text-center">
            <CheckCircle2 size={28} className="text-[var(--color-success)] opacity-80" />
            <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">All clear</p>
            <p className="mt-1 text-xs text-[var(--color-text-secondary)]">No priority items right now.</p>
          </div>
        ) : (
          <ul className="min-h-0 flex-1 space-y-2">
            {items.slice(0, 3).map((item) => (
              <li key={`${item.kind}-${item.id}`}>
                <button
                  type="button"
                  onClick={() => openItem(item)}
                  className="flex w-full items-center gap-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-3 text-left transition hover:border-[var(--color-accent-blue)]/30 hover:bg-[var(--color-surface-hover)]"
                >
                  <span
                    className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
                    style={{
                      backgroundColor: `color-mix(in srgb, ${priorityAccent(item.kind)} 14%, transparent)`,
                      color: priorityAccent(item.kind),
                    }}
                  >
                    {item.kind === 'request' ? (
                      <ClipboardCheck size={18} />
                    ) : item.kind === 'integrity' ? (
                      <AlertTriangle size={18} />
                    ) : (
                      <ImageIcon size={18} />
                    )}
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-semibold text-[var(--color-text-primary)]">{item.title}</div>
                    <div className="mt-0.5 truncate text-[11px] text-[var(--color-text-secondary)]">
                      {item.subtitle}
                    </div>
                  </div>
                  <span className="shrink-0 text-[10px] font-medium text-[var(--color-text-muted)]">
                    {item.timeLabel}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
        <div className="mt-auto grid grid-cols-1 gap-2 pt-4 sm:grid-cols-2">
          <button
            type="button"
            onClick={() => navigate('/documentation-requests')}
            className="inline-flex items-center justify-center gap-2 rounded-xl bg-[var(--color-accent-blue)] px-3 py-2.5 text-xs font-semibold text-white hover:opacity-95"
          >
            <ClipboardCheck size={15} />
            {pendingCount > 0 ? `Review Requests (${pendingCount})` : 'Review Requests'}
          </button>
          <button
            type="button"
            onClick={() => navigate('/media-integrity')}
            className="inline-flex items-center justify-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2.5 text-xs font-semibold text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]"
          >
            <AlertTriangle size={15} />
            {mediaPendingCount > 0 ? `Review Media (${mediaPendingCount})` : 'Review Media'}
          </button>
        </div>
      </div>
    </AdminCard>
  )
}

function scheduleDotColor(status: string) {
  const s = status.toLowerCase()
  if (s.includes('ongoing') || s.includes('live')) return 'var(--color-success)'
  if (s.includes('done') || s.includes('complete')) return 'var(--color-text-muted)'
  return 'var(--color-accent-blue)'
}

export function TodayScheduleTimelinePanel({ items }: { items: TodayScheduleItem[] }) {
  const navigate = useNavigate()

  return (
    <AdminCard as="section" className={`flex h-full ${ROW_HEIGHT} flex-col`}>
      <DashboardSectionHeader
        icon={Calendar}
        color="var(--color-accent-blue)"
        title="Today's Schedule"
        subtitle="Upcoming and ongoing events."
        trailing={<TextLink label="Open calendar" onClick={() => navigate('/event-calendar')} />}
      />
      <div className="mt-3 min-h-0 flex-1 overflow-y-auto">
        {items.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center py-8 text-center">
            <Calendar size={28} className="text-[var(--color-text-secondary)] opacity-50" />
            <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">No events scheduled today</p>
            <p className="mt-1 text-xs text-[var(--color-text-secondary)]">Enjoy your day!</p>
          </div>
        ) : (
          <ul className="space-y-0">
            {items.map((item, i) => (
              <li key={`${item.eventName}-${i}`} className="flex gap-3 py-2.5">
                <div className="w-[58px] shrink-0 pt-0.5 text-[11px] font-medium text-[var(--color-text-secondary)]">
                  {item.timeLabel}
                </div>
                <div className="flex flex-col items-center">
                  <span
                    className="mt-1 h-2.5 w-2.5 shrink-0 rounded-full"
                    style={{ backgroundColor: scheduleDotColor(item.status) }}
                  />
                  {i < items.length - 1 ? (
                    <span className="mt-1 w-px flex-1 min-h-[28px] bg-[var(--color-border)]" />
                  ) : null}
                </div>
                <div className="min-w-0 flex-1 pb-1">
                  <div className="text-sm font-semibold text-[var(--color-text-primary)]">{item.eventName}</div>
                  <div className="mt-0.5 truncate text-[11px] text-[var(--color-text-secondary)]">
                    {item.assignedMembers}
                  </div>
                </div>
              </li>
            ))}
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
}: {
  segments: { label: string; value: number; color: string; pct: number }[]
  total: number
}) {
  const size = 120
  const cx = size / 2
  const cy = size / 2
  const r = 42
  const stroke = 16
  const circ = 2 * Math.PI * r
  let offset = 0
  const safeTotal = total > 0 ? total : segments.reduce((s, x) => s + x.value, 0)

  return (
    <div className="mt-3 flex min-h-0 w-full flex-1 flex-col items-center gap-3">
      <div className="relative flex min-h-0 flex-1 items-center justify-center">
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
      <ul className="w-full space-y-1.5">
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

export function ActiveDocumentersPanel({ snapshot }: { snapshot: ActiveDocumenterSnapshot }) {
  const navigate = useNavigate()
  const segments = snapshot.breakdown.map((b, i) => ({
    label: b.label,
    value: b.count,
    color: DOC_COLORS[i % DOC_COLORS.length],
    pct: b.percent,
  }))

  return (
    <AdminCard
      as="section"
      padding="sm"
      className={`h-full ${BOTTOM_ROW_HEIGHT}`}
      bodyClassName={FILL_BODY}
    >
      <DashboardSectionHeader
        icon={Users}
        color="var(--color-accent-purple)"
        title="Active Documenters"
        subtitle="Competency mix of members."
        trailing={<TextLink label="Members" onClick={() => navigate('/members')} />}
      />
      {snapshot.totalActive === 0 ? (
        <div className="flex flex-1 flex-col items-center justify-center py-6 text-center">
          <Users size={28} className="text-[var(--color-text-secondary)] opacity-50" />
          <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">
            No active members yet
          </p>
          <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
            Competency appears once members start uploading.
          </p>
        </div>
      ) : (
        <DocumentersDonut segments={segments} total={snapshot.totalActive} />
      )}
    </AdminCard>
  )
}
