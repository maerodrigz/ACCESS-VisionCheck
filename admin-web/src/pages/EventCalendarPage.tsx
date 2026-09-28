import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { ChevronLeft, ChevronRight, ExternalLink, Loader2, Pencil, Plus, Search, Trash2 } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { createEvent, deleteEvent, fetchEvents, fetchUsers, updateEvent } from '../api/admin'
import {
  EventDayListItem,
  EventStatusLegend,
  EventUpcomingTable,
} from '../components/event-calendar/EventCalendarParts'
import { pageToolbarBtnClass, pageToolbarIconBtnClass, PageToolbarRefreshButton } from '../components/PageToolbar'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
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
  formatEventTime,
  formatEventTimeRange,
  formatShortDate,
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
    <div className="space-y-5">
      <AdminPageHeader
        title="Event Calendar"
        subtitle="Monitor documentation events, schedules, and team assignments in real time."
        backTo="/"
        actions={
          <>
            <button type="button" onClick={() => setShowCreate(true)} className={pageToolbarBtnClass}>
              <Plus size={16} className="shrink-0 text-[var(--color-text-secondary)]" strokeWidth={2} />
              Create Event
            </button>
            <PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />
          </>
        }
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <p className="text-xs text-[var(--color-text-secondary)]">
        Planning view for campus events. Approve and assign teams in{' '}
        <Link to="/documentation-requests" className="font-semibold text-[var(--color-accent-blue)] hover:underline">
          Documentation Requests
        </Link>
        .
      </p>

      <div className="flex flex-col gap-3 rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
        <div className="grid gap-3 md:grid-cols-[1fr_auto_auto]">
          <div className="relative min-w-0">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search events…"
              className="admin-input w-full rounded-xl py-2 pl-9 pr-3 text-sm"
            />
          </div>
          <AdminSelect
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
            className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2 text-sm font-semibold text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]"
          >
            Clear filters
          </button>
        </div>
        <p className="text-xs text-[var(--color-text-secondary)]">
          {filtered.length} event{filtered.length === 1 ? '' : 's'} · {upcoming.length} upcoming
        </p>
      </div>

      {loading && events.length === 0 ? (
        <div className="flex justify-center py-16">
          <Loader2 className="animate-spin text-[var(--color-text-muted)]" size={28} />
        </div>
      ) : (
        <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
          <div className="grid xl:grid-cols-[minmax(0,1.45fr)_minmax(0,1fr)]">
            <div className="border-b border-[var(--color-border)] p-4 md:p-5 xl:border-b-0 xl:border-r">
              <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                <h2 className="text-sm font-extrabold uppercase tracking-wide text-[var(--color-text-secondary)]">
                  Calendar
                </h2>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={goToday}
                    className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-1.5 text-xs font-semibold text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]"
                  >
                    Today
                  </button>
                  <button
                    type="button"
                    onClick={() => shiftMonth(-1)}
                    className={pageToolbarIconBtnClass}
                    aria-label="Previous month"
                  >
                    <ChevronLeft size={18} />
                  </button>
                  <span className="min-w-[140px] text-center text-sm font-bold text-[var(--color-text-primary)]">
                    {monthLabel}
                  </span>
                  <button
                    type="button"
                    onClick={() => shiftMonth(1)}
                    className={pageToolbarIconBtnClass}
                    aria-label="Next month"
                  >
                    <ChevronRight size={18} />
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-7 gap-1 text-center text-[11px] font-bold text-[var(--color-text-secondary)]">
                {WEEKDAYS.map((d) => (
                  <div key={d} className="py-1">
                    {d}
                  </div>
                ))}
              </div>
              <div className="mt-1 grid grid-cols-7 gap-1">
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
                        'flex min-h-[84px] flex-col rounded-lg border p-1.5 text-left transition',
                        inMonth ? 'bg-[var(--color-surface-muted)]' : 'bg-[var(--color-surface-hover)] opacity-50',
                        isSelected
                          ? 'border-[var(--color-accent-blue)] ring-1 ring-[var(--color-accent-blue)]/30'
                          : 'border-[var(--color-border-subtle)]',
                        isToday && !isSelected ? 'bg-[var(--color-accent-blue)]/10' : '',
                      ].join(' ')}
                    >
                      <span
                        className={[
                          'mb-1 inline-flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold',
                          isToday ? 'bg-[var(--color-accent-blue)] text-white' : 'text-[var(--color-text-primary)]',
                        ].join(' ')}
                      >
                        {day.getDate()}
                      </span>
                      <div className="space-y-0.5">
                        {dayEvents.slice(0, 2).map((ev) => {
                          const time = formatEventTime(ev.startTime)
                          const label = time ? `${time} · ${ev.title}` : ev.title
                          return (
                            <span
                              key={ev.id}
                              className="block truncate rounded px-1 py-0.5 text-[9px] font-semibold text-white"
                              style={{ backgroundColor: eventStatusColor(ev.status) }}
                              title={label}
                            >
                              {label}
                            </span>
                          )
                        })}
                        {dayEvents.length > 2 ? (
                          <span className="text-[9px] font-semibold text-[var(--color-text-secondary)]">
                            +{dayEvents.length - 2} more
                          </span>
                        ) : null}
                      </div>
                    </button>
                  )
                })}
              </div>
              <EventStatusLegend />
            </div>

            <div className="flex min-h-0 flex-col">
              <section className="border-b border-[var(--color-border)]">
                <div className="flex items-center justify-between gap-2 px-4 py-3">
                  <h2 className="text-sm font-extrabold text-[var(--color-text-primary)]">
                    {formatShortDate(selectedDay)}
                  </h2>
                  <span className="text-xs text-[var(--color-text-secondary)]">
                    {selectedDayEvents.length} event{selectedDayEvents.length === 1 ? '' : 's'}
                  </span>
                </div>
                {selectedDayEvents.length === 0 ? (
                  <p className="px-4 pb-4 text-sm text-[var(--color-text-secondary)]">No events on this date.</p>
                ) : (
                  <ul className="max-h-[280px] overflow-y-auto">
                    {selectedDayEvents.map((ev) => (
                      <EventDayListItem key={ev.id} event={ev} onSelect={setSelectedEvent} />
                    ))}
                  </ul>
                )}
              </section>

              <section className="flex min-h-0 flex-1 flex-col">
                <div className="flex items-center justify-between gap-2 px-4 py-3">
                  <h2 className="text-sm font-extrabold text-[var(--color-text-primary)]">Upcoming</h2>
                  <span className="text-xs text-[var(--color-text-secondary)]">{upcoming.length} scheduled</span>
                </div>
                <div className="max-h-[320px] flex-1 overflow-y-auto pb-2">
                  <EventUpcomingTable events={upcoming.slice(0, 15)} onSelect={setSelectedEvent} />
                </div>
              </section>
            </div>
          </div>
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
