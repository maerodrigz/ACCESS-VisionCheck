import { useCallback, useEffect, useState } from 'react'

import { Bell, Menu } from 'lucide-react'

import { useLocation, useNavigate } from 'react-router-dom'

import { fetchNotifications } from '../api/notifications'

import { useAuth } from '../context/AuthContext'

import { NOTIFICATIONS_CHANGED } from '../lib/notificationEvents'

import { parseNotification } from '../lib/notifications'

import { pageTitleForPath } from '../lib/pageTitles'

import { ProfileDropdown } from './ProfileDropdown'

const topIconBtnClass =
  'relative flex h-10 w-10 items-center justify-center rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[var(--color-text-secondary)] transition hover:border-[var(--color-border)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)]'

interface TopBarProps {
  mobile?: boolean
  onMenuClick?: () => void
}

export function TopBar({ mobile = false, onMenuClick }: TopBarProps) {
  const { user, logout } = useAuth()

  const navigate = useNavigate()

  const location = useLocation()

  const onNotifications = location.pathname === '/notifications'

  const [unread, setUnread] = useState(0)

  const loadUnread = useCallback(async () => {
    try {
      const raw = await fetchNotifications()

      const count = raw.map(parseNotification).filter((n) => n.unread).length

      setUnread(count)
    } catch {
      setUnread(0)
    }
  }, [])

  useEffect(() => {
    loadUnread()

    const interval = window.setInterval(loadUnread, 30000)

    const onChanged = () => loadUnread()

    window.addEventListener(NOTIFICATIONS_CHANGED, onChanged)

    return () => {
      window.clearInterval(interval)

      window.removeEventListener(NOTIFICATIONS_CHANGED, onChanged)
    }
  }, [loadUnread, location.pathname])

  if (!user) return null

  const pageTitle = pageTitleForPath(location.pathname)

  return (
    <header className="flex h-full items-center gap-3 px-4 md:px-6">
      {mobile ? (
        <button
          type="button"
          onClick={onMenuClick}
          className={topIconBtnClass}
          aria-label="Open navigation menu"
        >
          <Menu size={18} />
        </button>
      ) : null}

      <h1 className="min-w-0 truncate text-base font-extrabold tracking-tight text-[var(--color-text-primary)] md:text-lg">
        {pageTitle}
      </h1>

      <div className="ml-auto flex shrink-0 items-center gap-2">
        <button
          type="button"
          onClick={() => navigate('/notifications')}
          className={[
            topIconBtnClass,
            onNotifications ? 'border-[var(--color-accent-primary)]/50 text-[var(--color-accent-primary)]' : '',
          ].join(' ')}
          title="Notifications"
          aria-label={`Notifications${unread > 0 ? `, ${unread} unread` : ''}`}
        >
          <Bell size={18} />

          {unread > 0 ? (
            <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-[var(--color-danger)] px-1 text-[9px] font-bold text-white">
              {unread > 9 ? '9+' : unread}
            </span>
          ) : null}
        </button>

        <ProfileDropdown user={user} onLogout={logout} />
      </div>
    </header>
  )
}
