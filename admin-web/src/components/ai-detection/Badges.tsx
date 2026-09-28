import type { AiResultLabel, ConfidenceLevel, ReviewStatus } from '../../api/media'
import { aiResultLabelText, reviewStatusLabel } from '../../lib/aiDetection'

const aiColors: Record<AiResultLabel, string> = {
  human: 'var(--color-success)',
  ai_generated: 'var(--color-warning)',
  suspicious: 'var(--color-warning)',
  pending: 'var(--color-text-secondary)',
}

const reviewColors: Record<ReviewStatus, string> = {
  pending_review: 'var(--color-text-secondary)',
  verified_human: 'var(--color-success)',
  confirmed_ai_generated: 'var(--color-warning)',
  needs_further_review: 'var(--color-warning)',
  accepted_with_warning: 'var(--color-warning)',
  reupload_requested: 'var(--color-accent-blue)',
  rejected: 'var(--color-danger)',
  automated_low_ai_risk: 'var(--color-success)',
}

export function AiResultBadge({ label }: { label: AiResultLabel }) {
  const color = aiColors[label]
  return (
    <span
      className="inline-flex rounded-full px-2.5 py-0.5 text-[10px] font-extrabold uppercase tracking-wide"
      style={{ backgroundColor: `${color}18`, color }}
    >
      {aiResultLabelText(label)}
    </span>
  )
}

export function ReviewStatusBadge({ status }: { status: ReviewStatus }) {
  const color = reviewColors[status]
  return (
    <span
      className="inline-flex rounded-full px-2.5 py-0.5 text-[10px] font-bold"
      style={{ backgroundColor: `${color}14`, color }}
    >
      {reviewStatusLabel(status)}
    </span>
  )
}

export function ConfidenceBar({
  score,
  label,
  level,
}: {
  score: number
  label: string
  level: ConfidenceLevel
}) {
  const pct = Math.round(score * 100)
  const barColor =
    level === 'high' ? 'var(--color-success)' : level === 'medium' ? 'var(--color-warning)' : 'var(--color-danger)'

  return (
    <div>
      <div className="mb-1 flex justify-between text-[11px] text-[var(--color-text-secondary)]">
        <span>{label}</span>
        <span className="font-bold">{pct}%</span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-[var(--color-surface-muted)]">
        <div className="h-full rounded-full transition-all" style={{ width: `${pct}%`, backgroundColor: barColor }} />
      </div>
    </div>
  )
}
