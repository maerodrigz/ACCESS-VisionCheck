import { Bell } from 'lucide-react'
import type { AdminNotification } from '../../lib/notifications'
import { categoryLabel } from '../../lib/notifications'

const adminBadgeWarningClass =
  'rounded-full bg-[var(--color-warning)]/15 px-2 py-0.5 text-[10px] font-bold text-[var(--color-warning-text)]'

const adminOutlineBtnClass =
  'rounded-lg border border-[var(--color-border)] px-3 py-2 text-xs font-semibold text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]'

interface Props {
  items: AdminNotification[]
  onOpen: (item: AdminNotification) => void
}

function PriorityBadge({ priority }: { priority: AdminNotification['priority'] }) {
  if (priority !== 'high') {
    return <span className="text-[var(--color-text-secondary)]">Normal</span>
  }
  return (
    <span className={adminBadgeWarningClass}>HIGH</span>
  )
}

export function NotificationsTable({ items, onOpen }: Props) {
  if (items.length === 0) {
    return (
      <div className="flex flex-col items-center rounded-[var(--card-radius)] border border-dashed border-[var(--color-border)] bg-[var(--color-surface)] py-12 text-center">
        <Bell size={32} className="text-[var(--color-text-secondary)] opacity-40" />
        <p className="mt-3 font-semibold text-[var(--color-text-primary)]">No notifications</p>
        <p className="mt-1 text-sm text-[var(--color-text-secondary)]">Nothing matches your filters.</p>
      </div>
    )
  }

  return (
    <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[880px] text-left text-sm">
          <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
            <tr>
              <th className="px-4 py-3">Alert</th>
              <th className="px-4 py-3">Category</th>
              <th className="px-4 py-3">Priority</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">When</th>
              <th className="px-4 py-3 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {items.map((n) => (
              <tr
                key={n.id}
                className={[
                  'border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]',
                  n.unread ? 'bg-[var(--color-accent-blue)]/[0.04]' : '',
                ].join(' ')}
              >
                <td className="max-w-[360px] px-4 py-3.5">
                  <div className="flex items-start gap-2">
                    {n.unread ? (
                      <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-[var(--color-danger)]" aria-hidden />
                    ) : (
                      <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-transparent" aria-hidden />
                    )}
                    <div className="min-w-0">
                      <p
                        className={[
                          'truncate text-[var(--color-text-primary)]',
                          n.unread ? 'font-bold' : 'font-semibold',
                        ].join(' ')}
                      >
                        {n.title}
                      </p>
                      <p className="mt-0.5 line-clamp-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                        {n.message || '—'}
                      </p>
                    </div>
                  </div>
                </td>
                <td className="whitespace-nowrap px-4 py-3.5 text-[var(--color-text-secondary)]">
                  {categoryLabel(n.category)}
                </td>
                <td className="px-4 py-3.5">
                  <PriorityBadge priority={n.priority} />
                </td>
                <td className="whitespace-nowrap px-4 py-3.5">
                  {n.unread ? (
                    <span className="rounded-full bg-[var(--color-accent-blue)]/15 px-2 py-0.5 text-[10px] font-bold text-[var(--color-accent-blue)]">
                      Unread
                    </span>
                  ) : (
                    <span className="text-[var(--color-text-secondary)]">Read</span>
                  )}
                </td>
                <td className="whitespace-nowrap px-4 py-3.5 text-[var(--color-text-secondary)]">{n.timeAgo}</td>
                <td className="px-4 py-3.5 text-right">
                  <button
                    type="button"
                    onClick={() => onOpen(n)}
                    className={adminOutlineBtnClass}
                  >
                    Open
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
