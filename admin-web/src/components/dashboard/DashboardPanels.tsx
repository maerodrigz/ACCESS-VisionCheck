import type { LucideIcon } from 'lucide-react'
import {
  BarChart3,
  Bell,
  Calendar,
  CheckCircle2,
  ClipboardCheck,
  FileText,
  Megaphone,
  ShieldCheck,
  Sparkles,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { AdminCard } from '../AdminCard'
import { ActivityTypeIcon, dashboardActivityAccent, mapDashboardActivityKind } from '../ActivityTypeIcon'
import { StatIconTile } from '../StatCard'
import type {
  ActivityItem,
  AnnouncementItem,
  HomeDashboardSnapshot,
  MediaQueueSnapshot,
  PendingRequestItem,
  TodayScheduleItem,
} from '../../lib/dashboard'
import { buildDailySummary } from '../../lib/dashboard'
import type { AdminNotification } from '../../lib/notifications'
import { categoryLabel } from '../../lib/notifications'

export function DashboardSectionHeader({
  icon: Icon,
  color,
  title,
  subtitle,
  trailing,
}: {
  icon: LucideIcon
  color: string
  title: string
  subtitle?: string
  trailing?: React.ReactNode
}) {
  return (
    <div className="flex items-start justify-between gap-3">
      <div className="flex min-w-0 items-start gap-3">
        <StatIconTile icon={Icon} color={color} />
        <div className="min-w-0">
          <h2 className="text-[15px] font-bold leading-snug text-[var(--color-text-primary)]">{title}</h2>
          {subtitle ? (
            <p className="mt-1 text-xs leading-snug text-[var(--color-text-secondary)]">{subtitle}</p>
          ) : null}
        </div>
      </div>
      {trailing}
    </div>
  )
}

function TextLink({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="shrink-0 text-xs font-semibold text-[var(--color-accent-blue)] hover:underline"
    >
      {label}
    </button>
  )
}

function StatusBadge({ label }: { label: string }) {
  const s = label.toLowerCase()
  const color = s.includes('pending')
    ? 'var(--color-warning)'
    : s.includes('reject')
      ? 'var(--color-danger)'
      : s.includes('approv') || s.includes('assign') || s.includes('open')
        ? 'var(--color-success)'
        : 'var(--color-accent-blue)'
  return (
    <span
      className="inline-flex shrink-0 rounded-md px-2 py-0.5 text-[10px] font-bold"
      style={{ color, backgroundColor: `color-mix(in srgb, ${color} 12%, transparent)` }}
    >
      {label}
    </span>
  )
}

function EmptyState({
  title,
  message,
  icon: Icon,
}: {
  title: string
  message: string
  icon: LucideIcon
}) {
  return (
    <div className="flex flex-col items-center py-8 text-center">
      <Icon size={28} className="text-[var(--color-text-secondary)] opacity-50" />
      <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">{title}</p>
      <p className="mt-1 max-w-xs text-xs text-[var(--color-text-secondary)]">{message}</p>
    </div>
  )
}

export function PendingRequestsPanel({
  requests,
}: {
  requests: PendingRequestItem[]
}) {
  const navigate = useNavigate()
  return (
    <AdminCard as="section">
      <DashboardSectionHeader
        icon={ClipboardCheck}
        color="var(--color-danger)"
        title="Pending documentation requests"
        subtitle="Review and approve incoming documentation requests"
        trailing={<TextLink label="View all" onClick={() => navigate('/documentation-requests')} />}
      />
      {requests.length === 0 ? (
        <EmptyState
          icon={CheckCircle2}
          title="No pending requests"
          message="All documentation requests have been reviewed."
        />
      ) : (
        <ul className="mt-4 divide-y divide-[var(--color-border-subtle)]">
          {requests.map((r) => (
            <li key={r.id} className="flex flex-wrap items-center gap-3 py-3.5 first:pt-0 last:pb-0">
              <div className="min-w-0 flex-1">
                <div className="text-sm font-bold text-[var(--color-text-primary)]">{r.eventTitle}</div>
                <div className="text-xs text-[var(--color-text-secondary)]">{r.requestor}</div>
              </div>
              <div className="hidden text-xs text-[var(--color-text-secondary)] sm:block">{r.requestedDate}</div>
              <StatusBadge label={r.status} />
              <button
                type="button"
                onClick={() => navigate('/documentation-requests')}
                className="rounded-lg bg-[var(--color-accent-blue)] px-3 py-1.5 text-xs font-semibold text-white hover:opacity-95"
              >
                Review
              </button>
            </li>
          ))}
        </ul>
      )}
    </AdminCard>
  )
}

export function TodaySchedulePanel({ items }: { items: TodayScheduleItem[] }) {
  const navigate = useNavigate()
  return (
    <AdminCard as="section">
      <DashboardSectionHeader
        icon={Calendar}
        color="var(--color-accent-blue)"
        title="Today's schedule"
        subtitle="Approved documentation events happening today"
        trailing={<TextLink label="Open calendar" onClick={() => navigate('/event-calendar')} />}
      />
      {items.length === 0 ? (
        <EmptyState
          icon={Calendar}
          title="Nothing scheduled today"
          message="No approved documentation events on today's calendar."
        />
      ) : (
        <ul className="mt-4 space-y-2.5">
          {items.map((item, i) => (
            <li
              key={`${item.eventName}-${i}`}
              className="flex items-start gap-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3"
            >
              <div className="w-[72px] shrink-0 text-xs font-bold text-[var(--color-accent-blue)]">
                {item.timeLabel}
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-sm font-semibold text-[var(--color-text-primary)]">{item.eventName}</div>
                <div className="mt-0.5 truncate text-[11px] text-[var(--color-text-secondary)]">
                  {item.assignedMembers}
                </div>
              </div>
              <StatusBadge label={item.status} />
            </li>
          ))}
        </ul>
      )}
    </AdminCard>
  )
}

export function RecentActivityPanel({ items }: { items: ActivityItem[] }) {
  const navigate = useNavigate()

  return (
    <AdminCard as="section">
      <DashboardSectionHeader
        icon={FileText}
        color="var(--color-accent-blue)"
        title="Recent activity"
        subtitle="Latest updates across requests, media, and members"
        trailing={<TextLink label="View all" onClick={() => navigate('/documentation-requests')} />}
      />
      {items.length === 0 ? (
        <EmptyState
          icon={FileText}
          title="No recent activity"
          message="Activity will appear as your team works."
        />
      ) : (
        <ul className="mt-4 space-y-0">
          {items.map((item, i) => (
            <li key={`${item.title}-${i}`} className="flex gap-3 border-b border-[var(--color-border-subtle)] py-3 last:border-0">
              <div className="mt-0.5">
                <ActivityTypeIcon
                  kind={mapDashboardActivityKind(item.kind)}
                  accentColor={dashboardActivityAccent(item.kind, item.title)}
                  size="sm"
                />
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-xs font-semibold text-[var(--color-text-primary)]">{item.title}</div>
                {item.subtitle ? (
                  <div className="mt-0.5 truncate text-[11px] text-[var(--color-text-secondary)]">
                    {item.subtitle}
                  </div>
                ) : null}
                <div className="mt-1 flex items-center gap-2">
                  <StatusBadge label={item.status} />
                  <span className="text-[10px] text-[var(--color-text-secondary)]">{item.time}</span>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}
    </AdminCard>
  )
}

export function NotificationsPanel({ items }: { items: AdminNotification[] }) {
  const navigate = useNavigate()
  return (
    <AdminCard as="section">
      <DashboardSectionHeader
        icon={Bell}
        color="#7c3aed"
        title="Notifications"
        trailing={<TextLink label="View all" onClick={() => navigate('/notifications')} />}
      />
      {items.length === 0 ? (
        <EmptyState icon={Bell} title="No notifications" message="You're all caught up." />
      ) : (
        <ul className="mt-4 divide-y divide-[var(--color-border-subtle)]">
          {items.map((n) => (
            <li key={n.id}>
              <button
                type="button"
                onClick={() => navigate(n.route)}
                className="flex w-full items-start gap-2.5 py-3 text-left transition hover:bg-[var(--color-surface-hover)]"
              >
                {n.unread ? (
                  <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-[var(--color-danger)]" />
                ) : (
                  <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-transparent" />
                )}
                <div className="min-w-0 flex-1">
                  <span
                    className={[
                      'text-xs text-[var(--color-text-primary)]',
                      n.unread ? 'font-bold' : 'font-semibold',
                    ].join(' ')}
                  >
                    {n.title}
                  </span>
                  <div className="mt-0.5 text-[10px] text-[var(--color-text-secondary)]">{n.timeAgo}</div>
                </div>
              </button>
            </li>
          ))}
        </ul>
      )}
    </AdminCard>
  )
}

export function MediaQueuePanel({ queue }: { queue: MediaQueueSnapshot }) {
  const navigate = useNavigate()
  return (
    <AdminCard as="section">
      <DashboardSectionHeader
        icon={ShieldCheck}
        color="#0891b2"
        title="Media integrity"
        subtitle="AI-generated media review alerts"
      />
      <div className="mt-4 grid grid-cols-2 gap-3">
        <div className="rounded-xl border border-amber-500/20 bg-amber-500/10 p-3.5">
          <div className="text-2xl font-extrabold text-[var(--color-warning)]">{queue.pendingCount}</div>
          <div className="text-[11px] text-[var(--color-text-secondary)]">Pending evaluation</div>
        </div>
        <div className="rounded-xl border border-emerald-500/20 bg-emerald-500/10 p-3.5">
          <div className="text-2xl font-extrabold text-[var(--color-success)]">{queue.completedToday}</div>
          <div className="text-[11px] text-[var(--color-text-secondary)]">Completed today</div>
        </div>
      </div>
      <button
        type="button"
        onClick={() => navigate('/media-integrity')}
        className="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-[var(--color-accent-blue)] py-2.5 text-sm font-semibold text-white hover:opacity-95"
      >
        <ShieldCheck size={16} />
        Open Media Integrity
      </button>
    </AdminCard>
  )
}

export function AnnouncementsPanel({ items }: { items: AnnouncementItem[] }) {
  return (
    <AdminCard as="section">
      <DashboardSectionHeader
        icon={Megaphone}
        color="var(--color-success)"
        title="Announcements"
        subtitle="System updates and reminders"
      />
      <ul className="mt-4 space-y-2.5">
        {items.map((a, i) => (
          <li
            key={`${a.title}-${i}`}
            className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3"
          >
            <div className="flex items-start justify-between gap-2">
              <div className="text-xs font-bold text-[var(--color-text-primary)]">{a.title}</div>
              <span className="shrink-0 text-[10px] text-[var(--color-text-secondary)]">{a.dateLabel}</span>
            </div>
            <p className="mt-1 text-[11px] leading-relaxed text-[var(--color-text-secondary)]">{a.body}</p>
          </li>
        ))}
      </ul>
    </AdminCard>
  )
}

export function DailySummaryPanel({ snapshot }: { snapshot: HomeDashboardSnapshot }) {
  const summary = buildDailySummary(snapshot)
  return (
    <AdminCard as="section" className="border-[var(--color-accent-blue)]/20 bg-gradient-to-br from-[#1e3a8a]/40 to-[var(--color-surface)]">
      <div className="flex items-start gap-3">
        <div className="rounded-[10px] bg-[var(--color-accent-blue)]/20 p-2 text-[var(--color-accent-blue)]">
          <Sparkles size={18} />
        </div>
        <div>
          <h2 className="text-sm font-bold text-[var(--color-text-primary)]">Daily operations summary</h2>
          <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-primary)]">{summary}</p>
        </div>
      </div>
    </AdminCard>
  )
}

export function AnalyticsBanner() {
  const navigate = useNavigate()
  return (
    <div className="overflow-hidden rounded-[var(--card-radius)] bg-[var(--brand-hero-gradient)] p-6 shadow-[0_12px_40px_rgba(37,99,235,0.22)]">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-extrabold text-white">Need deeper insights?</h2>
          <p className="mt-1 max-w-md text-sm leading-relaxed text-white/90">
            Charts, trends, and performance reports live on the Analytics page.
          </p>
        </div>
        <button
          type="button"
          onClick={() => navigate('/analytics')}
          className="inline-flex items-center gap-2 rounded-xl bg-[var(--color-surface-elevated)] px-5 py-3 text-sm font-bold text-[var(--color-accent-blue)] hover:bg-[var(--color-surface-hover)]"
        >
          <BarChart3 size={18} />
          View full analytics
        </button>
      </div>
    </div>
  )
}

export function WelcomeHeader({ adminName }: { adminName: string }) {
  const h = new Date().getHours()
  const greeting = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening'
  const firstName = adminName.split(' ')[0] ?? 'Admin'

  return (
    <div>
      <h1 className="text-2xl font-extrabold tracking-tight text-[var(--color-text-primary)] md:text-[26px]">
        {greeting}, {firstName}!
      </h1>
      <p className="mt-1.5 text-sm text-[var(--color-text-secondary)]">
        Here&apos;s what needs your attention today.
      </p>
    </div>
  )
}

export { categoryLabel }
