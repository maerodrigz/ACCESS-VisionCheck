import type { TeamMemberProfile } from '../../lib/teamMembers'
import {
  MemberAvatar,
  MemberSkillBadge,
  TeamAvailabilityIndicator,
  TeamCoverageBadge,
} from './TeamMemberBadges'

interface Props {
  member: TeamMemberProfile
  onViewProfile: (member: TeamMemberProfile) => void
}

export function TeamMemberListRow({ member, onViewProfile }: Props) {
  return (
    <div className="flex flex-wrap items-center gap-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3 shadow-[0_2px_8px_rgba(15,39,68,0.04)]">
      <MemberAvatar name={member.name} avatarUrl={member.avatarUrl} size="sm" />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="truncate text-sm font-bold text-[var(--color-text-primary)]">{member.name}</h3>
          <TeamCoverageBadge role={member.coverageRole} />
          <MemberSkillBadge member={member} />
        </div>
        <div className="mt-1 flex flex-wrap gap-x-4 gap-y-0.5 text-[11px] text-[var(--color-text-secondary)]">
          <span>{Math.round(member.performanceScore)}% performance</span>
          <span>{member.completedTasks} accepted</span>
          <span>
            {member.averageQualityScore > 0 ? `${Math.round(member.averageQualityScore)}% quality` : 'No evals yet'}
          </span>
        </div>
      </div>
      <div className="hidden w-44 shrink-0 sm:block">
        <TeamAvailabilityIndicator member={member} compact />
      </div>
      <button
        type="button"
        onClick={() => onViewProfile(member)}
        className="shrink-0 rounded-lg bg-[var(--color-accent-blue)] px-3 py-2 text-xs font-semibold text-white hover:opacity-95"
      >
        View profile
      </button>
    </div>
  )
}
