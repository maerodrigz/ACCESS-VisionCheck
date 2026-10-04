import { useEffect, useRef, useState } from 'react'
import { Calendar } from 'lucide-react'
import { pageToolbarBtnClass, pageToolbarIconBtnClass } from '../PageToolbar'
import { formatDateRangeLabel, type DateRange } from '../../lib/analyticsOverview'

const toolbarBtn = pageToolbarBtnClass

export function DateRangePicker({
  range,
  onChange,
}: {
  range: DateRange
  onChange: (range: DateRange) => void
}) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    function onDoc(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [open])

  function toInput(d: Date) {
    return d.toISOString().slice(0, 10)
  }

  function applyPreset(days: number) {
    const end = new Date()
    end.setHours(23, 59, 59, 999)
    const start = new Date(end)
    start.setDate(start.getDate() - (days - 1))
    start.setHours(0, 0, 0, 0)
    onChange({ start, end })
    setOpen(false)
  }

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className={`${toolbarBtn} whitespace-nowrap`}
      >
        <Calendar size={16} className="shrink-0 text-[#64748b]" strokeWidth={2} />
        {formatDateRangeLabel(range)}
      </button>

      {open && (
        <div className="absolute right-0 z-30 mt-2 w-72 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4 shadow-lg">
          <div className="space-y-3">
            <label className="block text-xs font-semibold text-[var(--color-text-secondary)]">
              Start date
              <input
                type="date"
                value={toInput(range.start)}
                onChange={(e) => {
                  const start = new Date(e.target.value + 'T00:00:00')
                  if (!Number.isNaN(start.getTime())) onChange({ start, end: range.end })
                }}
                className="mt-1 w-full rounded-lg border border-[var(--color-border)] px-3 py-2 text-sm"
              />
            </label>
            <label className="block text-xs font-semibold text-[var(--color-text-secondary)]">
              End date
              <input
                type="date"
                value={toInput(range.end)}
                onChange={(e) => {
                  const end = new Date(e.target.value + 'T23:59:59')
                  if (!Number.isNaN(end.getTime())) onChange({ start: range.start, end })
                }}
                className="mt-1 w-full rounded-lg border border-[var(--color-border)] px-3 py-2 text-sm"
              />
            </label>
          </div>
          <div className="mt-3 flex flex-wrap gap-2 border-t border-[var(--color-border)] pt-3">
            {[7, 30, 90].map((d) => (
              <button
                key={d}
                type="button"
                onClick={() => applyPreset(d)}
                className="rounded-lg bg-slate-100 px-3 py-1.5 text-xs font-semibold text-[var(--color-text-secondary)] hover:bg-slate-200"
              >
                Last {d} days
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

export const analyticsToolbarBtnClass = pageToolbarBtnClass

export const analyticsToolbarIconBtnClass = pageToolbarIconBtnClass
