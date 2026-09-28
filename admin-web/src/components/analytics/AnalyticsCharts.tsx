import type { ReactNode } from 'react'
import {
  ChevronRight,
  TrendingDown,
  TrendingUp,
} from 'lucide-react'
import { AdminCard } from '../AdminCard'
import { AdminSelect } from '../AdminSelect'
import { ActivityTypeIcon } from '../ActivityTypeIcon'
import type { ActivityItem, OrgRank, QualityBucket, TimeSeriesPoint } from '../../lib/analyticsOverview'

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

export function EvaluationsAreaChart({ points }: { points: TimeSeriesPoint[] }) {
  const width = 720
  const height = 300
  const pad = { top: 24, right: 20, bottom: 44, left: 52 }
  const innerW = width - pad.left - pad.right
  const innerH = height - pad.top - pad.bottom
  const safePoints =
    points.length > 0 ? points : [{ label: '—', value: 0, date: new Date() }]

  const dataMax = Math.max(...safePoints.map((p) => p.value), 1)
  const niceMax = dataMax <= 800 ? 800 : Math.ceil(dataMax / 200) * 200
  const yStep = niceMax / 4
  const yTicks = [0, 1, 2, 3, 4].map((i) => ({
    val: Math.round(yStep * i),
    y: pad.top + innerH * (1 - i / 4),
  }))

  const coords = safePoints.map((p, i) => {
    const x =
      pad.left + (safePoints.length <= 1 ? innerW / 2 : (i / (safePoints.length - 1)) * innerW)
    const y = pad.top + innerH - (p.value / niceMax) * innerH
    return { x, y, ...p }
  })

  const linePath = coords
    .map((c, i) => `${i === 0 ? 'M' : 'L'} ${c.x} ${c.y}`)
    .join(' ')
  const areaPath = `${linePath} L ${coords[coords.length - 1]?.x ?? pad.left} ${pad.top + innerH} L ${coords[0]?.x ?? pad.left} ${pad.top + innerH} Z`

  const xLabelEvery = Math.max(1, Math.floor(coords.length / 5))

  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="h-full w-full" preserveAspectRatio="xMidYMid meet">
      {yTicks.map(({ val, y }) => (
        <g key={val}>
          <line x1={pad.left} y1={y} x2={width - pad.right} y2={y} stroke="#e8edf2" strokeWidth="1" />
          <text
            x={pad.left - 12}
            y={y + 5}
            textAnchor="end"
            fill="#64748b"
            fontSize="14"
            fontWeight="500"
          >
            {val}
          </text>
        </g>
      ))}
      <path d={areaPath} fill="url(#evalAreaGrad)" />
      <path
        d={linePath}
        fill="none"
        stroke="#0052d4"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      {coords.map((c) => (
        <circle key={`${c.label}-${c.x}`} cx={c.x} cy={c.y} r="4.5" fill="#0052d4" stroke="#fff" strokeWidth="2" />
      ))}
      {coords.map((c, i) =>
        i % xLabelEvery === 0 || i === coords.length - 1 ? (
          <text
            key={`${c.label}-x`}
            x={c.x}
            y={height - 12}
            textAnchor="middle"
            fill="#64748b"
            fontSize="14"
            fontWeight="500"
          >
            {c.label}
          </text>
        ) : null,
      )}
      <defs>
        <linearGradient id="evalAreaGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#0052d4" stopOpacity="0.28" />
          <stop offset="100%" stopColor="#0052d4" stopOpacity="0.03" />
        </linearGradient>
      </defs>
    </svg>
  )
}

function ChartDropdown({
  value,
  onChange,
  options,
}: {
  value: string
  onChange: (v: string) => void
  options: { value: string; label: string }[]
}) {
  return (
    <AdminSelect
      value={value}
      onChange={onChange}
      aria-label="Chart granularity"
      buttonClassName="rounded-lg py-1.5 pl-3 pr-2 text-xs font-semibold"
      options={options}
    />
  )
}

export function EvaluationsOverTimeCard({
  points,
  seriesMode,
  onSeriesModeChange,
}: {
  points: TimeSeriesPoint[]
  seriesMode: 'daily' | 'weekly'
  onSeriesModeChange: (mode: 'daily' | 'weekly') => void
}) {
  return (
    <AdminCard
      padding="md"
      bodyClassName="flex h-full min-h-0 flex-col"
      className={`h-full ${CHART_PAIR_HEIGHT}`}
    >
      <div className="mb-1 flex items-center justify-between gap-3">
        <h3 className="text-base font-extrabold text-[var(--color-text-primary)]">Evaluations Over Time</h3>
        <ChartDropdown
          value={seriesMode}
          onChange={(v) => onSeriesModeChange(v as 'daily' | 'weekly')}
          options={[
            { value: 'daily', label: 'Daily' },
            { value: 'weekly', label: 'Weekly' },
          ]}
        />
      </div>
      <div className="min-h-0 flex-1 w-full pt-2">
        <EvaluationsAreaChart points={points} />
      </div>
    </AdminCard>
  )
}

function QualityDonutLegend({
  segments,
  total,
}: {
  segments: { value: number; color: string; label: string }[]
  total: number
}) {
  const safeTotal = total > 0 ? total : segments.reduce((s, x) => s + x.value, 0)

  return (
    <div className="min-w-0 flex-1">
      {segments.map((seg, i) => {
        const pct = safeTotal > 0 ? (seg.value / safeTotal) * 100 : 0
        return (
          <div
            key={seg.label}
            className={[
              'flex items-center justify-between gap-3 py-3',
              i < segments.length - 1 ? 'border-b border-[#eef2f6]' : '',
            ].join(' ')}
          >
            <div className="flex min-w-0 items-center gap-2.5">
              <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: seg.color }} />
              <span className="truncate text-sm text-[var(--color-text-secondary)]">{seg.label}</span>
            </div>
            <span className="shrink-0 text-sm tabular-nums text-[var(--color-text-primary)]">
              <span className="font-bold">{pct.toFixed(1)}%</span>{' '}
              <span className="text-[var(--color-text-secondary)]">({seg.value.toLocaleString()})</span>
            </span>
          </div>
        )
      })}
    </div>
  )
}

function QualityDonutVisual({ segments, total }: { segments: { value: number; color: string }[]; total: number }) {
  const size = 168
  const cx = size / 2
  const cy = size / 2
  const r = 62
  const stroke = 24
  const circ = 2 * Math.PI * r
  let offset = 0
  const safeTotal = total > 0 ? total : segments.reduce((s, x) => s + x.value, 0)

  return (
    <div className="relative mx-auto shrink-0 lg:mx-0">
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
        <div className="text-[22px] font-extrabold leading-none text-[var(--color-text-primary)]">
          {safeTotal.toLocaleString()}
        </div>
        <div className="mt-1 text-xs font-medium text-[var(--color-text-secondary)]">Total</div>
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
}: {
  items: ActivityItem[]
  onViewAll?: () => void
}) {
  return (
    <AdminCard
      padding="sm"
      bodyClassName="flex h-full min-h-0 flex-col"
      className={`h-full ${BOTTOM_ROW_HEIGHT}`}
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

export function QualityDonutCard({ buckets, total }: { buckets: QualityBucket[]; total: number }) {
  const segments = buckets.map((b) => ({ value: b.count, color: b.color, label: b.label }))

  return (
    <AdminCard
      padding="md"
      bodyClassName="flex h-full min-h-0 flex-col"
      className={`h-full ${CHART_PAIR_HEIGHT}`}
    >
      <h3 className="text-base font-extrabold text-[var(--color-text-primary)]">Evaluations by Quality Level</h3>
      <div className="mt-4 flex min-h-0 flex-1 flex-col items-center justify-center gap-4 sm:flex-row sm:items-center sm:gap-5">
        <QualityDonutVisual segments={segments} total={total} />
        <QualityDonutLegend segments={segments} total={total} />
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
