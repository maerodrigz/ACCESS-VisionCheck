import {
  fetchDashboardStats,
  fetchEvaluations,
  fetchEvents,
  fetchMedia,
  fetchServiceRequests,
  fetchTasks,
} from '../api/admin'
import { fetchNotifications } from '../api/notifications'
import type { DashboardStats } from '../types/auth'
import { formatTimeAgo, parseNotification, type AdminNotification } from './notifications'

export interface HomeOverviewStats {
  pendingRequests: number
  todayEvents: number
  mediaPendingEvaluation: number
  activeMembers: number
  unreadNotifications: number
}

export interface PendingRequestItem {
  id: number
  eventTitle: string
  requestor: string
  requestedDate: string
  status: string
}

export interface TodayScheduleItem {
  timeLabel: string
  eventName: string
  assignedMembers: string
  status: string
}

export interface ActivityItem {
  kind: 'request' | 'media' | 'member' | 'task' | 'feedback'
  title: string
  subtitle: string
  status: string
  time: string
}

export interface MediaQueueSnapshot {
  pendingCount: number
  completedToday: number
}

export interface AnnouncementItem {
  title: string
  body: string
  dateLabel: string
}

export interface HomeDashboardSnapshot {
  overview: HomeOverviewStats
  pendingRequests: PendingRequestItem[]
  todaySchedule: TodayScheduleItem[]
  recentActivity: ActivityItem[]
  notifications: AdminNotification[]
  mediaQueue: MediaQueueSnapshot
  announcements: AnnouncementItem[]
  pendingMembers: number
  stats: DashboardStats
}

function parseDate(raw: unknown): Date | null {
  if (raw == null) return null
  const d = new Date(String(raw))
  return Number.isNaN(d.getTime()) ? null : d
}

function formatDate(raw: unknown): string {
  const d = parseDate(raw)
  if (!d) return '—'
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`
}

function formatTime(raw: string): string {
  const d = new Date(`1970-01-01T${raw}`)
  if (!Number.isNaN(d.getTime())) {
    const h = d.getHours() % 12 || 12
    const m = d.getMinutes().toString().padStart(2, '0')
    const ap = d.getHours() >= 12 ? 'PM' : 'AM'
    return `${h}:${m} ${ap}`
  }
  if (raw.includes(':')) return raw
  return raw
}

function titleCase(s: string): string {
  if (!s) return s
  return s
    .split(' ')
    .map((w) => (w ? `${w[0].toUpperCase()}${w.slice(1).toLowerCase()}` : w))
    .join(' ')
}

function mapPendingRequest(r: Record<string, unknown>): PendingRequestItem {
  return {
    id: Number(r.request_id ?? r.id ?? 0),
    eventTitle: String(r.event_name ?? r.title ?? 'Documentation request'),
    requestor: String(r.requester_name ?? r.organization_name ?? 'Unknown'),
    requestedDate: formatDate(r.created_at),
    status: String(r.status ?? 'Pending'),
  }
}

function mapTodayEvent(e: Record<string, unknown>, tasks: Record<string, unknown>[]): TodayScheduleItem {
  const eventId = Number(e.id)
  const assigned = tasks
    .filter((t) => Number(t.event_id) === eventId)
    .map((t) => String(t.member_name ?? t.assignee_name ?? ''))
    .filter(Boolean)

  const start = (e.start_time ?? e.event_time) as string | undefined
  const timeLabel = start && start.length > 0 ? formatTime(start) : 'All day'

  return {
    timeLabel,
    eventName: String(e.title ?? e.event_name ?? 'Event'),
    assignedMembers: assigned.length === 0 ? 'Unassigned' : assigned.join(', '),
    status: titleCase(String(e.status ?? 'Upcoming').replaceAll('_', ' ')),
  }
}

function activityTitleForRequest(status: string, r: Record<string, unknown>): string {
  const title = String(r.event_name ?? r.title ?? 'Documentation request')
  const s = status.toLowerCase()
  if (s.includes('approv')) return `Request approved: ${title}`
  if (s.includes('reject')) return `Request rejected: ${title}`
  return `New request: ${title}`
}

function buildRecentActivity(
  requests: Record<string, unknown>[],
  media: Record<string, unknown>[],
  evaluations: Record<string, unknown>[],
  notifications: Record<string, unknown>[],
): ActivityItem[] {
  const items: { date: Date | null; item: ActivityItem }[] = []

  for (const r of requests) {
    const d = parseDate(r.created_at)
    const status = String(r.status ?? 'Pending')
    items.push({
      date: d,
      item: {
        kind: 'request',
        title: activityTitleForRequest(status, r),
        subtitle: String(r.requester_name ?? ''),
        status,
        time: formatTimeAgo(r.created_at),
      },
    })
  }

  for (const n of notifications.slice(0, 20)) {
    const cat = String(n.category ?? '').toLowerCase()
    const title = String(n.title ?? '')
    if (cat === 'ai_detection') {
      items.push({
        date: parseDate(n.created_at),
        item: {
          kind: 'media',
          title,
          subtitle: String(n.message ?? n.body ?? ''),
          status: 'Integrity',
          time: formatTimeAgo(n.created_at),
        },
      })
      continue
    }
    if (cat === 'documentation_request' || cat === 'task_assignment' || cat === 'feedback') {
      items.push({
        date: parseDate(n.created_at),
        item: {
          kind: cat === 'documentation_request' ? 'request' : 'media',
          title,
          subtitle: String(n.message ?? n.body ?? ''),
          status: titleCase(cat.replaceAll('_', ' ')),
          time: formatTimeAgo(n.created_at),
        },
      })
      continue
    }
    if (cat.includes('facebook') || title.toLowerCase().includes('facebook')) {
      items.push({
        date: parseDate(n.created_at),
        item: {
          kind: 'media',
          title,
          subtitle: String(n.message ?? n.body ?? ''),
          status: 'Published',
          time: formatTimeAgo(n.created_at),
        },
      })
    }
  }

  for (const e of evaluations.slice(0, 30)) {
    const label = String(e.detection_result ?? e.ai_result ?? '').toLowerCase()
    if (label !== 'suspicious' && label !== 'ai_generated' && !label.includes('generated')) continue
    const score = Number(e.overall_score ?? 0) * 100
    items.push({
      date: parseDate(e.evaluated_at ?? e.created_at),
      item: {
        kind: 'media',
        title: `Media integrity flag: ${String(e.file_name ?? e.media_name ?? 'file')}`,
        subtitle: `${String(e.member_name ?? '')} · ${Math.round(score)}% quality`,
        status: 'Integrity',
        time: formatTimeAgo(e.evaluated_at ?? e.created_at),
      },
    })
  }

  for (const m of media.slice(0, 15)) {
    const label = String(m.detection_result ?? m.ai_result ?? '').toLowerCase()
    if (label !== 'suspicious' && label !== 'ai_generated' && !label.includes('generated')) continue
    items.push({
      date: parseDate(m.uploaded_at ?? m.created_at),
      item: {
        kind: 'media',
        title: `Integrity review needed: ${String(m.file_name ?? m.title ?? 'file')}`,
        subtitle: String(m.uploader_name ?? m.member_name ?? ''),
        status: 'Integrity',
        time: formatTimeAgo(m.uploaded_at ?? m.created_at),
      },
    })
  }

  for (const r of requests
    .filter((x) => {
      const s = String(x.status ?? '').toLowerCase()
      return s.includes('approv') || s.includes('reject')
    })
    .slice(0, 10)) {
    const status = String(r.status ?? '')
    items.push({
      date: parseDate(r.updated_at ?? r.created_at),
      item: {
        kind: 'request',
        title: `Request ${status.toLowerCase()}: ${String(r.event_name ?? r.title ?? 'Documentation')}`,
        subtitle: String(r.requester_name ?? ''),
        status,
        time: formatTimeAgo(r.updated_at ?? r.created_at),
      },
    })
  }

  items.sort((a, b) => (b.date?.getTime() ?? 0) - (a.date?.getTime() ?? 0))
  return items.slice(0, 8).map((e) => e.item)
}

function buildAnnouncements(notifications: AdminNotification[]): AnnouncementItem[] {
  const system = notifications
    .filter(
      (n) => n.category === 'system_alert' || n.title.toLowerCase().includes('announce'),
    )
    .slice(0, 3)
    .map((n) => ({ title: n.title, body: n.message, dateLabel: n.timeAgo }))

  if (system.length > 0) return system

  return [
    {
      title: 'Welcome to ACCESS VisionCheck',
      body: 'Review pending documentation requests daily and assign members before event dates.',
      dateLabel: 'System',
    },
    {
      title: 'Media integrity reminder',
      body: 'Potentially AI-generated uploads are queued for review. Open Media Integrity to verify flagged submissions.',
      dateLabel: 'Operations',
    },
  ]
}

export function buildDailySummary(snap: HomeDashboardSnapshot): string {
  const parts: string[] = []
  const o = snap.overview

  if (o.pendingRequests > 0) {
    parts.push(
      `${o.pendingRequests} documentation request${o.pendingRequests === 1 ? '' : 's'} need${o.pendingRequests === 1 ? 's' : ''} your review.`,
    )
  }
  if (o.todayEvents > 0) {
    parts.push(
      `${o.todayEvents} event${o.todayEvents === 1 ? '' : 's'} scheduled today — confirm assignments and coverage.`,
    )
  }
  if (o.mediaPendingEvaluation > 0) {
    parts.push(
      `${o.mediaPendingEvaluation} media item${o.mediaPendingEvaluation === 1 ? '' : 's'} await AI evaluation.`,
    )
  }
  if (snap.pendingMembers > 0) {
    parts.push(
      `${snap.pendingMembers} member registration${snap.pendingMembers === 1 ? '' : 's'} pending approval.`,
    )
  }
  if (o.unreadNotifications > 0) {
    parts.push(
      `You have ${o.unreadNotifications} unread notification${o.unreadNotifications === 1 ? '' : 's'}.`,
    )
  }
  if (parts.length === 0) {
    return "Operations look clear today. Check Today's Schedule and Recent Activity for anything that may need a follow-up."
  }
  return parts.join(' ')
}

export async function fetchHomeDashboard(): Promise<HomeDashboardSnapshot> {
  const [stats, requests, events, evaluations, media, notificationsRaw, tasks] = await Promise.all([
    fetchDashboardStats(),
    fetchServiceRequests(),
    fetchEvents(),
    fetchEvaluations(),
    fetchMedia(),
    fetchNotifications(),
    fetchTasks(),
  ])

  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())

  const pendingRequests = requests
    .filter((r) => String(r.status ?? 'Pending').toLowerCase() === 'pending')
    .map(mapPendingRequest)
    .sort((a, b) => b.requestedDate.localeCompare(a.requestedDate))

  const todayEvents = events
    .filter((e) => {
      const d = parseDate(e.event_date)
      if (!d) return false
      const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
      if (day.getTime() !== today.getTime()) return false
      const status = String(e.status ?? '').toLowerCase()
      return status !== 'cancelled' && status !== 'canceled'
    })
    .map((e) => mapTodayEvent(e, tasks))
    .sort((a, b) => a.timeLabel.localeCompare(b.timeLabel))

  const evaluatedMediaIds = new Set(
    evaluations.map((e) => Number(e.media_id)).filter((id) => id > 0),
  )
  const pendingMedia = media.filter((m) => {
    const id = Number(m.id)
    return id > 0 && !evaluatedMediaIds.has(id)
  }).length

  const completedToday = evaluations.filter((e) => {
    const d = parseDate(e.evaluated_at ?? e.created_at)
    if (!d) return false
    const day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    return day.getTime() === today.getTime()
  }).length

  const notifications = notificationsRaw
    .map(parseNotification)
    .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0))

  const unread = notifications.filter((n) => n.unread).length

  const overview: HomeOverviewStats = {
    pendingRequests: stats.pending_requests ?? pendingRequests.length,
    todayEvents: todayEvents.length,
    mediaPendingEvaluation: pendingMedia,
    activeMembers: stats.active_members ?? 0,
    unreadNotifications: unread,
  }

  return {
    overview,
    pendingRequests: pendingRequests.slice(0, 6),
    todaySchedule: todayEvents.slice(0, 5),
    recentActivity: buildRecentActivity(requests, media, evaluations, notificationsRaw),
    notifications: notifications.slice(0, 5),
    mediaQueue: { pendingCount: pendingMedia, completedToday },
    announcements: buildAnnouncements(notifications),
    pendingMembers: stats.pending_members ?? 0,
    stats,
  }
}
