import { useMemo, useState } from 'react'
import type { AnalyticsSnapshot } from '../../lib/analytics'
import { buildAnalyticsOverview, type DateRange } from '../../lib/analyticsOverview'
import { AssignmentsOverviewCard } from './AnalyticsPanels'
import {
  EvaluationsOverTimeCard,
  MediaDonutCard,
  QualityDonutCard,
  RecentActivityCard,
  TopMembersCard,
} from './AnalyticsCharts'

export function AnalyticsOverviewDashboard({
  data,
  range,
  onViewAllMembers,
  onViewAllActivity,
}: {
  data: AnalyticsSnapshot
  range: DateRange
  onViewAllMembers?: () => void
  onViewAllActivity?: () => void
}) {
  const [seriesMode, setSeriesMode] = useState<'daily' | 'weekly'>('daily')

  const model = useMemo(
    () => buildAnalyticsOverview(data, range, { seriesGranularity: seriesMode }),
    [data, range, seriesMode],
  )

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-2 rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
        <div className="flex flex-wrap gap-2">
          {model.kpis.map((kpi) => (
            <span
              key={kpi.label}
              className="rounded-full border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-1.5 text-xs font-bold text-[var(--color-text-secondary)]"
            >
              {kpi.label}: {kpi.value}
              {kpi.valueSuffix ?? ''}
              {kpi.growthPct != null && (
                <span className={kpi.growthPct >= 0 ? ' text-emerald-400' : ' text-red-400'}>
                  {' '}
                  ({kpi.growthPct >= 0 ? '+' : ''}
                  {kpi.growthPct.toFixed(0)}%)
                </span>
              )}
            </span>
          ))}
        </div>
      </div>

      <AssignmentsOverviewCard data={data} />

      <div className="grid grid-cols-1 items-stretch gap-4 lg:grid-cols-2">
        <EvaluationsOverTimeCard
          points={model.evaluationsSeries}
          seriesMode={seriesMode}
          onSeriesModeChange={setSeriesMode}
        />
        <QualityDonutCard buckets={model.qualityBuckets} total={model.qualityTotal} />
      </div>

      <div className="grid grid-cols-1 items-stretch gap-4 lg:grid-cols-3">
        <TopMembersCard members={model.topMembers} onViewAll={onViewAllMembers} />
        <MediaDonutCard photos={model.mediaPhotos} videos={model.mediaVideos} total={model.mediaTotal} />
        <RecentActivityCard items={model.recentActivity} onViewAll={onViewAllActivity} />
      </div>
    </div>
  )
}
