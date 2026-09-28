import { useCallback, useEffect, useState } from 'react'

import { useNavigate } from 'react-router-dom'

import { Bell, Brain, Calendar, MailOpen, RefreshCw, Users } from 'lucide-react'

import { fetchHomeDashboard, type HomeDashboardSnapshot } from '../lib/dashboard'

import { useAuth } from '../context/AuthContext'

import { AdminErrorBanner } from '../components/AdminAlert'
import { DashboardOverviewStrip } from '../components/dashboard/DashboardOverviewStrip'

import {

  AnalyticsBanner,

  AnnouncementsPanel,

  DailySummaryPanel,

  MediaQueuePanel,

  NotificationsPanel,

  PendingRequestsPanel,

  RecentActivityPanel,

  TodaySchedulePanel,

  WelcomeHeader,

} from '../components/dashboard/DashboardPanels'



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

      const snap = await fetchHomeDashboard()

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

    <div className="space-y-6">

      <div className="flex flex-wrap items-start justify-between gap-4">

        <WelcomeHeader adminName={user?.name ?? 'Admin'} />

        <button

          type="button"

          onClick={load}

          disabled={loading}

          className="inline-flex items-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-2 text-sm font-semibold text-[var(--color-text-secondary)] transition hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)] disabled:opacity-50"

        >

          <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />

          Refresh

        </button>

      </div>



      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}



      {loading && !data ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
          {Array.from({ length: 5 }).map((_, i) => (
            <div
              key={i}
              className="h-[120px] animate-pulse rounded-[var(--card-radius)] bg-[var(--color-surface-muted)]"
            />
          ))}
        </div>
      ) : o ? (
        <DashboardOverviewStrip
          items={[
            {
              icon: MailOpen,
              label: 'Pending Requests',
              value: o.pendingRequests,
              color: 'var(--color-danger)',
              onClick: () => navigate('/documentation-requests'),
            },
            {
              icon: Calendar,
              label: "Today's Events",
              value: o.todayEvents,
              color: 'var(--color-accent-blue)',
              onClick: () => navigate('/event-calendar'),
            },
            {
              icon: Brain,
              label: 'Media Awaiting Review',
              value: o.mediaPendingEvaluation,
              color: 'var(--color-accent-cyan)',
              onClick: () => navigate('/media-integrity'),
            },
            {
              icon: Users,
              label: 'Active Members',
              value: o.activeMembers,
              color: 'var(--color-success)',
              onClick: () => navigate('/members'),
            },
            {
              icon: Bell,
              label: 'Unread Alerts',
              value: o.unreadNotifications,
              color: 'var(--color-accent-purple)',
              onClick: () => navigate('/notifications'),
            },
          ]}
        />
      ) : null}



      {data && (

        <>

          <DailySummaryPanel snapshot={data} />



          <div className="grid gap-6 xl:grid-cols-5">

            <div className="space-y-6 xl:col-span-3">

              <PendingRequestsPanel requests={data.pendingRequests} />

              <RecentActivityPanel items={data.recentActivity} />

              <MediaQueuePanel queue={data.mediaQueue} />

            </div>

            <div className="space-y-6 xl:col-span-2">

              <TodaySchedulePanel items={data.todaySchedule} />

              <NotificationsPanel items={data.notifications} />

              <AnnouncementsPanel items={data.announcements} />

            </div>

          </div>



          <AnalyticsBanner />

        </>

      )}

    </div>

  )

}


