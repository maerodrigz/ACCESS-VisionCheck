import { useMemo, type ReactNode } from 'react'
import {
  ChevronRight,
  TrendingDown,
  TrendingUp,
} from 'lucide-react'
import { AdminCard } from '../AdminCard'
import { ActivityTypeIcon } from '../ActivityTypeIcon'
import {
  buildDocumentationActivitySeries,
  type ActivityItem,
  type DocumentationActivityPoint,
  type OrgRank,
} from '../../lib/analyticsOverview'

export function AnalyticsKpiCard({
  icon,
  iconBg,
  iconColor,
  label,
  value,
  valueSuffix,
  growthPct,
  growthLabel,
}: {
  icon: ReactNode
  iconBg: string
  iconColor: string
  label: string
  value: string
  valueSuffix?: string
  growthPct: number | null
  growthLabel?: string
}) {
  const showGrowth = growthPct !== null
  const pct = growthPct ?? 0
  const up = pct >= 0
  const trendText = up ? `+${Math.abs(pct).toFixed(0)}%` : `${Math.abs(pct).toFixed(0)}%`

  return (
    <div className="flex h-[112px] min-w-0 flex-col rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] p-4 shadow-[0_2px_8px_rgba(15,39,68,0.04)]">
      <div className="flex min-w-0 items-center gap-2">
        <div
          className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg"
          style={{ backgroundColor: iconBg, color: iconColor }}
        >
          {icon}
        </div>
        <p className="min-w-0 flex-1 truncate text-[11px] font-medium text-[var(--color-text-secondary)]">{label}</p>
      </div>
      <div className="mt-auto">
        <div className="flex items-baseline gap-0.5">
          <span className="text-xl font-extrabold leading-none text-[var(--color-text-primary)]">{value}</span>
          {valueSuffix && <span className="text-sm font-extrabold text-[var(--color-text-primary)]">{valueSuffix}</span>}
        </div>
        {showGrowth ? (
          <div className={`mt-1 flex items-center gap-0.5 text-[10px] font-semibold ${up ? 'text-emerald-400' : 'text-red-400'}`}>
            {up ? <TrendingUp size={12} strokeWidth={2.5} /> : <TrendingDown size={12} strokeWidth={2.5} />}
            <span>
              {trendText}
              {growthLabel ? ` · ${growthLabel}` : ''}
            </span>
          </div>
        ) : (
          <div className="mt-1 h-[14px]" aria-hidden />
        )}
      </div>
    </div>
  )
}

const CHART_PAIR_HEIGHT = 'h-[400px]'
const BOTTOM_ROW_HEIGHT = 'h-[300px]'

function niceAxisStep(dataMax: number, ticks: number): number {
  const raw = Math.max(1, Math.ceil(dataMax / ticks))
  const magnitude = 10 ** Math.floor(Math.log10(raw))
  for (const m of [1, 2, 5, 10]) {
    if (m * magnitude >= raw) return m * magnitude
  }
  return 10 * magnitude
}

function plural(n: number, word: string): string {
  return `${n} ${word}${n === 1 ? '' : 's'}`
}

function DocumentationActivityLegend() {
  return (
    <div className="flex shrink-0 flex-wrap items-center justify-end gap-x-4 gap-y-1 text-[11px] font-medium text-[var(--color-text-secondary)]">
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-[#2563eb]" aria-hidden />
        Requests
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-[#14b8a6]" aria-hidden />
        Events Covered
      </span>
    </div>
  )
}

function DocumentationActivityBarChart({ points }: { points: DocumentationActivityPoint[] }) {
  const width = 640
  const height = 210
  const pad = { top: 18, right: 12, bottom: 30, left: 36 }
  const innerW = width - pad.left - pad.right
  const innerH = height - pad.top - pad.bottom
  const tickCount = 4
  const dataMax = Math.max(...points.flatMap((p) => [p.requests, p.eventsCovered]), 1)
  const step = niceAxisStep(dataMax, tickCount)
  const axisMax = step * tickCount
  const slot = innerW / Math.max(points.length, 1)
  const groupW = Math.min(slot * 0.76, 72)
  const barW = Math.max(10, (groupW - 6) / 2)
  const now = new Date()
  const currentMonth = now.getMonth()
  const currentYear = now.getFullYear()

  const barHeight = (value: number) => (value / axisMax) * innerH

  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="h-full w-full" preserveAspectRatio="xMidYMid meet">
      <defs>
        <linearGradient id="docActivityRequests" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#38bdf8" />
          <stop offset="100%" stopColor="#2563eb" />
        </linearGradient>
        <linearGradient id="docActivityEvents" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#5eead4" />
          <stop offset="100%" stopColor="#0d9488" />
        </linearGradient>
      </defs>
      {Array.from({ length: tickCount + 1 }, (_, i) => {
        const y = pad.top + innerH * (1 - i / tickCount)
        return (
          <g key={i}>
            <line x1={pad.left} y1={y} x2={width - pad.right} y2={y} stroke="#e8edf2" strokeWidth="1" />
            <text x={pad.left - 8} y={y + 4} textAnchor="end" fill="#94a3b8" fontSize="11" fontWeight="500">
              {step * i}
            </text>
          </g>
        )
      })}
      {points.map((p, i) => {
        const groupX = pad.left + slot * i + (slot - groupW) / 2
        const cx = pad.left + slot * i + slot / 2
        const reqH = barHeight(p.requests)
        const evtH = barHeight(p.eventsCovered)
        const reqY = pad.top + innerH - reqH
        const evtY = pad.top + innerH - evtH
        const isCurrent = p.month === currentMonth && p.year === currentYear
        const reqX = groupX
        const evtX = groupX + barW + 6
        return (
          <g key={`${p.year}-${p.month}`} className="transition-opacity hover:opacity-90">
            <title>
              {`${p.label}: ${plural(p.requests, 'request')}, ${plural(p.eventsCovered, 'completed event')}`}
            </title>
            <rect x={pad.left + slot * i} y={pad.top} width={slot} height={innerH} fill="transparent" />
            {p.requests > 0 && (
              <>
                <rect x={reqX} y={reqY} width={barW} height={reqH} rx={4} fill="url(#docActivityRequests)" />
                <text x={reqX + barW / 2} y={reqY - 5} textAnchor="middle" fill="#334155" fontSize="11" fontWeight="700">
                  {p.requests}
                </text>
              </>
            )}
            {p.eventsCovered > 0 && (
              <>
                <rect x={evtX} y={evtY} width={barW} height={evtH} rx={4} fill="url(#docActivityEvents)" />
                <text x={evtX + barW / 2} y={evtY - 5} textAnchor="middle" fill="#334155" fontSize="11" fontWeight="700">
                  {p.eventsCovered}
                </text>
              </>
            )}
            <text
              x={cx}
              y={height - 10}
              textAnchor="middle"
              fill={isCurrent ? '#0052d4' : '#64748b'}
              fontSize="12"
              fontWeight={isCurrent ? '700' : '500'}
            >
              {p.label}
            </text>
          </g>
        )
      })}
    </svg>
  )
}

export function DocumentationActivityCard({
  requests,
  events,
  className = '',
}: {
  requests: Record<string, unknown>[]
  events: Record<string, unknown>[]
  className?: string
}) {
  const points = useMemo(() => buildDocumentationActivitySeries(requests, events, 6), [requests, events])

  return (
    <AdminCard
      padding="none"
      bodyClassName="flex min-h-0 flex-1 flex-col"
      className={`flex h-full min-w-0 flex-col overflow-hidden ${className}`.trim()}
    >
      <div className="flex items-start justify-between gap-2 px-4 pb-1 pt-3.5 sm:px-5">
        <div className="min-w-0 flex-1">
          <h3 className="text-sm font-extrabold text-[var(--color-text-primary)] sm:text-base">
            Documentation Activity
          </h3>
          <p className="mt-0.5 text-[11px] leading-snug text-[var(--color-text-secondary)] sm:text-xs">
            Monthly documentation requests and completed events.
          </p>
        </div>
        <DocumentationActivityLegend />
      </div>
      <div className="min-h-0 flex-1 px-2 pb-3 pt-0 sm:px-4 sm:pb-4">
        <DocumentationActivityBarChart points={points} />
      </div>
    </AdminCard>
  )
}

const MEDIA_EVAL_PHOTO_COLOR = '#38bdf8'
const MEDIA_EVAL_VIDEO_COLOR = '#a78bfa'

function MediaEvaluationOverviewLegend({ photos, videos }: { photos: number; videos: number }) {
  const rows = [
    { label: 'Photos', value: photos, color: MEDIA_EVAL_PHOTO_COLOR },
    { label: 'Videos', value: videos, color: MEDIA_EVAL_VIDEO_COLOR },
  ]

  return (
    <div className="flex min-w-0 flex-1 flex-col justify-center gap-5 py-1">
      {rows.map((row) => (
        <div key={row.label} className="flex items-center justify-between gap-3">
          <div className="flex min-w-0 items-center gap-2">
            <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: row.color }} />
            <span className="text-sm text-[var(--color-text-secondary)]">{row.label}</span>
          </div>
          <span className="shrink-0 text-sm font-bold tabular-nums text-[var(--color-text-primary)]">
            {row.value.toLocaleString()}
          </span>
        </div>
      ))}
    </div>
  )
}

function MediaEvaluationOverviewDonut({ photos, videos }: { photos: number; videos: number }) {
  const size = 176
  const cx = size / 2
  const cy = size / 2
  const r = 58
  const stroke = 22
  const circ = 2 * Math.PI * r
  const total = photos + videos
  const segments =
    total > 0
      ? [
          { value: photos, color: MEDIA_EVAL_PHOTO_COLOR },
          { value: videos, color: MEDIA_EVAL_VIDEO_COLOR },
        ]
      : []

  let offset = 0
  const pctLabels: { x: number; y: number; text: string }[] = []

  for (const seg of segments) {
    if (seg.value <= 0 || total <= 0) continue
    const len = (seg.value / total) * circ
    const startAngle = (offset / circ) * 360 - 90
    const sweep = (len / circ) * 360
    const midRad = ((startAngle + sweep / 2) * Math.PI) / 180
    const labelR = r + stroke / 2 + 14
    pctLabels.push({
      x: cx + labelR * Math.cos(midRad),
      y: cy + labelR * Math.sin(midRad) + 4,
      text: `${Math.round((seg.value / total) * 100)}%`,
    })
    offset += len
  }

  offset = 0

  return (
    <div className="relative mx-auto shrink-0 sm:mx-0">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden>
        <circle cx={cx} cy={cy} r={r} fill="none" stroke="#f1f5f9" strokeWidth={stroke} />
        {segments.map((seg, idx) => {
          if (seg.value <= 0 || total <= 0) return null
          const len = (seg.value / total) * circ
          const el = (
            <circle
              key={idx}
              cx={cx}
              cy={cy}
              r={r}
              fill="none"
              stroke={seg.color}
              strokeWidth={stroke}
              strokeLinecap="round"
              strokeDasharray={`${len} ${circ - len}`}
              strokeDashoffset={-offset}
              transform={`rotate(-90 ${cx} ${cy})`}
            />
          )
          offset += len
          return el
        })}
        {pctLabels.map((lbl, i) => (
          <text
            key={i}
            x={lbl.x}
            y={lbl.y}
            textAnchor="middle"
            fill="#64748b"
            fontSize="11"
            fontWeight="600"
          >
            {lbl.text}
          </text>
        ))}
      </svg>
      <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center text-center">
        <div className="text-2xl font-extrabold leading-none tabular-nums text-[var(--color-text-primary)]">
          {total.toLocaleString()}
        </div>
        <div className="mt-1 text-xs font-medium text-[var(--color-text-secondary)]">Evaluations</div>
      </div>
    </div>
  )
}

export function DonutChart({
  segments,
  total,
  compact = false,
}: {
  segments: { value: number; color: string; label: string; pct?: number }[]
  total: number
  compact?: boolean
}) {
  const size = compact ? 160 : 180
  const cx = size / 2
  const cy = size / 2
  const r = compact ? 58 : 66
  const stroke = compact ? 22 : 26
  const circ = 2 * Math.PI * r
  let offset = 0
  const safeTotal = total > 0 ? total : segments.reduce((s, x) => s + x.value, 0)

  return (
    <div className={`flex items-center gap-5 ${compact ? 'flex-col sm:flex-row' : 'flex-row'}`}>
      <div className="relative shrink-0">
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
          <circle cx={cx} cy={cy} r={r} fill="none" stroke="#f1f5f9" strokeWidth={stroke} />
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
                strokeLinecap="butt"
                transform={`rotate(-90 ${cx} ${cy})`}
              />
            )
            offset += len
            return el
          })}
        </svg>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <div className={`font-extrabold text-[var(--color-text-primary)] ${compact ? 'text-lg' : 'text-xl'}`}>
            {safeTotal.toLocaleString()}
          </div>
          <div className="text-[11px] font-medium text-[var(--color-text-secondary)]">Total</div>
        </div>
      </div>
      <div className="min-w-0 flex-1 space-y-2">
        {segments.map((seg) => {
          const pct = seg.pct ?? (safeTotal > 0 ? (seg.value / safeTotal) * 100 : 0)
          return (
            <div key={seg.label} className="flex items-center gap-2 text-[13px]">
              <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: seg.color }} />
              <span className="min-w-0 flex-1 text-[var(--color-text-secondary)]">{seg.label}</span>
              <span className="shrink-0 font-bold tabular-nums text-[var(--color-text-primary)]">
                {pct.toFixed(1)}%
              </span>
              <span className="shrink-0 text-xs tabular-nums text-[var(--color-text-secondary)]">
                ({seg.value.toLocaleString()})
              </span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

export function TopMembersCard({
  members,
  onViewAll,
}: {
  members: OrgRank[]
  onViewAll?: () => void
}) {
  const max = Math.max(...members.map((o) => o.score), 100)

  return (
    <AdminCard
      padding="sm"
      bodyClassName="flex h-full min-h-0 flex-col"
      className={`h-full ${BOTTOM_ROW_HEIGHT}`}
    >
      <h3 className="text-sm font-extrabold text-[var(--color-text-primary)]">Top Performing Members</h3>
      {members.length === 0 ? (
        <p className="mt-3 text-xs text-[var(--color-text-secondary)]">No member rankings yet.</p>
      ) : (
        <ul className="mt-3 min-h-0 flex-1 space-y-2">
          {members.map((o) => (
            <li key={o.rank} className="flex items-center gap-2">
              <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[var(--color-surface-muted)] text-[10px] font-bold text-[var(--color-text-muted)]">
                {o.rank}
              </span>
              <span className="w-[36%] min-w-0 truncate text-xs font-medium text-[var(--color-text-primary)]">
                {o.name}
              </span>
              <div className="min-w-0 flex-1">
                <div className="h-1.5 overflow-hidden rounded-full bg-[var(--color-surface-muted)]">
                  <div
                    className="h-full rounded-full bg-[var(--color-accent-blue)]"
                    style={{ width: `${Math.min(100, (o.score / max) * 100)}%` }}
                  />
                </div>
              </div>
              <span className="w-9 shrink-0 text-right text-xs font-extrabold tabular-nums text-[var(--color-text-primary)]">
                {o.score}
              </span>
            </li>
          ))}
        </ul>
      )}
      <button
        type="button"
        onClick={onViewAll}
        className="mt-auto flex w-full items-center justify-center gap-1 border-t border-[var(--color-border)] pt-3 text-xs font-semibold text-[var(--color-accent-blue)] hover:underline"
      >
        View All Members
        <ChevronRight size={14} />
      </button>
    </AdminCard>
  )
}

function MediaDonutVisual({ photos, videos, total }: { photos: number; videos: number; total: number }) {
  const segments = [
    { value: photos, color: '#22c55e' },
    { value: videos, color: '#0052d4' },
  ]
  const size = 128
  const cx = size / 2
  const cy = size / 2
  const r = 48
  const stroke = 18
  const circ = 2 * Math.PI * r
  let offset = 0
  const safeTotal = total > 0 ? total : photos + videos

  return (
    <div className="relative shrink-0">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={cx} cy={cy} r={r} fill="none" stroke="#f1f5f9" strokeWidth={stroke} />
        {segments.map((seg, idx) => {
          if (seg.value <= 0 || safeTotal <= 0) return null
          const len = (seg.value / safeTotal) * circ
          const el = (
            <circle
              key={idx}
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
        <div className="text-lg font-extrabold leading-none text-[var(--color-text-primary)]">
          {safeTotal.toLocaleString()}
        </div>
        <div className="mt-1 text-xs font-medium text-[var(--color-text-secondary)]">Total</div>
      </div>
    </div>
  )
}

function MediaDonutLegend({ photos, videos, total }: { photos: number; videos: number; total: number }) {
  const safeTotal = total > 0 ? total : photos + videos
  const rows = [
    { label: 'Photos', value: photos, color: '#22c55e' },
    { label: 'Videos', value: videos, color: '#0052d4' },
  ]

  return (
    <div className="min-w-0 flex-1 space-y-3">
      {rows.map((row) => {
        const pct = safeTotal > 0 ? (row.value / safeTotal) * 100 : 0
        return (
          <div key={row.label} className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <span className="h-2 w-2 shrink-0 rounded-full" style={{ backgroundColor: row.color }} />
              <span className="text-xs text-[var(--color-text-secondary)]">{row.label}</span>
            </div>
            <span className="shrink-0 text-xs tabular-nums text-[var(--color-text-primary)]">
              <span className="font-bold">{pct.toFixed(1)}%</span>{' '}
              <span className="text-[var(--color-text-secondary)]">({row.value.toLocaleString()})</span>
            </span>
          </div>
        )
      })}
    </div>
  )
}

function ActivityIcon({ kind, accentColor }: { kind: ActivityItem['icon']; accentColor?: string }) {
  return <ActivityTypeIcon kind={kind} accentColor={accentColor} />
}

export function RecentActivityCard({
  items,
  onViewAll,
  className,
}: {
  items: ActivityItem[]
  onViewAll?: () => void
  className?: string
}) {
  return (
    <AdminCard
      padding="sm"
      bodyClassName="flex h-full min-h-0 flex-col"
      className={`h-full min-w-0 ${className ?? BOTTOM_ROW_HEIGHT}`}
    >
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-extrabold text-[var(--color-text-primary)]">Recent Activity</h3>
        <button
          type="button"
          onClick={onViewAll}
          className="text-[11px] font-semibold text-[var(--color-accent-blue)] hover:underline"
        >
          View All
        </button>
      </div>
      {items.length === 0 ? (
        <p className="mt-3 text-xs text-[var(--color-text-secondary)]">No recent activity.</p>
      ) : (
        <ul className="mt-2 min-h-0 flex-1 divide-y divide-[var(--color-border)]">
          {items.map((item) => (
            <li key={item.id} className="flex gap-2.5 py-2 first:pt-0 last:pb-0">
              <ActivityIcon kind={item.icon} accentColor={item.accentColor} />
              <div className="min-w-0 flex-1">
                <p className="text-xs leading-snug font-medium text-[var(--color-text-primary)]">{item.title}</p>
                {item.subtitle && (
                  <p className="mt-0.5 text-[11px] text-[var(--color-text-secondary)]">{item.subtitle}</p>
                )}
                <p className="mt-0.5 text-[11px] text-[var(--color-text-secondary)]">{item.timeAgo}</p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </AdminCard>
  )
}

const MEMBER_PARTICIPATED_COLOR = '#0052d4'
const MEMBER_NO_ACTIVITY_COLOR = '#e2e8f0'

function ParticipationDonutChart({
  primary,
  secondary,
  centerValue,
  centerLabel,
  primaryColor,
  secondaryColor,
}: {
  primary: number
  secondary: number
  centerValue: number
  centerLabel: string
  primaryColor: string
  secondaryColor: string
}) {
  const size = 176
  const cx = size / 2
  const cy = size / 2
  const r = 58
  const stroke = 22
  const circ = 2 * Math.PI * r
  const total = primary + secondary
  const segments =
    total > 0
      ? [
          { value: primary, color: primaryColor },
          { value: secondary, color: secondaryColor },
        ]
      : []

  let offset = 0
  const pctLabels: { x: number; y: number; text: string }[] = []

  for (const seg of segments) {
    if (seg.value <= 0 || total <= 0) continue
    const len = (seg.value / total) * circ
    const startAngle = (offset / circ) * 360 - 90
    const sweep = (len / circ) * 360
    const midRad = ((startAngle + sweep / 2) * Math.PI) / 180
    const labelR = r + stroke / 2 + 14
    pctLabels.push({
      x: cx + labelR * Math.cos(midRad),
      y: cy + labelR * Math.sin(midRad) + 4,
      text: `${Math.round((seg.value / total) * 100)}%`,
    })
    offset += len
  }

  offset = 0

  return (
    <div className="relative mx-auto shrink-0 sm:mx-0">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden>
        <circle cx={cx} cy={cy} r={r} fill="none" stroke="#f8fafc" strokeWidth={stroke} />
        {segments.map((seg, idx) => {
          if (seg.value <= 0 || total <= 0) return null
          const len = (seg.value / total) * circ
          const el = (
            <circle
              key={idx}
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
        {pctLabels.map((lbl, i) => (
          <text
            key={i}
            x={lbl.x}
            y={lbl.y}
            textAnchor="middle"
            fill="#64748b"
            fontSize="11"
            fontWeight="600"
          >
            {lbl.text}
          </text>
        ))}
      </svg>
      <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center text-center">
        <div className="text-2xl font-extrabold leading-none tabular-nums text-[var(--color-text-primary)]">
          {centerValue.toLocaleString()}
        </div>
        <div className="mt-1 text-xs font-medium text-[var(--color-text-secondary)]">{centerLabel}</div>
      </div>
    </div>
  )
}

function EventsByCategoryBars({ categories }: { categories: { label: string; count: number }[] }) {
  const max = Math.max(...categories.map((c) => c.count), 1)

  return (
    <div className="flex min-h-0 flex-1 flex-col justify-center gap-3 py-1">
      {categories.map((row) => {
        const widthPct = row.count > 0 ? Math.max(8, (row.count / max) * 100) : 0
        return (
          <div key={row.label} className="grid grid-cols-[minmax(0,7.5rem)_1fr_auto] items-center gap-x-2 gap-y-0 sm:grid-cols-[minmax(0,8.5rem)_1fr_auto] sm:gap-x-3">
            <span className="truncate text-right text-[11px] font-medium leading-tight text-[var(--color-text-secondary)] sm:text-xs">
              {row.label}
            </span>
            <div className="min-w-0 h-2.5 overflow-hidden rounded-full bg-[var(--color-surface-muted)] sm:h-3">
              {row.count > 0 ? (
                <div
                  className="h-full rounded-full bg-[#38bdf8]"
                  style={{ width: `${widthPct}%` }}
                />
              ) : null}
            </div>
            <span className="w-6 shrink-0 text-right text-xs font-bold tabular-nums text-[var(--color-text-primary)] sm:w-7">
              {row.count}
            </span>
          </div>
        )
      })}
    </div>
  )
}

export function EventsByCategoryCard({
  categories,
  className,
}: {
  categories: { label: string; count: number }[]
  className?: string
}) {
  return (
    <AdminCard
      padding="none"
      bodyClassName="flex min-h-0 flex-1 flex-col"
      className={`flex h-full min-w-0 flex-col overflow-hidden ${className ?? CHART_PAIR_HEIGHT}`}
    >
      <div className="px-4 pb-1 pt-3.5 sm:px-5">
        <h3 className="text-sm font-extrabold text-[var(--color-text-primary)] sm:text-base">
          Events by Category
        </h3>
        <p className="mt-0.5 text-[11px] leading-snug text-[var(--color-text-secondary)] sm:text-xs">
          Distribution of completed events.
        </p>
      </div>
      <div className="flex min-h-0 flex-1 px-4 pb-4 pt-2 sm:px-5 sm:pb-5">
        <EventsByCategoryBars categories={categories} />
      </div>
    </AdminCard>
  )
}

export function MemberParticipationCard({
  stats,
  className,
}: {
  stats: { totalMembers: number; participated: number; noParticipation: number }
  className?: string
}) {
  const rows = [
    { label: 'Participated', value: stats.participated, color: MEMBER_PARTICIPATED_COLOR },
    {
      label: 'No recorded participation',
      value: stats.noParticipation,
      color: '#94a3b8',
    },
  ]

  return (
    <AdminCard
      padding="none"
      bodyClassName="flex min-h-0 flex-1 flex-col"
      className={`flex h-full min-w-0 flex-col overflow-hidden ${className ?? CHART_PAIR_HEIGHT}`}
    >
      <div className="px-4 pb-1 pt-3.5 sm:px-5">
        <h3 className="text-sm font-extrabold text-[var(--color-text-primary)] sm:text-base">
          Member Participation
        </h3>
        <p className="mt-0.5 text-[11px] leading-snug text-[var(--color-text-secondary)] sm:text-xs">
          Members with and without recorded documentation activity.
        </p>
      </div>
      <div className="flex min-h-0 flex-1 flex-col items-center justify-center gap-4 px-4 pb-4 sm:flex-row sm:items-center sm:gap-6 sm:px-5">
        <ParticipationDonutChart
          primary={stats.participated}
          secondary={stats.noParticipation}
          centerValue={stats.totalMembers}
          centerLabel="Total Members"
          primaryColor={MEMBER_PARTICIPATED_COLOR}
          secondaryColor={MEMBER_NO_ACTIVITY_COLOR}
        />
        <div className="flex min-w-0 flex-1 flex-col justify-center gap-5 py-1">
          {rows.map((row) => (
            <div key={row.label} className="flex items-center justify-between gap-3">
              <div className="flex min-w-0 items-center gap-2">
                <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: row.color }} />
                <span className="text-sm text-[var(--color-text-secondary)]">{row.label}</span>
              </div>
              <span className="shrink-0 text-sm font-bold tabular-nums text-[var(--color-text-primary)]">
                {row.value.toLocaleString()}
              </span>
            </div>
          ))}
        </div>
      </div>
    </AdminCard>
  )
}

/** Photos vs videos among evaluations in the reporting period (overview pair card). */
export function MediaEvaluationOverviewCard({
  photos,
  videos,
  className,
}: {
  photos: number
  videos: number
  className?: string
}) {
  return (
    <AdminCard
      padding="none"
      bodyClassName="flex min-h-0 flex-1 flex-col"
      className={`flex h-full min-w-0 flex-col overflow-hidden ${className ?? CHART_PAIR_HEIGHT}`}
    >
      <div className="px-4 pb-1 pt-3.5 sm:px-5">
        <h3 className="text-sm font-extrabold text-[var(--color-text-primary)] sm:text-base">
          Media Evaluation Overview
        </h3>
        <p className="mt-0.5 text-[11px] leading-snug text-[var(--color-text-secondary)] sm:text-xs">
          Evaluated photos and videos.
        </p>
      </div>
      <div className="flex min-h-0 flex-1 flex-col items-center justify-center gap-4 px-4 pb-4 sm:flex-row sm:items-center sm:gap-6 sm:px-5">
        <MediaEvaluationOverviewDonut photos={photos} videos={videos} />
        <MediaEvaluationOverviewLegend photos={photos} videos={videos} />
      </div>
    </AdminCard>
  )
}

export function RecentActivityFullPanel({ items }: { items: ActivityItem[] }) {
  return (
    <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
            <tr>
              <th className="px-4 py-3">Activity</th>
              <th className="px-4 py-3">Details</th>
              <th className="px-4 py-3 text-right">When</th>
            </tr>
          </thead>
          <tbody>
            {items.length === 0 ? (
              <tr>
                <td colSpan={3} className="px-4 py-10 text-center text-[var(--color-text-secondary)]">
                  No activity recorded yet.
                </td>
              </tr>
            ) : (
              items.map((item) => (
                <tr
                  key={item.id}
                  className="border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]"
                >
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <ActivityIcon kind={item.icon} accentColor={item.accentColor} />
                      <span className="font-medium text-[var(--color-text-primary)]">{item.title}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-[var(--color-text-secondary)]">{item.subtitle ?? '—'}</td>
                  <td className="whitespace-nowrap px-4 py-3 text-right text-[var(--color-text-secondary)]">
                    {item.timeAgo}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export function MediaDonutCard({ photos, videos, total }: { photos: number; videos: number; total: number }) {
  return (
    <AdminCard
      padding="sm"
      bodyClassName="flex h-full min-h-0 flex-col"
      className={`h-full ${BOTTOM_ROW_HEIGHT}`}
    >
      <h3 className="text-sm font-extrabold text-[var(--color-text-primary)]">Media Type Distribution</h3>
      <div className="mt-2 flex min-h-0 flex-1 flex-col items-center justify-center gap-3 sm:flex-row sm:items-center sm:gap-4">
        <MediaDonutVisual photos={photos} videos={videos} total={total} />
        <MediaDonutLegend photos={photos} videos={videos} total={total} />
      </div>
    </AdminCard>
  )
}
