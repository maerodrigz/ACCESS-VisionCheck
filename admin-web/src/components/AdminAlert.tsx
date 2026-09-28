import type { ReactNode } from 'react'

const toneClass = {
  error: 'admin-alert admin-alert--error',
  success: 'admin-alert admin-alert--success',
  warning: 'admin-alert admin-alert--warning',
} as const

export function AdminAlert({
  tone,
  children,
  className = '',
}: {
  tone: keyof typeof toneClass
  children: ReactNode
  className?: string
}) {
  return <div className={[toneClass[tone], className].filter(Boolean).join(' ')}>{children}</div>
}

/** Page-level API / load error strip. */
export function AdminErrorBanner({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <AdminAlert tone="error" className={className}>
      {children}
    </AdminAlert>
  )
}
