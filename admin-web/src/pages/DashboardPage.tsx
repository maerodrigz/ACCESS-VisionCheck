import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Bell, Calendar, ImageIcon, MailOpen } from 'lucide-react'

import { fetchHomeDashboard, type HomeDashboardSnapshot } from '../lib/dashboard'
import { useAuth } from '../context/AuthContext'
import { AdminErrorBanner } from '../components/AdminAlert'
import { SystemOverviewPanel } from '../components/dashboard/SystemOverviewPanel'
import {
  ActionCenterPanel,
  ActiveDocumentersPanel,
  AiReviewQueuePanel,
  TodayScheduleTimelinePanel,
} from '../components/dashboard/DashboardSep29Panels'

export function DashboardPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [data, setData] = useState<HomeDashboardSnapshot | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const adminName = (user?.name?.trim().split(/\s+/)[0] || 'Admin')

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
    <div className="w-full max-w-[1400px] space-y-3">
      <SystemOverviewPanel
        adminName={adminName}
        onRefresh={load}
        loading={loading}
        statsLoading={loading && !data}
        stats={
          o
            ? [
                {
                  icon: MailOpen,
                  label: 'Pending Requests',
                  sublabel: 'Needs approval',
                  value: o.pendingRequests,
                  accent: 'var(--color-danger)',
                  onClick: () => navigate('/documentation-requests'),
                },
                {
                  icon: Calendar,
                  label: "Today's Events",
                  sublabel: 'Scheduled today',
                  value: o.todayEvents,
                  accent: 'var(--color-accent-blue)',
                  onClick: () => navigate('/event-calendar'),
                },
                {
                  icon: ImageIcon,
                  label: 'Media for Review',
                  sublabel: 'Integrity needs action',
                  value: o.mediaPendingEvaluation,
                  accent: 'var(--color-accent-cyan)',
                  onClick: () => navigate('/media-integrity'),
                },
                {
                  icon: Bell,
                  label: 'Unread Alerts',
                  sublabel: 'Your notifications',
                  value: o.unreadNotifications,
                  accent: 'var(--color-accent-blue)',
                  onClick: () => navigate('/notifications'),
                  badge: o.unreadNotifications > 0,
                },
              ]
            : null
        }
      />

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

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
