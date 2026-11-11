import { useEffect, useState, type ReactNode } from 'react'
import type { LucideIcon } from 'lucide-react'
import { Moon, RefreshCw, Sun, Sunrise } from 'lucide-react'

export interface SystemOverviewStat {
  icon: LucideIcon
  label: string
  sublabel: string
  value: string | number
  /** Icon accent only (card body stays neutral). */
  accent: string
  onClick?: () => void
  badge?: boolean
}

interface Props {
  loading?: boolean
  onRefresh?: () => void
  stats: SystemOverviewStat[] | null
  /** Shown while overview counts are loading (no stats yet). */
  statsLoading?: boolean
  /** First name / display name for the greeting (defaults to Admin). */
  adminName?: string
}

function formatOverviewDate(d: Date) {
  return d.toLocaleDateString(undefined, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  })
}

export type DayPart = 'morning' | 'afternoon' | 'evening'

export function dayPartForHour(h: number): DayPart {
  if (h < 12) return 'morning'
  if (h < 17) return 'afternoon'
  return 'evening'
}

export function greetingForPart(part: DayPart, adminName = 'Admin') {
  const name = adminName.trim() || 'Admin'
  if (part === 'morning') return `Good morning, ${name}!`
  if (part === 'afternoon') return `Good afternoon, ${name}!`
  return `Good evening, ${name}!`
}

function GreetingIcon({ part }: { part: DayPart }) {
  if (part === 'morning') {
    return <Sunrise size={20} strokeWidth={2.2} className="text-amber-500" aria-hidden />
  }
  if (part === 'afternoon') {
    return <Sun size={20} strokeWidth={2.2} className="text-amber-500" aria-hidden />
  }
  return <Moon size={20} strokeWidth={2.2} className="text-sky-600" aria-hidden />
}

export function SystemOverviewPanel({
  loading,
  onRefresh,
  stats,
  statsLoading,
  adminName = 'Admin',
}: Props) {
  const [now, setNow] = useState(() => new Date())
  const part = dayPartForHour(now.getHours())
  const greeting = greetingForPart(part, adminName)

  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 60000)
    return () => window.clearInterval(id)
  }, [])

  return (
    <section
      className={[
        'w-full min-w-0 rounded-[18px] border border-[#BDEAF6] px-3.5 py-3.5 sm:px-5 sm:py-4',
        'bg-[linear-gradient(105deg,#D8F7FF_0%,#EAF5FF_48%,#F6FBFF_100%)]',
        'shadow-[0_1px_3px_rgba(16,45,74,0.06)]',
      ].join(' ')}
      aria-label="Dashboard overview"
    >
      <div className="flex min-w-0 flex-wrap items-start justify-between gap-2.5 sm:items-center">
        <div className="min-w-0">
          <div className="flex items-center gap-2.5">
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] border border-[#BDEAF6]/80 bg-white/70 shadow-sm">
              <GreetingIcon part={part} />
            </span>
            <h1 className="truncate text-[1.15rem] font-extrabold tracking-tight text-[#102D4A] sm:text-[1.3rem]">
              {greeting}
            </h1>
          </div>
          <p className="mt-1 pl-[46px] text-[13px] leading-snug text-[#4B6C83] sm:text-sm">
            Here&apos;s what needs your attention today.
          </p>
        </div>
        <div className="flex shrink-0 flex-wrap items-center gap-1.5 sm:ml-auto">
          {onRefresh ? (
            <button
              type="button"
              onClick={onRefresh}
              disabled={loading}
              className="inline-flex items-center gap-1.5 rounded-lg border border-[#BDEAF6] bg-white/80 px-2.5 py-1.5 text-[11px] font-semibold text-[#4B6C83] transition hover:bg-white disabled:opacity-50"
            >
              <RefreshCw size={12} className={loading ? 'animate-spin' : undefined} aria-hidden />
              Refresh
            </button>
          ) : null}
          <time
            dateTime={now.toISOString()}
            className="rounded-lg border border-[#BDEAF6] bg-white/60 px-2.5 py-1.5 text-[11px] font-medium tabular-nums text-[#4B6C83]"
          >
            {formatOverviewDate(now)}
          </time>
        </div>
      </div>

      <div className="my-3 h-px bg-[#BDEAF6]/80" role="presentation" />

      {statsLoading && !stats ? (
        <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <div
              key={i}
              className="h-[56px] animate-pulse rounded-[12px] border border-white/70 bg-white/45"
            />
          ))}
        </div>
      ) : stats ? (
        <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-4">
          {stats.map((item) => (
            <OverviewStatCard key={item.label} item={item} />
          ))}
        </div>
      ) : null}
    </section>
  )
}

function OverviewStatCard({ item }: { item: SystemOverviewStat }) {
  const Icon = item.icon
  const interactive = typeof item.onClick === 'function'

  const body: ReactNode = (
    <>
      <div
        className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md"
        style={{
          backgroundColor: `color-mix(in srgb, ${item.accent} 14%, white)`,
          color: item.accent,
        }}
      >
        <Icon size={14} strokeWidth={2.25} aria-hidden />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-1.5">
          <span className="text-base font-bold leading-none tabular-nums text-[#102D4A]">
            {item.value}
          </span>
          {item.badge ? (
            <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[var(--color-danger)]" aria-hidden />
          ) : null}
        </div>
        <p className="mt-0.5 truncate text-[11px] font-semibold leading-tight text-[#102D4A]">
          {item.label}
        </p>
        <p className="truncate text-[10px] leading-tight text-[#4B6C83]">{item.sublabel}</p>
      </div>
    </>
  )

  const className = [
    'flex min-h-[56px] min-w-0 items-center gap-2 rounded-[12px] border border-white/80 bg-white/70 px-2.5 py-2 text-left shadow-[0_1px_2px_rgba(16,45,74,0.04)] backdrop-blur-[2px] transition',
    interactive
      ? 'cursor-pointer hover:border-[#1A8FB8]/35 hover:bg-white/90 hover:shadow-[0_1px_4px_rgba(15,23,42,0.06)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--color-accent-blue)]'
      : '',
  ].join(' ')

  if (interactive) {
    return (
      <button type="button" onClick={item.onClick} className={className}>
        {body}
      </button>
    )
  }

  return <div className={className}>{body}</div>
}
