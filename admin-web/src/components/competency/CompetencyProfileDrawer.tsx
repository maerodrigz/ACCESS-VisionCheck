import { useEffect, useState, type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  CalendarCheck,
  CheckCircle2,
  Image,
  MessageSquare,
  Send,
  TrendingUp,
  Users,
  X,
} from 'lucide-react'
import { AdminDrawer } from '../AdminDrawer'
import type { CompetencyLevel, CompetencyMember } from '../../lib/competency'
import { competencyLevelLabel, memberNeedsReview } from '../../lib/competency'
import { MemberAvatar, TeamAvailabilityIndicator, TeamCoverageBadge } from '../documentation-team/TeamMemberBadges'
import {
  CompetencyLevelBadge,
  CompetencyProgressBar,
  CriterionRow,
  EventRecommendationBadge,
} from './CompetencyBadges'
import { MemberRecentUploadsSection } from '../documentation-team/MemberRecentUploadsSection'

interface Props {
  member: CompetencyMember | null
  saving?: boolean
  onClose: () => void
  onSendNotesToMember: (notes: string) => boolean | Promise<boolean>
  onUpdateLevel: (level: CompetencyLevel | 'system') => void
}

export function CompetencyProfileDrawer({
  member,
  saving = false,
  onClose,
  onSendNotesToMember,
  onUpdateLevel,
}: Props) {
  const navigate = useNavigate()
  const [notes, setNotes] = useState('')
  const [showLevelPicker, setShowLevelPicker] = useState(false)
  const [showNotesEditor, setShowNotesEditor] = useState(false)

  useEffect(() => {
    if (member) {
      setNotes(member.adminNotes ?? '')
      setShowNotesEditor(false)
      setShowLevelPicker(false)
    }
  }, [member])

  if (!member) return null
  const m = member
  const needsReview = memberNeedsReview(m)
  const hasActiveAssignment = m.profile.availability === 'assigned' && m.profile.currentAssignment != null

  return (
    <AdminDrawer
      open
      onClose={onClose}
      title="Competency profile"
      maxWidth="xl"
      bodyClassName="px-5 pb-5"
      footer={
        showNotesEditor ? (
          <div className="flex flex-nowrap items-center gap-2 overflow-x-auto bg-[var(--color-surface-muted)] p-3">
            <button
              type="button"
              disabled={saving}
              onClick={() => setShowLevelPicker((v) => !v)}
              className={[
                'inline-flex shrink-0 items-center gap-1.5 rounded-lg border px-3 py-2 text-sm font-semibold transition disabled:opacity-50',
                showLevelPicker
                  ? 'border-[var(--color-accent-cyan)] bg-[var(--color-accent-cyan)]/15 text-[var(--color-accent-cyan)]'
                  : 'border-[var(--color-accent-cyan)]/35 bg-[var(--color-accent-cyan)]/10 text-[var(--color-accent-cyan)] hover:bg-[var(--color-accent-cyan)]/15',
              ].join(' ')}
            >
              <TrendingUp size={15} />
              Update Level
            </button>
            <button
              type="button"
              disabled={saving}
              onClick={() => {
                onClose()
                const requestId = m.profile.currentAssignment?.requestId
                navigate(
                  requestId
                    ? `/documentation-requests?request=${requestId}`
                    : '/documentation-requests',
                )
              }}
              className="inline-flex shrink-0 items-center gap-1.5 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2 text-sm font-medium text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)] disabled:opacity-50"
            >
              <CalendarCheck size={15} className="text-[var(--color-accent-blue)]" />
              {hasActiveAssignment ? 'View assignment' : 'Assign to Event'}
            </button>
            <button
              type="button"
              disabled={saving}
              onClick={() => {
                onClose()
                navigate(`/members?q=${encodeURIComponent(m.profile.name)}`)
              }}
              className="inline-flex shrink-0 items-center gap-1.5 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2 text-sm font-medium text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)] disabled:opacity-50"
            >
              <Users size={15} className="text-[var(--color-text-secondary)]" />
              Team roster
            </button>
            <button
              type="button"
              disabled={saving}
              onClick={() => {
                onClose()
                navigate(`/media/member-uploads?q=${encodeURIComponent(m.profile.name)}`)
              }}
              className="inline-flex shrink-0 items-center gap-1.5 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2 text-sm font-medium text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)] disabled:opacity-50"
            >
              <Image size={15} className="text-[var(--color-text-secondary)]" />
              All uploads
            </button>
          </div>
        ) : undefined
      }
    >
          {needsReview && (
            <div className="mt-3 rounded-xl border border-amber-500/30 bg-amber-500/10 px-3 py-2.5 text-xs text-amber-200">
              {m.integrityViolations > 0
                ? 'Integrity violations on record. Review before large event assignments.'
                : m.currentLevel !== m.recommendedLevel
                  ? 'Current level differs from the system recommendation.'
                  : 'Open integrity warnings. Confirm status in Media Integrity.'}
            </div>
          )}
          <div className="flex flex-col items-center py-4 text-center">
            <MemberAvatar name={m.profile.name} avatarUrl={m.profile.avatarUrl} size="lg" />
            <h3 className="mt-3 text-xl font-extrabold">{m.profile.name}</h3>
            <TeamCoverageBadge role={m.profile.coverageRole} />
            <div className="mt-3 flex flex-wrap justify-center gap-4">
              <div>
                <div className="text-[10px] text-[var(--color-text-secondary)]">Current</div>
                <CompetencyLevelBadge level={m.currentLevel} overridden={m.levelOverridden} />
                {m.levelOverridden && (
                  <p className="mt-1 max-w-[140px] text-[10px] leading-snug text-[var(--color-text-secondary)]">
                    Admin override stays until cleared, even after new evaluations.
                  </p>
                )}
              </div>
              <div>
                <div className="text-[10px] text-[var(--color-text-secondary)]">Recommended</div>
                <CompetencyLevelBadge level={m.recommendedLevel} />
              </div>
            </div>
            {!showNotesEditor && (
              <button
                type="button"
                disabled={saving}
                onClick={() => setShowLevelPicker((v) => !v)}
                className="mt-3 text-[11px] font-semibold text-[var(--color-accent-cyan)] hover:underline disabled:opacity-50"
              >
                {showLevelPicker ? 'Hide level options' : 'Update level'}
              </button>
            )}
          </div>

          <Section title="Availability">
            <TeamAvailabilityIndicator member={m.profile} />
          </Section>

          <Section title="Recent uploads">
            <MemberRecentUploadsSection memberName={m.profile.name} uploads={m.profile.recentUploads} />
          </Section>

          <Section title="Performance metrics">
            <div className="space-y-3">
              <CompetencyProgressBar label="Overall performance" value={m.profile.performanceScore} />
              <CompetencyProgressBar label="Media acceptance rate" value={m.mediaAcceptanceRate} />
              <CompetencyProgressBar label="Skill score" value={m.assessment.skillScore} />
            </div>
          </Section>

          <Section title="Event recommendation">
            <EventRecommendationBadge recommendation={m.eventRecommendation} />
          </Section>

          <Section title="Assessment criteria">
            <div className="space-y-2">
              {m.assessment.criteria.map((c) => (
                <CriterionRow key={c.label} label={c.label} met={c.met} detail={c.detail} />
              ))}
            </div>
            <p className="mt-3 text-sm leading-relaxed text-[var(--color-text-secondary)]">{m.assessment.explanation}</p>
          </Section>

          <Section title="Strengths">
            <TagList items={m.strengths} />
          </Section>

          <Section title="Areas for improvement">
            <TagList items={m.areasForImprovement} />
          </Section>

          <Section title="Training recommendations">
            <ul className="list-inside list-disc space-y-1 text-sm text-[var(--color-text-secondary)]">
              {m.trainingRecommendations.map((t) => (
                <li key={t}>{t}</li>
              ))}
            </ul>
          </Section>

          <Section
            title="Media integrity"
            action={
              !showNotesEditor ? (
                <button
                  type="button"
                  disabled={saving}
                  onClick={() => setShowNotesEditor(true)}
                  className="inline-flex items-center gap-1 text-xs font-semibold text-[var(--color-accent-blue)] hover:underline disabled:opacity-50"
                >
                  <MessageSquare size={13} />
                  {m.adminNotes?.trim() ? 'Edit note' : 'Write note'}
                </button>
              ) : null
            }
          >
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3 text-sm">
              {m.integritySummary}
            </div>
          </Section>

          {showNotesEditor ? (
            <div className="mt-5 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-4">
              <div className="mb-3 flex items-center justify-between gap-2">
                <h4 className="text-sm font-bold text-[var(--color-text-primary)]">Admin note</h4>
                <button
                  type="button"
                  disabled={saving}
                  onClick={() => {
                    setShowNotesEditor(false)
                    setNotes(m.adminNotes ?? '')
                  }}
                  className="rounded-lg p-1 text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)] disabled:opacity-50"
                  aria-label="Close note editor"
                >
                  <X size={16} />
                </button>
              </div>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={4}
                autoFocus
                className="admin-input w-full rounded-xl px-3 py-2 text-sm outline-none focus:border-[var(--color-accent-cyan)]"
                placeholder="Guidance for this member, e.g. avoid AI-generated uploads…"
              />
              <p className="mt-2 text-[11px] leading-relaxed text-[var(--color-text-secondary)]">
                Sends to the member&apos;s Home dashboard under Latest Feedback and alerts them in-app.
              </p>
              <div className="mt-3 flex flex-wrap gap-2">
                <button
                  type="button"
                  disabled={saving || !notes.trim()}
                  onClick={async () => {
                    const sent = await onSendNotesToMember(notes)
                    if (sent) setShowNotesEditor(false)
                  }}
                  className="inline-flex items-center gap-2 rounded-lg bg-[var(--color-accent-blue)] px-4 py-2 text-sm font-semibold text-white hover:opacity-95 disabled:opacity-50"
                >
                  <Send size={15} />
                  Send to Member
                </button>
                <button
                  type="button"
                  disabled={saving}
                  onClick={() => {
                    setShowNotesEditor(false)
                    setNotes(m.adminNotes ?? '')
                  }}
                  className="rounded-lg border border-[var(--color-border)] px-4 py-2 text-sm font-semibold text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)] disabled:opacity-50"
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : null}

          {showLevelPicker && (
            <div className="mt-4 space-y-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
              <div className="text-xs font-bold text-[var(--color-text-secondary)]">Update competency level</div>
              <p className="text-[11px] leading-relaxed text-[var(--color-text-secondary)]">
                Overrides sync to the member profile and remain in effect until you choose system recommendation.
              </p>
              {(['beginner', 'intermediate', 'advanced'] as CompetencyLevel[]).map((level) => (
                <button
                  key={level}
                  type="button"
                  onClick={() => {
                    onUpdateLevel(level)
                    setShowLevelPicker(false)
                  }}
                  className="block w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2 text-left text-sm font-semibold hover:bg-[var(--color-surface-hover)]"
                >
                  {competencyLevelLabel(level)}
                </button>
              ))}
              <button
                type="button"
                onClick={() => {
                  onUpdateLevel('system')
                  setShowLevelPicker(false)
                }}
                className="block w-full rounded-lg border border-[var(--color-accent-blue)]/30 bg-[var(--color-accent-blue)]/15 px-3 py-2 text-left text-sm font-semibold text-[var(--color-accent-blue)]"
              >
                Use system recommendation ({competencyLevelLabel(m.recommendedLevel)})
              </button>
            </div>
          )}
    </AdminDrawer>
  )
}

function Section({
  title,
  action,
  children,
}: {
  title: string
  action?: ReactNode
  children: ReactNode
}) {
  return (
    <div className="mt-5">
      <div className="flex items-center justify-between gap-2">
        <h4 className="text-sm font-bold text-[var(--color-text-primary)]">{title}</h4>
        {action}
      </div>
      <div className="mt-2">{children}</div>
    </div>
  )
}

function TagList({ items }: { items: string[] }) {
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((item) => (
        <span
          key={item}
          className="inline-flex items-center gap-1 rounded-full bg-emerald-50 px-2.5 py-1 text-[11px] font-semibold text-emerald-700"
        >
          <CheckCircle2 size={12} />
          {item}
        </span>
      ))}
    </div>
  )
}
