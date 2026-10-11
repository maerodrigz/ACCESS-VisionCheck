import { useCallback, useEffect, useMemo, useState } from 'react'
import { Download, Loader2 } from 'lucide-react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { AnalyticsOverviewDashboard } from '../components/analytics/AnalyticsOverviewDashboard'
import { RecentActivityFullPanel } from '../components/analytics/AnalyticsCharts'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { pageToolbarBtnClass, PageToolbarRefreshButton } from '../components/PageToolbar'
import { useToast } from '../context/ToastContext'
import {
  EventsAnalyticsPanel,
  FeedbackAnalyticsPanel,
  MediaAnalyticsPanel,
  ParticipationTable,
  RankingsSummaryPanel,
} from '../components/analytics/AnalyticsPanels'
import {
  ANALYTICS_TABS,
  fetchAnalyticsSnapshot,
  parseAnalyticsTab,
  type AnalyticsSnapshot,
  type AnalyticsTab,
} from '../lib/analytics'
import {
  buildRecentActivityList,
  dateRangeForPeriod,
  type ReportingPeriod,
} from '../lib/analyticsOverview'
import {
  AnalyticsOverviewSection,
  ReportingPeriodSelect,
} from '../components/analytics/AnalyticsOverviewSection'

const ANALYTICS_PAGE_SUBTITLE =
  'Monitor documentation activities, media evaluations, and member performance.'

const TAB_SUBTITLES: Record<AnalyticsTab, string> = {
  overview: ANALYTICS_PAGE_SUBTITLE,
  participation: 'Member participation, uploads, and quality scores.',
  rankings: 'Leaderboard summary and top performers.',
  feedback: 'Requester ratings and satisfaction trends.',
  media: 'Upload volume, format mix, and AI detection.',
  events: 'Calendar events and completion status.',
  activity: 'Recent actions across the platform.',
}

export function AnalyticsPage() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const tab = parseAnalyticsTab(searchParams.get('tab'))
  const [data, setData] = useState<AnalyticsSnapshot | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadingDetails, setLoadingDetails] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [exporting, setExporting] = useState(false)
  const { showToast } = useToast()
  const [reportingPeriod, setReportingPeriod] = useState<ReportingPeriod>('this_month')
  const range = useMemo(
    () => dateRangeForPeriod(reportingPeriod, data),
    [reportingPeriod, data],
  )

  const load = useCallback(async () => {
    setLoading(true)
    setLoadingDetails(true)
    setError(null)
    try {
      const snap = await fetchAnalyticsSnapshot({
        onPartial: (partial) => {
          setData(partial)
          setLoading(false)
        },
      })
      setData(snap)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load analytics')
      setData(null)
    } finally {
      setLoading(false)
      setLoadingDetails(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  async function exportReport() {
    if (!data || exporting) return
    setExporting(true)
    try {
      const { exportAnalyticsPdf } = await import('../lib/analyticsPdf')
      exportAnalyticsPdf(data, range, tab)
      showToast('Analytics report downloaded')
    } catch (e) {
      showToast(e instanceof Error ? `Could not create PDF: ${e.message}` : 'Could not create PDF', 'error')
    } finally {
      setExporting(false)
    }
  }

  const activityItems = useMemo(
    () => (data ? buildRecentActivityList(data, 50) : []),
    [data],
  )

  function setTab(next: AnalyticsTab) {
    if (next === 'overview') setSearchParams({})
    else setSearchParams({ tab: next })
  }

  const tabLabel = ANALYTICS_TABS.find((t) => t.id === tab)?.label ?? 'Analytics'

  const tabNeedsHeavyDataset =
    tab === 'media' || tab === 'activity' || tab === 'participation' || tab === 'overview'

  return (
    <div className={`pb-8 ${tab === 'overview' ? 'space-y-2' : 'space-y-5'}`}>
      <AdminPageHeader
        subtitle={tab === 'overview' ? ANALYTICS_PAGE_SUBTITLE : TAB_SUBTITLES[tab]}
        backTo="/"
        compact={tab === 'overview'}
        actions={
          <>
            <ReportingPeriodSelect
              period={reportingPeriod}
              onPeriodChange={setReportingPeriod}
              disabled={Boolean(error) && !data}
            />
            <button
              type="button"
              onClick={exportReport}
              disabled={!data || exporting}
              className={`${pageToolbarBtnClass} disabled:opacity-50`}
            >
              {exporting ? (
                <Loader2 size={16} className="shrink-0 animate-spin text-[var(--color-text-secondary)]" strokeWidth={2} />
              ) : (
                <Download size={16} className="shrink-0 text-[var(--color-text-secondary)]" strokeWidth={2} />
              )}
              Export PDF
            </button>
            <PageToolbarRefreshButton onClick={load} disabled={loading} loading={loading} />
          </>
        }
      />

      {error && (
        <AdminErrorBanner>{error}</AdminErrorBanner>
      )}

      {tab === 'overview' ? (
        <AnalyticsOverviewSection
          data={data}
          range={range}
          period={reportingPeriod}
          loading={loading || loadingDetails}
          unavailable={Boolean(error) && !data}
        />
      ) : null}

      <div className="flex flex-wrap gap-2">
        {ANALYTICS_TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setTab(t.id)}
            className={[
              'rounded-full px-4 py-1.5 text-xs font-bold transition',
              tab === t.id
                ? 'bg-[var(--color-accent-blue)] text-white'
                : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
            ].join(' ')}
          >
            {t.label}
          </button>
        ))}
      </div>

      {(loading && !data) || (loadingDetails && tabNeedsHeavyDataset) ? (
        <div className="flex justify-center py-16">
          <Loader2 className="animate-spin text-[var(--color-text-muted)]" size={28} />
        </div>
      ) : data ? (
        <>
          {tab !== 'overview' && (
            <div className="flex items-center justify-between gap-2">
              <h2 className="text-sm font-bold text-[var(--color-text-primary)]">{tabLabel}</h2>
              {tab === 'activity' && (
                <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
                  {activityItems.length} events
                </span>
              )}
            </div>
          )}
          {tab === 'overview' && (
            <AnalyticsOverviewDashboard
              data={data}
              range={range}
              onViewAllMembers={() => navigate('/members')}
              onViewAllActivity={() => setTab('activity')}
            />
          )}
          {tab === 'participation' && <ParticipationTable data={data} />}
          {tab === 'rankings' && <RankingsSummaryPanel data={data} />}
          {tab === 'feedback' && <FeedbackAnalyticsPanel data={data} />}
          {tab === 'media' && <MediaAnalyticsPanel data={data} />}
          {tab === 'events' && <EventsAnalyticsPanel data={data} />}
          {tab === 'activity' && <RecentActivityFullPanel items={activityItems} />}
        </>
      ) : null}
    </div>
  )
}
