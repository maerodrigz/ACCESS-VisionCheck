import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { ChevronDown, Loader2 } from 'lucide-react'
import {
  assignDocumentationTeam,
  assignMemberToRequest,
  fetchRecommendedMembers,
  fetchRequestAssignments,
} from '../../api/admin'
import type { DocumentationRequestItem } from '../../lib/documentationRequests'
import {
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

const ACCEPTED_STATUSES = new Set(['accepted', 'in_progress', 'completed'])

function mapRecommended(rows: Record<string, unknown>[]): RecommendedMember[] {
  return rows.map((r) => ({
    member_id: Number(r.member_id ?? 0),
    name: String(r.name ?? r.fullname ?? 'Member'),
    task_role: String(r.task_role ?? ''),
    performance_score: Number(r.performance_score ?? 0),
    skill_level: String(r.skill_level ?? 'N/A'),
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

function assignmentStatusLabel(status: string): { label: string; bg: string; text: string } {
  const s = status.toLowerCase().replace(/\s+/g, '_')
  if (s === 'accepted') return { label: 'Accepted', bg: 'rgba(22,163,74,0.12)', text: '#16a34a' }
  if (s === 'completed') return { label: 'Completed', bg: 'rgba(22,163,74,0.12)', text: '#16a34a' }
  if (s === 'in_progress') return { label: 'In progress', bg: 'rgba(0,82,212,0.12)', text: '#0052d4' }
  if (s === 'declined') return { label: 'Declined', bg: 'rgba(220,38,38,0.1)', text: '#dc2626' }
  return { label: 'Pending', bg: 'rgba(245,158,11,0.14)', text: '#d97706' }
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
  const [manageOpen, setManageOpen] = useState(false)
  const manageInitialized = useRef(false)

  const isTeamLocked =
    item.displayStatus === 'completed' || item.displayStatus === 'archived'
  const canManageTeam = !isTeamLocked
  const isArchived = item.displayStatus === 'archived'

  const isApproved =
    item.displayStatus === 'approved' ||
    item.displayStatus === 'completed' ||
    item.displayStatus === 'archived' ||
    item.rawStatus.toLowerCase() === 'approved'

  const load = useCallback(async () => {
    if (!isApproved) return
    setLoading(true)
    setError(null)
    try {
      const rows = await fetchRequestAssignments(item.id)
      const mapped = mapAssignments(rows)
      setAssignments(mapped)

      if (canManageTeam) {
        const [photoRec, videoRec] = await Promise.all([
          fetchRecommendedMembers(item.id, 'photographer'),
          fetchRecommendedMembers(item.id, 'videographer'),
        ])
        setPhotographers(mapRecommended(photoRec))
        setVideographers(mapRecommended(videoRec))
        if (!manageInitialized.current) {
          manageInitialized.current = true
          setManageOpen(mapped.length === 0)
        }
      } else {
        setPhotographers([])
        setVideographers([])
        setManageOpen(false)
      }
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : canManageTeam
            ? 'Could not load team recommendations'
            : 'Could not load assigned team',
      )
    } finally {
      setLoading(false)
    }
  }, [canManageTeam, isApproved, item.id])

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
  const acceptedIds = useMemo(
    () => new Set(assignments.filter((a) => ACCEPTED_STATUSES.has(a.status.toLowerCase())).map((a) => a.member_id)),
    [assignments],
  )
  const assignedIds = useMemo(() => new Set(assignments.map((a) => a.member_id)), [assignments])

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
      <div className="flex items-center gap-2 py-3 text-sm text-[var(--color-text-secondary)]">
        <Loader2 className="h-4 w-4 animate-spin" />
        {canManageTeam ? 'Loading recommendations…' : 'Loading team…'}
      </div>
    )
  }

  return (
    <div className="space-y-3">
      <section className="rounded-xl border border-[var(--color-border)] bg-white p-4">
        <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Assigned Documentation Team</h3>
        <p className="mt-0.5 text-[11px] text-[var(--color-text-secondary)]">
          {isArchived
            ? 'Archived request. Coverage team is read-only.'
            : isTeamLocked
              ? 'Coverage team for this completed request. Assignments are read-only.'
              : 'Members must accept before coverage is confirmed.'}
        </p>
        {assignments.length === 0 ? (
          <p className="mt-3 text-sm text-[var(--color-text-secondary)]">No members assigned yet.</p>
        ) : (
          <ul className="mt-3 divide-y divide-[var(--color-border)]">
            {assignments.map((a) => {
              const tone = assignmentStatusLabel(a.status)
              return (
                <li key={a.id} className="flex flex-wrap items-start justify-between gap-2 py-2.5 first:pt-0 last:pb-0">
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">{a.member_name}</p>
                    <div className="mt-0.5">
                      <RoleLabel role={a.task_role} />
                    </div>
                    {a.replaced_member_name ? (
                      <p className="mt-0.5 text-[11px] text-[var(--color-text-secondary)]">
                        Replacement for {a.replaced_member_name}
                      </p>
                    ) : null}
                    {a.status === 'declined' && a.decline_reason ? (
                      <p className="mt-1 text-[11px] text-red-600">Reason: {a.decline_reason}</p>
                    ) : null}
                  </div>
                  <span
                    className="inline-flex shrink-0 rounded-full px-2 py-0.5 text-[10px] font-bold"
                    style={{ backgroundColor: tone.bg, color: tone.text }}
                  >
                    {tone.label}
                  </span>
                  {a.status === 'declined' && canManageTeam ? (
                    <div className="w-full">
                      <ReplacementBlock
                        role={a.task_role}
                        declined={a}
                        recommendations={a.task_role === 'photographer' ? photographers : videographers}
                        onAssign={(memberId) => void assignReplacement(a, memberId)}
                        submitting={submitting}
                      />
                    </div>
                  ) : null}
                </li>
              )
            })}
          </ul>
        )}
      </section>

      {error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div>
      ) : null}

      {canManageTeam ? (
        <section className="rounded-xl border border-[var(--color-border)] bg-white">
          <button
            type="button"
            className="flex w-full items-center justify-between gap-2 px-4 py-3 text-left"
            onClick={() => setManageOpen((open) => !open)}
            aria-expanded={manageOpen}
          >
            <div>
              <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Manage Team</h3>
              <p className="text-[11px] text-[var(--color-text-secondary)]">
                Recommended members. Accepted assignments are not replaced automatically.
              </p>
            </div>
            <ChevronDown
              size={18}
              className={`shrink-0 text-[var(--color-text-secondary)] transition ${manageOpen ? 'rotate-180' : ''}`}
            />
          </button>

          {manageOpen ? (
            <div className="space-y-3 border-t border-[var(--color-border)] px-4 py-3">
              <RecommendationList
                title="Recommended Photographers"
                members={photographers}
                selectedId={photographerId}
                assignedIds={assignedIds}
                acceptedIds={acceptedIds}
                onSelect={(id) => {
                  if (acceptedIds.has(id)) return
                  setPhotographerId(id)
                  setReplacementFor(declinedPhotographer ?? null)
                }}
              />

              <RecommendationList
                title="Recommended Videographers"
                members={videographers}
                selectedId={videographerId}
                assignedIds={assignedIds}
                acceptedIds={acceptedIds}
                onSelect={(id) => {
                  if (acceptedIds.has(id)) return
                  setVideographerId(id)
                  setReplacementFor(declinedVideographer ?? null)
                }}
              />

              {(photographerId !== '' || videographerId !== '') && !showConfirm ? (
                <button
                  type="button"
                  className="w-full rounded-xl bg-[var(--color-accent-blue)] px-4 py-2.5 text-sm font-bold text-white"
                  onClick={() => setShowConfirm(true)}
                >
                  Review & Confirm Assignment
                </button>
              ) : null}

              {showConfirm ? (
                <div className="rounded-xl border border-[var(--color-border)] bg-white p-3">
                  <p className="text-[11px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                    Confirm assignment
                  </p>
                  <div className="mt-2 space-y-1 text-sm">
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
                  <p className="mt-2 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs font-medium text-amber-950">
                    Selected members will receive an assignment notification and must accept or decline the assignment.
                  </p>
                  <div className="mt-3 flex gap-2">
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
          ) : null}
        </section>
      ) : null}
    </div>
  )
}

function RecommendationList({
  title,
  members,
  selectedId,
  assignedIds,
  acceptedIds,
  onSelect,
}: {
  title: string
  members: RecommendedMember[]
  selectedId: number | ''
  assignedIds: Set<number>
  acceptedIds: Set<number>
  onSelect: (id: number) => void
}) {
  return (
    <div>
      <p className="mb-2 text-[11px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">{title}</p>
      {members.length === 0 ? (
        <p className="text-sm text-[var(--color-text-secondary)]">No eligible members available.</p>
      ) : (
        <div className="space-y-1.5">
          {members.map((m, index) => {
            const selected = selectedId === m.member_id
            const accepted = acceptedIds.has(m.member_id)
            const alreadyAssigned = assignedIds.has(m.member_id)
            return (
              <button
                key={m.member_id}
                type="button"
                disabled={accepted}
                onClick={() => onSelect(m.member_id)}
                className={`w-full rounded-lg border px-3 py-2 text-left transition ${
                  accepted
                    ? 'cursor-not-allowed border-[var(--color-border)] bg-[var(--color-surface-muted)] opacity-80'
                      : selected
                      ? 'border-[var(--color-accent-blue)] bg-[var(--color-accent-blue)]/10 ring-1 ring-[var(--color-accent-blue)]'
                      : 'border-[var(--color-border)] bg-white hover:border-[var(--color-accent-cyan)]'
                }`}
              >
                <div className="flex items-start gap-2.5">
                  <RankBadge index={index} />
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {m.name}
                      {m.recommended && !alreadyAssigned ? (
                        <span className="ml-2 rounded-full bg-cyan-100 px-2 py-0.5 text-[10px] font-bold text-cyan-800">
                          Recommended
                        </span>
                      ) : null}
                      {alreadyAssigned ? (
                        <span className="ml-2 rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-bold text-slate-600">
                          Assigned
                        </span>
                      ) : null}
                    </p>
                    <p className="mt-0.5 text-[11px] text-[var(--color-text-secondary)]">
                      Performance: {m.performance_score} · Skill: {m.skill_level}
                    </p>
                    <p className="mt-1 flex flex-wrap items-center gap-2 text-[11px] text-[var(--color-text-secondary)]">
                      <AvailabilityPill availability={m.availability} />
                      <span>Current assignments: {m.current_assignments}</span>
                    </p>
                  </div>
                  {selected ? (
                    <span className="text-[10px] font-bold uppercase text-[var(--color-accent-blue)]">
                      Selected
                    </span>
                  ) : null}
                  {accepted ? (
                    <span className="text-[10px] font-bold uppercase text-[var(--color-text-secondary)]">
                      Locked
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
    <div className="mt-2 rounded-lg border border-dashed border-[var(--color-border)] px-3 py-2">
      <p className="text-[11px] font-bold text-[var(--color-text-primary)]">Recommended Replacement</p>
      <p className="mt-0.5 text-sm font-semibold">{replacement.name}</p>
      <p className="text-[11px] text-[var(--color-text-secondary)]">
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
