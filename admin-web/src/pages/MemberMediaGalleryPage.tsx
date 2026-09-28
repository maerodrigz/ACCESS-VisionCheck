import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { MediaGalleryTabs } from '../components/media-library/MediaGalleryTabs'
import { Image, RefreshCw, Search, Video } from 'lucide-react'
import { archiveMediaFile, deleteMedia, fetchEvaluations, fetchMedia } from '../api/admin'
import { isEvaluationFlagged, parseEvaluation } from '../lib/evaluationReview'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminConfirmDialog } from '../components/AdminConfirmDialog'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { AdminEmptyState } from '../components/AdminEmptyState'
import { MediaPreviewDrawer } from '../components/media-library/MediaPreviewDrawer'
import { MediaTile } from '../components/media-library/MediaTile'
import { PageLoader } from '../components/PageLoader'
import { pageToolbarBtnClass } from '../components/PageToolbar'
import { useAuth } from '../context/AuthContext'
import { useToast } from '../context/ToastContext'
import {
  filterByMediaFormat,
  parseMediaRows,
  refreshAssetFlags,
  type MediaAsset,
} from '../lib/mediaLibrary'

type FormatFilter = 'photos' | 'videos'

const FORMAT_TABS: { id: FormatFilter; label: string; icon: typeof Image }[] = [
  { id: 'photos', label: 'Photos', icon: Image },
  { id: 'videos', label: 'Videos', icon: Video },
]

function parseFormatFilter(raw: string | null): FormatFilter {
  return raw === 'videos' ? 'videos' : 'photos'
}

export function MemberMediaGalleryPage() {
  const { user } = useAuth()
  const isAdmin = user?.role === 'Admin'
  const { showToast } = useToast()
  const [searchParams, setSearchParams] = useSearchParams()
  const [all, setAll] = useState<MediaAsset[]>([])
  const [evalByMediaId, setEvalByMediaId] = useState<
    Map<number, { evaluationId: number; integrityFlagged: boolean }>
  >(() => new Map())
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState(() => searchParams.get('q') ?? '')
  const [formatFilter, setFormatFilter] = useState<FormatFilter>(() =>
    parseFormatFilter(searchParams.get('format')),
  )
  const [previewItem, setPreviewItem] = useState<MediaAsset | null>(null)
  const [confirmDelete, setConfirmDelete] = useState<MediaAsset | null>(null)
  const [confirmArchive, setConfirmArchive] = useState<MediaAsset | null>(null)
  const [busy, setBusy] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [rows, evalRows] = await Promise.all([fetchMedia(), fetchEvaluations()])
      const items = parseMediaRows(rows).map(refreshAssetFlags)
      const evalMap = new Map<number, { evaluationId: number; integrityFlagged: boolean }>()
      for (const raw of evalRows) {
        const ev = parseEvaluation(raw)
        if (!ev.mediaId) continue
        evalMap.set(ev.mediaId, {
          evaluationId: ev.id,
          integrityFlagged: isEvaluationFlagged(ev),
        })
      }
      setEvalByMediaId(evalMap)
      setAll(items)
      setPreviewItem((prev) => {
        if (!prev) return null
        return items.find((a) => a.id === prev.id) ?? null
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load member uploads')
      setAll([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  useEffect(() => {
    const mediaId = Number(searchParams.get('media') || 0)
    if (!mediaId || all.length === 0) return
    const item = all.find((a) => a.id === mediaId)
    if (!item) return
    setPreviewItem(item)
    const next = new URLSearchParams(searchParams)
    next.delete('media')
    setSearchParams(next, { replace: true })
  }, [all, searchParams, setSearchParams])

  const baseItems = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) {
      return all.filter((a) => a.mediaCategory === 'member_evaluation')
    }
    return all.filter(
      (a) =>
        a.fileName.toLowerCase().includes(q) ||
        a.uploaderName.toLowerCase().includes(q) ||
        a.eventName.toLowerCase().includes(q),
    )
  }, [all, search])

  const filtered = useMemo(
    () => filterByMediaFormat(baseItems, formatFilter),
    [baseItems, formatFilter],
  )

  const activeTab = FORMAT_TABS.find((t) => t.id === formatFilter) ?? FORMAT_TABS[0]
  const ActiveIcon = activeTab.icon

  async function handleArchive(item: MediaAsset) {
    setBusy(true)
    try {
      await archiveMediaFile(item.id)
      if (previewItem?.id === item.id) setPreviewItem(null)
      await load()
      showToast('Media archived')
      setConfirmArchive(null)
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Archive failed', 'error')
    } finally {
      setBusy(false)
    }
  }

  async function handleDelete(item: MediaAsset) {
    setBusy(true)
    try {
      await deleteMedia(item.id)
      if (previewItem?.id === item.id) setPreviewItem(null)
      await load()
      showToast('Media deleted permanently')
      setConfirmDelete(null)
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Delete failed', 'error')
    } finally {
      setBusy(false)
    }
  }

  function downloadItem(item: MediaAsset) {
    const link = document.createElement('a')
    link.href = item.thumbnailUrl
    link.download = item.fileName
    link.target = '_blank'
    link.rel = 'noopener noreferrer'
    link.click()
  }

  return (
    <div className="space-y-6 pb-12">
      <AdminPageHeader
        subtitle="Practice evaluation photos and videos from members. Never published to Facebook."
        backTo="/"
        actions={
          <button type="button" onClick={load} disabled={loading} className={pageToolbarBtnClass}>
            <RefreshCw size={16} className={loading ? 'animate-spin' : 'shrink-0 text-[var(--color-text-secondary)]'} />
            Refresh
          </button>
        }
      />

      <MediaGalleryTabs />

      <p className="text-xs text-[var(--color-text-secondary)]">
        Practice scores are shown to members in the mobile app. Open{' '}
        <Link to="/media-integrity" className="font-semibold text-[var(--color-accent-blue)] hover:underline">
          Media Integrity
        </Link>{' '}
        when AI flags an upload for admin review.
      </p>

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div className="rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <div className="relative min-w-0 flex-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search member, file name…"
              className="admin-input w-full rounded-xl py-2 pl-9 pr-3 text-sm"
            />
          </div>
          <div className="flex shrink-0 gap-1.5" role="tablist" aria-label="Media format">
            {FORMAT_TABS.map((tab) => {
              const Icon = tab.icon
              const active = formatFilter === tab.id
              return (
                <button
                  key={tab.id}
                  type="button"
                  role="tab"
                  aria-selected={active}
                  onClick={() => setFormatFilter(tab.id)}
                  className={[
                    'inline-flex items-center gap-1.5 rounded-full px-4 py-1.5 text-xs font-bold transition',
                    active
                      ? 'bg-[var(--color-accent-blue)] text-white'
                      : 'border border-[var(--color-border)] bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]',
                  ].join(' ')}
                >
                  <Icon size={14} />
                  {tab.label}
                </button>
              )
            })}
          </div>
        </div>
        <p className="mt-2 text-xs text-[var(--color-text-secondary)]">
          {filtered.length} {formatFilter === 'photos' ? 'photo' : 'video'}
          {filtered.length === 1 ? '' : 's'} shown
        </p>
      </div>

      {loading && all.length === 0 ? (
        <PageLoader label="Loading member uploads…" />
      ) : filtered.length === 0 ? (
        <AdminEmptyState
          title={formatFilter === 'photos' ? 'No photos found' : 'No videos found'}
        >
          {formatFilter === 'photos'
            ? 'Switch to Videos or adjust your search to see other member uploads.'
            : 'Switch to Photos or adjust your search to see other member uploads.'}
        </AdminEmptyState>
      ) : (
        <section>
          <div className="mb-3 flex items-center gap-2">
            <ActiveIcon
              size={16}
              className={
                formatFilter === 'photos'
                  ? 'text-[var(--color-accent-cyan)]'
                  : 'text-[var(--color-accent-blue)]'
              }
            />
            <h2 className="text-sm font-bold text-[var(--color-text-primary)]">{activeTab.label}</h2>
            <span className="rounded-full bg-[var(--color-surface-muted)] px-2 py-0.5 text-[10px] font-bold text-[var(--color-text-secondary)]">
              {filtered.length}
            </span>
          </div>
          <div className="grid grid-cols-[repeat(auto-fill,minmax(168px,1fr))] gap-4">
            {filtered.map((item) => (
              <MediaTile
                key={item.id}
                item={item}
                selected={false}
                isAdmin={isAdmin}
                onTap={() => setPreviewItem(item)}
                onSelectToggle={() => setPreviewItem(item)}
                onToggleBestShot={() => undefined}
              />
            ))}
          </div>
        </section>
      )}

      {previewItem && (
        <MediaPreviewDrawer
          item={previewItem}
          isAdmin={isAdmin}
          integrityFlagged={evalByMediaId.get(previewItem.id)?.integrityFlagged ?? false}
          onClose={() => setPreviewItem(null)}
          onDownload={() => downloadItem(previewItem)}
          onMoveToAlbum={() => showToast('Album moves apply to event media only.', 'info')}
          onArchive={() => setConfirmArchive(previewItem)}
          onDelete={() => setConfirmDelete(previewItem)}
          onToggleBestShot={() => showToast('Best picks apply to event media only.', 'info')}
          onPublishFacebook={() => showToast('Member evaluation media is never published to Facebook.', 'info')}
        />
      )}

      <AdminConfirmDialog
        open={confirmArchive != null}
        title="Archive media?"
        message={
          confirmArchive
            ? `"${confirmArchive.fileName}" will be hidden from the gallery for all admins.`
            : ''
        }
        confirmLabel="Archive"
        loading={busy}
        onCancel={() => !busy && setConfirmArchive(null)}
        onConfirm={() => confirmArchive && void handleArchive(confirmArchive)}
      />

      <AdminConfirmDialog
        open={confirmDelete != null}
        title="Delete permanently?"
        message={
          confirmDelete
            ? `"${confirmDelete.fileName}" will be removed from the server. This cannot be undone.`
            : ''
        }
        confirmLabel="Delete"
        tone="danger"
        loading={busy}
        onCancel={() => !busy && setConfirmDelete(null)}
        onConfirm={() => confirmDelete && void handleDelete(confirmDelete)}
      />
    </div>
  )
}
