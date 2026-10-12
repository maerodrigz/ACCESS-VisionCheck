import { useCallback, useEffect, useState, type FormEvent } from 'react'

import { Bell, Loader2, Menu, Search } from 'lucide-react'

import { useLocation, useNavigate } from 'react-router-dom'

import { fetchNotifications } from '../api/notifications'

import { useAuth } from '../context/AuthContext'

import { useToast } from '../context/ToastContext'

import { resolveGlobalSearch } from '../lib/globalAdminSearch'

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

  const { showToast } = useToast()

  const onNotifications = location.pathname === '/notifications'

  const [unread, setUnread] = useState(0)
  const [searchQuery, setSearchQuery] = useState('')
  const [searching, setSearching] = useState(false)

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

  async function handleGlobalSearch(e: FormEvent) {
    e.preventDefault()
    const q = searchQuery.trim()
    if (!q || searching) return
    setSearching(true)
    try {
      const result = await resolveGlobalSearch(q)
      navigate(result.path)
      showToast(result.hint, 'info')
    } catch {
      navigate(`/documentation-requests?q=${encodeURIComponent(q)}`)
      showToast('Opened documentation requests with your search.', 'info')
    } finally {
      setSearching(false)
    }
  }

  if (!user) return null

  const pageTitle = pageTitleForPath(location.pathname)
  const onHome = location.pathname === '/'

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

      {!mobile && onHome ? (
        <form
          className="relative hidden min-w-0 max-w-md flex-1 md:block"
          onSubmit={handleGlobalSearch}
          role="search"
        >
          <Search
            size={16}
            className="pointer-events-none absolute left-3 top-1/2 z-[1] -translate-y-1/2 text-[var(--color-text-muted)]"
          />
          <input
            type="search"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            disabled={searching}
            placeholder="Search requests, events, members, or media..."
            className="h-10 w-full rounded-xl border border-[var(--color-border)] bg-[var(--topbar-search-bg)] pl-9 pr-10 text-sm text-[var(--color-text-primary)] placeholder:text-[var(--color-text-muted)] disabled:opacity-70"
            aria-label="Search admin workspace"
          />
          {searching ? (
            <Loader2
              size={16}
              className="absolute right-3 top-1/2 -translate-y-1/2 animate-spin text-[var(--color-text-muted)]"
            />
          ) : null}
        </form>
      ) : (
        <h1 className="min-w-0 truncate text-base font-extrabold tracking-tight text-[var(--color-text-primary)] md:text-lg">
          {pageTitle}
        </h1>
      )}

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
