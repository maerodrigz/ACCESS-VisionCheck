import { Activity, Home, Bell, Shield, Image, Lock } from 'lucide-react'
import {
  SYSTEM_CONFIG_SECTIONS,
  type SystemConfigSectionId,
} from '../../lib/systemConfiguration'

const SECTION_ICONS: Record<SystemConfigSectionId, typeof Home> = {
  general: Home,
  notifications: Bell,
  ai_evaluation: Shield,
  media: Image,
  security: Lock,
  monitor: Activity,
}

interface Props {
  activeSection: SystemConfigSectionId
  dirtySections: Set<SystemConfigSectionId>
  onNavigate: (section: SystemConfigSectionId) => void
}

function NavItem({
  section,
  active,
  dirty,
  onNavigate,
  variant,
}: {
  section: (typeof SYSTEM_CONFIG_SECTIONS)[number]
  active: boolean
  dirty: boolean
  onNavigate: (section: SystemConfigSectionId) => void
  variant: 'sidebar' | 'tabs'
}) {
  const Icon = SECTION_ICONS[section.id]
  const className = [
    'sys-config__nav-item',
    active ? 'is-active' : '',
    dirty ? 'has-unsaved' : '',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <button
      type="button"
      className={className}
      onClick={() => onNavigate(section.id)}
      aria-current={active ? 'page' : undefined}
      role={variant === 'tabs' ? 'tab' : undefined}
    >
      <span className="sys-config__nav-icon" aria-hidden>
        <Icon size={18} strokeWidth={2} />
      </span>
      <span className="sys-config__nav-label">{section.label}</span>
      {dirty ? <span className="sys-config__nav-dot" aria-label="Unsaved changes" /> : null}
    </button>
  )
}

export function SystemConfigNav({ activeSection, dirtySections, onNavigate }: Props) {
  const items = SYSTEM_CONFIG_SECTIONS.map((section) => (
    <NavItem
      key={section.id}
      section={section}
      active={activeSection === section.id}
      dirty={dirtySections.has(section.id)}
      onNavigate={onNavigate}
      variant="sidebar"
    />
  ))

  return (
    <>
      <aside className="sys-config__nav sys-config__nav--sidebar" aria-label="Settings sections">
        <div className="sys-config__nav-title">Settings</div>
        <div className="sys-config__nav-list">{items}</div>
      </aside>
      <div className="sys-config__nav sys-config__nav--tabs" role="tablist" aria-label="Settings sections">
        {SYSTEM_CONFIG_SECTIONS.map((section) => (
          <NavItem
            key={`tab-${section.id}`}
            section={section}
            active={activeSection === section.id}
            dirty={dirtySections.has(section.id)}
            onNavigate={onNavigate}
            variant="tabs"
          />
        ))}
      </div>
    </>
  )
}
