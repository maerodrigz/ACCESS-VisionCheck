import type { LucideIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { LayoutGrid } from 'lucide-react'
import { AdminFeatureHeader } from './AdminFeatureHeader'

/**
 * @deprecated Prefer `AdminFeatureHeader` with an explicit feature icon.
 * Kept so older call sites still render the unified colored header.
 */
export function AdminPageHeader({
  title = 'Admin',
  subtitle,
  actions,
  backTo,
  backLabel,
  icon,
}: {
  title?: string
  subtitle: string
  actions?: ReactNode
  backTo?: string
  backLabel?: string
  compact?: boolean
  icon?: LucideIcon
}) {
  return (
    <AdminFeatureHeader
      icon={icon ?? LayoutGrid}
      title={title}
      description={subtitle}
      actions={actions}
      backTo={backTo}
      backLabel={backLabel}
    />
  )
}
