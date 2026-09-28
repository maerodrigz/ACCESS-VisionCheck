import { AlertTriangle } from 'lucide-react'
import type { RequesterFeedbackItem } from '../../lib/requesterFeedback'
import { commentPreview, formatFeedbackDate } from '../../lib/requesterFeedback'
import { FeedbackStatusBadge, StarRatingDisplay } from './FeedbackBadges'

interface Props {
  items: RequesterFeedbackItem[]
  onViewDetails: (item: RequesterFeedbackItem) => void
  onRespond: (item: RequesterFeedbackItem) => void
  onArchive: (item: RequesterFeedbackItem) => void
}

export function FeedbackReviewsTable({ items, onViewDetails, onRespond, onArchive }: Props) {
  return (
    <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
      <table className="w-full table-fixed text-left text-sm">
        <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
          <tr>
            <th className="w-[38%] px-3 py-2.5 md:px-4 md:py-3">Event & requester</th>
            <th className="w-[14%] px-3 py-2.5 md:px-4 md:py-3">Rating</th>
            <th className="w-[18%] px-3 py-2.5 md:px-4 md:py-3">Status</th>
            <th className="w-[30%] px-3 py-2.5 text-right md:px-4 md:py-3">Actions</th>
          </tr>
        </thead>
        <tbody>
          {items.length === 0 ? (
            <tr>
              <td colSpan={4} className="px-4 py-10 text-center text-[var(--color-text-secondary)]">
                No reviews match your filters.
              </td>
            </tr>
          ) : (
            items.map((item) => {
              const isPending = item.reviewStatus === 'pending'
              return (
                <tr
                  key={item.id}
                  className={[
                    'border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]',
                    isPending ? 'bg-[var(--color-surface-muted)]' : '',
                  ].join(' ')}
                >
                  <td className="px-3 py-3 md:px-4 md:py-3.5">
                    <p className="truncate font-semibold text-[var(--color-text-primary)]">{item.eventName}</p>
                    <p className="mt-0.5 truncate text-[11px] text-[var(--color-text-secondary)]">
                      {item.organization} · {item.requesterName}
                    </p>
                    <p className="mt-0.5 truncate text-[10px] text-[var(--color-text-muted)]">
                      Event {formatFeedbackDate(item.eventDate)} · Submitted {formatFeedbackDate(item.submittedAt)}
                    </p>
                    {item.needsAttention && item.attentionReason ? (
                      <p className="mt-1 flex items-start gap-1 text-[11px] text-[var(--color-warning-text)]">
                        <AlertTriangle size={12} className="mt-0.5 shrink-0" />
                        <span className="line-clamp-2">{item.attentionReason}</span>
                      </p>
                    ) : null}
                    <p className="mt-1 line-clamp-2 text-[10px] leading-snug text-[var(--color-text-muted)]">
                      {commentPreview(item.comment)}
                    </p>
                  </td>
                  <td className="px-3 py-3 md:px-4 md:py-3.5">
                    <StarRatingDisplay rating={item.rating} size={14} showValue />
                  </td>
                  <td className="px-3 py-3 md:px-4 md:py-3.5">
                    <FeedbackStatusBadge status={item.reviewStatus} />
                  </td>
                  <td className="px-3 py-3 md:px-4 md:py-3.5">
                    <div className="flex flex-wrap justify-end gap-1">
                      <button
                        type="button"
                        onClick={() => onViewDetails(item)}
                        className="rounded-lg border border-[var(--color-border)] px-2 py-1 text-[11px] font-semibold hover:bg-[var(--color-surface-hover)]"
                      >
                        View
                      </button>
                      <button
                        type="button"
                        onClick={() => onRespond(item)}
                        className={[
                          'rounded-lg px-2 py-1 text-[11px] font-semibold hover:opacity-95',
                          isPending
                            ? 'bg-[var(--color-accent-blue)] text-white'
                            : 'border border-[var(--color-border)] hover:bg-[var(--color-surface-hover)]',
                        ].join(' ')}
                      >
                        Respond
                      </button>
                      <button
                        type="button"
                        onClick={() => onArchive(item)}
                        className="rounded-lg border border-[var(--color-border)] px-2 py-1 text-[11px] font-semibold hover:bg-[var(--color-surface-hover)]"
                      >
                        Archive
                      </button>
                    </div>
                  </td>
                </tr>
              )
            })
          )}
        </tbody>
      </table>
    </div>
  )
}
