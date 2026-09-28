import { useEffect, useMemo, useState } from 'react'
import { fetchMemberRatings } from '../../api/admin'
import type { AssignedMember } from '../../lib/documentationRequests'
import {
  formatTaskRole,
  parseMemberRatingRow,
  StarRow,
  type MemberRequesterRatingRow,
} from './memberRequesterRatingsShared'

interface Props {
  requestId: number
  assignedMembers: AssignedMember[]
  visible: boolean
}

export function RequestMemberRatingsSection({ requestId, assignedMembers, visible }: Props) {
  const [rows, setRows] = useState<MemberRequesterRatingRow[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!visible || assignedMembers.length === 0) {
      setRows([])
      setError(null)
      return
    }
    let cancelled = false
    setLoading(true)
    setError(null)
    void fetchMemberRatings({ requestId })
      .then((data) => {
        if (cancelled) return
        setRows(data.map(parseMemberRatingRow))
      })
      .catch((e) => {
        if (cancelled) return
        setRows([])
        setError(e instanceof Error ? e.message : 'Could not load member ratings')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [assignedMembers.length, requestId, visible])

  const merged = useMemo(() => {
    const byMember = new Map(rows.map((r) => [r.memberId, r]))
    return assignedMembers.map((member) => ({
      member,
      rating: byMember.get(member.id) ?? null,
    }))
  }, [assignedMembers, rows])

  if (!visible || assignedMembers.length === 0) return null

  const ratedCount = merged.filter((m) => m.rating != null).length

  return (
    <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <div className="text-xs font-bold text-[var(--color-text-secondary)]">Member ratings</div>
          <p className="mt-1 text-[11px] leading-relaxed text-[var(--color-text-muted)]">
            Per-photographer and per-videographer feedback from the requestor for this event.
          </p>
        </div>
        {!loading && (
          <span className="rounded-full bg-[var(--color-surface-elevated)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
            {ratedCount}/{assignedMembers.length} rated
          </span>
        )}
      </div>

      {loading ? (
        <p className="mt-3 text-xs text-[var(--color-text-muted)]">Loading ratings…</p>
      ) : error ? (
        <p className="mt-3 text-xs text-red-500">{error}</p>
      ) : (
        <div className="mt-3 space-y-2">
          {merged.map(({ member, rating }) => (
            <div
              key={member.id}
              className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2.5"
            >
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="min-w-0">
                  <div className="text-sm font-semibold text-[var(--color-text-primary)]">{member.name}</div>
                  <div className="text-[11px] text-[var(--color-text-secondary)]">
                    {formatTaskRole(rating?.taskRole ?? member.role)}
                  </div>
                </div>
                {rating ? (
                  <div className="text-right">
                    <StarRow rating={rating.rating} />
                    <div className="mt-0.5 text-[10px] font-semibold text-[var(--color-text-secondary)]">
                      {rating.rating}/5
                    </div>
                  </div>
                ) : (
                  <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-muted)]">
                    Not rated yet
                  </span>
                )}
              </div>
              {rating?.comment?.trim() ? (
                <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                  {rating.comment.trim()}
                </p>
              ) : null}
            </div>
          ))}
          {ratedCount === 0 && (
            <p className="text-[11px] text-[var(--color-text-muted)]">
              The requestor has not submitted member ratings for this event yet.
            </p>
          )}
        </div>
      )}
    </div>
  )
}
