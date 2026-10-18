import { useState } from 'react'
import { LogOut } from 'lucide-react'
import { NavLink } from 'react-router-dom'

import { sidebarSections } from '../config/navigation'
import { useAuth } from '../context/AuthContext'

import { AccessBrand } from './AccessBrand'
import { LogoutConfirmDialog } from './LogoutConfirmDialog'

interface SidebarNavProps {
  onNavigate?: () => void
}

export function SidebarBrand({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex h-full items-center px-2">
      <AccessBrand linkToHome compact onCyanBackground markSize={compact ? 32 : 34} />
    </div>
  )
}

function SidebarSignOutFooter({ onSignOutClick }: { onSignOutClick: () => void }) {
  return (
    <div className="mt-2 shrink-0 border-t border-[var(--color-sidebar-border)] px-1.5 pt-2 pb-1">
      <button
        type="button"
        onClick={onSignOutClick}
        className="group flex w-full items-center gap-2 rounded-lg px-1.5 py-1.5 text-[12px] font-semibold leading-tight tracking-tight text-[var(--color-sidebar-text-muted)] transition-all hover:bg-red-500/12 hover:text-[var(--color-danger)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-white/50"
      >
        <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-md bg-white/25 text-[var(--color-sidebar-text-muted)] transition-colors group-hover:bg-red-500/15 group-hover:text-[var(--color-danger)]">
          <LogOut size={14} strokeWidth={2} aria-hidden />
        </span>
        <span className="min-w-0 flex-1 truncate text-left">Sign out</span>
      </button>
    </div>
  )
}

export function SidebarNav({ onNavigate }: SidebarNavProps) {
  const { logout } = useAuth()
  const [logoutOpen, setLogoutOpen] = useState(false)

  const confirmLogout = () => {
    setLogoutOpen(false)
    onNavigate?.()
    logout()
  }

  return (
    <>
      <nav className="flex h-full min-h-0 flex-col overflow-hidden px-0 py-2">
        <div className="min-h-0 flex-1 overflow-x-hidden overflow-y-auto px-1.5">
          {sidebarSections.map((section, si) => (
            <div key={section.label ?? 'root'} className={si > 0 ? 'mt-2' : ''}>
              {section.label && (
                <div className="mb-0.5 px-1.5 text-[8px] font-bold tracking-[0.1em] text-[var(--color-sidebar-text-muted)]">
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
                          'flex items-center gap-2 rounded-lg px-1.5 py-1.5 text-[12px] font-semibold leading-tight tracking-tight transition-all',
                          isActive
                            ? 'bg-[var(--nav-active-bg)] text-[var(--nav-active-text)] shadow-sm'
                            : 'text-[var(--color-sidebar-text)] hover:bg-white/45 hover:text-[var(--color-sidebar-text)]',
                        ].join(' ')
                      }
                    >
                      {({ isActive }) => (
                        <>
                          <span
                            className={[
                              'flex h-6 w-6 shrink-0 items-center justify-center rounded-md',
                              isActive
                                ? 'bg-[var(--nav-active-icon-bg)] text-[var(--nav-active-icon-color)]'
                                : 'bg-[var(--nav-icon-bg)] text-[var(--nav-icon-color)]',
                            ].join(' ')}
                          >
                            <item.icon size={14} strokeWidth={2} />
                          </span>
                          <span className="min-w-0 flex-1 truncate" title={item.label}>
                            {item.label}
                          </span>
                        </>
                      )}
                    </NavLink>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <SidebarSignOutFooter onSignOutClick={() => setLogoutOpen(true)} />
      </nav>

      <LogoutConfirmDialog
        open={logoutOpen}
        onCancel={() => setLogoutOpen(false)}
        onConfirm={confirmLogout}
      />
    </>
  )
}

export function Sidebar({ onNavigate }: SidebarNavProps) {
  return (
    <aside
      className="admin-sidebar flex h-full shrink-0 flex-col"
      style={{ width: 'var(--sidebar-width)' }}
    >
      <div className="admin-sidebar flex h-[var(--topbar-height)] shrink-0 items-center border-b border-[var(--color-sidebar-border)] px-2">
        <AccessBrand linkToHome compact onCyanBackground markSize={34} />
      </div>
      <div className="flex min-h-0 flex-1 flex-col overflow-hidden">
        <SidebarNav onNavigate={onNavigate} />
      </div>
    </aside>
  )
}
