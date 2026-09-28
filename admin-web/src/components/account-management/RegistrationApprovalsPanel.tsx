import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  approveMemberRegistration,
  approveOrganizationRegistration,
  fetchMemberRegistrations,
  fetchOrganizationRegistrations,
  rejectMemberRegistration,
  rejectOrganizationRegistration,
} from '../../api/admin'
import { DrawerBackButton } from '../AdminBackButton'
import { AdminErrorBanner } from '../AdminAlert'
import { PendingOrganizationRegistrationsTable } from '../documentation-team/PendingOrganizationRegistrationsTable'
import { PendingRegistrationsTable } from '../documentation-team/PendingRegistrationsTable'
import { PageLoader } from '../PageLoader'
import { PageToolbarRefreshButton } from '../PageToolbar'
import {
  isFacultyOrInstructor,
  isOrganizationRequestor,
  parsePendingOrganizationRegistration,
  type PendingOrganizationRegistration,
  type RegistrationApprovalTab,
} from '../../lib/registrations'
import { parsePendingRegistration, type PendingRegistration } from '../../lib/teamMembers'

const TABS: { id: RegistrationApprovalTab; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'members', label: 'Members' },
  { id: 'faculty_instructors', label: 'Faculty & instructors' },
  { id: 'organizations', label: 'Organizations' },
]

function parseTab(raw: string | null): RegistrationApprovalTab {
  if (raw === 'members' || raw === 'faculty_instructors' || raw === 'organizations') return raw
  return 'all'
}

interface Props {
  initialTab?: RegistrationApprovalTab
  onBack: () => void
  onTabChange: (tab: RegistrationApprovalTab) => void
}

export function RegistrationApprovalsPanel({ initialTab = 'all', onBack, onTabChange }: Props) {
  const [tab, setTab] = useState<RegistrationApprovalTab>(initialTab)
  const [members, setMembers] = useState<PendingRegistration[]>([])
  const [requestors, setRequestors] = useState<PendingOrganizationRegistration[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [memberRows, requestorRows] = await Promise.all([
        fetchMemberRegistrations('pending'),
        fetchOrganizationRegistrations('pending'),
      ])
      setMembers(memberRows.map(parsePendingRegistration))
      setRequestors(requestorRows.map(parsePendingOrganizationRegistration))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load registrations')
      setMembers([])
      setRequestors([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    setTab(initialTab)
  }, [initialTab])

  const facultyInstructors = useMemo(
    () => requestors.filter(isFacultyOrInstructor),
    [requestors],
  )
  const organizations = useMemo(
    () => requestors.filter(isOrganizationRequestor),
    [requestors],
  )

  const counts = useMemo(
    () => ({
      all: members.length + requestors.length,
      members: members.length,
      faculty_instructors: facultyInstructors.length,
      organizations: organizations.length,
    }),
    [members.length, requestors.length, facultyInstructors.length, organizations.length],
  )

  function selectTab(next: RegistrationApprovalTab) {
    setTab(next)
    onTabChange(next)
  }

  async function handleApproveMember(id: number) {
    await approveMemberRegistration(id)
    await load()
  }

  async function handleRejectMember(id: number, reason: string) {
    await rejectMemberRegistration(id, reason)
    await load()
  }

  async function handleApproveRequestor(id: number) {
    await approveOrganizationRegistration(id)
    await load()
  }

  async function handleRejectRequestor(id: number, reason: string) {
    await rejectOrganizationRegistration(id, reason)
    await load()
  }

  const visibleMembers = tab === 'all' || tab === 'members' ? members : []
  const visibleFaculty =
    tab === 'all' || tab === 'faculty_instructors' ? facultyInstructors : []
  const visibleOrganizations =
    tab === 'all' || tab === 'organizations' ? organizations : []

  const nothingPending =
    !loading &&
    ((tab === 'all' && counts.all === 0) ||
      (tab === 'members' && counts.members === 0) ||
      (tab === 'faculty_instructors' && counts.faculty_instructors === 0) ||
      (tab === 'organizations' && counts.organizations === 0))

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <DrawerBackButton label="Back to accounts" onClick={onBack} />
          <div>
            <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Registration approvals</h2>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Review pending sign-ups for members, faculty, instructors, and organizations. Admin accounts are
              created manually and do not appear here.
            </p>
          </div>
        </div>
        <PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />
      </div>

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div className="flex flex-wrap gap-2">
        {TABS.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => selectTab(item.id)}
            className={[
              'rounded-full px-4 py-1.5 text-xs font-bold transition',
              tab === item.id
                ? 'bg-[var(--color-accent-blue)] text-white'
                : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
            ].join(' ')}
          >
            {item.label} ({counts[item.id]})
          </button>
        ))}
      </div>

      {loading && counts.all === 0 ? (
        <PageLoader label="Loading registrations…" />
      ) : nothingPending ? (
        <div className="rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] px-4 py-10 text-center text-sm text-[var(--color-text-secondary)]">
          No pending registrations in this view.
        </div>
      ) : (
        <div className="space-y-6">
          {visibleMembers.length > 0 && (
            <section className="space-y-2">
              {tab === 'all' && (
                <h3 className="text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                  ACCESS members ({visibleMembers.length})
                </h3>
              )}
              <PendingRegistrationsTable
                registrations={visibleMembers}
                onApprove={handleApproveMember}
                onReject={handleRejectMember}
              />
            </section>
          )}

          {visibleFaculty.length > 0 && (
            <section className="space-y-2">
              {tab === 'all' && (
                <h3 className="text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                  Faculty & instructors ({visibleFaculty.length})
                </h3>
              )}
              <PendingOrganizationRegistrationsTable
                registrations={visibleFaculty}
                onApprove={handleApproveRequestor}
                onReject={handleRejectRequestor}
              />
            </section>
          )}

          {visibleOrganizations.length > 0 && (
            <section className="space-y-2">
              {tab === 'all' && (
                <h3 className="text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                  Organizations ({visibleOrganizations.length})
                </h3>
              )}
              <PendingOrganizationRegistrationsTable
                registrations={visibleOrganizations}
                onApprove={handleApproveRequestor}
                onReject={handleRejectRequestor}
              />
            </section>
          )}
        </div>
      )}
    </div>
  )
}
