import { AdminEmptyState } from '../AdminEmptyState'
import type { TeamMemberProfile } from '../../lib/teamMembers'
import {
  MemberAccountStatusBadge,
  MemberAvatar,
  MemberRequesterRatingDisplay,
  MemberSkillBadge,
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
    <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
            <tr>
              <th className="px-4 py-3">Member</th>
              <th className="px-4 py-3">Role</th>
              <th className="px-4 py-3">Availability</th>
              <th className="px-4 py-3">Ratings</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {members.map((member) => (
              <tr
                key={member.id}
                className="border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]"
              >
                <td className="px-4 py-3">
                  <div className="flex items-center gap-3">
                    <MemberAvatar name={member.name} avatarUrl={member.avatarUrl} size="sm" />
                    <div className="min-w-0">
                      <div className="font-bold text-[var(--color-text-primary)]">{member.name}</div>
                      <div className="mt-1 flex flex-wrap items-center gap-1.5">
                        <MemberSkillBadge member={member} />
                      </div>
                    </div>
                  </div>
                </td>
                <td className="px-4 py-3">
                  <TeamCoverageBadge role={member.coverageRole} />
                </td>
                <td className="px-4 py-3">
                  <div className="min-w-[140px]">
                    <TeamAvailabilityIndicator member={member} compact />
                  </div>
                </td>
                <td className="px-4 py-3">
                  <MemberRequesterRatingDisplay member={member} />
                </td>
                <td className="px-4 py-3">
                  <MemberAccountStatusBadge member={member} />
                </td>
                <td className="px-4 py-3 text-right">
                  <button
                    type="button"
                    onClick={() => onViewProfile(member)}
                    className="rounded-lg bg-[var(--color-accent-blue)] px-3 py-1.5 text-xs font-semibold text-white hover:opacity-95"
                  >
                    Roster details
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
