import type { ComponentPropsWithoutRef, ElementType, ReactNode } from 'react'

const shadow = 'shadow-[0_8px_32px_rgba(0,0,0,0.24)]'

type AdminCardProps<T extends ElementType = 'div'> = {
  as?: T
  children: ReactNode
  className?: string
  bodyClassName?: string
  padding?: 'none' | 'sm' | 'md' | 'lg'
  hover?: boolean
  dashed?: boolean
} & Omit<ComponentPropsWithoutRef<T>, 'as' | 'children' | 'className'>

const paddingClass = {
  none: '',
  sm: 'p-4',
  md: 'p-5',
  lg: 'p-6',
} as const

/** Standard admin surface card — radius, border, shadow. */
export function AdminCard<T extends ElementType = 'div'>({
  as,
  children,
  className = '',
  bodyClassName = '',
  padding = 'md',
  hover = false,
  dashed = false,
  ...rest
}: AdminCardProps<T>) {
  const Tag = as ?? 'div'

  return (
    <Tag
      className={[
        'flex flex-col overflow-hidden rounded-[var(--card-radius)] border bg-[var(--color-surface)]',
        dashed ? 'border-dashed border-[var(--color-border)]' : 'border-[var(--color-border)]',
        shadow,
        hover
          ? 'transition hover:border-[var(--color-accent-blue)]/30 hover:bg-[var(--color-surface-elevated)]'
          : '',
        className,
      ]
        .filter(Boolean)
        .join(' ')}
      {...rest}
    >
      <div className={[paddingClass[padding], bodyClassName].filter(Boolean).join(' ')}>{children}</div>
    </Tag>
  )
}

/** Shared card shell classes for rare custom layouts (prefer AdminCard). */
export const adminCardShellClass =
  'flex flex-col overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] shadow-[0_8px_32px_rgba(0,0,0,0.24)]'
