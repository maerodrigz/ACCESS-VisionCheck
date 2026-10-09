import { AlertTriangle } from 'lucide-react'
import type { CompetencyMember } from '../../lib/competency'
import { memberNeedsReview } from '../../lib/competency'
import { MemberAvatar, TeamCoverageBadge } from '../documentation-team/TeamMemberBadges'
import { CompetencyLevelBadge } from './CompetencyBadges'

interface Props {
  members: CompetencyMember[]
  onViewProfile: (member: CompetencyMember) => void
}

export function CompetencyMembersTable({ members, onViewProfile }: Props) {
  if (members.length === 0) {
    return (
      <div className="rounded-[var(--card-radius)] border border-dashed border-[var(--color-border)] px-4 py-10 text-center text-sm text-[var(--color-text-secondary)]">
        No members match your filters.
      </div>
    )
  }

  return (
    <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
      <div className="overflow-x-auto">
      <table className="w-full min-w-[720px] text-left text-sm">
        <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
          <tr>
            <th className="min-w-[220px] px-4 py-3">Member</th>
            <th className="min-w-[160px] px-4 py-3">Competency</th>
            <th className="min-w-[120px] px-4 py-3">Performance</th>
            <th className="min-w-[100px] px-4 py-3 text-right">Action</th>
          </tr>
        </thead>
        <tbody>
          {members.map((member) => {
            const needsReview = memberNeedsReview(member)
            const m = member.profile
            return (
              <tr
                key={m.id}
                className="border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]"
              >
                <td className="px-4 py-3">
                  <div className="flex min-w-0 items-center gap-3">
                    <MemberAvatar name={m.name} avatarUrl={m.avatarUrl} size="sm" />
                    <div className="min-w-0">
                      <div className="truncate font-bold text-[var(--color-text-primary)]">{m.name}</div>
                      <div className="mt-1">
                        <TeamCoverageBadge role={m.coverageRole} />
                      </div>
                      {needsReview ? (
                        <p className="mt-1.5 flex items-center gap-1 text-[11px] text-[var(--color-warning-text)]">
                          <AlertTriangle size={11} className="shrink-0" />
                          Needs review
                        </p>
                      ) : (
                        <p className="mt-1.5 text-[10px] text-[var(--color-text-muted)]">
                          {member.eventsCovered} events · {Math.round(member.mediaAcceptanceRate)}% acceptance
                        </p>
                      )}
                    </div>
                  </div>
                </td>
                <td className="px-4 py-3">
                  <CompetencyLevelBadge level={member.currentLevel} overridden={member.levelOverridden} compact />
                  {member.currentLevel !== member.recommendedLevel && (
                    <p className="mt-1.5 text-[11px] text-[var(--color-text-muted)]">
                      System recommends {member.recommendedLevel}
                    </p>
                  )}
                </td>
                <td className="px-4 py-3">
                  <div className="font-semibold text-[var(--color-text-primary)]">
                    {Math.round(m.performanceScore)}%
                  </div>
                  <div className="mt-0.5 text-[10px] text-[var(--color-text-muted)]">Overall score</div>
                </td>
                <td className="px-4 py-3 text-right">
                  <button
                    type="button"
                    onClick={() => onViewProfile(member)}
                    className="rounded-lg bg-[var(--color-accent-blue)] px-3 py-1.5 text-xs font-semibold text-white hover:opacity-95"
                  >
                    View profile
                  </button>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
      </div>
    </div>
  )
}
