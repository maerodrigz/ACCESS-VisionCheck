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
}

export function PriorityBadge({ priority }: { priority: RequestPriority }) {
  const color = priorityColors[priority]
  return (
    <span
      className="inline-flex rounded-md border px-2 py-0.5 text-[10px] font-bold"
      style={{ color, borderColor: `${color}40`, backgroundColor: `${color}14` }}
    >
      {priorityLabel(priority)}
    </span>
  )
}

export function StatusBadge({ status }: { status: RequestDisplayStatus }) {
  const color = statusColors[status]
  return (
    <span
      className="inline-flex rounded-full px-2.5 py-1 text-[11px] font-bold"
      style={{ color, backgroundColor: `${color}1f` }}
    >
      {statusLabel(status)}
    </span>
  )
}

const avatarColors = ['#2563eb', '#16a34a', '#7c3aed', '#0891b2', '#f59e0b']

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
