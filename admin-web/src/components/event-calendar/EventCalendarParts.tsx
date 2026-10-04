import { Calendar, Clock, MapPin, Users } from 'lucide-react'
import {
  EVENT_STATUS_LEGEND,
  eventDocumenters,
  eventStatusColor,
  eventStatusLabel,
  formatCompactDate,
  formatEventTime,
  formatEventTimeRange,
  type CalendarEvent,
  type EventStatus,
} from '../../lib/eventCalendar'

export function EventStatusBadge({ status }: { status: EventStatus }) {
  const color = eventStatusColor(status)
  return (
    <span
      className="inline-flex shrink-0 items-center rounded-full px-2 py-0.5 text-[10px] font-semibold leading-none"
      style={{
        color,
        backgroundColor: `color-mix(in srgb, ${color} 14%, transparent)`,
      }}
    >
      {eventStatusLabel(status)}
    </span>
  )
}

export function EventStatusLegend() {
  return (
    <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1">
      {EVENT_STATUS_LEGEND.map(({ status, label }) => (
        <span key={status} className="inline-flex items-center gap-1.5 text-[10px] text-[var(--color-text-secondary)]">
          <span className="h-1.5 w-1.5 shrink-0 rounded-full" style={{ backgroundColor: eventStatusColor(status) }} />
          {label}
        </span>
      ))}
    </div>
  )
}

export function SelectedDayEventCard({
  event,
  onSelect,
}: {
  event: CalendarEvent
  onSelect: (event: CalendarEvent) => void
}) {
  const timeLabel = formatEventTimeRange(event.startTime, event.endTime) ?? 'All day'
  const documenters = eventDocumenters(event)

  return (
    <button
      type="button"
      onClick={() => onSelect(event)}
      className="w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2.5 text-left transition hover:border-[var(--color-accent-blue)]/40 hover:bg-[var(--color-surface-hover)]"
    >
      <div className="flex items-start justify-between gap-2">
        <span className="min-w-0 text-sm font-semibold leading-snug text-[var(--color-text-primary)]">
          {event.title}
        </span>
        <EventStatusBadge status={event.status} />
      </div>
      <div className="mt-1.5 space-y-1 text-[11px] text-[var(--color-text-secondary)]">
        <div className="flex items-center gap-1.5">
          <Clock size={12} className="shrink-0 text-[var(--color-accent-blue)]" />
          <span>{timeLabel}</span>
        </div>
        <div className="flex items-center gap-1.5">
          <MapPin size={12} className="shrink-0 text-[var(--color-accent-cyan)]" />
          <span className="truncate">{event.location || 'N/A'}</span>
        </div>
        <div className="flex items-start gap-1.5">
          <Users size={12} className="mt-0.5 shrink-0 text-[var(--color-accent-purple)]" />
          <span className="min-w-0 flex-1 break-words">
            {documenters.length > 0 ? documenters.join(', ') : 'Unassigned'}
          </span>
        </div>
      </div>
    </button>
  )
}

export function SelectedDayEmpty() {
  return (
    <div className="flex flex-col items-center px-3 py-6 text-center">
      <Calendar size={22} className="text-[var(--color-text-muted)]" />
      <p className="mt-2 text-sm font-semibold text-[var(--color-text-primary)]">No events on this date</p>
      <p className="mt-0.5 text-xs text-[var(--color-text-secondary)]">Select another day, or create an event.</p>
    </div>
  )
}

export function EventUpcomingCards({
  events,
  onSelect,
}: {
  events: CalendarEvent[]
  onSelect: (event: CalendarEvent) => void
}) {
  if (events.length === 0) {
    return <p className="py-4 text-center text-xs text-[var(--color-text-secondary)]">No upcoming events.</p>
  }

  return (
    <ul className="space-y-1.5">
      {events.map((ev) => {
        const time = formatEventTime(ev.startTime) ?? 'All day'
        const place = ev.location ? `${time} · ${ev.location}` : time
        return (
          <li key={ev.id}>
            <button
              type="button"
              onClick={() => onSelect(ev)}
              className="flex w-full items-center gap-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-2.5 py-2 text-left transition hover:border-[var(--color-accent-blue)]/40 hover:bg-[var(--color-surface-hover)]"
            >
              <span className="w-12 shrink-0 text-[11px] font-semibold text-[var(--color-accent-blue)]">
                {formatCompactDate(ev.eventDate)}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-xs font-semibold text-[var(--color-text-primary)]">
                  {ev.title}
                </span>
                <span className="block truncate text-[10px] text-[var(--color-text-secondary)]">{place}</span>
              </span>
              <EventStatusBadge status={ev.status} />
            </button>
          </li>
        )
      })}
    </ul>
  )
}
