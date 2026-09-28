import { NavLink } from 'react-router-dom'

import { sidebarSections } from '../config/navigation'

import { AccessBrand } from './AccessBrand'

interface SidebarNavProps {
  onNavigate?: () => void
}

export function SidebarBrand({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex h-full items-center px-4">
      <AccessBrand linkToHome markSize={compact ? 36 : 40} />
    </div>
  )
}

export function SidebarNav({ onNavigate }: SidebarNavProps) {
  return (
    <nav className="h-full overflow-y-auto px-3 py-4 pb-6">
      {sidebarSections.map((section, si) => (
        <div key={section.label ?? 'root'} className={si > 0 ? 'mt-6' : ''}>
          {section.label && (
            <div className="mb-2 px-3 text-[10px] font-bold tracking-[0.14em] text-[var(--color-accent-cyan)]">
              {section.label}
            </div>
          )}
          <ul className="space-y-1">
            {section.items.map((item) => (
              <li key={item.id}>
                <NavLink
                  to={item.path}
                  end={item.path === '/'}
                  onClick={onNavigate}
                  className={({ isActive }) =>
                    [
                      'flex items-center gap-2.5 rounded-xl px-2.5 py-2 text-[13px] font-semibold transition-all',
                      isActive
                        ? 'bg-[var(--nav-active-bg)] text-white'
                        : 'text-[var(--color-sidebar-text)] hover:bg-white/5 hover:text-white',
                    ].join(' ')
                  }
                >
                  {({ isActive }) => (
                    <>
                      <span
                        className={[
                          'flex h-7 w-7 shrink-0 items-center justify-center rounded-lg',
                          isActive
                            ? 'bg-white/16 text-white'
                            : 'bg-white/[0.06] text-[var(--color-accent-cyan)]',
                        ].join(' ')}
                      >
                        <item.icon size={16} strokeWidth={2} />
                      </span>
                      <span>{item.label}</span>
                    </>
                  )}
                </NavLink>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </nav>
  )
}

export function Sidebar({ onNavigate }: SidebarNavProps) {
  return (
    <aside
      className="flex h-full shrink-0 flex-col bg-[var(--color-sidebar-bg)]"
      style={{ width: 'var(--sidebar-width)' }}
    >
      <div className="flex h-[var(--topbar-height)] shrink-0 items-center border-b border-[var(--color-sidebar-border)] bg-[var(--color-sidebar-bg)] px-4">
        <AccessBrand linkToHome markSize={40} />
      </div>
      <SidebarNav onNavigate={onNavigate} />
    </aside>
  )
}
