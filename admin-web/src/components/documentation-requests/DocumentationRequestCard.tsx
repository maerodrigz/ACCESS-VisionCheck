import { Calendar, ClipboardList, MapPin } from 'lucide-react'
import { AdminCard } from '../AdminCard'
import type { DocumentationRequestItem, RequestDisplayStatus } from '../../lib/documentationRequests'
import { requestRefLabel } from '../../lib/documentationRequests'
import { MemberAvatarStack, PriorityBadge, StatusBadge } from './RequestBadges'

const statusBorderColor: Record<RequestDisplayStatus, string> = {
  pending: 'var(--color-warning)',
  approved: 'var(--color-accent-blue)',
  rejected: 'var(--color-danger)',
  completed: 'var(--color-success)',
}

interface Props {
  item: DocumentationRequestItem
  variant?: 'full' | 'kanban'
  onReview: (item: DocumentationRequestItem) => void
}

function actionLabel(status: RequestDisplayStatus): string {
  switch (status) {
    case 'pending':
      return 'Review'
    case 'approved':
      return 'Assign team'
    case 'rejected':
      return 'View reason'
    default:
      return 'View details'
  }
}

export function DocumentationRequestCard({ item, variant = 'full', onReview }: Props) {
  const borderColor = statusBorderColor[item.displayStatus]
  const refLabel = requestRefLabel(item.id)
  const isKanban = variant === 'kanban'

  const shellClass = [
    'overflow-hidden rounded-lg border border-[var(--color-border-subtle)] bg-[var(--color-surface-muted)]',
    'transition',
    isKanban ? 'cursor-pointer hover:border-[var(--color-accent-blue)]/35 hover:bg-[var(--color-surface-hover)]' : '',
  ]
    .filter(Boolean)
    .join(' ')

  const inner = (
    <div className="flex min-w-0">
      <div className="w-1 shrink-0" style={{ backgroundColor: borderColor }} aria-hidden />
      <div className={isKanban ? 'min-w-0 flex-1 p-3' : 'min-w-0 flex-1 p-5'}>
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-1.5">
              <span className="inline-flex items-center gap-1 rounded-md bg-[var(--color-surface-muted)] px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                <ClipboardList size={11} strokeWidth={2.5} />
                Documentation
              </span>
              <span className="text-[10px] font-bold text-[var(--color-text-secondary)]">{refLabel}</span>
            </div>
            {!isKanban && (
              <p className="mt-1.5 text-[11px] text-[var(--color-text-secondary)]">
                Submitted by <span className="font-semibold text-[var(--color-text-primary)]">{item.requestor}</span>
                {' · '}
                {item.createdAtLabel}
              </p>
            )}
          </div>
          <PriorityBadge priority={item.priority} />
        </div>

        <h3
          className={[
            'font-bold leading-snug text-[var(--color-text-primary)]',
            isKanban ? 'mt-2 line-clamp-2 text-[13px]' : 'mt-3 line-clamp-2 text-[15px]',
          ].join(' ')}
        >
          {item.eventTitle}
        </h3>

        {isKanban ? (
          <p className="mt-1 truncate text-[11px] text-[var(--color-text-secondary)]">{item.requestor}</p>
        ) : null}

        <div className={`space-y-1.5 text-xs text-[var(--color-text-secondary)] ${isKanban ? 'mt-2' : 'mt-3'}`}>
          <div className="flex items-center gap-2">
            <Calendar size={14} />
            <span>Event: {item.eventDateLabel}</span>
          </div>
          {item.venue && (
            <div className="flex items-center gap-2">
              <MapPin size={14} />
              <span className="truncate">{item.venue}</span>
            </div>
          )}
          {isKanban && (
            <p className="text-[10px] text-[var(--color-text-secondary)]">Submitted {item.createdAtLabel}</p>
          )}
        </div>

        <div className={`flex items-center justify-between gap-2 ${isKanban ? 'mt-2.5' : 'mt-3'}`}>
          {!isKanban && <StatusBadge status={item.displayStatus} />}
          <MemberAvatarStack members={item.assignedMembers} maxVisible={isKanban ? 2 : 3} />
        </div>

        {!isKanban && item.details && (
          <p className="mt-3 line-clamp-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">{item.details}</p>
        )}

        {!isKanban && (
          <div className="mt-4 flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => onReview(item)}
              className={[
                'rounded-lg px-3 py-1.5 text-xs font-semibold',
                item.displayStatus === 'completed'
                  ? 'border border-[var(--color-border)] text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]'
                  : 'bg-[var(--color-accent-blue)] text-white hover:opacity-95',
              ].join(' ')}
            >
              {actionLabel(item.displayStatus)}
            </button>
          </div>
        )}
      </div>
    </div>
  )

  if (isKanban) {
    return (
      <article
        className={shellClass}
        role="button"
        tabIndex={0}
        onClick={() => onReview(item)}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            onReview(item)
          }
        }}
      >
        {inner}
      </article>
    )
  }

  return (
    <AdminCard as="article" hover padding="none" className="overflow-hidden">
      {inner}
    </AdminCard>
  )
}
