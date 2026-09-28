import type { ReactNode } from 'react'
import type { SectionSaveState } from '../../lib/systemConfiguration'

export function ConfigToggle({
  label,
  hint,
  checked,
  disabled,
  onChange,
}: {
  id?: string
  label: string
  hint?: string
  checked: boolean
  disabled?: boolean
  onChange: (checked: boolean) => void
}) {
  return (
    <div className="sys-config__row">
      <div className="sys-config__row-text">
        <div className="sys-config__row-label">{label}</div>
        {hint ? <div className="sys-config__row-hint">{hint}</div> : null}
      </div>
      <label className="sys-config__toggle">
        <input
          type="checkbox"
          checked={checked}
          disabled={disabled}
          onChange={(e) => onChange(e.target.checked)}
        />
        <span className="sys-config__toggle-track" />
      </label>
    </div>
  )
}

export function SectionStatus({
  state,
  error,
}: {
  state: SectionSaveState
  error: string | null
}) {
  if (state === 'saving') {
    return <span className="sys-config__card-status sys-config__card-status--saving">Saving…</span>
  }
  if (state === 'success') {
    return <span className="sys-config__card-status sys-config__card-status--success">Saved</span>
  }
  if (state === 'error' && error) {
    return <span className="sys-config__card-status sys-config__card-status--error">{error}</span>
  }
  return null
}

export function ConfigCard({
  icon,
  title,
  description,
  wide,
  children,
  footer,
}: {
  icon: ReactNode
  title: string
  description: string
  wide?: boolean
  children: ReactNode
  footer: ReactNode
}) {
  return (
    <article className={`sys-config__card${wide ? ' sys-config__card--wide' : ''}`}>
      <div className="sys-config__card-head">
        <div className="sys-config__card-icon">{icon}</div>
        <div>
          <h2 className="sys-config__card-title">{title}</h2>
          <p className="sys-config__card-desc">{description}</p>
        </div>
      </div>
      <div className="sys-config__card-body">{children}</div>
      <div className="sys-config__card-foot">{footer}</div>
    </article>
  )
}

export function FieldError({ message }: { message?: string }) {
  if (message) {
    return (
      <span className="sys-config__field-error" role="alert">
        {message}
      </span>
    )
  }
  return <span className="sys-config__field-error" aria-live="polite" />
}
