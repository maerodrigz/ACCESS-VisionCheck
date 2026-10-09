import { Calendar, Pencil } from 'lucide-react'
import type { CompetencyLevel, CriterionStatus, EventScaleRecommendation } from '../../lib/competency'
import { competencyLevelLabel, eventRecommendationLabel } from '../../lib/competency'

const levelColors: Record<CompetencyLevel, string> = {
  beginner: 'var(--color-text-secondary)',
  intermediate: 'var(--color-accent-cyan)',
  advanced: 'var(--color-accent-blue)',
}

export function CompetencyLevelBadge({
  level,
  overridden = false,
  compact = false,
}: {
  level: CompetencyLevel
  overridden?: boolean
  compact?: boolean
}) {
  const color = levelColors[level]
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full border font-bold ${compact ? 'px-2 py-0.5 text-[10px]' : 'px-2.5 py-1 text-[11px]'}`}
      style={{
        color,
        backgroundColor: `color-mix(in srgb, ${color} 14%, transparent)`,
        borderColor: `color-mix(in srgb, ${color} 40%, transparent)`,
      }}
      title={overridden ? 'Admin override — kept until cleared or changed' : undefined}
    >
      {competencyLevelLabel(level)}
      {overridden && (
        <>
          <Pencil size={compact ? 10 : 11} aria-hidden />
          {!compact && <span className="font-semibold opacity-80">Override</span>}
        </>
      )}
    </span>
  )
}

export function EventRecommendationBadge({ recommendation }: { recommendation: EventScaleRecommendation }) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-lg border border-[var(--color-accent-blue)]/20 bg-[var(--color-accent-blue)]/10 px-2.5 py-1.5 text-[11px] font-semibold text-[var(--color-accent-blue)]">
      <Calendar size={14} />
      Recommended for: {eventRecommendationLabel(recommendation)}
    </span>
  )
}

export function CompetencyProgressBar({
  label,
  value,
  max = 100,
  suffix = '%',
  emptyLabel,
  hint,
}: {
  label: string
  value?: number | null
  max?: number
  suffix?: string
  emptyLabel?: string
  hint?: string
}) {
  const showValue = value != null && !Number.isNaN(value)
  const pct = showValue && max > 0 ? Math.min(1, Math.max(0, value / max)) : 0
  return (
    <div>
      <div className="flex justify-between gap-2 text-[11px]">
        <span className="text-[var(--color-text-secondary)]">{label}</span>
        <span className="shrink-0 font-bold text-[var(--color-text-primary)]">
          {showValue ? (
            <>
              {Math.round(value)}
              {suffix}
            </>
          ) : (
            (emptyLabel ?? 'N/A')
          )}
        </span>
      </div>
      {showValue ? (
        <div className="mt-1.5 h-1.5 overflow-hidden rounded bg-[var(--color-border)]">
          <div className="h-full rounded bg-[var(--color-accent-blue)]" style={{ width: `${pct * 100}%` }} />
        </div>
      ) : (
        <p className="mt-1 text-[10px] text-[var(--color-text-muted)]">No measured score on record yet.</p>
      )}
      {hint ? <p className="mt-1 text-[10px] leading-snug text-[var(--color-text-muted)]">{hint}</p> : null}
    </div>
  )
}

export function CriterionRow({
  label,
  met,
  detail,
  status,
}: {
  label: string
  met: boolean
  detail: string
  status?: CriterionStatus
}) {
  const state = status ?? (met ? 'met' : 'not_met')
  const icon =
    state === 'met' ? '✓' : state === 'insufficient_data' ? '—' : '○'
  const iconClass =
    state === 'met'
      ? 'text-[var(--color-success)]'
      : state === 'insufficient_data'
        ? 'text-[var(--color-text-muted)]'
        : 'text-[var(--color-text-secondary)]'
  return (
    <div className="flex items-start gap-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-2.5 text-xs">
      <span className={iconClass}>{icon}</span>
      <div className="min-w-0 flex-1">
        <div className="font-semibold text-[var(--color-text-primary)]">{label}</div>
        <div className="text-[var(--color-text-secondary)]">{detail}</div>
      </div>
    </div>
  )
}
