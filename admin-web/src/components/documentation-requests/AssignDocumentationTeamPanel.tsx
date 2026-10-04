import { useCallback, useEffect, useMemo, useState } from 'react'
import { Loader2 } from 'lucide-react'
import {
  assignDocumentationTeam,
  assignMemberToRequest,
  fetchRecommendedMembers,
  fetchRequestAssignments,
} from '../../api/admin'
import type { DocumentationRequestItem } from '../../lib/documentationRequests'
import {
  AssignmentStatusBadge,
  AvailabilityPill,
  RankBadge,
  RoleLabel,
} from '../documentation-team/AssignmentUiBadges'

export interface RecommendedMember {
  member_id: number
  name: string
  task_role: string
  performance_score: number
  skill_level: string
  availability: 'available' | 'limited' | 'unavailable'
  current_assignments: number
  recommended: boolean
}

export interface RequestAssignmentRow {
  id: number
  member_id: number
  member_name: string
  task_role: string
  status: string
  decline_reason?: string | null
  replaces_assignment_id?: number | null
  replaced_member_name?: string | null
}

interface Props {
  item: DocumentationRequestItem
  onAssigned: () => void
}

function mapRecommended(rows: Record<string, unknown>[]): RecommendedMember[] {
  return rows.map((r) => ({
    member_id: Number(r.member_id ?? 0),
    name: String(r.name ?? r.fullname ?? 'Member'),
    task_role: String(r.task_role ?? ''),
    performance_score: Number(r.performance_score ?? 0),
    skill_level: String(r.skill_level ?? '—'),
    availability: (r.availability as RecommendedMember['availability']) ?? 'limited',
    current_assignments: Number(r.current_assignments ?? 0),
    recommended: Boolean(r.recommended),
  }))
}

function mapAssignments(rows: Record<string, unknown>[]): RequestAssignmentRow[] {
  return rows.map((r) => ({
    id: Number(r.id ?? r.assignment_id ?? 0),
    member_id: Number(r.member_id ?? 0),
    member_name: String(r.member_name ?? 'Member'),
    task_role: String(r.task_role ?? ''),
    status: String(r.status ?? ''),
    decline_reason: r.decline_reason != null ? String(r.decline_reason) : null,
    replaces_assignment_id:
      r.replaces_assignment_id != null ? Number(r.replaces_assignment_id) : null,
    replaced_member_name: r.replaced_member_name != null ? String(r.replaced_member_name) : null,
  }))
}

export function AssignDocumentationTeamPanel({ item, onAssigned }: Props) {
  const [photographers, setPhotographers] = useState<RecommendedMember[]>([])
  const [videographers, setVideographers] = useState<RecommendedMember[]>([])
  const [assignments, setAssignments] = useState<RequestAssignmentRow[]>([])
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [photographerId, setPhotographerId] = useState<number | ''>('')
  const [videographerId, setVideographerId] = useState<number | ''>('')
  const [showConfirm, setShowConfirm] = useState(false)
  const [replacementFor, setReplacementFor] = useState<RequestAssignmentRow | null>(null)

  const isApproved =
    item.displayStatus === 'approved' ||
    item.displayStatus === 'completed' ||
    item.rawStatus.toLowerCase() === 'approved'

  const load = useCallback(async () => {
    if (!isApproved) return
    setLoading(true)
    setError(null)
    try {
      const [photoRec, videoRec, rows] = await Promise.all([
        fetchRecommendedMembers(item.id, 'photographer'),
        fetchRecommendedMembers(item.id, 'videographer'),
        fetchRequestAssignments(item.id),
      ])
      setPhotographers(mapRecommended(photoRec))
      setVideographers(mapRecommended(videoRec))
      setAssignments(mapAssignments(rows))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not load team recommendations')
    } finally {
      setLoading(false)
    }
  }, [isApproved, item.id])

  useEffect(() => {
    void load()
  }, [load])

  const declinedPhotographer = useMemo(
    () => assignments.find((a) => a.task_role === 'photographer' && a.status === 'declined'),
    [assignments],
  )
  const declinedVideographer = useMemo(
    () => assignments.find((a) => a.task_role === 'videographer' && a.status === 'declined'),
    [assignments],
  )

  const selectedPhotographer = photographers.find((m) => m.member_id === photographerId)
  const selectedVideographer = videographers.find((m) => m.member_id === videographerId)

  async function confirmAssignment() {
    setSubmitting(true)
    setError(null)
    try {
      if (photographerId !== '' || videographerId !== '') {
        await assignDocumentationTeam(item.id, {
          photographer_id: photographerId === '' ? undefined : photographerId,
          videographer_id: videographerId === '' ? undefined : videographerId,
          replaces_assignment_id: replacementFor?.id,
        })
      }
      setShowConfirm(false)
      setPhotographerId('')
      setVideographerId('')
      setReplacementFor(null)
      await load()
      onAssigned()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not confirm assignment')
    } finally {
      setSubmitting(false)
    }
  }

  async function assignReplacement(row: RequestAssignmentRow, memberId: number) {
    setSubmitting(true)
    setError(null)
    try {
      await assignMemberToRequest(item.id, {
        member_id: memberId,
        task_role: row.task_role,
      })
      await load()
      onAssigned()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not assign replacement')
    } finally {
      setSubmitting(false)
    }
  }

  if (!isApproved) {
    return (
      <p className="text-sm text-[var(--color-text-secondary)]">
        Approve this request before assigning the documentation team.
      </p>
    )
  }

  if (loading) {
    return (
      <div className="flex items-center gap-2 py-6 text-sm text-[var(--color-text-secondary)]">
        <Loader2 className="h-4 w-4 animate-spin" />
        Loading recommendations…
      </div>
    )
  }

  return (
    <div className="space-y-5">
      <div>
        <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Assign Documentation Team</h3>
        <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
          Recommended by system — you choose the final assignment. Members must accept before coverage is confirmed.
        </p>
      </div>

      {error ? (
        <div className="rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm text-red-300">{error}</div>
      ) : null}

      {assignments.length > 0 ? (
        <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-4">
          <p className="mb-3 text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
            Documentation Team Status
          </p>
          <div className="space-y-3">
            {assignments.map((a) => (
              <div key={a.id} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] p-3 text-sm">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <RoleLabel role={a.task_role} />
                    <p className="mt-1 text-[var(--color-text-primary)]">{a.member_name}</p>
                    {a.replaced_member_name ? (
                      <p className="text-xs text-[var(--color-text-secondary)]">
                        Replacement for {a.replaced_member_name}
                      </p>
                    ) : null}
                  </div>
                  <AssignmentStatusBadge status={a.status} />
                </div>
                {a.status === 'declined' && a.decline_reason ? (
                  <p className="mt-2 text-xs text-red-600">Reason: {a.decline_reason}</p>
                ) : null}
                {a.status === 'declined' ? (
                  <ReplacementBlock
                    role={a.task_role}
                    declined={a}
                    recommendations={a.task_role === 'photographer' ? photographers : videographers}
                    onAssign={(memberId) => void assignReplacement(a, memberId)}
                    submitting={submitting}
                  />
                ) : null}
              </div>
            ))}
          </div>
        </div>
      ) : null}

      <RecommendationList
        title="Recommended Photographers"
        members={photographers}
        selectedId={photographerId}
        onSelect={(id) => {
          setPhotographerId(id)
          setReplacementFor(declinedPhotographer ?? null)
        }}
      />

      <RecommendationList
        title="Recommended Videographers"
        members={videographers}
        selectedId={videographerId}
        onSelect={(id) => {
          setVideographerId(id)
          setReplacementFor(declinedVideographer ?? null)
        }}
      />

      {(photographerId !== '' || videographerId !== '') && !showConfirm ? (
        <button
          type="button"
          className="w-full rounded-xl bg-[var(--color-accent-blue)] px-4 py-3 text-sm font-bold text-white"
          onClick={() => setShowConfirm(true)}
        >
          Review & Confirm Assignment
        </button>
      ) : null}

      {showConfirm ? (
        <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] p-4 shadow-sm">
          <p className="text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
            Documentation Team
          </p>
          <div className="mt-3 space-y-2 text-sm">
            {selectedPhotographer ? (
              <p>
                <span className="font-semibold">Photographer:</span> {selectedPhotographer.name}
              </p>
            ) : null}
            {selectedVideographer ? (
              <p>
                <span className="font-semibold">Videographer:</span> {selectedVideographer.name}
              </p>
            ) : null}
            <p>
              <span className="font-semibold">Event:</span> {item.eventTitle}
            </p>
            <p>
              <span className="font-semibold">Date:</span> {item.eventDateLabel}
            </p>
          </div>
          <p className="mt-3 rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-xs text-amber-200">
            Selected members will receive an assignment notification and must accept or decline the assignment.
          </p>
          <div className="mt-4 flex gap-2">
            <button
              type="button"
              className="flex-1 rounded-lg border border-[var(--color-border)] px-3 py-2 text-sm font-semibold"
              onClick={() => setShowConfirm(false)}
              disabled={submitting}
            >
              Cancel
            </button>
            <button
              type="button"
              className="flex-1 rounded-lg bg-[var(--color-accent-blue)] px-3 py-2 text-sm font-bold text-white"
              onClick={() => void confirmAssignment()}
              disabled={submitting}
            >
              {submitting ? 'Confirming…' : 'Confirm Assignment'}
            </button>
          </div>
        </div>
      ) : null}
    </div>
  )
}

function RecommendationList({
  title,
  members,
  selectedId,
  onSelect,
}: {
  title: string
  members: RecommendedMember[]
  selectedId: number | ''
  onSelect: (id: number) => void
}) {
  return (
    <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] p-4">
      <p className="mb-3 text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">{title}</p>
      {members.length === 0 ? (
        <p className="text-sm text-[var(--color-text-secondary)]">No eligible members available.</p>
      ) : (
        <div className="space-y-2">
          {members.map((m, index) => {
            const selected = selectedId === m.member_id
            return (
              <button
                key={m.member_id}
                type="button"
                onClick={() => onSelect(m.member_id)}
                className={`w-full rounded-lg border px-3 py-3 text-left transition ${
                  selected
                    ? 'border-[var(--color-accent-blue)] bg-[var(--color-accent-blue)]/10 ring-1 ring-[var(--color-accent-blue)]'
                    : 'border-[var(--color-border)] hover:border-[var(--color-accent-cyan)]'
                }`}
              >
                <div className="flex items-start gap-2.5">
                  <RankBadge index={index} />
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold text-[var(--color-text-primary)]">
                      {m.name}
                      {m.recommended ? (
                        <span className="ml-2 rounded-full bg-cyan-100 px-2 py-0.5 text-[10px] font-bold text-cyan-800">
                          Recommended
                        </span>
                      ) : null}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
                      Performance: {m.performance_score} · Skill: {m.skill_level}
                    </p>
                    <p className="mt-1 flex flex-wrap items-center gap-2 text-xs text-[var(--color-text-secondary)]">
                      <AvailabilityPill availability={m.availability} />
                      <span>Current assignments: {m.current_assignments}</span>
                    </p>
                  </div>
                  {selected ? (
                    <span className="text-[10px] font-bold uppercase text-[var(--color-accent-blue)]">
                      Selected by Admin
                    </span>
                  ) : null}
                </div>
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}

function ReplacementBlock({
  role,
  declined,
  recommendations,
  onAssign,
  submitting,
}: {
  role: string
  declined: RequestAssignmentRow
  recommendations: RecommendedMember[]
  onAssign: (memberId: number) => void
  submitting: boolean
}) {
  const replacement = recommendations[0]
  if (!replacement) {
    return <p className="mt-2 text-xs text-[var(--color-text-secondary)]">No replacement candidates available.</p>
  }
  return (
    <div className="mt-3 rounded-lg border border-dashed border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
      <p className="text-xs font-bold text-[var(--color-text-primary)]">Recommended Replacement</p>
      <p className="mt-1 text-sm font-semibold">{replacement.name}</p>
      <p className="text-xs text-[var(--color-text-secondary)]">
        Performance: {replacement.performance_score} · {replacement.skill_level} ·{' '}
        <AvailabilityPill availability={replacement.availability} />
      </p>
      <button
        type="button"
        disabled={submitting}
        className="mt-2 rounded-lg bg-[var(--color-accent-blue)] px-3 py-1.5 text-xs font-bold text-white"
        onClick={() => onAssign(replacement.member_id)}
      >
        Assign Replacement
      </button>
      <p className="mt-1 text-[10px] text-[var(--color-text-secondary)]">
        Replacing {declined.member_name} ({role})
      </p>
    </div>
  )
}
