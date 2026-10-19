import type { DocumentationRequestItem, RequestDisplayStatus } from '../../lib/documentationRequests'
import { requestRefLabel } from '../../lib/documentationRequests'
import { AssignedMemberList, PriorityBadge, StatusBadge } from './RequestBadges'

function actionLabel(status: RequestDisplayStatus): string {
  switch (status) {
    case 'pending':
      return 'Review'
    case 'approved':
      return 'View & Assign'
    case 'rejected':
      return 'View Details'
    default:
      return 'View Details'
  }
}

interface Props {
  items: DocumentationRequestItem[]
  onReview: (item: DocumentationRequestItem) => void
}

export function DocumentationRequestsTable({ items, onReview }: Props) {
  return (
    <div className="overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-[0_1px_2px_rgba(15,39,68,0.04)]">
      <table className="w-full table-fixed text-left text-sm">
        <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
          <tr>
            <th className="w-[38%] px-3 py-2">Event & request</th>
            <th className="w-[18%] px-3 py-2">Schedule</th>
            <th className="w-[26%] px-3 py-2">Status</th>
            <th className="w-[18%] px-3 py-2 text-right">Actions</th>
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
                className="cursor-pointer border-b border-[var(--color-border-subtle)] align-top transition last:border-0 hover:bg-[var(--color-surface-hover)]"
              >
                <td className="px-3 py-2">
                  <p className="truncate text-[13px] font-bold text-[var(--color-text-primary)]">{item.eventTitle}</p>
                  <p className="mt-0.5 truncate text-[11px] text-[var(--color-text-secondary)]">
                    <span className="font-semibold text-[var(--color-accent-blue)]">{requestRefLabel(item.id)}</span>
                    <span className="text-[var(--color-text-muted)]"> · </span>
                    {item.requestor}
                  </p>
                  {item.venue ? (
                    <p className="mt-0.5 truncate text-[10px] text-[var(--color-text-muted)]">{item.venue}</p>
                  ) : null}
                  {item.details ? (
                    <p className="truncate text-[10px] text-[var(--color-text-muted)]">{item.details}</p>
                  ) : null}
                </td>
                <td className="px-3 py-2">
                  <p className="text-xs font-semibold text-[var(--color-text-primary)]">{item.eventDateLabel}</p>
                  <p className="mt-0.5 text-[10px] text-[var(--color-text-muted)]">Submitted {item.createdAtLabel}</p>
                  <div className="mt-1">
                    <PriorityBadge priority={item.priority} />
                  </div>
                </td>
                <td className="px-3 py-2">
                  <StatusBadge status={item.displayStatus} />
                  <div className="mt-1.5">
                    <AssignedMemberList members={item.assignedMembers} />
                  </div>
                </td>
                <td className="px-3 py-2 text-right">
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation()
                      onReview(item)
                    }}
                    className={[
                      'rounded-lg px-2.5 py-1 text-[11px] font-semibold',
                      item.displayStatus === 'completed' || item.displayStatus === 'archived'
                        ? 'border border-[var(--color-border)] text-[var(--color-text-primary)] hover:bg-[var(--color-surface-muted)]'
                        : 'bg-[var(--color-accent-blue)] text-white hover:opacity-95',
                    ].join(' ')}
                  >
                    {actionLabel(item.displayStatus)}
                  </button>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  )
}
