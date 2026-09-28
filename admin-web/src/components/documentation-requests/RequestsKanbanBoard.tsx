import type { DocumentationRequestItem, RequestDisplayStatus } from '../../lib/documentationRequests'
import { statusLabel } from '../../lib/documentationRequests'
import { DocumentationRequestCard } from './DocumentationRequestCard'

const COLUMNS: RequestDisplayStatus[] = ['pending', 'approved', 'rejected', 'completed']

const columnAccent: Record<RequestDisplayStatus, string> = {
  pending: 'var(--color-warning)',
  approved: 'var(--color-accent-blue)',
  rejected: 'var(--color-danger)',
  completed: 'var(--color-success)',
}

interface Props {
  items: DocumentationRequestItem[]
  onReview: (item: DocumentationRequestItem) => void
}

function KanbanColumn({
  status,
  items,
  onReview,
}: {
  status: RequestDisplayStatus
  items: DocumentationRequestItem[]
  onReview: (item: DocumentationRequestItem) => void
}) {
  const accent = columnAccent[status]

  return (
    <div className="flex min-w-0 flex-1 flex-col rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
      <div className="mb-3 flex items-center gap-2">
        <span className="h-2 w-2 shrink-0 rounded-full" style={{ backgroundColor: accent }} aria-hidden />
        <h2 className="text-[13px] font-bold text-[var(--color-text-primary)]">{statusLabel(status)}</h2>
        <span className="ml-auto rounded-full border border-[var(--color-border)] bg-[var(--color-surface)] px-2 py-0.5 text-[11px] font-bold text-[var(--color-text-secondary)]">
          {items.length}
        </span>
      </div>

      <div className="flex flex-col gap-2.5">
        {items.length === 0 ? (
          <p className="py-8 text-center text-xs text-[var(--color-text-secondary)]">No requests</p>
        ) : (
          items.map((item) => (
            <DocumentationRequestCard key={item.id} item={item} variant="kanban" onReview={onReview} />
          ))
        )}
      </div>
    </div>
  )
}

export function RequestsKanbanBoard({ items, onReview }: Props) {
  return (
    <>
      <div className="hidden gap-3 xl:flex xl:items-start">
        {COLUMNS.map((status) => (
          <KanbanColumn
            key={status}
            status={status}
            items={items.filter((i) => i.displayStatus === status)}
            onReview={onReview}
          />
        ))}
      </div>

      <div className="flex flex-col gap-4 xl:hidden">
        {COLUMNS.map((status) => {
          const columnItems = items.filter((i) => i.displayStatus === status)
          if (columnItems.length === 0) return null
          return (
            <KanbanColumn key={status} status={status} items={columnItems} onReview={onReview} />
          )
        })}
        {items.length === 0 && (
          <p className="py-8 text-center text-sm text-[var(--color-text-secondary)]">No requests in this view.</p>
        )}
      </div>
    </>
  )
}
