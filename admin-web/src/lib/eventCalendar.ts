export type EventStatus =
  | 'upcoming'
  | 'ongoing'
  | 'completed'
  | 'cancelled'
  | 'pending_documentation'
  | 'assigned'

export interface CalendarEvent {
  id: number
  requestId: number | null
  title: string
  eventDate: Date
  endDate: Date | null
  startTime: string | null
  endTime: string | null
  location: string | null
  description: string | null
  status: EventStatus
  assignedMemberId: number | null
  assignedMemberName: string | null
  documentationTeam: string[]
  requestStatus: string | null
}

const STATUS_COLORS: Record<EventStatus, string> = {
  upcoming: '#2563eb',
  ongoing: '#00c4e8',
  completed: '#16a34a',
  cancelled: '#64748b',
  pending_documentation: '#f59e0b',
  assigned: '#7c3aed',
}

export const EVENT_STATUS_LEGEND: { status: EventStatus; label: string }[] = [
  { status: 'upcoming', label: 'Upcoming' },
  { status: 'assigned', label: 'Assigned' },
  { status: 'ongoing', label: 'Ongoing' },
  { status: 'pending_documentation', label: 'Pending documentation' },
  { status: 'completed', label: 'Completed' },
  { status: 'cancelled', label: 'Cancelled' },
]

export function eventStatusLabel(status: EventStatus): string {
  switch (status) {
    case 'upcoming':
      return 'Upcoming'
    case 'ongoing':
      return 'Ongoing'
    case 'completed':
      return 'Completed'
    case 'cancelled':
      return 'Cancelled'
    case 'pending_documentation':
      return 'Pending Documentation'
    case 'assigned':
      return 'Assigned'
    default:
      return status
  }
}

export function eventStatusColor(status: EventStatus): string {
  return STATUS_COLORS[status] ?? STATUS_COLORS.upcoming
}

function parseStatus(raw: unknown): EventStatus {
  const n = String(raw ?? 'upcoming')
    .toLowerCase()
    .replace(/\s+/g, '_')
  if (n === 'ongoing') return 'ongoing'
  if (n === 'completed') return 'completed'
  if (n === 'cancelled' || n === 'canceled') return 'cancelled'
  if (n === 'pending_documentation') return 'pending_documentation'
  if (n === 'assigned') return 'assigned'
  return 'upcoming'
}

function parseDate(raw: unknown): Date | null {
  if (!raw) return null
  const d = new Date(String(raw))
  return Number.isNaN(d.getTime()) ? null : d
}

function parseTimeSortKey(raw: string | null): number {
  if (!raw) return 9999
  const parts = raw.split(':').map(Number)
  if (parts.length < 2 || parts.some((n) => Number.isNaN(n))) return 9999
  return parts[0] * 60 + parts[1]
}

function parseTeam(raw: unknown): string[] {
  if (!Array.isArray(raw)) return []
  return raw.map((n) => String(n).trim()).filter(Boolean)
}

export function formatEventTime(raw: string | null): string | null {
  if (!raw) return null
  const match = raw.match(/^(\d{1,2}):(\d{2})/)
  if (!match) return raw
  const hour = Number(match[1])
  const minute = match[2]
  const period = hour >= 12 ? 'PM' : 'AM'
  const h12 = hour % 12 || 12
  return `${h12}:${minute} ${period}`
}

export function formatEventTimeRange(startTime: string | null, endTime: string | null): string | null {
  const start = formatEventTime(startTime)
  const end = formatEventTime(endTime)
  if (start && end) return `${start} – ${end}`
  return start ?? end
}

export function parseCalendarEvent(row: Record<string, unknown>): CalendarEvent | null {
  const eventDate = parseDate(row.event_date ?? row.start_date)
  if (!eventDate) return null
  const requestIdRaw = row.request_id ?? row.documentation_request_id
  const requestId =
    requestIdRaw != null && Number(requestIdRaw) > 0 ? Number(requestIdRaw) : null
  return {
    id: Number(row.id ?? row.event_id ?? 0),
    requestId,
    title: String(row.title ?? row.event_name ?? 'Untitled event'),
    eventDate,
    endDate: parseDate(row.end_date),
    startTime: row.start_time != null ? String(row.start_time) : null,
    endTime: row.end_time != null ? String(row.end_time) : null,
    location: row.location != null ? String(row.location) : row.venue != null ? String(row.venue) : null,
    description: row.description != null ? String(row.description) : null,
    status: parseStatus(row.status),
    assignedMemberId:
      row.assigned_member_id != null
        ? Number(row.assigned_member_id)
        : row.assigned_member != null
          ? Number(row.assigned_member)
          : null,
    assignedMemberName:
      row.assigned_member_name != null
        ? String(row.assigned_member_name)
        : row.member_name != null
          ? String(row.member_name)
          : null,
    documentationTeam: parseTeam(row.documentation_team),
    requestStatus: row.request_status != null ? String(row.request_status) : null,
  }
}

function sortByTime(a: CalendarEvent, b: CalendarEvent): number {
  const ta = parseTimeSortKey(a.startTime)
  const tb = parseTimeSortKey(b.startTime)
  if (ta !== tb) return ta - tb
  return a.title.localeCompare(b.title)
}

export function sameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

export function formatEventDate(d: Date): string {
  return d.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })
}

export function formatShortDate(d: Date): string {
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

export function formatCompactDate(d: Date): string {
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

/** People already attached to the event: the request team, or the single assigned member. */
export function eventDocumenters(event: CalendarEvent): string[] {
  if (event.documentationTeam.length > 0) return event.documentationTeam
  if (event.assignedMemberName) return [event.assignedMemberName]
  return []
}

/** Covered when a documenter is assigned, or the event status is already Assigned. */
export function isCoveredEvent(event: CalendarEvent): boolean {
  return event.status === 'assigned' || eventDocumenters(event).length > 0
}

export function eventsOnDay(events: CalendarEvent[], day: Date): CalendarEvent[] {
  return events.filter((e) => sameDay(e.eventDate, day)).sort(sortByTime)
}

export function upcomingEvents(events: CalendarEvent[]): CalendarEvent[] {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return events
    .filter((e) => {
      const d = new Date(e.eventDate)
      d.setHours(0, 0, 0, 0)
      return d >= today
    })
    .sort((a, b) => {
      const dayDiff = a.eventDate.getTime() - b.eventDate.getTime()
      if (dayDiff !== 0) return dayDiff
      return sortByTime(a, b)
    })
}

export function buildMonthGrid(focused: Date): Date[] {
  const year = focused.getFullYear()
  const month = focused.getMonth()
  const first = new Date(year, month, 1)
  const startOffset = (first.getDay() + 6) % 7
  const start = new Date(year, month, 1 - startOffset)
  return Array.from({ length: 42 }, (_, i) => {
    const d = new Date(start)
    d.setDate(start.getDate() + i)
    return d
  })
}
