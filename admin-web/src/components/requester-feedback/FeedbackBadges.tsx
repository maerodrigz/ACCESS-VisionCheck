import { AlertTriangle, Star } from 'lucide-react'
import type { FeedbackReviewStatus } from '../../lib/requesterFeedback'

export function StarRatingDisplay({
  rating,
  size = 18,
  showValue = false,
}: {
  rating: number
  size?: number
  showValue?: boolean
}) {
  return (
    <div className="inline-flex items-center gap-0.5">
      {Array.from({ length: 5 }, (_, i) => (
        <Star
          key={i}
          size={size}
          className={i < rating ? 'fill-amber-400 text-amber-400' : 'text-[var(--color-border)]'}
        />
      ))}
      {showValue && (
        <span className="ml-1.5 text-sm font-bold text-[var(--color-text-primary)]">{rating}/5</span>
      )}
    </div>
  )
}

export function LowRatingAlertBanner({ reason }: { reason: string }) {
  return (
    <div className="rounded-xl border border-red-500/30 bg-red-500/10 p-3.5">
      <div className="flex gap-2.5">
        <AlertTriangle size={18} className="shrink-0 text-red-400" />
        <div>
          <div className="text-xs font-extrabold text-[var(--color-text-primary)]">Needs Administrator Attention</div>
          <div className="mt-1 text-xs leading-relaxed text-[var(--color-text-secondary)]">{reason}</div>
        </div>
      </div>
    </div>
  )
}

const statusStyles: Record<FeedbackReviewStatus, { bg: string; text: string; label: string }> = {
  pending: { bg: 'rgba(245,158,11,0.12)', text: 'var(--color-warning)', label: 'Pending Review' },
  reviewed: { bg: 'rgba(34,197,94,0.12)', text: 'var(--color-success)', label: 'Reviewed' },
  archived: { bg: 'rgba(100,116,139,0.12)', text: 'var(--color-text-secondary)', label: 'Archived' },
}

export function FeedbackStatusBadge({ status }: { status: FeedbackReviewStatus }) {
  const s = statusStyles[status]
  return (
    <span
      className="inline-flex rounded-full border px-2.5 py-0.5 text-[11px] font-bold"
      style={{ backgroundColor: s.bg, color: s.text, borderColor: `${s.text}44` }}
    >
      {s.label}
    </span>
  )
}
