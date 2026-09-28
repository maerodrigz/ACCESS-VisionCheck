import type { DocumentationRequestItem, RequestDisplayStatus } from '../../lib/documentationRequests'
import { requestRefLabel } from '../../lib/documentationRequests'
import { MemberAvatarStack, PriorityBadge, StatusBadge } from './RequestBadges'

function actionLabel(status: RequestDisplayStatus): string {
  switch (status) {
    case 'pending':
      return 'Review'
    case 'approved':
      return 'View & assign'
    case 'rejected':
      return 'View details'
    default:
      return 'View details'
  }
}

interface Props {
  items: DocumentationRequestItem[]
  onReview: (item: DocumentationRequestItem) => void
}

export function DocumentationRequestsTable({ items, onReview }: Props) {
  return (
    <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
      <table className="w-full table-fixed text-left text-sm">
        <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
          <tr>
            <th className="w-[40%] px-3 py-2.5 md:px-4 md:py-3">Event & request</th>
            <th className="w-[18%] px-3 py-2.5 md:px-4 md:py-3">Schedule</th>
            <th className="w-[18%] px-3 py-2.5 md:px-4 md:py-3">Status</th>
            <th className="w-[24%] px-3 py-2.5 text-right md:px-4 md:py-3">Actions</th>
          </tr>
        </thead>
        <tbody>
          {items.length === 0 ? (
            <tr>
              <td colSpan={4} className="px-4 py-10 text-center text-[var(--color-text-secondary)]">
                No documentation requests match your filters.
              </td>
            </tr>
          ) : (
            items.map((item) => (
              <tr
                key={item.id}
                role="button"
                tabIndex={0}
                onClick={() => onReview(item)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault()
                    onReview(item)
                  }
                }}
                className="cursor-pointer border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]"
              >
                <td className="px-3 py-3 md:px-4 md:py-3.5">
                  <p className="truncate font-bold text-[var(--color-text-primary)]">{item.eventTitle}</p>
                  <p className="mt-0.5 text-[11px] font-semibold text-[var(--color-text-secondary)]">
                    {requestRefLabel(item.id)} · {item.requestor}
                  </p>
                  {item.venue ? (
                    <p className="mt-0.5 truncate text-[10px] text-[var(--color-text-muted)]">{item.venue}</p>
                  ) : null}
                  {item.details ? (
                    <p className="mt-1 line-clamp-2 text-[10px] leading-snug text-[var(--color-text-muted)]">
                      {item.details}
                    </p>
                  ) : null}
                </td>
                <td className="px-3 py-3 md:px-4 md:py-3.5">
                  <p className="text-xs font-semibold text-[var(--color-text-primary)]">{item.eventDateLabel}</p>
                  <p className="mt-0.5 text-[10px] text-[var(--color-text-muted)]">Submitted {item.createdAtLabel}</p>
                  <div className="mt-1.5">
                    <PriorityBadge priority={item.priority} />
                  </div>
                </td>
                <td className="px-3 py-3 md:px-4 md:py-3.5">
                  <StatusBadge status={item.displayStatus} />
                  <div className="mt-2">
                    <MemberAvatarStack members={item.assignedMembers} maxVisible={3} />
                  </div>
                </td>
                <td className="px-3 py-3 md:px-4 md:py-3.5">
                  <div className="flex flex-wrap justify-end gap-1">
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation()
                        onReview(item)
                      }}
                      className={[
                        'rounded-lg px-2.5 py-1.5 text-[11px] font-semibold',
                        item.displayStatus === 'completed'
                          ? 'border border-[var(--color-border)] text-[var(--color-text-primary)] hover:bg-[var(--color-surface-muted)]'
                          : 'bg-[var(--color-accent-blue)] text-white hover:opacity-95',
                      ].join(' ')}
                    >
                      {actionLabel(item.displayStatus)}
                    </button>
                  </div>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  )
}
