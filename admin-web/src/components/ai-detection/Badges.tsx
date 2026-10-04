import type { AiResultLabel, ReviewStatus } from '../../api/media'
import { aiResultLabelText, reviewStatusLabel } from '../../lib/aiDetection'

const aiColors: Record<AiResultLabel, string> = {
  human: 'var(--color-success)',
  ai_generated: 'var(--color-danger)',
  suspicious: 'var(--color-warning)',
  pending: 'var(--color-text-secondary)',
}

const reviewColors: Record<ReviewStatus, string> = {
  pending_review: 'var(--color-text-secondary)',
  verified_human: 'var(--color-success)',
  confirmed_ai_generated: 'var(--color-danger)',
  needs_further_review: 'var(--color-warning)',
  accepted_with_warning: 'var(--color-warning)',
  reupload_requested: 'var(--color-accent-blue)',
  rejected: 'var(--color-danger)',
  automated_low_ai_risk: 'var(--color-success)',
}

const riskLabels: Record<AiResultLabel, string> = {
  human: 'Low Risk',
  suspicious: 'Suspicious',
  ai_generated: 'High Risk',
  pending: 'Pending Scan',
}

function tint(color: string, pct = 14) {
  return `color-mix(in srgb, ${color} ${pct}%, transparent)`
}

export function AiResultBadge({ label }: { label: AiResultLabel }) {
  const color = aiColors[label]
  return (
    <span
      className="inline-flex rounded-full px-2.5 py-0.5 text-[10px] font-extrabold uppercase tracking-wide"
      style={{ backgroundColor: tint(color), color }}
    >
      {aiResultLabelText(label)}
    </span>
  )
}

export function RiskBadge({ label }: { label: AiResultLabel }) {
  const color = aiColors[label]
  return (
    <span
      className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-bold"
      style={{ backgroundColor: tint(color), color }}
    >
      <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: color }} />
      {riskLabels[label]}
    </span>
  )
}

export function AiProbability({
  label,
  probability,
  showLabel = true,
}: {
  label: AiResultLabel
  probability: number
  showLabel?: boolean
}) {
  const color = aiColors[label]
  const value = label === 'pending' ? 'N/A' : `${Math.round(probability * 100)}%`
  return (
    <span className="inline-flex items-center gap-1.5 text-[11px] text-[var(--color-text-secondary)]">
      <span className="h-2 w-2 rounded-full" style={{ backgroundColor: color }} aria-hidden />
      {showLabel ? 'AI Probability:' : null}
      <span className="font-bold text-[var(--color-text-primary)]">{value}</span>
    </span>
  )
}

const compactReviewLabels: Partial<Record<ReviewStatus, string>> = {
  needs_further_review: 'Needs Further Review',
  confirmed_ai_generated: 'Confirmed AI',
  automated_low_ai_risk: 'Auto Cleared',
}

export function ReviewStatusBadge({ status, compact = false }: { status: ReviewStatus; compact?: boolean }) {
  const color = reviewColors[status]
  return (
    <span
      className="inline-flex whitespace-nowrap rounded-full px-2 py-0.5 text-[10px] font-bold"
      style={{ backgroundColor: tint(color, 12), color }}
    >
      {(compact && compactReviewLabels[status]) || reviewStatusLabel(status)}
    </span>
  )
}