import { Monitor, Moon, Sun } from 'lucide-react'
import { useTheme, type ThemePreference } from '../context/ThemeContext'

const OPTIONS: { id: ThemePreference; label: string; icon: typeof Sun }[] = [
  { id: 'light', label: 'Light', icon: Sun },
  { id: 'dark', label: 'Dark', icon: Moon },
  { id: 'system', label: 'System', icon: Monitor },
]

export function ThemePreferencePicker({ compact = false }: { compact?: boolean }) {
  const { preference, setPreference } = useTheme()

  return (
    <div
      className={compact ? 'theme-picker theme-picker--compact' : 'theme-picker'}
      role="group"
      aria-label="Appearance"
    >
      {!compact ? <span className="theme-picker__label">Appearance</span> : null}
      <div className="theme-picker__options">
        {OPTIONS.map(({ id, label, icon: Icon }) => {
          const active = preference === id
          return (
            <button
              key={id}
              type="button"
              className={['theme-picker__option', active ? 'is-active' : ''].filter(Boolean).join(' ')}
              aria-pressed={active}
              title={label}
              onClick={() => setPreference(id)}
            >
              <Icon size={16} strokeWidth={2} aria-hidden />
              <span className="theme-picker__option-label">{label}</span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
