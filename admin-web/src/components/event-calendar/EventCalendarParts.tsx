import { Clock, MapPin, Users } from 'lucide-react'

import {

  EVENT_STATUS_LEGEND,

  eventStatusColor,

  eventStatusLabel,

  formatEventTime,

  formatEventTimeRange,

  formatShortDate,

  type CalendarEvent,

} from '../../lib/eventCalendar'



export function EventStatusLegend() {

  return (

    <div className="mt-4 flex flex-wrap gap-x-4 gap-y-2 border-t border-[var(--color-border)] pt-4">

      <span className="w-full text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">

        Status legend

      </span>

      {EVENT_STATUS_LEGEND.map(({ status, label }) => (

        <span key={status} className="inline-flex items-center gap-1.5 text-[11px] text-[var(--color-text-secondary)]">

          <span

            className="h-2.5 w-2.5 shrink-0 rounded-full"

            style={{ backgroundColor: eventStatusColor(status) }}

            aria-hidden

          />

          {label}

        </span>

      ))}

    </div>

  )

}



export function EventScheduleMeta({ event, compact = false }: { event: CalendarEvent; compact?: boolean }) {

  const timeLabel = formatEventTimeRange(event.startTime, event.endTime)

  const team =

    event.documentationTeam.length > 0

      ? event.documentationTeam.join(', ')

      : event.assignedMemberName



  return (

    <div className={`space-y-0.5 text-xs text-[var(--color-text-secondary)] ${compact ? '' : 'mt-0.5'}`}>

      {timeLabel && (

        <div className="flex items-center gap-1.5">

          <Clock size={12} className="shrink-0 opacity-70" />

          <span>{timeLabel}</span>

        </div>

      )}

      {event.location && (

        <div className="flex items-center gap-1.5">

          <MapPin size={12} className="shrink-0 opacity-70" />

          <span className="truncate">{event.location}</span>

        </div>

      )}

      {team && (

        <div className="flex items-center gap-1.5">

          <Users size={12} className="shrink-0 opacity-70" />

          <span className="truncate">{team}</span>

        </div>

      )}

    </div>

  )

}



const rowButtonClass =

  'flex w-full items-start gap-3 px-3 py-3 text-left transition hover:bg-[var(--color-surface-hover)]'



export function EventDayListItem({

  event,

  onSelect,

}: {

  event: CalendarEvent

  onSelect: (event: CalendarEvent) => void

}) {

  const timeLabel = formatEventTime(event.startTime)



  return (

    <li className="border-b border-[var(--color-border-subtle)] last:border-0">

      <button type="button" onClick={() => onSelect(event)} className={rowButtonClass}>

        <span

          className="mt-1 h-2 w-2 shrink-0 rounded-full"

          style={{ backgroundColor: eventStatusColor(event.status) }}

          aria-hidden

        />

        <div className="min-w-0 flex-1">

          <div className="flex items-start justify-between gap-2">

            <div className="min-w-0 font-semibold text-[var(--color-text-primary)]">{event.title}</div>

            {timeLabel ? (

              <span className="shrink-0 text-[11px] font-bold text-[var(--color-accent-blue)]">{timeLabel}</span>

            ) : null}

          </div>

          <EventScheduleMeta event={event} compact />

        </div>

        <span

          className="shrink-0 rounded-full px-2 py-0.5 text-[10px] font-bold text-white"

          style={{ backgroundColor: eventStatusColor(event.status) }}

        >

          {eventStatusLabel(event.status)}

        </span>

      </button>

    </li>

  )

}



export function EventUpcomingTable({

  events,

  onSelect,

}: {

  events: CalendarEvent[]

  onSelect: (event: CalendarEvent) => void

}) {

  if (events.length === 0) {

    return <p className="px-3 py-6 text-sm text-[var(--color-text-secondary)]">No upcoming events in this view.</p>

  }



  return (

    <div className="overflow-x-auto">

      <table className="w-full min-w-[320px] text-left text-sm">

        <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">

          <tr>

            <th className="px-3 py-2">Date</th>

            <th className="px-3 py-2">Event</th>

            <th className="px-3 py-2">Status</th>

          </tr>

        </thead>

        <tbody>

          {events.map((ev) => (

            <tr

              key={ev.id}

              className="cursor-pointer border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]"

              onClick={() => onSelect(ev)}

              onKeyDown={(e) => {

                if (e.key === 'Enter') onSelect(ev)

              }}

              tabIndex={0}

              role="button"

            >

              <td className="whitespace-nowrap px-3 py-2.5 text-xs font-semibold text-[var(--color-text-secondary)]">

                {formatShortDate(ev.eventDate)}

              </td>

              <td className="px-3 py-2.5">

                <div className="font-semibold text-[var(--color-text-primary)]">{ev.title}</div>

                <div className="text-[11px] text-[var(--color-text-secondary)]">

                  {formatEventTime(ev.startTime) ?? 'All day'}

                  {ev.location ? ` · ${ev.location}` : ''}

                </div>

              </td>

              <td className="px-3 py-2.5">

                <span

                  className="inline-block rounded-full px-2 py-0.5 text-[10px] font-bold text-white"

                  style={{ backgroundColor: eventStatusColor(ev.status) }}

                >

                  {eventStatusLabel(ev.status)}

                </span>

              </td>

            </tr>

          ))}

        </tbody>

      </table>

    </div>

  )

}


