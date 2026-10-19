import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CheckCheck, Loader2, Megaphone, Search, Trash2 } from 'lucide-react'
import {
  clearReadNotifications,
  fetchNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from '../api/notifications'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { MemberAnnouncementDialog } from '../components/notifications/BroadcastAnnouncementDialog'
import { NotificationsTable } from '../components/notifications/NotificationsTable'
import { useToast } from '../context/ToastContext'
import {
  pageToolbarBtnClass,
  pageToolbarPrimaryBtnClass,
  PageToolbarRefreshButton,
} from '../components/PageToolbar'
import { emitNotificationsChanged } from '../lib/notificationEvents'
import {
  categoryLabel,
  matchesNotificationFilter,
  parseNotification,
  type AdminNotification,
  type NotificationFilterChip,
} from '../lib/notifications'

const FILTER_CHIPS: { id: NotificationFilterChip; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'unread', label: 'Unread' },
  { id: 'requests', label: 'Requests' },
  { id: 'members', label: 'Members' },
  { id: 'media', label: 'Media' },
  { id: 'integrity', label: 'Integrity' },
  { id: 'feedback', label: 'Feedback' },
  { id: 'system', label: 'System' },
]

function timelineGroup(d: Date | null): 'today' | 'yesterday' | 'earlier' {
  if (!d) return 'earlier'
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  const diff = today.getTime() - day.getTime()
  if (diff === 0) return 'today'
  if (diff === 86400000) return 'yesterday'
  return 'earlier'
}

export function NotificationCenterPage() {
  const navigate = useNavigate()
  const { showToast } = useToast()
  const [items, setItems] = useState<AdminNotification[]>([])
  const [showAnnouncement, setShowAnnouncement] = useState(false)
  const [chip, setChip] = useState<NotificationFilterChip>('unread')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const raw = await fetchNotifications()
      setItems(raw.map(parseNotification).sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0)))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load notifications')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return items.filter((n) => {
      if (!matchesNotificationFilter(n, chip)) return false
      if (!q) return true
      return (
        n.title.toLowerCase().includes(q) ||
        n.message.toLowerCase().includes(q) ||
        categoryLabel(n.category).toLowerCase().includes(q)
      )
    })
  }, [items, chip, search])

  const chipCounts = useMemo(() => {
    const counts = {} as Record<NotificationFilterChip, number>
    for (const c of FILTER_CHIPS) {
      counts[c.id] = items.filter((n) => matchesNotificationFilter(n, c.id)).length
    }
    return counts
  }, [items])

  const unread = items.filter((n) => n.unread).length
  const highPriority = items.filter((n) => n.priority === 'high').length
  const todayCount = items.filter((n) => timelineGroup(n.createdAt) === 'today').length

  async function handleOpen(n: AdminNotification) {
    if (n.unread && n.id > 0) {
      try {
        await markNotificationRead(n.id)
        setItems((prev) => prev.map((x) => (x.id === n.id ? { ...x, unread: false } : x)))
        emitNotificationsChanged()
      } catch {
        /* continue navigation */
      }
    }
    navigate(n.route)
  }

  async function handleMarkAllRead() {
    setBusy(true)
    try {
      await markAllNotificationsRead()
      setItems((prev) => prev.map((n) => ({ ...n, unread: false })))
      emitNotificationsChanged()
    } finally {
      setBusy(false)
    }
  }

  async function handleClearRead() {
    setBusy(true)
    try {
      await clearReadNotifications()
      setItems((prev) => prev.filter((n) => n.unread))
      emitNotificationsChanged()
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-5 pb-8">
      <AdminPageHeader
        title="Notification Center"
        subtitle="Alerts for requests, assignments, media reviews, and system events"
        backTo="/"
        actions={
          <>
            <button
              type="button"
              onClick={() => setShowAnnouncement(true)}
              className={pageToolbarPrimaryBtnClass}
            >
              <Megaphone size={18} strokeWidth={2.25} />
              New announcement
            </button>
            <PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />
          </>
        }
      />

      {error && (
        <AdminErrorBanner>{error}</AdminErrorBanner>
      )}

      <div className="flex flex-wrap gap-2">
        {FILTER_CHIPS.map((f) => (
          <button
            key={f.id}
            type="button"
            onClick={() => setChip(f.id)}
            className={[
              'rounded-full px-4 py-1.5 text-xs font-bold transition',
              chip === f.id
                ? 'bg-[var(--color-accent-blue)] text-white'
                : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
            ].join(' ')}
          >
            {f.label} ({chipCounts[f.id] ?? 0})
          </button>
        ))}
      </div>

      <div className="flex flex-col gap-2 rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
          <div className="relative min-w-0 flex-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
            <input
              type="search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search notifications…"
              className="admin-input w-full rounded-xl py-2 pl-9 pr-3 text-sm"
            />
          </div>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              disabled={busy || unread === 0}
              onClick={handleMarkAllRead}
              className={`${pageToolbarBtnClass} disabled:opacity-50`}
            >
              {busy ? <Loader2 size={16} className="animate-spin" /> : <CheckCheck size={16} />}
              Mark all read
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={handleClearRead}
              className={`${pageToolbarBtnClass} disabled:opacity-50`}
            >
              <Trash2 size={16} />
              Clear read
            </button>
          </div>
        </div>
        <p className="text-xs text-[var(--color-text-muted)]">
          {items.length} total · {unread} unread · {highPriority} high priority · {todayCount} today
        </p>
      </div>

      <div className="flex items-center justify-between gap-2">
        <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Inbox</h2>
        <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
          {filtered.length} alert{filtered.length === 1 ? '' : 's'}
        </span>
      </div>

      {loading && items.length === 0 ? (
        <div className="flex justify-center py-16">
          <Loader2 size={28} className="animate-spin text-[var(--color-accent-blue)]" />
        </div>
      ) : filtered.length === 0 ? (
        <NotificationsTable items={[]} onOpen={handleOpen} />
      ) : (
        <NotificationsTable items={filtered} onOpen={handleOpen} />
      )}

      <MemberAnnouncementDialog
        open={showAnnouncement}
        onClose={() => setShowAnnouncement(false)}
        onSent={() => showToast('Announcement sent to members', 'success')}
      />
    </div>
  )
}
