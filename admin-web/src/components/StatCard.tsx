import { useState } from 'react'
import type { LucideIcon } from 'lucide-react'
import { AdminCard } from './AdminCard'

/** 12% tint — matches Flutter `color.withValues(alpha: 0.12)` on icon tiles. */
export function statColorTint(color: string, amount = 12) {
  return `color-mix(in srgb, ${color} ${amount}%, transparent)`
}

export function StatIconTile({
  icon: Icon,
  color,
  size = 20,
}: {
  icon: LucideIcon
  color: string
  size?: number
}) {
  return (
    <div
      className="inline-flex rounded-[10px] p-2"
      style={{ backgroundColor: statColorTint(color), color }}
    >
      <Icon size={size} strokeWidth={2} />
    </div>
  )
}

interface StatCardProps {
  icon: LucideIcon
  label: string
  value: string | number
  color: string
  onClick?: () => void
  /** Red dot badge (e.g. unread alerts) — matches Flutter overview cards. */
  badge?: boolean
}

export function StatCard({ icon, label, value, color, onClick, badge }: StatCardProps) {
  const [hovered, setHovered] = useState(false)

  const content = (
    <div className="flex h-full min-h-[108px] flex-col">
      <div className="flex items-start gap-2">
        <StatIconTile icon={icon} color={color} />
        {badge ? (
          <span
            className="ml-auto mt-1.5 h-2 w-2 shrink-0 rounded-full bg-[var(--color-danger)]"
            aria-hidden
          />
        ) : null}
      </div>
      <div className="mt-auto pt-4">
        <div className="text-2xl font-extrabold leading-none text-[var(--color-text-primary)]">{value}</div>
        <div className="mt-1 text-xs font-medium leading-snug text-[var(--color-text-secondary)]">{label}</div>
      </div>
    </div>
  )

  const hoverClass = hovered ? 'shadow-[var(--color-card-hover-shadow)]' : ''
  const hoverStyle =
    hovered && onClick ? { borderColor: statColorTint(color, 35) } : undefined

  if (onClick) {
    return (
      <AdminCard
        as="button"
        type="button"
        onClick={onClick}
        padding="sm"
        hover={false}
        className={`cursor-pointer text-left transition-shadow duration-150 ${hoverClass}`}
        style={hoverStyle}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
      >
        {content}
      </AdminCard>
    )
  }

  return (
    <AdminCard padding="sm" className="text-left">
      {content}
    </AdminCard>
  )
}
