import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import {
  CalendarCheck,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  ExternalLink,
  Loader2,
  Pencil,
  Plus,
  Search,
  Trash2,
  Users,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { createEvent, deleteEvent, fetchEvents, fetchUsers, updateEvent } from '../api/admin'
import {
  EventStatusLegend,
  EventUpcomingCards,
  SelectedDayEmpty,
  SelectedDayEventCard,
} from '../components/event-calendar/EventCalendarParts'
import { pageToolbarIconBtnClass, PageToolbarRefreshButton } from '../components/PageToolbar'
import { AdminErrorBanner } from '../components/AdminAlert'
import { useToast } from '../context/ToastContext'
import { AdminSelect } from '../components/AdminSelect'
import { AdminConfirmDialog } from '../components/AdminConfirmDialog'
import { DrawerBackButton } from '../components/AdminBackButton'
import { requestRefLabel } from '../lib/documentationRequests'
import {
  buildMonthGrid,
  eventStatusColor,
  eventStatusLabel,
  eventsOnDay,
  formatEventDate,
  formatEventTimeRange,
  isCoveredEvent,
  parseCalendarEvent,
  sameDay,
  upcomingEvents,
  EVENT_STATUS_LEGEND,
  type CalendarEvent,
  type EventStatus,
} from '../lib/eventCalendar'

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

export function EventCalendarPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [events, setEvents] = useState<CalendarEvent[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<EventStatus | ''>('')
  const [focusedMonth, setFocusedMonth] = useState(() => new Date())
  const [selectedDay, setSelectedDay] = useState(() => new Date())
  const [selectedEvent, setSelectedEvent] = useState<CalendarEvent | null>(null)
  const [showCreate, setShowCreate] = useState(false)
  const [editEvent, setEditEvent] = useState<CalendarEvent | null>(null)
  const [deleteTarget, setDeleteTarget] = useState<CalendarEvent | null>(null)
  const { showToast } = useToast()

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const rows = await fetchEvents()
      setEvents(rows.map(parseCalendarEvent).filter((e): e is CalendarEvent => e != null))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load events')
      setEvents([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    const eventId = Number(searchParams.get('event') || 0)
    const requestId = Number(searchParams.get('request') || 0)
    if ((!eventId && !requestId) || events.length === 0) return
    const event =
      (eventId ? events.find((e) => e.id === eventId) : null) ??
      (requestId ? events.find((e) => e.requestId === requestId) : null)
    if (!event) return
    setSelectedEvent(event)
    setFocusedMonth(new Date(event.eventDate.getFullYear(), event.eventDate.getMonth(), 1))
    setSelectedDay(event.eventDate)
    const next = new URLSearchParams(searchParams)
    next.delete('event')
    next.delete('request')
    setSearchParams(next, { replace: true })
  }, [events, searchParams, setSearchParams])

  const filtered = useMemo(() => {
    return events.filter((e) => {
      if (search && !e.title.toLowerCase().includes(search.toLowerCase())) return false
      if (statusFilter && e.status !== statusFilter) return false
      return true
    })
  }, [events, search, statusFilter])

  const monthDays = useMemo(() => buildMonthGrid(focusedMonth), [focusedMonth])
  const upcoming = useMemo(() => upcomingEvents(filtered), [filtered])
  const selectedDayEvents = useMemo(() => eventsOnDay(filtered, selectedDay), [filtered, selectedDay])
  const summary = useMemo(
    () => ({
      total: events.length,
      upcoming: upcomingEvents(events).length,
      covered: events.filter(isCoveredEvent).length,
    }),
    [events],
  )

  function shiftMonth(delta: number) {
    setFocusedMonth((prev) => new Date(prev.getFullYear(), prev.getMonth() + delta, 1))
  }

  function goToday() {
    const now = new Date()
    setFocusedMonth(new Date(now.getFullYear(), now.getMonth(), 1))
    setSelectedDay(now)
  }

  const monthLabel = focusedMonth.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })

  return (
    <div className="mx-auto max-w-[1400px] space-y-3">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <p className="min-w-0 text-sm leading-snug text-[var(--color-text-secondary)]">
          Monitor documentation events, schedules, and team assignments in real time. Assign teams in{' '}
          <Link to="/documentation-requests" className="font-semibold text-[var(--color-accent-blue)] hover:underline">
            Documentation Requests
          </Link>
          .
        </p>
        <div className="flex shrink-0 items-center gap-2">
          <button
            type="button"
            onClick={() => setShowCreate(true)}
            className="inline-flex items-center gap-1.5 rounded-full bg-[var(--color-accent-blue)] px-3.5 py-1.5 text-sm font-semibold text-white hover:opacity-95"
          >
            <Plus size={15} strokeWidth={2.25} />
            Create Event
          </button>
          <PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />
        </div>
      </div>

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
        <CalendarSummaryCard
          icon={CalendarDays}
          label="Total Events"
          hint="on the calendar"
          value={summary.total}
          color="var(--color-accent-blue)"
        />
        <CalendarSummaryCard
          icon={CalendarCheck}
          label="Upcoming Events"
          hint="today and later"
          value={summary.upcoming}
          color="var(--color-accent-cyan)"
        />
        <CalendarSummaryCard
          icon={Users}
          label="Assigned/Covered"
          hint="with a documenter"
          value={summary.covered}
          color="var(--color-accent-purple)"
        />
      </div>

      <div className="flex flex-col gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-2 shadow-[0_1px_2px_rgba(15,39,68,0.04)] sm:flex-row sm:items-center">
        <div className="relative min-w-0 flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search events…"
            aria-label="Search events"
            className="admin-input w-full rounded-lg py-1.5 pl-9 pr-3 text-sm"
          />
        </div>
        <AdminSelect
          className="sm:w-52"
          buttonClassName="rounded-lg py-1.5"
          value={statusFilter}
          onChange={(v) => setStatusFilter(v as EventStatus | '')}
          aria-label="Filter by status"
          options={[
            { value: '', label: 'All statuses' },
            { value: 'upcoming', label: 'Upcoming' },
            { value: 'ongoing', label: 'Ongoing' },
            { value: 'assigned', label: 'Assigned' },
            { value: 'pending_documentation', label: 'Pending Documentation' },
            { value: 'completed', label: 'Completed' },
            { value: 'cancelled', label: 'Cancelled' },
          ]}
        />
        <button
          type="button"
          onClick={() => {
            setSearch('')
            setStatusFilter('')
          }}
          className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-1.5 text-sm font-semibold text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]"
        >
          Clear filters
        </button>
      </div>

      {loading && events.length === 0 ? (
        <div className="flex justify-center py-16">
          <Loader2 className="animate-spin text-[var(--color-text-muted)]" size={28} />
        </div>
      ) : (
        <div className="grid items-start gap-3 xl:grid-cols-[minmax(0,1.55fr)_minmax(280px,0.78fr)] xl:items-stretch">
          <section className="min-h-0 rounded-xl border border-[color-mix(in_srgb,var(--color-accent-blue)_12%,var(--color-border))] bg-[color-mix(in_srgb,var(--color-accent-blue)_5%,var(--color-surface))] p-3 shadow-[0_1px_2px_rgba(15,39,68,0.04)] md:p-4">
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <h2 className="text-xl font-bold tracking-tight text-[var(--color-text-primary)] sm:text-2xl">
                {monthLabel}
              </h2>
              <div className="flex items-center gap-1.5">
                <button
                  type="button"
                  onClick={goToday}
                  className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-2.5 py-1 text-xs font-semibold text-[var(--color-accent-blue)] hover:bg-[var(--color-surface-hover)]"
                >
                  Today
                </button>
                <button
                  type="button"
                  onClick={() => shiftMonth(-1)}
                  className={`${pageToolbarIconBtnClass} h-8 w-8 rounded-lg`}
                  aria-label="Previous month"
                >
                  <ChevronLeft size={16} />
                </button>
                <button
                  type="button"
                  onClick={() => shiftMonth(1)}
                  className={`${pageToolbarIconBtnClass} h-8 w-8 rounded-lg`}
                  aria-label="Next month"
                >
                  <ChevronRight size={16} />
                </button>
              </div>
            </div>

            <div className="mb-2 grid grid-cols-7 rounded-lg bg-[color-mix(in_srgb,var(--color-accent-blue)_7%,var(--color-surface))] px-1 py-2.5 text-center text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-secondary)] sm:px-2 sm:py-3 sm:text-xs">
              {WEEKDAYS.map((d) => (
                <div key={d} className="px-0.5">
                  {d}
                </div>
              ))}
            </div>
            <div className="grid grid-cols-7 items-start gap-1">
              {monthDays.map((day) => {
                const inMonth = day.getMonth() === focusedMonth.getMonth()
                const isToday = sameDay(day, new Date())
                const isSelected = sameDay(day, selectedDay)
                const dayEvents = eventsOnDay(filtered, day)
                return (
                  <button
                    key={day.toISOString()}
                    type="button"
                    onClick={() => setSelectedDay(day)}
                    className={[
                      'flex min-h-[4.5rem] w-full flex-col rounded-md border px-1 py-1 text-left transition sm:min-h-[5rem]',
                      inMonth
                        ? 'border-[var(--color-border)] bg-[var(--color-surface)]'
                        : 'border-transparent bg-transparent',
                      isSelected ? 'border-[var(--color-accent-blue)] ring-1 ring-[var(--color-accent-blue)]/25' : '',
                      isToday ? 'bg-[color-mix(in_srgb,var(--color-accent-blue)_8%,var(--color-surface))]' : '',
                    ].join(' ')}
                  >
                    <span
                      className={[
                        'mb-1 inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[11px] font-bold',
                        isToday
                          ? 'bg-[var(--color-accent-blue)] text-white'
                          : inMonth
                            ? 'text-[var(--color-text-primary)]'
                            : 'text-[var(--color-text-muted)]',
                      ].join(' ')}
                    >
                      {day.getDate()}
                    </span>
                    <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                      {dayEvents.map((ev) => (
                        <span
                          key={ev.id}
                          className="block w-full rounded px-1 py-0.5 text-[10px] font-semibold leading-snug text-white whitespace-normal break-words sm:text-[11px]"
                          style={{ backgroundColor: eventStatusColor(ev.status) }}
                          title={ev.title}
                        >
                          {ev.title}
                        </span>
                      ))}
                    </div>
                  </button>
                )
              })}
            </div>
            <EventStatusLegend />
          </section>

          <aside className="flex min-h-0 flex-col overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] shadow-[0_1px_2px_rgba(15,39,68,0.04)] xl:max-h-[calc(100dvh-var(--topbar-height)-10.5rem)]">
            <section className="flex min-h-0 flex-col border-b border-[var(--color-border)] p-3">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <h2 className="text-[11px] font-bold uppercase tracking-wide text-[var(--color-accent-blue)]">
                    Selected Day
                  </h2>
                  <p className="mt-0.5 text-sm font-bold leading-snug text-[var(--color-text-primary)]">
                    {formatEventDate(selectedDay)}
                  </p>
                </div>
                <span className="shrink-0 rounded-full bg-[color-mix(in_srgb,var(--color-accent-blue)_10%,transparent)] px-2 py-1 text-[11px] font-semibold text-[var(--color-accent-blue)]">
                  {selectedDayEvents.length} event{selectedDayEvents.length === 1 ? '' : 's'}
                </span>
              </div>
              <div className="mt-2 min-h-0 max-h-[min(280px,36dvh)] space-y-1.5 overflow-y-auto overscroll-y-contain">
                {selectedDayEvents.length === 0 ? (
                  <SelectedDayEmpty />
                ) : (
                  selectedDayEvents.map((ev) => (
                    <SelectedDayEventCard key={ev.id} event={ev} onSelect={setSelectedEvent} />
                  ))
                )}
              </div>
            </section>

            <section className="flex min-h-0 flex-1 flex-col p-3">
              <div className="mb-2 flex shrink-0 items-center justify-between gap-2">
                <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Upcoming Events</h2>
                <span className="text-[11px] font-semibold text-[var(--color-text-secondary)]">{upcoming.length}</span>
              </div>
              <div className="min-h-0 flex-1 overflow-y-auto overscroll-y-contain xl:max-h-[min(280px,36dvh)]">
                <EventUpcomingCards events={upcoming.slice(0, 15)} onSelect={setSelectedEvent} />
              </div>
            </section>
          </aside>
        </div>
      )}

      {selectedEvent && (
        <EventDetailModal
          event={selectedEvent}
          onClose={() => setSelectedEvent(null)}
          onEdit={() => {
            setEditEvent(selectedEvent)
            setSelectedEvent(null)
          }}
          onDelete={() => {
            setDeleteTarget(selectedEvent)
            setSelectedEvent(null)
          }}
        />
      )}

      {editEvent && (
        <EditEventModal
          event={editEvent}
          onClose={() => setEditEvent(null)}
          onSaved={async () => {
            setEditEvent(null)
            await load()
            showToast('Event updated')
          }}
        />
      )}

      {deleteTarget && (
        <AdminConfirmDialog
          open
          title="Delete event?"
          message={`Permanently delete "${deleteTarget.title}"? This cannot be undone.`}
          confirmLabel="Delete"
          tone="danger"
          onCancel={() => setDeleteTarget(null)}
          onConfirm={async () => {
            try {
              await deleteEvent(deleteTarget.id)
              setDeleteTarget(null)
              await load()
              showToast('Event deleted')
            } catch (e) {
              showToast(e instanceof Error ? e.message : 'Failed to delete event', 'error')
            }
          }}
        />
      )}

      {showCreate && (
        <CreateEventModal
          onClose={() => setShowCreate(false)}
          onCreated={async () => {
            setShowCreate(false)
            await load()
            showToast('Event created')
          }}
        />
      )}
    </div>
  )
}

function CalendarSummaryCard({
  icon: Icon,
  label,
  hint,
  value,
  color,
}: {
  icon: typeof CalendarDays
  label: string
  hint: string
  value: number
  color: string
}) {
  return (
    <div
      className="flex h-[62px] items-center gap-2.5 rounded-xl border border-[var(--color-border)] px-3 shadow-[0_1px_2px_rgba(15,39,68,0.04)]"
      style={{ backgroundColor: `color-mix(in srgb, ${color} 6%, var(--color-surface))` }}
    >
      <span
        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg"
        style={{ backgroundColor: `color-mix(in srgb, ${color} 16%, var(--color-surface))`, color }}
      >
        <Icon size={16} strokeWidth={2.25} />
      </span>
      <span className="min-w-0">
        <span className="block text-lg font-extrabold leading-none tabular-nums text-[var(--color-text-primary)]">
          {value}
        </span>
        <span className="mt-0.5 block truncate text-[11px] font-semibold leading-tight text-[var(--color-text-primary)]">
          {label}
        </span>
        <span className="block truncate text-[10px] leading-tight text-[var(--color-text-secondary)]">{hint}</span>
      </span>
    </div>
  )
}

function EventDetailModal({
  event,
  onClose,
  onEdit,
  onDelete,
}: {
  event: CalendarEvent
  onClose: () => void
  onEdit: () => void
  onDelete: () => void
}) {
  const navigate = useNavigate()
  const timeLabel = formatEventTimeRange(event.startTime, event.endTime)
  const team =
    event.documentationTeam.length > 0
      ? event.documentationTeam
      : event.assignedMemberName
        ? [event.assignedMemberName]
        : []

  function openRequest() {
    if (!event.requestId) return
    onClose()
    navigate(`/documentation-requests?request=${event.requestId}`)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div
        className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-2xl bg-[var(--color-surface-elevated)] p-6 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start gap-2">
          <DrawerBackButton onClick={onClose} label="Back" />
          <div className="min-w-0 flex-1">
            <span
              className="inline-block rounded-full px-2.5 py-1 text-[11px] font-bold text-white"
              style={{ backgroundColor: eventStatusColor(event.status) }}
            >
              {eventStatusLabel(event.status)}
            </span>
            <h3 className="mt-2 text-lg font-extrabold text-[var(--color-text-primary)]">{event.title}</h3>
            <p className="mt-1 text-sm text-[var(--color-text-secondary)]">{formatEventDate(event.eventDate)}</p>
            {timeLabel && <p className="mt-0.5 text-sm font-semibold text-[var(--color-text-primary)]">{timeLabel}</p>}
          </div>
        </div>

        {event.requestId && (
          <div className="mt-4 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2.5 text-sm">
            <span className="text-xs font-bold text-[var(--color-text-secondary)]">Linked documentation request</span>
            <div className="mt-1 flex flex-wrap items-center justify-between gap-2">
              <span className="font-semibold text-[var(--color-text-primary)]">
                {requestRefLabel(event.requestId)}
                {event.requestStatus ? ` · ${event.requestStatus}` : ''}
              </span>
              <button
                type="button"
                onClick={openRequest}
                className="inline-flex items-center gap-1 rounded-lg bg-[var(--color-accent-blue)] px-3 py-1.5 text-xs font-semibold text-white hover:opacity-95"
              >
                Open request
                <ExternalLink size={12} />
              </button>
            </div>
          </div>
        )}

        <dl className="mt-4 space-y-3 text-sm">
          {event.location && (
            <div>
              <dt className="text-xs font-bold text-[var(--color-text-secondary)]">Venue</dt>
              <dd className="mt-0.5 font-semibold">{event.location}</dd>
            </div>
          )}
          {team.length > 0 && (
            <div>
              <dt className="text-xs font-bold text-[var(--color-text-secondary)]">Documentation team</dt>
              <dd className="mt-1 flex flex-wrap gap-1.5">
                {team.map((name) => (
                  <span
                    key={name}
                    className="rounded-full bg-[var(--color-accent-blue)]/15 px-2.5 py-1 text-xs font-semibold text-[var(--color-accent-blue)]"
                  >
                    {name}
                  </span>
                ))}
              </dd>
            </div>
          )}
          {event.description && (
            <div>
              <dt className="text-xs font-bold text-[var(--color-text-secondary)]">Description</dt>
              <dd className="mt-1 leading-relaxed text-[var(--color-text-primary)]">{event.description}</dd>
            </div>
          )}
        </dl>

        <div className="mt-6 flex flex-wrap gap-2">
          <button
            type="button"
            onClick={onEdit}
            className="inline-flex flex-1 items-center justify-center gap-2 rounded-xl border border-[var(--color-border)] py-2 text-sm font-semibold hover:bg-[var(--color-surface-hover)]"
          >
            <Pencil size={16} />
            Edit
          </button>
          <button
            type="button"
            onClick={onDelete}
            className="inline-flex flex-1 items-center justify-center gap-2 rounded-xl border border-red-500/40 py-2 text-sm font-semibold text-red-600 hover:bg-red-500/10"
          >
            <Trash2 size={16} />
            Delete
          </button>
          <button
            type="button"
            onClick={onClose}
            className="w-full rounded-xl border border-[var(--color-border)] py-2 text-sm font-semibold sm:w-auto sm:flex-1"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  )
}

function EditEventModal({
  event,
  onClose,
  onSaved,
}: {
  event: CalendarEvent
  onClose: () => void
  onSaved: () => void
}) {
  const [title, setTitle] = useState(event.title)
  const [eventDate, setEventDate] = useState(() => event.eventDate.toISOString().slice(0, 10))
  const [location, setLocation] = useState(event.location ?? '')
  const [description, setDescription] = useState(event.description ?? '')
  const [status, setStatus] = useState<EventStatus>(event.status)
  const [memberId, setMemberId] = useState(event.assignedMemberId ? String(event.assignedMemberId) : '')
  const [members, setMembers] = useState<{ id: number; name: string }[]>([])
  const [saving, setSaving] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    fetchUsers()
      .then((rows) =>
        setMembers(
          rows
            .filter((u) => String(u.status ?? '').toLowerCase() === 'approved')
            .map((u) => ({
              id: u.user_id,
              name: u.name || 'Member',
            }))
            .filter((m) => m.id > 0),
        ),
      )
      .catch(() => setMembers([]))
  }, [])

  async function submit() {
    if (!title.trim()) {
      setErr('Event title is required')
      return
    }
    setSaving(true)
    setErr(null)
    try {
      await updateEvent(event.id, {
        title: title.trim(),
        event_date: eventDate,
        location: location.trim() || undefined,
        description: description.trim() || undefined,
        status,
        ...(memberId ? { assigned_member_id: Number(memberId) } : { assigned_member_id: null }),
      })
      onSaved()
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to update event')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div
        className="max-h-[90vh] w-full max-w-md overflow-y-auto rounded-2xl bg-[var(--color-surface-elevated)] p-6 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-lg font-extrabold text-[var(--color-text-primary)]">Edit event</h3>
        <div className="mt-4 space-y-3">
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Title
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="mt-1 w-full rounded-xl border border-[var(--color-border)] px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Event date
            <input
              type="date"
              value={eventDate}
              onChange={(e) => setEventDate(e.target.value)}
              className="mt-1 w-full rounded-xl border border-[var(--color-border)] px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Location
            <input
              value={location}
              onChange={(e) => setLocation(e.target.value)}
              className="mt-1 w-full rounded-xl border border-[var(--color-border)] px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Description
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
              className="mt-1 w-full rounded-xl border border-[var(--color-border)] px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Status
            <AdminSelect
              className="mt-1"
              value={status}
              onChange={(v) => setStatus(v as EventStatus)}
              aria-label="Event status"
              options={EVENT_STATUS_LEGEND.map((s) => ({ value: s.status, label: s.label }))}
            />
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Assign member (optional)
            <AdminSelect
              className="mt-1"
              value={memberId}
              onChange={setMemberId}
              aria-label="Assign member"
              options={[
                { value: '', label: 'Unassigned' },
                ...members.map((m) => ({ value: String(m.id), label: m.name })),
              ]}
            />
          </label>
          {err && <p className="text-sm text-red-600">{err}</p>}
        </div>
        <div className="mt-6 flex gap-2">
          <button type="button" onClick={onClose} className="flex-1 rounded-xl border border-[var(--color-border)] py-2 text-sm font-semibold">
            Cancel
          </button>
          <button
            type="button"
            disabled={saving}
            onClick={() => void submit()}
            className="flex-1 rounded-xl bg-[var(--color-accent-blue)] py-2 text-sm font-semibold text-white disabled:opacity-60"
          >
            {saving ? 'Saving…' : 'Save changes'}
          </button>
        </div>
      </div>
    </div>
  )
}

function CreateEventModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [title, setTitle] = useState('')
  const [eventDate, setEventDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [location, setLocation] = useState('')
  const [memberId, setMemberId] = useState('')
  const [members, setMembers] = useState<{ id: number; name: string }[]>([])
  const [saving, setSaving] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    fetchUsers()
      .then((rows) =>
        setMembers(
          rows
            .filter((u) => String(u.status ?? '').toLowerCase() === 'approved')
            .map((u) => ({
              id: u.user_id,
              name: u.name || 'Member',
            }))
            .filter((m) => m.id > 0),
        ),
      )
      .catch(() => setMembers([]))
  }, [])

  async function submit() {
    if (!title.trim()) {
      setErr('Event title is required')
      return
    }
    setSaving(true)
    setErr(null)
    try {
      await createEvent({
        title: title.trim(),
        event_date: eventDate,
        location: location.trim() || undefined,
        status: 'upcoming',
        ...(memberId ? { assigned_member_id: Number(memberId) } : {}),
      })
      onCreated()
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to create event')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div
        className="w-full max-w-md rounded-2xl bg-[var(--color-surface-elevated)] p-6 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-lg font-extrabold text-[var(--color-text-primary)]">Create event</h3>
        <div className="mt-4 space-y-3">
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Title
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="mt-1 w-full rounded-xl border border-[var(--color-border)] px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Event date
            <input
              type="date"
              value={eventDate}
              onChange={(e) => setEventDate(e.target.value)}
              className="mt-1 w-full rounded-xl border border-[var(--color-border)] px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Location
            <input
              value={location}
              onChange={(e) => setLocation(e.target.value)}
              className="mt-1 w-full rounded-xl border border-[var(--color-border)] px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-xs font-bold text-[var(--color-text-secondary)]">
            Assign member (optional)
            <AdminSelect
              className="mt-1"
              value={memberId}
              onChange={setMemberId}
              aria-label="Assign member"
              options={[
                { value: '', label: 'Unassigned' },
                ...members.map((m) => ({ value: String(m.id), label: m.name })),
              ]}
            />
          </label>
          {err && <p className="text-sm text-red-600">{err}</p>}
        </div>
        <div className="mt-6 flex gap-2">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 rounded-xl border border-[var(--color-border)] py-2 text-sm font-semibold"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={submit}
            disabled={saving}
            className="flex-1 rounded-xl bg-[var(--color-accent-blue)] py-2 text-sm font-semibold text-white disabled:opacity-50"
          >
            {saving ? 'Saving…' : 'Create'}
          </button>
        </div>
      </div>
    </div>
  )
}
