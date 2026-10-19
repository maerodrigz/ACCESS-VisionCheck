import { useEffect, useMemo, useState } from 'react'
import { fetchFeedback, fetchMemberRatings } from '../../api/admin'
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
  completed?: boolean
}

interface OverallFeedback {
  rating: number
  comment: string
}

export function RequestMemberRatingsSection({
  requestId,
  assignedMembers,
  visible,
}: Props) {
  const [rows, setRows] = useState<MemberRequesterRatingRow[]>([])
  const [overall, setOverall] = useState<OverallFeedback | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!visible) {
      setRows([])
      setOverall(null)
      setError(null)
      return
    }
    let cancelled = false
    setLoading(true)
    setError(null)
    void Promise.all([
      assignedMembers.length > 0 ? fetchMemberRatings({ requestId }) : Promise.resolve([]),
      fetchFeedback(),
    ])
      .then(([ratingRows, feedbackRows]) => {
        if (cancelled) return
        setRows(ratingRows.map(parseMemberRatingRow))
        const match = feedbackRows.find((row) => Number(row.request_id ?? 0) === requestId)
        if (match) {
          setOverall({
            rating: Math.min(5, Math.max(0, Math.round(Number(match.rating ?? 0)))),
            comment: String(match.comment ?? match.feedback ?? match.message ?? '').trim(),
          })
        } else {
          setOverall(null)
        }
      })
      .catch((e) => {
        if (cancelled) return
        setRows([])
        setOverall(null)
        setError(e instanceof Error ? e.message : 'Could not load requestor feedback')
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

  if (!visible) return null

  const ratedCount = merged.filter((m) => m.rating != null).length
  const hasAnyFeedback = overall != null || ratedCount > 0

  return (
    <section className="rounded-xl border border-[var(--color-border)] bg-white p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Requestor Feedback</h3>
        {!loading && hasAnyFeedback && assignedMembers.length > 0 ? (
          <span className="text-[11px] font-semibold text-[var(--color-text-secondary)]">
            {ratedCount}/{assignedMembers.length} members rated
          </span>
        ) : null}
      </div>

      {loading ? (
        <p className="mt-2 text-xs text-[var(--color-text-secondary)]">Loading feedback…</p>
      ) : error ? (
        <p className="mt-2 text-xs text-red-600">{error}</p>
      ) : !hasAnyFeedback ? (
        <p className="mt-2 text-sm text-[var(--color-text-secondary)]">No feedback submitted yet</p>
      ) : (
        <div className="mt-3 space-y-3">
          {overall ? (
            <div className="rounded-lg border border-[var(--color-border)] px-3 py-2.5">
              <p className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
                Overall event rating
              </p>
              <div className="mt-1 flex items-center gap-2">
                <StarRow rating={overall.rating} />
                <span className="text-xs font-semibold text-[var(--color-text-secondary)]">
                  {overall.rating}/5
                </span>
              </div>
              {overall.comment ? (
                <p className="mt-1.5 text-sm leading-relaxed text-[var(--color-text-primary)]">
                  {overall.comment}
                </p>
              ) : null}
            </div>
          ) : null}

          {merged.map(({ member, rating }) => (
            <div key={member.id} className="flex flex-wrap items-start justify-between gap-2">
              <div className="min-w-0">
                <div className="text-sm font-semibold text-[var(--color-text-primary)]">{member.name}</div>
                <div className="text-[11px] text-[var(--color-text-secondary)]">
                  {formatTaskRole(rating?.taskRole ?? member.role)}
                </div>
                {rating?.comment?.trim() ? (
                  <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                    {rating.comment.trim()}
                  </p>
                ) : null}
              </div>
              {rating ? (
                <div className="text-right">
                  <StarRow rating={rating.rating} />
                  <div className="mt-0.5 text-[10px] font-semibold text-[var(--color-text-secondary)]">
                    {rating.rating}/5
                  </div>
                </div>
              ) : (
                <span className="text-[11px] font-semibold text-[var(--color-text-muted)]">Not rated yet</span>
              )}
            </div>
          ))}
        </div>
      )}
    </section>
  )
}
