import { useCallback, useEffect, useState } from 'react'

import { useNavigate } from 'react-router-dom'

import { Bell, Calendar, ImageIcon, MailOpen } from 'lucide-react'

import { fetchHomeDashboard, type HomeDashboardSnapshot } from '../lib/dashboard'

import { useAuth } from '../context/AuthContext'

import { AdminErrorBanner } from '../components/AdminAlert'
import { DashboardOverviewStrip } from '../components/dashboard/DashboardOverviewStrip'
import {
  ActionCenterPanel,
  ActiveDocumentersPanel,
  AiReviewQueuePanel,
  TodayScheduleTimelinePanel,
} from '../components/dashboard/DashboardSep29Panels'
import { WelcomeHeader } from '../components/dashboard/DashboardPanels'

export function DashboardPage() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [data, setData] = useState<HomeDashboardSnapshot | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const snap = await fetchHomeDashboard({
        streamHeavy: true,
        onPartial: (partial) => {
          setData(partial)
          setLoading(false)
        },
      })
      setData(snap)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load dashboard')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const o = data?.overview

  return (
    <div className="w-full max-w-[1400px] space-y-4">
      <WelcomeHeader adminName={user?.name ?? 'Admin'} onRefresh={load} loading={loading} />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      {loading && !data ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <div
              key={i}
              className="h-[62px] animate-pulse rounded-xl bg-[var(--color-surface-muted)]"
            />
          ))}
        </div>
      ) : o ? (
        <DashboardOverviewStrip
          items={[
            {
              icon: MailOpen,
              label: 'Pending Requests',
              sublabel: 'needs approval',
              value: o.pendingRequests,
              color: 'var(--color-danger)',
              bgColor: 'color-mix(in srgb, var(--color-danger) 6%, var(--color-surface))',
              onClick: () => navigate('/documentation-requests'),
            },
            {
              icon: Calendar,
              label: "Today's Events",
              sublabel: 'scheduled today',
              value: o.todayEvents,
              color: 'var(--color-accent-blue)',
              bgColor: 'color-mix(in srgb, var(--color-accent-blue) 6%, var(--color-surface))',
              onClick: () => navigate('/event-calendar'),
            },
            {
              icon: ImageIcon,
              label: 'Media Awaiting Review',
              sublabel: 'integrity needs action',
              value: o.mediaPendingEvaluation,
              color: 'var(--color-accent-cyan)',
              bgColor: 'color-mix(in srgb, var(--color-accent-cyan) 8%, var(--color-surface))',
              onClick: () => navigate('/media-integrity'),
            },
            {
              icon: Bell,
              label: 'Unread Alerts',
              sublabel: 'new notifications',
              value: o.unreadNotifications,
              color: 'var(--color-accent-purple)',
              bgColor: 'color-mix(in srgb, var(--color-accent-purple) 8%, var(--color-surface))',
              onClick: () => navigate('/notifications'),
              badge: o.unreadNotifications > 0,
            },
          ]}
        />
      ) : null}

      {data ? (
        <>
          <div className="grid items-stretch gap-3 lg:grid-cols-[1.45fr_0.85fr]">
            <ActionCenterPanel requests={data.pendingRequests} />
            <TodayScheduleTimelinePanel items={data.upcomingEvents} />
          </div>

          <div className="grid items-start gap-3 lg:grid-cols-[1.45fr_0.85fr]">
            <AiReviewQueuePanel snapshot={data.aiReviewQueue} />
            <ActiveDocumentersPanel snapshot={data.activeDocumenters} />
          </div>
        </>
      ) : null}
    </div>
  )
}
