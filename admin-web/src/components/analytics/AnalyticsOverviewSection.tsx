import { Calendar, ChevronDown } from 'lucide-react'
import {
  REPORTING_PERIOD_OPTIONS,
  type ReportingPeriod,
} from '../../lib/analyticsOverview'

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
