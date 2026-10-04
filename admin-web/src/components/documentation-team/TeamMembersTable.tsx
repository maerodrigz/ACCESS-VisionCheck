import { AdminEmptyState } from '../AdminEmptyState'
import type { TeamMemberProfile } from '../../lib/teamMembers'
import {
  MemberAccountStatusBadge,
  MemberAvatar,
  MemberRequesterRatingDisplay,
  RosterCompetencyBadge,
  TeamAvailabilityIndicator,
  TeamCoverageBadge,
} from './TeamMemberBadges'

interface Props {
  members: TeamMemberProfile[]
  onViewProfile: (member: TeamMemberProfile) => void
}

/** Unified member table — list layout you liked, without a card per row. */
export function TeamMembersTable({ members, onViewProfile }: Props) {
  if (members.length === 0) {
    return (
      <AdminEmptyState title="No members match your filters">
        Adjust filters or approve new registrations.
      </AdminEmptyState>
    )
  }

  return (
    <div className="overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-[0_1px_2px_rgba(15,39,68,0.04)]">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[720px] text-left text-sm">
          <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
            <tr>
              <th className="px-3 py-2">Member</th>
              <th className="px-3 py-2">Role</th>
              <th className="px-3 py-2">Availability</th>
              <th className="px-3 py-2">Ratings</th>
              <th className="px-3 py-2">Status</th>
              <th className="px-3 py-2 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {members.map((member) => (
              <tr
                key={member.id}
                className="border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]"
              >
                <td className="px-3 py-2">
                  <div className="flex items-center gap-2.5">
                    <MemberAvatar name={member.name} avatarUrl={member.avatarUrl} size="xs" />
                    <div className="min-w-0">
                      <div className="truncate text-[13px] font-bold text-[var(--color-text-primary)]">
                        {member.name}
                      </div>
                      <div className="mt-1">
                        <RosterCompetencyBadge member={member} />
                      </div>
                    </div>
                  </div>
                </td>
                <td className="px-3 py-2">
                  <TeamCoverageBadge role={member.coverageRole} />
                </td>
                <td className="px-3 py-2">
                  <TeamAvailabilityIndicator member={member} compact />
                </td>
                <td className="px-3 py-2">
                  <MemberRequesterRatingDisplay member={member} compact />
                </td>
                <td className="px-3 py-2">
                  <MemberAccountStatusBadge member={member} />
                </td>
                <td className="px-3 py-2 text-right">
                  <button
                    type="button"
                    onClick={() => onViewProfile(member)}
                    className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-2.5 py-1 text-[11px] font-semibold text-[var(--color-accent-blue)] hover:bg-[var(--color-surface-hover)]"
                  >
                    View Details
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
