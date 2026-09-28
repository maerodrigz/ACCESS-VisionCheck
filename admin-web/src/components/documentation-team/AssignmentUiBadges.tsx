import { Camera, Video } from 'lucide-react'

export function RoleLabel({ role }: { role: string }) {
  const label = role.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
  const isVideo = role.toLowerCase().includes('video')
  return (
    <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-[var(--color-text-primary)]">
      {isVideo ? (
        <Video size={14} className="text-[var(--color-accent-blue)]" />
      ) : (
        <Camera size={14} className="text-[var(--color-accent-blue)]" />
      )}
      {label}
    </span>
  )
}

const availabilityStyles: Record<string, { bg: string; text: string; label: string }> = {
  available: { bg: 'rgba(22,163,74,0.12)', text: '#16a34a', label: 'Available' },
  limited: { bg: 'rgba(245,158,11,0.14)', text: '#d97706', label: 'Limited' },
  unavailable: { bg: 'rgba(220,38,38,0.1)', text: '#dc2626', label: 'Unavailable' },
}

export function AvailabilityPill({ availability }: { availability: string }) {
  const style = availabilityStyles[availability] ?? {
    bg: 'rgba(100,116,139,0.12)',
    text: 'var(--color-text-secondary)',
    label: availability,
  }
  return (
    <span
      className="inline-flex rounded-full px-2 py-0.5 text-[10px] font-bold"
      style={{ backgroundColor: style.bg, color: style.text }}
    >
      {style.label}
    </span>
  )
}

export function AssignmentStatusBadge({ status }: { status: string }) {
  const s = status.toLowerCase().replace(/\s+/g, '_')
  let bg = 'rgba(100,116,139,0.12)'
  let text = 'var(--color-text-secondary)'
  let label = status.replace(/_/g, ' ')

  if (s === 'accepted' || s === 'completed' || s === 'in_progress') {
    bg = 'rgba(22,163,74,0.12)'
    text = '#16a34a'
    label = s === 'accepted' ? 'Accepted' : label.replace(/\b\w/g, (c) => c.toUpperCase())
  } else if (s === 'declined') {
    bg = 'rgba(220,38,38,0.1)'
    text = '#dc2626'
    label = 'Declined'
  } else if (s === 'pending_acceptance' || s === 'assigned') {
    bg = 'rgba(245,158,11,0.14)'
    text = '#d97706'
    label = 'Awaiting acceptance'
  }

  return (
    <span
      className="inline-flex shrink-0 rounded-full px-2 py-0.5 text-[10px] font-bold capitalize"
      style={{ backgroundColor: bg, color: text }}
    >
      {label}
    </span>
  )
}

export function RankBadge({ index }: { index: number }) {
  if (index > 2) {
    return (
      <span className="inline-flex h-5 min-w-[1.25rem] items-center justify-center rounded-md bg-[var(--color-surface-muted)] px-1 text-[10px] font-bold text-[var(--color-text-secondary)]">
        {index + 1}
      </span>
    )
  }
  const colors = ['#f59e0b', '#94a3b8', '#b45309']
  return (
    <span
      className="inline-flex h-5 min-w-[1.25rem] items-center justify-center rounded-md px-1 text-[10px] font-extrabold text-white"
      style={{ backgroundColor: colors[index] }}
    >
      #{index + 1}
    </span>
  )
}
