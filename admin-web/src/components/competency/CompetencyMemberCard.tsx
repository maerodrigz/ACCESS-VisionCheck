import { AdminCard } from '../AdminCard'
import type { CompetencyMember } from '../../lib/competency'
import { memberInitialsFromCompetency, memberNeedsReview } from '../../lib/competency'
import { TeamAvailabilityIndicator, TeamCoverageBadge } from '../documentation-team/TeamMemberBadges'
import { CompetencyLevelBadge, EventRecommendationBadge } from './CompetencyBadges'

interface Props {
  member: CompetencyMember
  onViewProfile: (member: CompetencyMember) => void
}

function StatTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-2.5 py-2.5">
      <div className="text-sm font-extrabold">{value}</div>
      <div className="text-[10px] text-[var(--color-text-secondary)]">{label}</div>
    </div>
  )
}

export function CompetencyMemberCard({ member, onViewProfile }: Props) {
  const m = member
  const highlight = memberNeedsReview(m)
  return (
    <AdminCard
      as="article"
      hover
      padding="md"
      className={['flex h-full flex-col', highlight ? 'border-amber-200/80' : ''].join(' ')}
    >
      <div className="flex items-start gap-3">
        <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-[var(--color-accent-blue)]/15 text-lg font-extrabold text-[var(--color-accent-blue)]">
          {memberInitialsFromCompetency(m)}
        </div>
        <div className="min-w-0 flex-1">
          <h3 className="truncate font-bold">{m.profile.name}</h3>
          <div className="mt-1">
            <TeamCoverageBadge role={m.profile.coverageRole} />
          </div>
        </div>
        <CompetencyLevelBadge level={m.currentLevel} overridden={m.levelOverridden} compact />
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2">
        <StatTile label="Performance" value={`${Math.round(m.profile.performanceScore)}%`} />
        <StatTile label="Acceptance" value={`${Math.round(m.mediaAcceptanceRate)}%`} />
      </div>

      <div className="mt-3">
        <TeamAvailabilityIndicator member={m.profile} compact />
      </div>

      {m.profile.currentAssignment && (
        <p className="mt-2 truncate text-[11px] text-[var(--color-text-secondary)]">
          Assignment: {m.profile.currentAssignment.eventName}
        </p>
      )}

      <div className="mt-3">
        <EventRecommendationBadge recommendation={m.eventRecommendation} />
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
