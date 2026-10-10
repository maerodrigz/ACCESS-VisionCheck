import { useMemo } from 'react'
import type { AnalyticsSnapshot } from '../../lib/analytics'
import { buildAnalyticsOverview, type DateRange } from '../../lib/analyticsOverview'
import {
  DocumentationActivityCard,
  MediaEvaluationOverviewCard,
  EventsByCategoryCard,
  MemberParticipationCard,
} from './AnalyticsCharts'

/** Matches dashboard Pending Service Requests row height. */
const CHART_ROW_HEIGHT = 'h-[320px]'

export function AnalyticsOverviewDashboard({
  data,
  range,
  onViewAllMembers: _onViewAllMembers,
  onViewAllActivity: _onViewAllActivity,
}: {
  data: AnalyticsSnapshot
  range: DateRange
  onViewAllMembers?: () => void
  onViewAllActivity?: () => void
}) {
  const model = useMemo(() => buildAnalyticsOverview(data, range), [data, range])

  return (
    <div className="space-y-1.5">
      <div className="grid grid-cols-1 items-stretch gap-1.5 lg:grid-cols-2">
        <DocumentationActivityCard
          requests={data.requests}
          events={data.events}
          className={CHART_ROW_HEIGHT}
        />
        <MediaEvaluationOverviewCard
          photos={model.evaluationPhotos}
          videos={model.evaluationVideos}
          className={CHART_ROW_HEIGHT}
        />
      </div>

      <div className="grid grid-cols-1 items-stretch gap-1.5 lg:grid-cols-2">
        <MemberParticipationCard stats={model.memberParticipation} className={CHART_ROW_HEIGHT} />
        <EventsByCategoryCard categories={model.eventsByCategory} className={CHART_ROW_HEIGHT} />
      </div>
    </div>
  )
}
