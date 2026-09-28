import type { LucideIcon } from 'lucide-react'
import { StatCard } from '../StatCard'

export interface OverviewStatItem {
  icon: LucideIcon
  label: string
  value: string | number
  color: string
  onClick?: () => void
}

interface Props {
  items: OverviewStatItem[]
}

/** Overview stats — semantic StatCards (one accent system, color on icon only). */
export function DashboardOverviewStrip({ items }: Props) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
      {items.map((item) => (
        <StatCard
          key={item.label}
          icon={item.icon}
          label={item.label}
          value={item.value}
          color={item.color}
          onClick={item.onClick}
        />
      ))}
    </div>
  )
}
