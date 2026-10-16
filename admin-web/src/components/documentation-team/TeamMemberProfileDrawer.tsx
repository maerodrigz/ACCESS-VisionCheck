import { useState, type ReactNode } from 'react'
import { DeactivateMemberDialog } from '../DeactivateMemberDialog'
import { AdminSelect } from '../AdminSelect'
import { Loader2 } from 'lucide-react'
import { AdminDrawer } from '../AdminDrawer'
import { useNavigate } from 'react-router-dom'
import type { TeamMemberProfile } from '../../lib/teamMembers'
import { coverageRoleLabel, formatTeamDate } from '../../lib/teamMembers'
import {
  MemberAccountStatusBadge,
  MemberAvatar,
  MemberRequesterRatingDisplay,
  TeamAvailabilityIndicator,
  TeamCoverageBadge,
} from './TeamMemberBadges'
import { memberAccountLabel } from '../../lib/teamMembers'
import { MemberRequesterRatingsHistory } from '../documentation-requests/MemberRequesterRatingsHistory'

interface Props {
  member: TeamMemberProfile | null
  onClose: () => void
  onDeactivate: (member: TeamMemberProfile, deleteUploads: boolean) => Promise<void>
  onStatusChange: (member: TeamMemberProfile, status: string, reason?: string) => Promise<void>
}

export function TeamMemberProfileDrawer({ member, onClose, onDeactivate, onStatusChange }: Props) {
  const navigate = useNavigate()
  const [busy, setBusy] = useState(false)
  const [showStatus, setShowStatus] = useState(false)
  const [newStatus, setNewStatus] = useState('approved')
  const [showDeactivateConfirm, setShowDeactivateConfirm] = useState(false)
  const [rejectReason, setRejectReason] = useState('')

  if (!member) return null

  async function handleStatusSave() {
    if (newStatus === 'rejected' && rejectReason.trim().length < 3) return
    setBusy(true)
    try {
      await onStatusChange(member!, newStatus, newStatus === 'rejected' ? rejectReason.trim() : undefined)
      setShowStatus(false)
    } finally {
      setBusy(false)
    }
  }

  async function handleDeactivate(deleteUploads: boolean) {
    setBusy(true)
    try {
      await onDeactivate(member!, deleteUploads)
      onClose()
    } finally {
      setBusy(false)
      setShowDeactivateConfirm(false)
    }
  }

  return (
    <>
      <AdminDrawer
        open
        onClose={onClose}
        title="Member profile"
        maxWidth="md"
        bodyClassName="px-5 pb-5"
        footer={
          <div className="bg-[var(--color-surface-muted)] p-4">
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => {
                  onClose()
                  const requestId = member.currentAssignment?.requestId
                  navigate(
                    requestId
                      ? `/documentation-requests?request=${requestId}`
                      : '/documentation-requests',
                  )
                }}
                className="rounded-lg bg-[var(--color-accent-blue)] px-4 py-2 text-sm font-semibold text-white"
              >
                {member.currentAssignment ? 'View assignment' : 'Assign to Event'}
              </button>
              <button
                type="button"
                onClick={() => setShowStatus(true)}
                className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-4 py-2 text-sm font-semibold"
              >
                Edit Status
              </button>
              <button
                type="button"
                onClick={() => {
                  onClose()
                  navigate(`/competency?q=${encodeURIComponent(member.name)}`)
                }}
                className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-4 py-2 text-sm font-semibold"
              >
                Open competency profile
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={() => setShowDeactivateConfirm(true)}
                className="rounded-lg border border-red-200 px-4 py-2 text-sm font-semibold text-red-600 disabled:opacity-50"
              >
                Deactivate
              </button>
            </div>
          </div>
        }
      >
          <div className="flex flex-col items-center py-4 text-center">
            <MemberAvatar name={member.name} avatarUrl={member.avatarUrl} size="lg" />
            <h3 className="mt-3 text-xl font-extrabold text-[var(--color-text-primary)]">{member.name}</h3>
            <div className="mt-2 flex flex-wrap items-center justify-center gap-2">
              <TeamCoverageBadge role={member.coverageRole} />
              <MemberAccountStatusBadge member={member} />
            </div>
          </div>

          <Section title="Availability">
            <TeamAvailabilityIndicator member={member} />
          </Section>

          <Section title="Personal information">
            <InfoRow label="Email" value={member.email} />
            <InfoRow label="Contact" value={member.contactNumber ?? '—'} />
            <InfoRow label="Role" value={coverageRoleLabel(member.coverageRole)} />
            <InfoRow label="Joined" value={formatTeamDate(member.dateJoined)} />
            <InfoRow label="Account status" value={memberAccountLabel(member)} />
          </Section>

          <Section title="Requester ratings">
            <MemberRequesterRatingDisplay member={member} />
            <div className="mt-3">
              <div className="mb-2 text-[11px] font-bold text-[var(--color-text-secondary)]">Recent events</div>
              <MemberRequesterRatingsHistory memberId={member.id} />
            </div>
          </Section>

          <Section title="Current assignment">
            {member.currentAssignment ? (
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3.5">
                <div className="text-sm font-bold text-[var(--color-text-primary)]">
                  {member.currentAssignment.eventName}
                </div>
                <div className="mt-1 text-xs text-[var(--color-text-secondary)]">
                  {member.currentAssignment.assignmentRole} · {member.currentAssignment.scheduleLabel}
                </div>
                <div className="mt-1 text-[11px] font-semibold text-[var(--color-accent-blue)]">
                  Status: {member.currentAssignment.status}
                </div>
              </div>
            ) : (
              <p className="text-xs text-[var(--color-text-secondary)]">No active assignment.</p>
            )}
          </Section>

          <Section title="Skill and performance">
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3.5">
              <p className="text-xs leading-relaxed text-[var(--color-text-secondary)]">
                Competency level, performance metrics, requester ratings, training notes, and level overrides are
                managed in Competency Management.
              </p>
              <button
                type="button"
                onClick={() => {
                  onClose()
                  navigate(`/competency?q=${encodeURIComponent(member.name)}`)
                }}
                className="mt-3 rounded-lg bg-[var(--color-accent-blue)] px-3 py-2 text-xs font-semibold text-white hover:opacity-95"
              >
                Open competency profile for {member.name}
              </button>
            </div>
          </Section>

          {showStatus && (
            <div className="mt-4 space-y-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
              <label className="text-xs font-bold text-[var(--color-text-secondary)]">Update status</label>
              <AdminSelect
                value={newStatus}
                onChange={setNewStatus}
                aria-label="Update member status"
                options={[
                  { value: 'approved', label: 'Approved' },
                  { value: 'pending', label: 'Pending' },
                  { value: 'rejected', label: 'Rejected' },
                ]}
              />
              {newStatus === 'rejected' && (
                <textarea
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder="Rejection reason…"
                  rows={3}
                  className="w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2 text-sm"
                />
              )}
              <div className="flex gap-2">
                <button
                  type="button"
                  disabled={busy}
                  onClick={handleStatusSave}
                  className="flex-1 rounded-lg bg-[var(--color-accent-blue)] py-2 text-sm font-semibold text-white disabled:opacity-50"
                >
                  {busy ? <Loader2 size={14} className="mx-auto animate-spin" /> : 'Save status'}
                </button>
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => setShowStatus(false)}
                  className="rounded-lg border border-[var(--color-border)] px-4 py-2 text-sm font-semibold"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
      </AdminDrawer>

      <DeactivateMemberDialog
        open={showDeactivateConfirm}
        memberName={member.name}
        userId={member.id}
        uploadCount={member.uploadCount}
        loading={busy}
        onConfirm={(deleteUploads) => void handleDeactivate(deleteUploads)}
        onCancel={() => setShowDeactivateConfirm(false)}
      />
    </>
  )
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mt-5">
      <h4 className="text-sm font-bold text-[var(--color-text-primary)]">{title}</h4>
      <div className="mt-2">{children}</div>
    </div>
  )
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="mb-2 flex gap-3 text-xs">
      <span className="w-24 shrink-0 text-[var(--color-text-secondary)]">{label}</span>
      <span className="font-semibold text-[var(--color-text-primary)]">{value}</span>
    </div>
  )
}
