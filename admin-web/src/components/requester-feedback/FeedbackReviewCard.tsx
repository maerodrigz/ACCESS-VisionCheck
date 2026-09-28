import { AdminCard } from '../AdminCard'
import type { RequesterFeedbackItem } from '../../lib/requesterFeedback'
import { commentPreview, formatFeedbackDate, organizationInitials } from '../../lib/requesterFeedback'
import { FeedbackStatusBadge, LowRatingAlertBanner, StarRatingDisplay } from './FeedbackBadges'

interface Props {
  item: RequesterFeedbackItem
  onViewDetails: (item: RequesterFeedbackItem) => void
  onRespond: (item: RequesterFeedbackItem) => void
  onArchive: (item: RequesterFeedbackItem) => void
}

export function FeedbackReviewCard({ item, onViewDetails, onRespond, onArchive }: Props) {
  const isPending = item.reviewStatus === 'pending'

  return (
    <AdminCard
      as="article"
      hover
      padding="md"
      className={['flex h-full flex-col', isPending ? 'border-amber-200/80' : ''].join(' ')}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-start gap-3">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[var(--color-accent-blue)]/15 text-sm font-extrabold text-[var(--color-accent-blue)]">
          {organizationInitials(item.organization)}
        </div>
        <div className="min-w-0">
          <h3 className="font-extrabold text-[var(--color-text-primary)]">{item.eventName}</h3>
          <p className="text-xs text-[var(--color-text-secondary)]">{item.organization}</p>
          <p className="text-[11px] text-[var(--color-text-secondary)]">
            Event · {formatFeedbackDate(item.eventDate)}
          </p>
        </div>
        </div>
        <FeedbackStatusBadge status={item.reviewStatus} />
      </div>

      <div className="mt-3">
        <StarRatingDisplay rating={item.rating} size={20} showValue />
      </div>

      {item.needsAttention && item.attentionReason && (
        <div className="mt-2.5">
          <LowRatingAlertBanner reason={item.attentionReason} />
        </div>
      )}

      <p className="mt-3 line-clamp-3 text-xs leading-relaxed text-[var(--color-text-primary)]">
        {commentPreview(item.comment)}
      </p>
      <p className="mt-2 text-[11px] text-[var(--color-text-secondary)]">
        Submitted {formatFeedbackDate(item.submittedAt)}
      </p>

      <div className="mt-auto flex flex-wrap gap-2 pt-4">
        <button
          type="button"
          onClick={() => onViewDetails(item)}
          className="rounded-lg border border-[var(--color-border)] px-3 py-2 text-xs font-semibold hover:bg-[var(--color-surface-hover)]"
        >
          View Details
        </button>
        <button
          type="button"
          onClick={() => onRespond(item)}
          className={[
            'rounded-lg px-3 py-2 text-xs font-semibold hover:opacity-95',
            isPending
              ? 'bg-[var(--color-accent-blue)] text-white'
              : 'border border-[var(--color-border)] bg-[var(--color-surface-elevated)] text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]',
          ].join(' ')}
        >
          Respond
        </button>
        <button
          type="button"
          onClick={() => onArchive(item)}
          className="rounded-lg border border-[var(--color-border)] px-3 py-2 text-xs font-semibold hover:bg-[var(--color-surface-hover)]"
        >
          Archive
        </button>
      </div>
    </AdminCard>
  )
}
