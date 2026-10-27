import { useCallback, useEffect, useState } from 'react'
import { Loader2 } from 'lucide-react'
import {
  fetchAdminSubmissionChain,
  type AdminSubmissionChainTimeline,
  type SubmissionChainMediaRow,
} from '../../api/submissionChain'
import { reviewStatusLabel } from '../../lib/aiDetection'
import { chainMediaRoleLabel, formatChainEventType } from '../../lib/submissionChainPresentation'

type Props = {
  mediaId: number
  refreshKey?: string | number
  onOpenRelatedMedia?: (mediaId: number) => void
}

export function SubmissionChainPanel({ mediaId, refreshKey, onOpenRelatedMedia }: Props) {
  const [chain, setChain] = useState<AdminSubmissionChainTimeline | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchAdminSubmissionChain(mediaId)
      setChain(data)
    } catch (e) {
      setChain(null)
      setError(e instanceof Error ? e.message : 'Could not load submission chain')
    } finally {
      setLoading(false)
    }
  }, [mediaId])

  useEffect(() => {
    void load()
  }, [load, refreshKey])

  if (loading) {
    return (
      <div className="flex items-center gap-2 py-3 text-xs text-[var(--color-text-secondary)]">
        <Loader2 size={14} className="animate-spin" />
        Loading submission chain…
      </div>
    )
  }

  if (error) {
    return (
      <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)]/40 px-3 py-2 text-xs text-[var(--color-danger)]">
        {error}
      </div>
    )
  }

  if (!chain || chain.media.length === 0) {
    return (
      <p className="text-xs text-[var(--color-text-muted)]">No linked submission history for this media yet.</p>
    )
  }

  const activeId = chain.active_replacement_media_id

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2 text-[10px] text-[var(--color-text-secondary)]">
        <span>Chain #{chain.chain_id}</span>
        <span>Root media {chain.root_media_id}</span>
        {chain.xp_award_locked ? <span className="font-semibold text-[var(--color-warning)]">XP locked</span> : null}
      </div>
      <ul className="space-y-2">
        {chain.media.map((item) => (
          <ChainMediaCard
            key={item.media_id}
            item={item}
            rootMediaId={chain.root_media_id}
            isActiveReplacement={activeId != null && item.media_id === activeId}
            onOpenRelatedMedia={onOpenRelatedMedia}
          />
        ))}
      </ul>
      {chain.events.length > 0 ? (
        <div>
          <p className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
            Chain events
          </p>
          <ul className="mt-1 max-h-32 space-y-1 overflow-y-auto text-[11px] text-[var(--color-text-primary)]">
            {chain.events.map((ev) => (
              <li key={ev.id} className="rounded border border-[var(--color-border)]/60 px-2 py-1">
                <span className="font-semibold">{formatChainEventType(ev.event_type)}</span>
                {ev.media_id ? ` · media ${ev.media_id}` : ''}
                {ev.created_at ? (
                  <span className="text-[var(--color-text-muted)]"> · {new Date(ev.created_at).toLocaleString()}</span>
                ) : null}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  )
}

function ChainMediaCard({
  item,
  rootMediaId,
  isActiveReplacement,
  onOpenRelatedMedia,
}: {
  item: SubmissionChainMediaRow
  rootMediaId: number
  isActiveReplacement: boolean
  onOpenRelatedMedia?: (mediaId: number) => void
}) {
  const role = chainMediaRoleLabel(item, rootMediaId)
  const status = item.review_status
    ? reviewStatusLabel(item.review_status as import('../../api/media').ReviewStatus)
    : null

  return (
    <li
      className={[
        'rounded-lg border px-3 py-2',
        isActiveReplacement
          ? 'border-[var(--color-accent-blue)] bg-[var(--color-accent-blue)]/5'
          : 'border-[var(--color-border)] bg-[var(--color-surface)]',
      ].join(' ')}
    >
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="truncate text-xs font-bold text-[var(--color-text-primary)]">{item.file_name}</p>
          <p className="text-[10px] text-[var(--color-text-secondary)]">
            {role} · ID {item.media_id}
            {item.uploaded_at ? ` · ${new Date(item.uploaded_at).toLocaleString()}` : ''}
          </p>
          {status ? (
            <p className="mt-0.5 text-[10px] font-semibold text-[var(--color-text-primary)]">Review: {status}</p>
          ) : null}
          {item.admin_remarks?.trim() ? (
            <p className="mt-1 text-[11px] leading-snug text-[var(--color-text-secondary)]">{item.admin_remarks}</p>
          ) : null}
        </div>
        {isActiveReplacement && onOpenRelatedMedia && item.media_id !== rootMediaId ? (
          <button
            type="button"
            className="shrink-0 rounded-md border border-[var(--color-border)] px-2 py-1 text-[10px] font-semibold hover:bg-[var(--color-surface-hover)]"
            onClick={() => onOpenRelatedMedia(item.media_id)}
          >
            Open in queue
          </button>
        ) : null}
      </div>
    </li>
  )
}
