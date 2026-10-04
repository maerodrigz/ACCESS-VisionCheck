import { useEffect, useId, useRef, useState } from 'react'

import { ChevronDown } from 'lucide-react'

export interface AdminSelectOption {
  value: string
  label: string
}

interface AdminSelectProps {
  value: string
  onChange: (value: string) => void
  options: AdminSelectOption[]
  className?: string
  buttonClassName?: string
  disabled?: boolean
  placement?: 'bottom' | 'top'
  'aria-label'?: string
}

const triggerClass =
  'admin-input flex w-full items-center justify-between gap-2 rounded-xl px-3 py-2 text-left text-sm text-[var(--color-text-primary)] transition hover:bg-[var(--color-surface-hover)] disabled:cursor-not-allowed disabled:opacity-50'

const menuClass =
  'absolute left-0 right-0 z-50 max-h-60 overflow-y-auto rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] py-1 shadow-[0_12px_32px_rgba(0,0,0,0.35)]'

const optionClass = (active: boolean) =>
  [
    'flex w-full px-3 py-2 text-left text-sm transition',
    active
      ? 'bg-[var(--nav-active-bg)] font-semibold text-white'
      : 'text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]',
  ].join(' ')

/** Dark-themed dropdown — replaces native select so options stay readable. */
export function AdminSelect({
  value,
  onChange,
  options,
  className = '',
  buttonClassName = '',
  disabled = false,
  placement = 'bottom',
  'aria-label': ariaLabel,
}: AdminSelectProps) {
  const [open, setOpen] = useState(false)
  const wrapRef = useRef<HTMLDivElement>(null)
  const listboxId = useId()
  const selected = options.find((o) => o.value === value)

  useEffect(() => {
    if (!open) return

    const onPointerDown = (e: MouseEvent) => {
      if (!wrapRef.current?.contains(e.target as Node)) setOpen(false)
    }

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }

    document.addEventListener('mousedown', onPointerDown)
    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('mousedown', onPointerDown)
      document.removeEventListener('keydown', onKeyDown)
    }
  }, [open])

  return (
    <div ref={wrapRef} className={['relative', className].filter(Boolean).join(' ')}>
      <button
        type="button"
        disabled={disabled}
        aria-label={ariaLabel}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listboxId}
        onClick={() => setOpen((v) => !v)}
        className={[triggerClass, buttonClassName].filter(Boolean).join(' ')}
      >
        <span className="min-w-0 truncate">{selected?.label ?? 'Select…'}</span>
        <ChevronDown
          size={16}
          className={['shrink-0 text-[var(--color-text-muted)] transition', open ? 'rotate-180' : ''].join(' ')}
          aria-hidden
        />
      </button>

      {open ? (
        <ul
          id={listboxId}
          role="listbox"
          aria-label={ariaLabel}
          className={[
            menuClass,
            placement === 'top' ? 'bottom-[calc(100%+4px)]' : 'top-[calc(100%+4px)]',
          ].join(' ')}
        >
          {options.map((opt) => {
            const active = opt.value === value
            return (
              <li key={opt.value || '__empty'} role="option" aria-selected={active}>
                <button
                  type="button"
                  className={optionClass(active)}
                  onClick={() => {
                    onChange(opt.value)
                    setOpen(false)
                  }}
                >
                  {opt.label}
                </button>
              </li>
            )
          })}
        </ul>
      ) : null}
    </div>
  )
}
