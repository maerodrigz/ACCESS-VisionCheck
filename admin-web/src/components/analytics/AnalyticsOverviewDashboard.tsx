import { useMemo } from 'react'
import type { AnalyticsSnapshot } from '../../lib/analytics'
import { buildAnalyticsOverview, type DateRange } from '../../lib/analyticsOverview'
import {
  MediaDonutCard,
  QualityDonutCard,
  RecentActivityCard,
  RequestsByMonthCard,
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
  const model = useMemo(() => buildAnalyticsOverview(data, range), [data, range])

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-1 items-stretch gap-4 lg:grid-cols-2">
        <RequestsByMonthCard requests={data.requests} />
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
