import type { LucideIcon } from 'lucide-react'
import { useState } from 'react'

export interface OverviewStatItem {
  icon: LucideIcon
  label: string
  sublabel: string
  value: string | number
  color: string
  bgColor: string
  onClick?: () => void
  badge?: boolean
}

interface Props {
  items: OverviewStatItem[]
}

/** Compact horizontal KPI tiles (short rectangles). */
export function DashboardOverviewStrip({ items }: Props) {
  return (
    <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-4">
      {items.map((item) => (
        <OverviewKpiCard key={item.label} item={item} />
      ))}
    </div>
  )
}

function OverviewKpiCard({ item }: { item: OverviewStatItem }) {
  const [hovered, setHovered] = useState(false)
  const Icon = item.icon

  const inner = (
    <div className="flex h-[62px] items-center gap-2.5 px-3 py-2">
      <div
        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg"
        style={{ backgroundColor: `color-mix(in srgb, ${item.color} 18%, white)`, color: item.color }}
      >
        <Icon size={16} strokeWidth={2.25} />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline gap-1.5">
          <span className="text-lg font-extrabold leading-none tabular-nums text-[var(--color-text-primary)]">
            {item.value}
          </span>
          {item.badge ? (
            <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[var(--color-danger)]" aria-hidden />
          ) : null}
        </div>
        <p className="mt-0.5 truncate text-[11px] font-semibold leading-tight text-[var(--color-text-primary)]">
          {item.label}
        </p>
        <p className="truncate text-[10px] leading-tight text-[var(--color-text-secondary)]">{item.sublabel}</p>
      </div>
    </div>
  )

  const className = [
    'rounded-xl border border-[var(--color-border)] text-left transition-shadow duration-150',
    hovered && item.onClick ? 'shadow-[var(--color-card-hover-shadow)]' : 'shadow-[0_1px_2px_rgba(15,39,68,0.04)]',
  ].join(' ')

  if (item.onClick) {
    return (
      <button
        type="button"
        onClick={item.onClick}
        className={className}
        style={{ backgroundColor: item.bgColor }}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
      >
        {inner}
      </button>
    )
  }

  return (
    <div className={className} style={{ backgroundColor: item.bgColor }}>
      {inner}
    </div>
  )
}
