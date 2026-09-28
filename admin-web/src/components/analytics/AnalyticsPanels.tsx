import { AdminCard } from '../AdminCard'
import type { AnalyticsSnapshot } from '../../lib/analytics'
import { qualityPercentFromRanking } from '../../lib/analytics'

interface Segment {
  label: string
  value: number
  color: string
}

export function DistributionCard({ title, segments }: { title: string; segments: Segment[] }) {
  const total = segments.reduce((sum, s) => sum + s.value, 0)

  return (
    <AdminCard padding="md">
      <h3 className="text-sm font-extrabold text-[var(--color-text-primary)]">{title}</h3>
      {total === 0 ? (
        <p className="mt-3 text-sm text-[var(--color-text-secondary)]">No data yet.</p>
      ) : (
        <>
          <div className="mt-4 flex h-3 overflow-hidden rounded-lg">
            {segments
              .filter((s) => s.value > 0)
              .map((seg) => (
                <div key={seg.label} className="h-full" style={{ flex: seg.value, backgroundColor: seg.color }} />
              ))}
          </div>
          <div className="mt-4 space-y-2">
            {segments.map((seg) => (
              <div key={seg.label} className="flex items-center gap-2 text-sm">
                <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: seg.color }} />
                <span className="flex-1 text-[var(--color-text-secondary)]">{seg.label}</span>
                <span className="font-bold">{seg.value}</span>
                <span className="text-xs text-[var(--color-text-secondary)]">
                  {total > 0 ? `${Math.round((seg.value / total) * 100)}%` : '0%'}
                </span>
              </div>
            ))}
          </div>
        </>
      )}
    </AdminCard>
  )
}

export function AssignmentsOverviewCard({ data }: { data: AnalyticsSnapshot }) {
  const s = data.stats
  return (
    <DistributionCard
      title="Member assignments"
      segments={[
        {
          label: 'Awaiting acceptance',
          value: Number(s.pending_assignments ?? 0),
          color: 'var(--color-warning)',
        },
        {
          label: 'Accepted',
          value: Number(s.accepted_assignments ?? s.completed_tasks ?? 0),
          color: 'var(--color-success)',
        },
        {
          label: 'Declined',
          value: Number(s.declined_assignments ?? 0),
          color: 'var(--color-danger)',
        },
      ]}
    />
  )
}

export function AnalyticsOverviewPanel({ data }: { data: AnalyticsSnapshot }) {
  const s = data.stats
  const rs = data.rankingsSummary

  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <MiniStat label="Total events" value={String(s.total_events ?? 0)} />
        <MiniStat label="Accepted assignments" value={String(s.accepted_assignments ?? s.completed_tasks ?? '—')} />
        <MiniStat label="Awaiting acceptance" value={String(s.pending_assignments ?? '—')} />
        <MiniStat label="Active members" value={String(s.active_members ?? 0)} />
        <MiniStat label="Media uploads" value={String(s.media_uploads ?? 0)} />
        <MiniStat
          label="Avg feedback"
          value={s.avg_feedback_rating != null ? Number(s.avg_feedback_rating).toFixed(1) : '—'}
        />
        <MiniStat label="Top performer" value={String(rs.top_performer_name ?? '—')} />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <DistributionCard
          title="Documentation requests"
          segments={[
            { label: 'Pending', value: Number(s.pending_requests ?? 0), color: 'var(--color-warning)' },
            { label: 'Approved', value: Number(s.approved_requests ?? 0), color: 'var(--color-success)' },
            { label: 'Rejected', value: Number(s.rejected_requests ?? 0), color: 'var(--color-danger)' },
            { label: 'Completed', value: Number(s.completed_requests ?? 0), color: 'var(--color-accent-blue)' },
          ]}
        />
        <AssignmentsOverviewCard data={data} />
        <DistributionCard
          title="Media & quality"
          segments={[
            { label: 'Uploads', value: Number(s.media_uploads ?? 0), color: '#0891B2' },
            { label: 'Evaluations', value: Number(s.total_evaluations ?? 0), color: 'var(--color-accent-blue)' },
            { label: 'AI flagged', value: Number(s.ai_flagged ?? 0), color: 'var(--color-danger)' },
          ]}
        />
      </div>
    </div>
  )
}

function AnalyticsSummaryLine({ parts }: { parts: string[] }) {
  return <p className="text-xs text-[var(--color-text-muted)]">{parts.join(' · ')}</p>
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <AdminCard padding="sm">
      <div className="text-xl font-extrabold text-[var(--color-text-primary)]">{value}</div>
      <div className="text-xs font-semibold text-[var(--color-text-secondary)]">{label}</div>
    </AdminCard>
  )
}

export function ParticipationTable({ data }: { data: AnalyticsSnapshot }) {
  const rows = data.rankings.slice(0, 50).map((r) => ({
    name: String(r.member_name ?? r.fullname ?? r.name ?? 'Member'),
    tasks: Number(r.completed_tasks ?? r.tasks_completed ?? 0),
    uploads: Number(r.uploads ?? r.total_uploads ?? r.media_uploads ?? r.upload_count ?? 0),
    points: Number(r.points ?? r.total_points ?? r.good_evaluations ?? r.participation_score ?? 0),
    quality: qualityPercentFromRanking(r),
    skill: String(r.skill_level ?? '—'),
  }))

  return (
    <AdminCard padding="none" bodyClassName="overflow-x-auto">
      <table className="w-full min-w-[640px] text-left text-sm">
        <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-xs font-bold text-[var(--color-text-secondary)]">
          <tr>
            <th className="px-4 py-3">Member</th>
            <th className="px-4 py-3">Accepted</th>
            <th className="px-4 py-3">Uploads</th>
            <th className="px-4 py-3">Points</th>
            <th className="px-4 py-3">Avg quality</th>
            <th className="px-4 py-3">Skill</th>
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr>
              <td colSpan={6} className="px-4 py-8 text-center text-[var(--color-text-secondary)]">
                No participation data yet.
              </td>
            </tr>
          ) : (
            rows.map((row) => (
              <tr key={row.name} className="border-b border-[var(--color-border)] last:border-0">
                <td className="px-4 py-3 font-semibold">{row.name}</td>
                <td className="px-4 py-3">{row.tasks}</td>
                <td className="px-4 py-3">{row.uploads}</td>
                <td className="px-4 py-3">{row.points}</td>
                <td className="px-4 py-3">{row.quality > 0 ? `${Math.round(row.quality)}%` : '—'}</td>
                <td className="px-4 py-3">{row.skill}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </AdminCard>
  )
}

export function RankingsSummaryPanel({ data }: { data: AnalyticsSnapshot }) {
  const rs = data.rankingsSummary
  const rows = [
    { label: 'Total ranked', value: String(rs.total_ranked ?? 0) },
    { label: 'Top performer', value: String(rs.top_performer_name ?? 'N/A') },
    { label: 'Top performer points', value: String(rs.top_performer_points ?? 0) },
    { label: 'Needs improvement', value: String(rs.needs_improvement_count ?? 0) },
    { label: 'Most active uploader', value: String(rs.most_active_uploader_name ?? 'N/A') },
    { label: 'Most uploads', value: String(rs.most_active_uploads ?? 0) },
  ]

  return (
    <div className="overflow-hidden rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)]">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[480px] text-left text-sm">
          <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
            <tr>
              <th className="px-4 py-3">Metric</th>
              <th className="px-4 py-3 text-right">Value</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr
                key={row.label}
                className="border-b border-[var(--color-border-subtle)] transition last:border-0 hover:bg-[var(--color-surface-hover)]"
              >
                <td className="px-4 py-3 text-[var(--color-text-secondary)]">{row.label}</td>
                <td className="px-4 py-3 text-right font-semibold text-[var(--color-text-primary)]">{row.value}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export function FeedbackAnalyticsPanel({ data }: { data: AnalyticsSnapshot }) {
  const avg =
    data.stats.avg_feedback_rating != null ? Number(data.stats.avg_feedback_rating).toFixed(1) : 'N/A'
  const distribution = [5, 4, 3, 2, 1].map((star) => ({
    label: `${star} stars`,
    value: data.feedback.filter((f) => Math.round(Number(f.rating ?? 0)) === star).length,
    color: star >= 4 ? 'var(--color-success)' : star === 3 ? 'var(--color-warning)' : 'var(--color-danger)',
  }))

  return (
    <div className="space-y-4">
      <AnalyticsSummaryLine
        parts={[
          `${data.feedback.length} total`,
          `${avg}/5 average`,
          `${data.stats.feedback_count ?? 0} in stats`,
        ]}
      />
      <DistributionCard title="Rating distribution" segments={distribution} />
    </div>
  )
}

export function MediaAnalyticsPanel({ data }: { data: AnalyticsSnapshot }) {
  const photos = data.media.filter((m) => !String(m.file_type ?? '').toLowerCase().includes('video')).length
  const videos = data.media.length - photos
  const ai = data.aiSummary as Record<string, unknown>

  return (
    <div className="space-y-4">
      <AnalyticsSummaryLine
        parts={[
          `${data.media.length} total media`,
          `${photos} photos`,
          `${videos} videos`,
          `${data.evaluations.length} evaluations`,
        ]}
      />
      <DistributionCard
        title="Media format mix"
        segments={[
          { label: 'Photos', value: photos, color: '#22c55e' },
          { label: 'Videos', value: videos, color: 'var(--color-accent-blue)' },
        ]}
      />
      <AdminCard padding="md">
        <h3 className="text-sm font-extrabold text-[var(--color-text-primary)]">AI detection summary</h3>
        <AnalyticsSummaryLine
          parts={[
            `${ai.total_scanned ?? 0} scanned`,
            `${ai.human_count ?? 0} human`,
            `${ai.ai_generated_count ?? 0} AI generated`,
            `${ai.pending_review_count ?? 0} pending review`,
          ]}
        />
      </AdminCard>
    </div>
  )
}

export function EventsAnalyticsPanel({ data }: { data: AnalyticsSnapshot }) {
  const events = data.events
  const today = new Date()
  today.setHours(0, 0, 0, 0)

  let upcoming = 0
  let completed = 0
  for (const e of events) {
    const status = String(e.status ?? '').toLowerCase()
    if (status === 'completed') completed++
    const d = new Date(String(e.event_date ?? ''))
    if (!Number.isNaN(d.getTime()) && d >= today && status !== 'completed' && status !== 'cancelled') {
      upcoming++
    }
  }

  return (
    <div className="space-y-4">
      <AnalyticsSummaryLine
        parts={[`${events.length} total`, `${upcoming} upcoming`, `${completed} completed`]}
      />
      <AdminCard padding="none" bodyClassName="overflow-x-auto">
        <div className="border-b border-[var(--color-border)] px-4 py-3">
          <h3 className="text-sm font-extrabold text-[var(--color-text-primary)]">Event schedule report</h3>
        </div>
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead className="border-b border-[var(--color-border)] bg-[var(--color-surface-muted)] text-xs font-bold text-[var(--color-text-secondary)]">
            <tr>
              <th className="px-4 py-3">Event</th>
              <th className="px-4 py-3">Date</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Assigned</th>
              <th className="px-4 py-3">Location</th>
            </tr>
          </thead>
          <tbody>
            {events.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-[var(--color-text-secondary)]">
                  No events on the calendar yet.
                </td>
              </tr>
            ) : (
              events.map((e, i) => (
                <tr key={String(e.id ?? i)} className="border-b border-[var(--color-border)] last:border-0">
                  <td className="px-4 py-3 font-semibold">{String(e.title ?? '—')}</td>
                  <td className="px-4 py-3">{String(e.event_date ?? '—')}</td>
                  <td className="px-4 py-3">{String(e.status ?? '—')}</td>
                  <td className="px-4 py-3">{String(e.assigned_member_name ?? '—')}</td>
                  <td className="px-4 py-3">{String(e.location ?? '—')}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </AdminCard>
    </div>
  )
}

export function InsightsCard({ lines }: { lines: string[] }) {
  return (
    <AdminCard padding="md">
      <h3 className="text-sm font-extrabold text-[var(--color-text-primary)]">Key insights</h3>
      <ul className="mt-3 space-y-2">
        {lines.map((line) => (
          <li key={line} className="flex gap-2 text-sm leading-relaxed text-[var(--color-text-primary)]">
            <span className="font-bold text-[var(--color-accent-blue)]">•</span>
            <span>{line}</span>
          </li>
        ))}
      </ul>
    </AdminCard>
  )
}
