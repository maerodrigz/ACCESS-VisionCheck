import type { ReactNode } from 'react'

import { AdminBackButton } from './AdminBackButton'

export function AdminPageHeader({
  subtitle,
  actions,
  backTo,
  backLabel,
}: {
  /** @deprecated Feature name is shown in the top bar. Kept for call-site compatibility. */
  title?: string
  subtitle: string
  actions?: ReactNode
  backTo?: string
  backLabel?: string
}) {
  return (
    <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
      <div className="min-w-0 flex-1">
        {backTo ? <AdminBackButton to={backTo} label={backLabel ?? 'Back to dashboard'} /> : null}

        <p className={`text-sm leading-relaxed text-[var(--color-text-secondary)] ${backTo ? 'mt-2' : ''}`}>
          {subtitle}
        </p>

      </div>

      {actions ? (

        <div className="flex w-full shrink-0 flex-wrap items-center justify-end gap-2 lg:w-auto">

          {actions}

        </div>

      ) : null}

    </div>

  )

}


