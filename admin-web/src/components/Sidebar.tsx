import { NavLink } from 'react-router-dom'

import { sidebarSections } from '../config/navigation'

import { AccessBrand } from './AccessBrand'

interface SidebarNavProps {
  onNavigate?: () => void
}

export function SidebarBrand({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex h-full items-center px-3">
      <AccessBrand linkToHome compact markSize={compact ? 36 : 40} />
    </div>
  )
}

export function SidebarNav({ onNavigate }: SidebarNavProps) {
  return (
    <nav className="flex h-full min-h-0 flex-col overflow-hidden px-2 py-2">
      {sidebarSections.map((section, si) => (
        <div key={section.label ?? 'root'} className={si > 0 ? 'mt-2' : ''}>
          {section.label && (
            <div className="mb-0.5 px-2 text-[9px] font-bold tracking-[0.12em] text-[var(--color-accent-cyan)]">
              {section.label}
            </div>
          )}
          <ul className="space-y-0.5">
            {section.items.map((item) => (
              <li key={item.id}>
                <NavLink
                  to={item.path}
                  end={item.path === '/'}
                  onClick={onNavigate}
                  className={({ isActive }) =>
                    [
                      'flex items-center gap-2.5 rounded-lg px-2 py-1.5 text-[13px] font-semibold leading-tight transition-all',
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
                          'flex h-7 w-7 shrink-0 items-center justify-center rounded-md',
                          isActive
                            ? 'bg-white/16 text-white'
                            : 'bg-white/[0.06] text-[var(--color-accent-cyan)]',
                        ].join(' ')}
                      >
                        <item.icon size={15} strokeWidth={2} />
                      </span>
                      <span className="min-w-0 flex-1 whitespace-nowrap">{item.label}</span>
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
      <div className="flex h-[var(--topbar-height)] shrink-0 items-center border-b border-[var(--color-sidebar-border)] bg-[var(--color-sidebar-bg)] px-3">
        <AccessBrand linkToHome compact markSize={40} />
      </div>
      <div className="min-h-0 flex-1 overflow-hidden">
        <SidebarNav onNavigate={onNavigate} />
      </div>
    </aside>
  )
}
