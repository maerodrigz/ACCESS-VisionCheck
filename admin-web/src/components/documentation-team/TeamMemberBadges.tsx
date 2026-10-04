import { Camera, Star, Video } from 'lucide-react'
import type {
  MemberAccountLabel,
  SkillLevelTier,
  TeamAvailability,
  TeamCoverageRole,
  TeamMemberProfile,
} from '../../lib/teamMembers'
import {
  availabilitySubtitle,
  availabilityTitle,
  coverageRoleLabel,
  memberAccountLabel,
  memberInitials,
  skillLevelLabel,
} from '../../lib/teamMembers'

const avatarSizes = {
  xs: 'h-8 w-8 text-[11px]',
  sm: 'h-11 w-11 text-sm',
  md: 'h-14 w-14 text-lg',
  lg: 'h-20 w-20 text-2xl',
} as const

export function MemberAvatar({
  name,
  avatarUrl,
  size = 'md',
  className = '',
  fallbackClassName = 'bg-[var(--color-accent-blue)]/15 text-[var(--color-accent-blue)]',
}: {
  name: string
  avatarUrl?: string | null
  size?: keyof typeof avatarSizes
  className?: string
  fallbackClassName?: string
}) {
  const sizeClass = avatarSizes[size]
  if (avatarUrl) {
    return (
      <img
        src={avatarUrl}
        alt=""
        className={`shrink-0 rounded-full object-cover bg-[var(--color-accent-blue)]/15 ${sizeClass} ${className}`}
      />
    )
  }
  return (
    <div
      className={`flex shrink-0 items-center justify-center rounded-full font-extrabold ${fallbackClassName} ${sizeClass} ${className}`}
    >
      {memberInitials(name)}
    </div>
  )
}

const skillColors: Record<SkillLevelTier, { bg: string; text: string }> = {
  expert: { bg: 'rgba(124,58,237,0.12)', text: '#7C3AED' },
  advanced: { bg: 'rgba(37,99,235,0.12)', text: 'var(--color-accent-blue)' },
  intermediate: { bg: 'rgba(20,177,208,0.12)', text: 'var(--color-accent-cyan)' },
  beginner: { bg: 'rgba(100,116,139,0.12)', text: 'var(--color-text-secondary)' },
}

export function TeamCoverageBadge({ role }: { role: TeamCoverageRole }) {
  if (role === 'unassigned') {
    return (
      <span className="inline-flex rounded-md border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-semibold text-[var(--color-text-secondary)]">
        Role pending
      </span>
    )
  }
  const isPhoto = role === 'photographer'
  return (
    <span className="inline-flex items-center gap-1 rounded-full bg-[var(--color-accent-blue)]/15 px-2 py-0.5 text-[10px] font-semibold leading-none text-[var(--color-accent-blue)]">
      {isPhoto ? <Camera size={12} /> : <Video size={12} />}
      {coverageRoleLabel(role)}
    </span>
  )
}

export function SkillLevelBadge({ tier, label }: { tier: SkillLevelTier; label: string }) {
  const colors = skillColors[tier]
  return (
    <span
      className="inline-flex shrink-0 rounded-md px-2 py-0.5 text-[10px] font-bold"
      style={{ backgroundColor: colors.bg, color: colors.text }}
    >
      {label}
    </span>
  )
}

const availabilityColors: Record<TeamAvailability, string> = {
  available: 'var(--color-success)',
  assigned: 'var(--color-warning)',
  unavailable: 'var(--color-text-muted)',
}

export function TeamAvailabilityIndicator({
  member,
  compact = false,
}: {
  member: TeamMemberProfile
  compact?: boolean
}) {
  const color = availabilityColors[member.availability]
  const title = availabilityTitle(member.availability)
  const subtitle = availabilitySubtitle(member)
  const tooltip = subtitle && subtitle !== title ? `${title}: ${subtitle}` : title

  const statusPill = (
    <span
      className={[
        'inline-flex max-w-full shrink-0 items-center gap-1.5 rounded-full font-semibold',
        compact ? 'px-2 py-0.5 text-[10px] leading-none' : 'px-2.5 py-1 text-[11px]',
      ].join(' ')}
      style={{ backgroundColor: `color-mix(in srgb, ${color} 14%, transparent)`, color }}
    >
      <span className="h-1.5 w-1.5 shrink-0 rounded-full" style={{ backgroundColor: color }} aria-hidden />
      <span className="truncate">{title}</span>
    </span>
  )

  if (compact) {
    return (
      <span title={tooltip} className="inline-flex max-w-full">
        {statusPill}
      </span>
    )
  }

  return (
    <div className="flex flex-wrap items-center gap-x-3 gap-y-1" title={tooltip}>
      {statusPill}
      {subtitle && subtitle !== title ? (
        <span className="min-w-0 text-xs leading-snug text-[var(--color-text-secondary)]">{subtitle}</span>
      ) : null}
    </div>
  )
}

export function TeamPerformanceBar({
  label,
  value,
  max,
  suffix = '',
}: {
  label: string
  value: number
  max: number
  suffix?: string
}) {
  const pct = max > 0 ? Math.min(1, Math.max(0, value / max)) : 0
  return (
    <div>
      <div className="flex items-center justify-between text-[11px]">
        <span className="text-[var(--color-text-secondary)]">{label}</span>
        <span className="font-bold text-[var(--color-text-primary)]">
          {Math.round(value)}
          {suffix}
        </span>
      </div>
      <div className="mt-1.5 h-1.5 overflow-hidden rounded bg-[var(--color-border)]">
        <div
          className="h-full rounded bg-[var(--color-accent-blue)] transition-all"
          style={{ width: `${pct * 100}%` }}
        />
      </div>
    </div>
  )
}

export function MemberSkillBadge({ member }: { member: TeamMemberProfile }) {
  return <SkillLevelBadge tier={member.skillTier} label={skillLevelLabel(member)} />
}

/** Roster label for the three competency groups already used on the dashboard. */
function rosterCompetencyLabel(member: TeamMemberProfile): 'Amateur' | 'Developing' | 'Advanced' {
  const raw = `${member.skillLevel ?? ''} ${member.skillTier}`.toLowerCase()
  if (raw.includes('advanced') || raw.includes('expert')) return 'Advanced'
  if (raw.includes('develop') || raw.includes('intermediate')) return 'Developing'
  return 'Amateur'
}

export function RosterCompetencyBadge({ member }: { member: TeamMemberProfile }) {
  const label = rosterCompetencyLabel(member)
  const color =
    label === 'Advanced'
      ? 'var(--color-accent-blue)'
      : label === 'Developing'
        ? 'var(--color-accent-cyan)'
        : 'var(--color-text-secondary)'
  return (
    <span
      className="inline-flex rounded-full px-1.5 py-0.5 text-[10px] font-semibold leading-none"
      style={{ color, backgroundColor: `color-mix(in srgb, ${color} 14%, transparent)` }}
    >
      {label}
    </span>
  )
}

const accountStatusStyles: Record<MemberAccountLabel, { bg: string; text: string }> = {
  Active: { bg: 'rgba(16,185,129,0.12)', text: '#059669' },
  Inactive: { bg: 'rgba(100,116,139,0.12)', text: 'var(--color-text-secondary)' },
  Pending: { bg: 'rgba(245,158,11,0.12)', text: '#D97706' },
}

export function MemberAccountStatusBadge({ member }: { member: TeamMemberProfile }) {
  const label = memberAccountLabel(member)
  const colors = accountStatusStyles[label]
  return (
    <span
      className="inline-flex shrink-0 rounded-full px-2 py-0.5 text-[10px] font-semibold leading-none"
      style={{ backgroundColor: colors.bg, color: colors.text }}
    >
      {label}
    </span>
  )
}

export function MemberRequesterRatingDisplay({
  member,
  compact = false,
}: {
  member: TeamMemberProfile
  compact?: boolean
}) {
  if (member.requesterRatingCount <= 0 || member.requesterRatingAvg == null) {
    return <span className="text-[11px] text-[var(--color-text-muted)]">No ratings</span>
  }

  const rounded = Math.round(member.requesterRatingAvg * 10) / 10
  const filled = Math.round(member.requesterRatingAvg)

  if (compact) {
    return (
      <span
        className="inline-flex items-center gap-1"
        aria-label={`${rounded} out of 5 from ${member.requesterRatingCount} rating${member.requesterRatingCount === 1 ? '' : 's'}`}
      >
        <Star size={13} className="fill-amber-400 text-amber-400" strokeWidth={1.5} />
        <span className="text-xs font-semibold tabular-nums text-[var(--color-text-primary)]">{rounded}</span>
        <span className="text-[10px] text-[var(--color-text-muted)]">({member.requesterRatingCount})</span>
      </span>
    )
  }

  return (
    <div className="min-w-[88px]">
      <div className="flex items-center gap-0.5" aria-label={`${rounded} out of 5 average from requestors`}>
        {Array.from({ length: 5 }, (_, i) => (
          <Star
            key={i}
            size={13}
            className={i < filled ? 'fill-amber-400 text-amber-400' : 'text-[var(--color-text-muted)]'}
            strokeWidth={1.5}
          />
        ))}
      </div>
      <div className="mt-1 text-[11px] font-semibold text-[var(--color-text-primary)]">{rounded}/5</div>
      <div className="text-[10px] text-[var(--color-text-muted)]">
        {member.requesterRatingCount} rating{member.requesterRatingCount === 1 ? '' : 's'}
      </div>
    </div>
  )
}
