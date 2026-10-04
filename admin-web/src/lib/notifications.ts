export type NotificationCategory =
  | 'documentation_request'
  | 'task_assignment'
  | 'media_evaluation'
  | 'ai_detection'
  | 'feedback'
  | 'system_alert'

export interface AdminNotification {
  id: number
  title: string
  message: string
  unread: boolean
  category: NotificationCategory
  priority: 'high' | 'normal' | 'low'
  actionType: string | null
  actionRefId: number | null
  userName: string | null
  createdAt: Date | null
  timeAgo: string
  route: string
}

export function formatTimeAgo(raw: unknown): string {
  if (raw == null) return 'Recently'
  const dt = new Date(String(raw))
  if (Number.isNaN(dt.getTime())) return 'Recently'
  const diff = Date.now() - dt.getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'Just now'
  if (mins < 60) return `${mins} min ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs} hr ago`
  const days = Math.floor(hrs / 24)
  if (days < 7) return `${days} day${days === 1 ? '' : 's'} ago`
  return `${dt.getMonth() + 1}/${dt.getDate()}/${dt.getFullYear()}`
}

function categoryFromString(raw: string | null | undefined): NotificationCategory {
  switch ((raw ?? '').toLowerCase()) {
    case 'documentation_request':
      return 'documentation_request'
    case 'task_assignment':
      return 'task_assignment'
    case 'media_evaluation':
      return 'media_evaluation'
    case 'ai_detection':
      return 'ai_detection'
    case 'feedback':
      return 'feedback'
    default:
      return 'system_alert'
  }
}

export function routeForNotification(
  actionType: string | null,
  category: NotificationCategory,
  actionRefId: number | null,
): string {
  const ref = actionRefId != null && actionRefId > 0 ? actionRefId : null

  switch (actionType) {
    case 'view_request':
      return ref ? `/documentation-requests?request=${ref}` : '/documentation-requests'
    case 'review_media':
      return ref ? `/media-integrity?media=${ref}` : '/media-integrity'
    case 'view_result':
      return ref ? `/media?media=${ref}` : '/media'
    case 'view_task':
      if (ref) return `/documentation-requests?assignment=${ref}`
      return '/documentation-requests'
    case 'view_feedback':
      return ref ? `/feedback?feedback=${ref}` : '/feedback'
    default:
      switch (category) {
        case 'documentation_request':
          return ref ? `/documentation-requests?request=${ref}` : '/documentation-requests'
        case 'task_assignment':
          return ref ? `/documentation-requests?assignment=${ref}` : '/members'
        case 'media_evaluation':
          return ref ? `/media?media=${ref}` : '/media'
        case 'ai_detection':
          return ref ? `/media-integrity?media=${ref}` : '/media-integrity'
        case 'feedback':
          return ref ? `/feedback?feedback=${ref}` : '/feedback'
        default:
          return '/notifications'
      }
  }
}

export function categoryLabel(category: NotificationCategory): string {
  switch (category) {
    case 'documentation_request':
      return 'Documentation Request'
    case 'task_assignment':
      return 'Task Assignment'
    case 'media_evaluation':
      return 'Media Evaluation'
    case 'ai_detection':
      return 'Media Integrity'
    case 'feedback':
      return 'Requester Feedback'
    default:
      return 'System Alert'
  }
}

export function parseNotification(raw: Record<string, unknown>): AdminNotification {
  const category = categoryFromString(raw.category as string | undefined)
  const actionType = (raw.action_type as string | null) ?? null
  const actionRefId = raw.action_ref_id != null ? Number(raw.action_ref_id) : null
  return {
    id: Number(raw.id ?? -1),
    title: String(raw.title ?? 'Notification'),
    message: String(raw.message ?? raw.body ?? ''),
    unread: raw.is_read !== true,
    category,
    priority: (raw.priority as 'high' | 'normal' | 'low') ?? 'normal',
    actionType,
    actionRefId: Number.isFinite(actionRefId) ? actionRefId : null,
    userName: raw.user_name != null ? String(raw.user_name) : null,
    createdAt: raw.created_at ? new Date(String(raw.created_at)) : null,
    timeAgo: formatTimeAgo(raw.created_at),
    route: routeForNotification(actionType, category, Number.isFinite(actionRefId) ? actionRefId : null),
  }
}

export type NotificationFilterChip =
  | 'all'
  | 'unread'
  | 'requests'
  | 'members'
  | 'media'
  | 'integrity'
  | 'feedback'
  | 'system'

export function matchesNotificationFilter(n: AdminNotification, chip: NotificationFilterChip): boolean {
  switch (chip) {
    case 'all':
      return true
    case 'unread':
      return n.unread
    case 'requests':
      return n.category === 'documentation_request'
    case 'members':
      return n.category === 'task_assignment'
    case 'media':
      return n.category === 'media_evaluation'
    case 'integrity':
      return n.category === 'ai_detection'
    case 'feedback':
      return n.category === 'feedback'
    case 'system':
      return n.category === 'system_alert'
    default:
      return true
  }
}
