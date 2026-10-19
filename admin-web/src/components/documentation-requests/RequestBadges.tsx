import type { AssignedMember, RequestDisplayStatus, RequestPriority } from '../../lib/documentationRequests'
import { priorityLabel, statusLabel } from '../../lib/documentationRequests'

const priorityColors: Record<RequestPriority, string> = {
  urgent: 'var(--color-danger)',
  high: '#ea580c',
  normal: 'var(--color-accent-blue)',
  low: 'var(--color-text-secondary)',
}

const statusColors: Record<RequestDisplayStatus, string> = {
  pending: 'var(--color-warning)',
  approved: 'var(--color-accent-blue)',
  rejected: 'var(--color-danger)',
  completed: 'var(--color-success)',
  archived: 'var(--color-text-secondary)',
}

function tint(color: string, percent: number) {
  return `color-mix(in srgb, ${color} ${percent}%, transparent)`
}

export function PriorityBadge({ priority }: { priority: RequestPriority }) {
  const color = priorityColors[priority]
  return (
    <span
      className="inline-flex rounded-full px-1.5 py-0.5 text-[10px] font-semibold leading-none"
      style={{ color, backgroundColor: tint(color, 14) }}
    >
      {priorityLabel(priority)}
    </span>
  )
}

export function StatusBadge({ status }: { status: RequestDisplayStatus }) {
  const color = statusColors[status]
  return (
    <span
      className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-semibold leading-none"
      style={{ color, backgroundColor: tint(color, 14) }}
    >
      <span className="h-1.5 w-1.5 shrink-0 rounded-full" style={{ backgroundColor: color }} aria-hidden />
      {statusLabel(status)}
    </span>
  )
}

const avatarColors = ['#2563eb', '#16a34a', '#7c3aed', '#0891b2', '#f59e0b']

/** Initials plus the member name, for the request table. */
export function AssignedMemberList({ members, maxVisible = 2 }: { members: AssignedMember[]; maxVisible?: number }) {
  if (members.length === 0) {
    return <p className="text-[11px] text-[var(--color-text-muted)]">Unassigned</p>
  }

  const visible = members.slice(0, maxVisible)
  const extra = members.length - visible.length

  return (
    <ul className="space-y-1">
      {visible.map((m, i) => (
        <li key={m.id} className="flex min-w-0 items-center gap-1.5">
          <span
            className="inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[8px] font-bold"
            style={{
              backgroundColor: tint(avatarColors[i % avatarColors.length], 16),
              color: avatarColors[i % avatarColors.length],
            }}
            aria-hidden
          >
            {m.initials}
          </span>
          <span className="truncate text-[11px] font-medium text-[var(--color-text-primary)]">{m.name}</span>
        </li>
      ))}
      {extra > 0 ? (
        <li className="pl-6 text-[10px] font-semibold text-[var(--color-text-secondary)]">+{extra} more</li>
      ) : null}
    </ul>
  )
}

export function MemberAvatarStack({ members, maxVisible = 3 }: { members: AssignedMember[]; maxVisible?: number }) {
  if (members.length === 0) {
    return <span className="text-[11px] text-[var(--color-text-secondary)]">Unassigned</span>
  }

  const visible = members.slice(0, maxVisible)
  const extra = members.length - visible.length

  return (
    <div className="flex items-center">
      {visible.map((m, i) => (
        <span
          key={m.id}
          className="-ml-1 inline-flex h-7 w-7 items-center justify-center rounded-full border-2 border-white text-[9px] font-extrabold first:ml-0"
          style={{
            backgroundColor: `${avatarColors[i % avatarColors.length]}22`,
            color: avatarColors[i % avatarColors.length],
            zIndex: visible.length - i,
          }}
          title={m.name}
        >
          {m.initials}
        </span>
      ))}
      {extra > 0 && (
        <span className="-ml-1 inline-flex h-7 w-7 items-center justify-center rounded-full border-2 border-white bg-slate-200 text-[9px] font-bold text-slate-600">
          +{extra}
        </span>
      )}
    </div>
  )
}
