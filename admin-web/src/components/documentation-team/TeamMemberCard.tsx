import { AdminCard } from '../AdminCard'
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

function StatTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-2.5 py-2.5">
      <div className="text-sm font-extrabold text-[var(--color-text-primary)]">{value}</div>
      <div className="text-[10px] text-[var(--color-text-secondary)]">{label}</div>
    </div>
  )
}

export function TeamMemberCard({ member, onViewProfile }: Props) {
  const m = member
  return (
    <AdminCard as="article" hover padding="md" className="flex h-full flex-col">
      <div className="flex items-start gap-3">
        <MemberAvatar name={m.name} avatarUrl={m.avatarUrl} size="md" />
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-[15px] font-bold text-[var(--color-text-primary)]">{m.name}</h3>
          <div className="mt-1">
            <TeamCoverageBadge role={m.coverageRole} />
          </div>
        </div>
        <MemberSkillBadge member={m} />
      </div>

      <div className="mt-3.5">
        <TeamAvailabilityIndicator member={m} compact />
      </div>

      <div className="mt-3.5 grid grid-cols-3 gap-2">
        <StatTile label="Performance" value={`${Math.round(m.performanceScore)}%`} />
        <StatTile label="Accepted" value={String(m.completedTasks)} />
        <StatTile
          label="Avg quality"
          value={m.averageQualityScore > 0 ? `${Math.round(m.averageQualityScore)}%` : '—'}
        />
      </div>

      <div className="mt-auto pt-4">
        <button
          type="button"
          onClick={() => onViewProfile(m)}
          className="w-full rounded-lg bg-[var(--color-accent-blue)] py-2.5 text-sm font-semibold text-white hover:opacity-95"
        >
          View Profile
        </button>
      </div>
    </AdminCard>
  )
}
