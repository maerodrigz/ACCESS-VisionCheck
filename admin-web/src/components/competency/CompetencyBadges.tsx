import { Calendar, Pencil } from 'lucide-react'
import type { CompetencyLevel, EventScaleRecommendation } from '../../lib/competency'
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
      style={{ backgroundColor: `${color}18`, borderColor: `${color}55`, color }}
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
}: {
  label: string
  value: number
  max?: number
  suffix?: string
}) {
  const pct = max > 0 ? Math.min(1, Math.max(0, value / max)) : 0
  return (
    <div>
      <div className="flex justify-between text-[11px]">
        <span className="text-[var(--color-text-secondary)]">{label}</span>
        <span className="font-bold">
          {Math.round(value)}
          {suffix}
        </span>
      </div>
      <div className="mt-1.5 h-1.5 overflow-hidden rounded bg-[var(--color-border)]">
        <div className="h-full rounded bg-[var(--color-accent-blue)]" style={{ width: `${pct * 100}%` }} />
      </div>
    </div>
  )
}

export function CriterionRow({ label, met, detail }: { label: string; met: boolean; detail: string }) {
  return (
    <div className="flex items-start gap-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-2.5 text-xs">
      <span className={met ? 'text-[var(--color-success)]' : 'text-[var(--color-text-secondary)]'}>
        {met ? '✓' : '○'}
      </span>
      <div className="min-w-0 flex-1">
        <div className="font-semibold text-[var(--color-text-primary)]">{label}</div>
        <div className="text-[var(--color-text-secondary)]">{detail}</div>
      </div>
    </div>
  )
}
