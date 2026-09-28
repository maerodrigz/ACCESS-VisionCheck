import { NavLink } from 'react-router-dom'
import { Image, Upload } from 'lucide-react'

const TABS = [
  { id: 'events', label: 'Event Media', path: '/media', icon: Image },
  { id: 'members', label: 'Member Uploads', path: '/media/member-uploads', icon: Upload },
] as const

/** Switches between event documentation and member practice uploads inside Media Gallery. */
export function MediaGalleryTabs() {
  return (
    <div className="flex flex-wrap gap-2" role="tablist" aria-label="Media gallery sections">
      {TABS.map((tab) => {
        const Icon = tab.icon
        return (
          <NavLink
            key={tab.id}
            to={tab.path}
            end={tab.path === '/media'}
            role="tab"
            className={({ isActive }) =>
              [
                'inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-xs font-bold transition',
                isActive
                  ? 'bg-[var(--color-accent-blue)] text-white'
                  : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
              ].join(' ')
            }
          >
            <Icon size={14} />
            {tab.label}
          </NavLink>
        )
      })}
    </div>
  )
}
