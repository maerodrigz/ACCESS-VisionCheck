import { Star } from 'lucide-react'

export interface MemberRequesterRatingRow {
  id: number
  memberId: number
  memberName: string | null
  taskRole: string | null
  requestorName: string | null
  eventTitle: string | null
  requestId: number
  rating: number
  comment: string | null
  createdAt: string | null
}

export function parseMemberRatingRow(row: Record<string, unknown>): MemberRequesterRatingRow {
  return {
    id: Number(row.id ?? 0),
    memberId: Number(row.member_id ?? 0),
    memberName: row.member_name != null ? String(row.member_name) : null,
    taskRole: row.task_role != null ? String(row.task_role) : null,
    requestorName: row.requestor_name != null ? String(row.requestor_name) : null,
    eventTitle: row.event_title != null ? String(row.event_title) : null,
    requestId: Number(row.request_id ?? 0),
    rating: Number(row.rating ?? 0),
    comment: row.comment != null ? String(row.comment) : null,
    createdAt: row.created_at != null ? String(row.created_at) : null,
  }
}

export function formatTaskRole(raw: string | null | undefined): string {
  if (!raw?.trim()) return 'Member'
  const normalized = raw.trim().replaceAll('_', ' ')
  return normalized[0].toUpperCase() + normalized.slice(1).toLowerCase()
}

export function formatRatingDate(raw: string | null | undefined): string {
  if (!raw?.trim()) return ''
  const dt = new Date(raw.trim())
  if (Number.isNaN(dt.getTime())) return raw.trim()
  return dt.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

export function StarRow({ rating, size = 14 }: { rating: number; size?: number }) {
  const filled = Math.max(0, Math.min(5, Math.round(rating)))
  return (
    <div className="flex items-center gap-0.5" aria-label={`${rating} out of 5 stars`}>
      {Array.from({ length: 5 }, (_, i) => (
        <Star
          key={i}
          size={size}
          className={i < filled ? 'fill-amber-400 text-amber-400' : 'text-[var(--color-text-muted)]'}
          strokeWidth={1.5}
        />
      ))}
    </div>
  )
}
