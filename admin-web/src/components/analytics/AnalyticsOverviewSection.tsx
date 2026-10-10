import { useMemo } from 'react'
import type { LucideIcon } from 'lucide-react'
import { Calendar, CalendarCheck, ChevronDown, ClipboardList, ImageIcon, Users } from 'lucide-react'
import type { AnalyticsSnapshot } from '../../lib/analytics'
import {
  buildOverviewSectionMetricsBundle,
  REPORTING_PERIOD_OPTIONS,
  type DateRange,
  type OverviewMetricTrend,
  type ReportingPeriod,
} from '../../lib/analyticsOverview'
type CardState = 'ready' | 'loading' | 'unavailable'

const CARD_THEMES = {
  requests: {
    color: 'var(--color-accent-blue)',
    bgColor: 'color-mix(in srgb, var(--color-accent-blue) 6%, var(--color-surface))',
  },
  events: {
    color: 'var(--color-success)',
    bgColor: 'color-mix(in srgb, var(--color-success) 6%, var(--color-surface))',
  },
  evaluations: {
    color: 'var(--color-accent-purple)',
    bgColor: 'color-mix(in srgb, var(--color-accent-purple) 8%, var(--color-surface))',
  },
  documenters: {
    color: '#ea580c',
    bgColor: 'color-mix(in srgb, #ea580c 7%, var(--color-surface))',
  },
} as const

function metricDisplay(value: number | null, state: CardState): string {
  if (state === 'unavailable') return 'N/A'
  return String(value ?? 0)
}

function TrendLine({ trend, state }: { trend: OverviewMetricTrend | null; state: CardState }) {
  if (state !== 'ready' || !trend || trend.growthPct === null) return null
  const up = trend.growthPct >= 0
  const color = up ? '#16a34a' : '#dc2626'
  const arrow = up ? '↑' : '↓'
  const pct = Math.abs(trend.growthPct)
  const formatted = Number.isInteger(pct) ? String(pct) : pct.toFixed(1)
  return (
    <p className="mt-0.5 text-[10px] font-semibold leading-tight" style={{ color }}>
      {arrow} {formatted}% {trend.comparisonLabel}
    </p>
  )
}

export function ReportingPeriodSelect({
  period,
  onPeriodChange,
  disabled,
}: {
  period: ReportingPeriod
  onPeriodChange: (period: ReportingPeriod) => void
  disabled?: boolean
}) {
  const label = REPORTING_PERIOD_OPTIONS.find((o) => o.id === period)?.label ?? 'This Month'
  return (
    <div className="relative inline-flex min-w-[9.5rem] max-w-full items-center">
      <Calendar
        size={16}
        strokeWidth={2}
        className="pointer-events-none absolute left-3 top-1/2 z-[1] -translate-y-1/2 text-[var(--color-text-secondary)]"
        aria-hidden
      />
      <select
        value={period}
        disabled={disabled}
        onChange={(e) => onPeriodChange(e.target.value as ReportingPeriod)}
        aria-label="Reporting period"
        className="h-9 w-full cursor-pointer appearance-none rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] py-0 pl-9 pr-8 text-xs font-bold text-[var(--color-text-primary)] shadow-[0_1px_2px_rgba(15,39,68,0.04)] outline-none transition hover:bg-[var(--color-surface-hover)] focus:border-[var(--color-accent-blue)] disabled:cursor-not-allowed disabled:opacity-60"
      >
        {REPORTING_PERIOD_OPTIONS.map((opt) => (
          <option key={opt.id} value={opt.id}>
            {opt.label}
          </option>
        ))}
      </select>
      <ChevronDown
        size={16}
        strokeWidth={2}
        className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-[var(--color-text-secondary)]"
        aria-hidden
      />
      <span className="sr-only">{label}</span>
    </div>
  )
}

function PerformanceKpiCard({
  icon: Icon,
  label,
  value,
  trend,
  theme,
  state,
}: {
  icon: LucideIcon
  label: string
  value: string
  trend: OverviewMetricTrend | null
  theme: (typeof CARD_THEMES)[keyof typeof CARD_THEMES]
  state: CardState
}) {
  return (
    <div
      className="flex min-h-[4.75rem] items-center gap-2.5 rounded-xl border border-[var(--color-border)] px-3 py-2 shadow-[0_1px_2px_rgba(15,39,68,0.04)] transition-shadow duration-150 hover:shadow-[var(--color-card-hover-shadow)]"
      style={{ backgroundColor: theme.bgColor }}
    >
      <div
        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg"
        style={{
          backgroundColor: `color-mix(in srgb, ${theme.color} 18%, white)`,
          color: theme.color,
        }}
      >
        <Icon size={16} strokeWidth={2.25} />
      </div>
      <div className="min-w-0 flex-1 leading-tight">
        <p className="truncate text-[11px] font-semibold text-[var(--color-text-primary)] sm:text-xs">{label}</p>
        <p className="mt-0.5 text-lg font-extrabold tabular-nums leading-none text-[var(--color-text-primary)]">
          {value}
        </p>
        <TrendLine trend={trend} state={state} />
      </div>
    </div>
  )
}

function OverviewCardSkeleton({ bgColor }: { bgColor: string }) {
  return (
    <div
      className="flex min-h-[4.75rem] animate-pulse items-center gap-2.5 rounded-xl border border-[var(--color-border)] px-3 py-2.5"
      style={{ backgroundColor: bgColor }}
      aria-hidden
    >
      <div className="h-9 w-9 shrink-0 rounded-lg bg-[var(--color-surface-muted)]" />
      <div className="min-w-0 flex-1 space-y-1.5">
        <div className="h-2.5 w-24 rounded bg-[var(--color-surface-muted)]" />
        <div className="h-6 w-10 rounded bg-[var(--color-surface-muted)]" />
        <div className="h-2 w-20 rounded bg-[var(--color-surface-muted)]" />
      </div>
    </div>
  )
}

export function AnalyticsOverviewSection({
  data,
  range,
  period,
  loading,
  unavailable,
}: {
  data: AnalyticsSnapshot | null
  range: DateRange
  period: ReportingPeriod
  loading: boolean
  unavailable: boolean
}) {
  const bundle = useMemo(
    () => (data ? buildOverviewSectionMetricsBundle(data, range, period) : null),
    [data, range, period],
  )

  const cardState: CardState =
    unavailable ? 'unavailable' : loading && !bundle ? 'loading' : 'ready'

  const cards: {
    key: keyof typeof CARD_THEMES
    icon: LucideIcon
    label: string
    value: number | null
    trend: OverviewMetricTrend | null
  }[] = [
    {
      key: 'requests',
      icon: ClipboardList,
      label: 'Documentation Requests',
      value: bundle?.current.documentationRequests ?? null,
      trend: bundle?.trends.documentationRequests ?? null,
    },
    {
      key: 'events',
      icon: CalendarCheck,
      label: 'Completed Events',
      value: bundle?.current.completedEvents ?? null,
      trend: bundle?.trends.completedEvents ?? null,
    },
    {
      key: 'evaluations',
      icon: ImageIcon,
      label: 'Media Evaluations',
      value: bundle?.current.mediaEvaluations ?? null,
      trend: bundle?.trends.mediaEvaluations ?? null,
    },
    {
      key: 'documenters',
      icon: Users,
      label: 'Active Documenters',
      value: bundle?.current.activeDocumenters ?? null,
      trend: bundle?.trends.activeDocumenters ?? null,
    },
  ]

  return (
    <section aria-label="Performance overview" className="space-y-2">
      <div>
        <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Performance Overview</h2>
        <p className="mt-0.5 text-[11px] text-[var(--color-text-muted)] sm:text-xs">
          Summary metrics for the selected reporting period.
        </p>
      </div>
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-4">
        {cardState === 'loading' && !bundle
          ? cards.map((c) => <OverviewCardSkeleton key={c.label} bgColor={CARD_THEMES[c.key].bgColor} />)
          : cards.map((c) => (
              <PerformanceKpiCard
                key={c.label}
                icon={c.icon}
                label={c.label}
                value={metricDisplay(c.value, cardState)}
                trend={c.trend}
                theme={CARD_THEMES[c.key]}
                state={cardState}
              />
            ))}
      </div>
      {!unavailable && data ? (
        <p className="text-[11px] leading-snug text-[var(--color-text-muted)]">
          Figures are computed from the loaded analytics dataset and filtered by date on this device. List
          endpoints do not accept a period parameter; very large histories may be incomplete if the server
          truncates results.
        </p>
      ) : null}
    </section>
  )
}
