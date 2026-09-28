import { useEffect, useState } from 'react'
import { fetchMemberRatings } from '../../api/admin'
import {
  formatRatingDate,
  formatTaskRole,
  parseMemberRatingRow,
  StarRow,
  type MemberRequesterRatingRow,
} from './memberRequesterRatingsShared'

interface Props {
  memberId: number
  limit?: number
}

export function MemberRequesterRatingsHistory({ memberId, limit = 5 }: Props) {
  const [rows, setRows] = useState<MemberRequesterRatingRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    void fetchMemberRatings({ memberId })
      .then((data) => {
        if (cancelled) return
        setRows(data.slice(0, limit).map(parseMemberRatingRow))
      })
      .catch(() => {
        if (!cancelled) setRows([])
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [limit, memberId])

  if (loading) {
    return <p className="text-xs text-[var(--color-text-muted)]">Loading rating history…</p>
  }

  if (rows.length === 0) {
    return (
      <p className="text-xs text-[var(--color-text-secondary)]">
        No event ratings yet. Ratings appear when requestors submit feedback after events.
      </p>
    )
  }

  return (
    <div className="space-y-2">
      {rows.map((row) => {
        const dateLabel = formatRatingDate(row.createdAt)
        return (
          <div
            key={row.id}
            className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2.5"
          >
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <div className="truncate text-xs font-semibold text-[var(--color-text-primary)]">
                  {row.eventTitle?.trim() || `Event #${row.requestId}`}
                </div>
                <div className="mt-0.5 text-[10px] text-[var(--color-text-muted)]">
                  {[formatTaskRole(row.taskRole), row.requestorName, dateLabel].filter(Boolean).join(' · ')}
                </div>
              </div>
              <StarRow rating={row.rating} size={12} />
            </div>
            {row.comment?.trim() ? (
              <p className="mt-1.5 text-[11px] leading-relaxed text-[var(--color-text-secondary)]">
                {row.comment.trim()}
              </p>
            ) : null}
          </div>
        )
      })}
    </div>
  )
}
