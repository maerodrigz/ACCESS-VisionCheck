import { AlertTriangle } from 'lucide-react'
import { AdminEmptyState } from '../AdminEmptyState'
import type { EvaluationReviewItem } from '../../lib/evaluationReview'
import { formatEvalDate, isEvaluationFlagged, scoreTone } from '../../lib/evaluationReview'

interface Props {
  items: EvaluationReviewItem[]
  onReview: (item: EvaluationReviewItem) => void
}

function AiBadge({ result }: { result: string | null }) {
  if (!result) return <span className="text-xs text-[var(--color-text-muted)]">N/A</span>
  const lower = result.toLowerCase()
  const cls =
    lower === 'human'
      ? 'bg-emerald-500/15 text-emerald-300'
      : lower === 'suspicious'
        ? 'bg-amber-500/15 text-amber-300'
        : lower === 'ai_generated'
          ? 'bg-red-500/15 text-red-300'
          : 'bg-[var(--color-surface-muted)] text-[var(--color-text-secondary)]'
  return (
    <span className={`inline-flex rounded-full px-2 py-0.5 text-[10px] font-bold uppercase ${cls}`}>
      {result.replace(/_/g, ' ')}
    </span>
  )
}

export function EvaluationsTable({ items, onReview }: Props) {
  if (items.length === 0) {
    return (
      <AdminEmptyState title="No evaluations match your filters">
        Member practice uploads and scored media will appear here.
      </AdminEmptyState>
    )
  }

  return (
    <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
      <table className="w-full table-fixed text-left text-sm">
        <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
          <tr>
            <th className="w-[40%] px-3 py-2.5 md:px-4 md:py-3">Member & upload</th>
            <th className="w-[14%] px-3 py-2.5 md:px-4 md:py-3">Score</th>
            <th className="w-[16%] px-3 py-2.5 md:px-4 md:py-3">AI scan</th>
            <th className="w-[30%] px-3 py-2.5 text-right md:px-4 md:py-3">Actions</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => {
            const flagged = isEvaluationFlagged(item)
            return (
              <tr
                key={item.id}
                className={[
                  'border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]',
                  flagged ? 'bg-[var(--color-surface-muted)]' : '',
                ].join(' ')}
              >
                <td className="px-3 py-3 md:px-4 md:py-3.5">
                  <p className="truncate font-semibold text-[var(--color-text-primary)]">{item.memberName}</p>
                  <p className="mt-0.5 truncate text-[11px] text-[var(--color-text-secondary)]">{item.fileName}</p>
                  <p className="mt-0.5 truncate text-[10px] text-[var(--color-text-muted)]">
                    {item.sourceLabel}
                    {item.eventTitle ? ` · ${item.eventTitle}` : ''}
                  </p>
                  <p className="mt-0.5 text-[10px] text-[var(--color-text-muted)]">
                    Evaluated {formatEvalDate(item.evaluatedAt)}
                  </p>
                  {flagged ? (
                    <p className="mt-1 flex items-start gap-1 text-[11px] text-[var(--color-warning-text)]">
                      <AlertTriangle size={12} className="mt-0.5 shrink-0" />
                      <span className="line-clamp-2">AI flagged for review</span>
                    </p>
                  ) : null}
                </td>
                <td className="px-3 py-3 md:px-4 md:py-3.5">
                  <p className={`text-sm font-extrabold ${scoreTone(item.overallScore)}`}>
                    {Math.round(item.overallScore)}%
                  </p>
                  <p className="mt-0.5 truncate text-[10px] font-semibold text-[var(--color-text-secondary)]">
                    {item.qualityLevel ?? 'No tier'}
                  </p>
                </td>
                <td className="px-3 py-3 md:px-4 md:py-3.5">
                  <AiBadge result={item.aiResult} />
                </td>
                <td className="px-3 py-3 md:px-4 md:py-3.5">
                  <div className="flex flex-wrap justify-end gap-1">
                    <button
                      type="button"
                      onClick={() => onReview(item)}
                      className="rounded-lg bg-[var(--color-accent-blue)] px-2.5 py-1.5 text-[11px] font-semibold text-white hover:opacity-95"
                    >
                      Review
                    </button>
                  </div>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
