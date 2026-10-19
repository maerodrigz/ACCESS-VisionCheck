export type RequestFilterTab = 'all' | 'pending' | 'approved' | 'rejected' | 'completed' | 'archived'

export type RequestDisplayStatus = 'pending' | 'approved' | 'rejected' | 'completed' | 'archived'

export type RequestPriority = 'urgent' | 'high' | 'normal' | 'low'

export type RequestSortOption = 'newest' | 'oldest' | 'eventDateAsc' | 'eventDateDesc' | 'priority'

export interface AssignedMember {
  id: number
  name: string
  role: string
  initials: string
}

export interface DocumentationRequestItem {
  id: number
  requesterId: number
  eventTitle: string
  requestor: string
  eventDate?: Date
  venue?: string
  details?: string
  rawStatus: string
  displayStatus: RequestDisplayStatus
  priority: RequestPriority
  createdAt?: Date
  assignedMembers: AssignedMember[]
  rejectionReason?: string
  eventDateLabel: string
  createdAtLabel: string
  startTime?: string
  endTime?: string
  archivedAt?: Date
}

function parseDate(raw: unknown): Date | undefined {
  if (raw == null) return undefined
  const d = new Date(String(raw))
  return Number.isNaN(d.getTime()) ? undefined : d
}

function formatDate(d?: Date): string {
  if (!d) return '—'
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

/** Requestor submission timestamp for admin review (local timezone). */
function formatClock(raw?: string | null): string {
  const value = (raw ?? '').trim()
  if (!value) return ''
  const part = value.includes('T') ? (value.split('T')[1] ?? value) : value
  const d = new Date(`1970-01-01T${part}`)
  if (!Number.isNaN(d.getTime())) {
    const h = d.getHours() % 12 || 12
    const m = d.getMinutes().toString().padStart(2, '0')
    const ap = d.getHours() >= 12 ? 'PM' : 'AM'
    return `${h}:${m} ${ap}`
  }
  return value
}

/** Event coverage window from request start/end times. */
export function formatRequestTimeRange(start?: string | null, end?: string | null): string {
  const from = formatClock(start)
  const to = formatClock(end)
  if (from && to && from !== to) return `${from} – ${to}`
  if (from) return from
  return 'Not specified'
}

export function formatRequestSubmittedAt(d?: Date): string {
  if (!d) return '—'
  return d.toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

function deriveDisplayStatus(
  rawStatus: string,
  archivedAt?: Date,
  _eventDate?: Date,
  _tasks: Record<string, unknown>[] = [],
): RequestDisplayStatus {
  if (archivedAt) return 'archived'
  const s = rawStatus.toLowerCase()
  if (s === 'rejected') return 'rejected'
  if (s === 'pending') return 'pending'
  if (s === 'completed') return 'completed'
  if (s === 'approved') return 'approved'
  return 'pending'
}

function derivePriority(eventDate: Date | undefined, status: RequestDisplayStatus): RequestPriority {
  if (status === 'completed' || status === 'archived' || status === 'rejected') return 'low'
  if (!eventDate) return 'normal'
  const days = Math.floor((eventDate.getTime() - Date.now()) / 86400000)
  if (days < 0) return 'high'
  if (days <= 2) return 'urgent'
  if (days <= 7) return 'high'
  if (days <= 21) return 'normal'
  return 'low'
}

function memberInitials(name: string): string {
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase()
  return name ? name[0].toUpperCase() : '?'
}

export function parseDocumentationRequest(
  request: Record<string, unknown>,
  tasksForRequest: Record<string, unknown>[] = [],
): DocumentationRequestItem {
  const eventDate = parseDate(request.event_date)
  const createdAt = parseDate(request.created_at)
  const rawStatus = String(request.status ?? 'Pending')
  const archivedAt = parseDate(request.archived_at)

  const assignedMembers: AssignedMember[] = tasksForRequest.map((t) => {
    const name = String(t.member_name ?? 'Member')
    return {
      id: Number(t.member_id ?? 0),
      name,
      role: String(t.task_role ?? 'photographer'),
      initials: memberInitials(name),
    }
  })

  const displayStatus = deriveDisplayStatus(rawStatus, archivedAt, eventDate, tasksForRequest)
  const priority = derivePriority(eventDate, displayStatus)

  return {
    id: Number(request.request_id ?? request.id ?? 0),
    requesterId: Number(request.requester_id ?? 0),
    eventTitle: String(request.event_name ?? request.title ?? 'Documentation request'),
    requestor: String(request.requester_name ?? 'Unknown'),
    eventDate,
    venue: request.venue != null ? String(request.venue) : undefined,
    details: request.details != null ? String(request.details) : request.description != null ? String(request.description) : undefined,
    rawStatus,
    displayStatus,
    priority,
    createdAt,
    assignedMembers,
    rejectionReason: request.rejection_reason != null ? String(request.rejection_reason) : undefined,
    eventDateLabel: formatDate(eventDate),
    createdAtLabel: formatDate(createdAt) || 'Recently',
    startTime: request.start_time != null ? String(request.start_time) : undefined,
    endTime: request.end_time != null ? String(request.end_time) : undefined,
    archivedAt,
  }
}

export function matchesFilter(item: DocumentationRequestItem, tab: RequestFilterTab): boolean {
  if (tab === 'archived') return item.displayStatus === 'archived'
  if (item.displayStatus === 'archived') return false
  if (tab === 'all') return true
  return item.displayStatus === tab
}

export function filterAndSortRequests(
  items: DocumentationRequestItem[],
  opts: {
    tab: RequestFilterTab
    search: string
    sort: RequestSortOption
    priorityFilter?: RequestPriority | null
  },
): DocumentationRequestItem[] {
  const q = opts.search.trim().toLowerCase()
  let list = items.filter((item) => {
    if (!matchesFilter(item, opts.tab)) return false
    if (opts.priorityFilter && item.priority !== opts.priorityFilter) return false
    if (!q) return true
    return (
      item.eventTitle.toLowerCase().includes(q) ||
      item.requestor.toLowerCase().includes(q) ||
      (item.venue ?? '').toLowerCase().includes(q) ||
      requestRefLabel(item.id).toLowerCase().includes(q) ||
      String(item.id).includes(q.replace(/\D/g, ''))
    )
  })

  const priorityRank: Record<RequestPriority, number> = {
    urgent: 4,
    high: 3,
    normal: 2,
    low: 1,
  }

  list = [...list].sort((a, b) => {
    switch (opts.sort) {
      case 'oldest':
        return (a.createdAt?.getTime() ?? 0) - (b.createdAt?.getTime() ?? 0)
      case 'eventDateAsc':
        return (a.eventDate?.getTime() ?? Infinity) - (b.eventDate?.getTime() ?? Infinity)
      case 'eventDateDesc':
        return (b.eventDate?.getTime() ?? 0) - (a.eventDate?.getTime() ?? 0)
      case 'priority':
        return priorityRank[b.priority] - priorityRank[a.priority]
      default:
        return (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0)
    }
  })

  return list
}

export function countByStatus(items: DocumentationRequestItem[]): Record<RequestDisplayStatus, number> {
  return {
    pending: items.filter((i) => i.displayStatus === 'pending').length,
    approved: items.filter((i) => i.displayStatus === 'approved').length,
    rejected: items.filter((i) => i.displayStatus === 'rejected').length,
    completed: items.filter((i) => i.displayStatus === 'completed').length,
    archived: items.filter((i) => i.displayStatus === 'archived').length,
  }
}

export function priorityLabel(p: RequestPriority): string {
  return p.charAt(0).toUpperCase() + p.slice(1)
}

export function statusLabel(s: RequestDisplayStatus): string {
  return s.charAt(0).toUpperCase() + s.slice(1)
}

/** Human-readable request reference for admin queues (e.g. REQ-0012). */
export function requestRefLabel(id: number): string {
  return `REQ-${String(id).padStart(4, '0')}`
}
