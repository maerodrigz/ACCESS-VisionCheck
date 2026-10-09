import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import {
  AlertCircle,
  ArrowLeft,
  FolderOpen,
  Loader2,
  RefreshCw,
  Search,
  Upload,
} from 'lucide-react'
import {
  archiveMediaFile,
  deleteMedia,
  fetchServiceRequests,
  uploadMediaFile,
} from '../api/admin'
import {
  bulkPublishEventMediaToFacebook,
  fetchEventMedia,
  fetchFacebookConfigStatus,
  fetchFacebookPublishHistory,
  updateEventMediaCuration,
  type FacebookConfigStatus,
  type FacebookHistoryEntry,
} from '../api/eventMedia'
import { AdminCard } from '../components/AdminCard'
import { AdminErrorBanner } from '../components/AdminAlert'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { pageToolbarBtnClass } from '../components/PageToolbar'
import { AdminConfirmDialog } from '../components/AdminConfirmDialog'
import { MoveAlbumModal } from '../components/media-library/MoveAlbumModal'
import { AdminOperationBanner, type OperationBannerState } from '../components/AdminOperationBanner'
import { AdminSelect } from '../components/AdminSelect'
import { FacebookPublishModal } from '../components/media-library/FacebookPublishModal'
import {
  BestPicksSection,
  EventAlbumsSection,
  FacebookHistoryCollapsible,
  MediaBulkToolbar,
} from '../components/media-library/MediaAlbumSections'
import { MediaPreviewDrawer } from '../components/media-library/MediaPreviewDrawer'
import { MediaTileGrid } from '../components/media-library/MediaTileGrid'
import { useAuth } from '../context/AuthContext'
import { useToast } from '../context/ToastContext'
import {
  albumKey,
  buildAlbums,
  canPublishToFacebook,
  computeMediaStats,
  filterAlbumsBySearch,
  filterMedia,
  parseEventMediaRows,
  pendingBestShots,
  refreshAssetFlags,
  type MediaAlbum,
  type MediaAsset,
} from '../lib/mediaLibrary'
import { publishOneToFacebookBrowser, openFacebookPage } from '../lib/facebookShare'
import type { FacebookPublishStatus } from '../api/eventMedia'

type FbChip = FacebookPublishStatus | 'all'
type GalleryKind = 'photos' | 'videos'

const PUBLISH_STATUS_OPTIONS: { id: FbChip; label: string }[] = [
  { id: 'all', label: 'All publish status' },
  { id: 'not_published', label: 'Not published' },
  { id: 'published', label: 'Published' },
  { id: 'failed', label: 'Failed' },
]

export function MediaLibraryPage() {
  const { user } = useAuth()
  const [searchParams, setSearchParams] = useSearchParams()
  const isAdmin = user?.role === 'Admin'
  const fileInputRef = useRef<HTMLInputElement>(null)

  const [all, setAll] = useState<MediaAsset[]>([])
  const [albums, setAlbums] = useState<MediaAlbum[]>([])
  const [requests, setRequests] = useState<Record<string, unknown>[]>([])
  const [fbHistory, setFbHistory] = useState<FacebookHistoryEntry[]>([])
  const [fbConfig, setFbConfig] = useState<FacebookConfigStatus | null>(null)
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [galleryKind, setGalleryKind] = useState<GalleryKind>('photos')
  const [fbFilter, setFbFilter] = useState<FbChip>('all')
  const [selectedAlbumId, setSelectedAlbumId] = useState<string | null>(null)
  const [selectedAlbumName, setSelectedAlbumName] = useState<string | null>(null)
  const [previewItem, setPreviewItem] = useState<MediaAsset | null>(null)
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set())
  const { showToast } = useToast()
  const [publishing, setPublishing] = useState(false)
  const [publishModalOpen, setPublishModalOpen] = useState(false)
  const [publishTargets, setPublishTargets] = useState<MediaAsset[]>([])
  const [operationBanner, setOperationBanner] = useState<OperationBannerState | null>(null)
  const [confirmDialog, setConfirmDialog] = useState<
    | { kind: 'delete-one'; item: MediaAsset }
    | { kind: 'archive-one'; item: MediaAsset }
    | { kind: 'delete-bulk'; count: number }
    | { kind: 'delete-album'; albumId: string; name: string; ids: number[] }
    | { kind: 'archive-album'; albumId: string; name: string; ids: number[] }
    | null
  >(null)
  const [moveAlbumItems, setMoveAlbumItems] = useState<MediaAsset[] | null>(null)
  const [dialogBusy, setDialogBusy] = useState(false)
  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [eventRows, reqs, history, fbStatus] = await Promise.all([
        fetchEventMedia(),
        fetchServiceRequests(),
        fetchFacebookPublishHistory(30).catch(() => [] as FacebookHistoryEntry[]),
        fetchFacebookConfigStatus().catch(() => null),
      ])
      const syncedItems = parseEventMediaRows(eventRows).map(refreshAssetFlags)
      const albumList = buildAlbums(syncedItems)
      const approved = reqs.filter((r) => String(r.status ?? '').toLowerCase() === 'approved')
      setAll(syncedItems)
      setAlbums(albumList)
      setRequests(approved.length > 0 ? approved : reqs)
      setFbHistory(history)
      setFbConfig(fbStatus)
      setPreviewItem((prev) => {
        if (!prev) return null
        const found = syncedItems.find((m) => m.id === prev.id)
        return found ? refreshAssetFlags(found) : null
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load media gallery')
      setAll([])
      setAlbums([])
      setFbHistory([])
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
    setPreviewItem(refreshAssetFlags(item))
    const next = new URLSearchParams(searchParams)
    next.delete('media')
    setSearchParams(next, { replace: true })
  }, [all, searchParams, setSearchParams])

  const publishedItems = useMemo(
    () =>
      filterMedia(all, '', null, {
        mediaCategory: 'event_documentation',
        facebookPublishStatus: 'published',
      }).sort((a, b) => {
        const ta = a.uploadedAt?.getTime() ?? 0
        const tb = b.uploadedAt?.getTime() ?? 0
        return tb - ta
      }),
    [all],
  )
  const stats = useMemo(() => computeMediaStats(all, albums), [all, albums])
  const bestPickItems = useMemo(() => pendingBestShots(all), [all])
  const bestPickPublishReady = useMemo(
    () => bestPickItems.filter(canPublishToFacebook).length,
    [bestPickItems],
  )

  const searchActive = search.trim().length > 0

  const filtered = useMemo(() => {
    const items = filterMedia(all, search, selectedAlbumId, {
      mediaCategory: 'event_documentation',
      facebookPublishStatus: fbFilter === 'all' ? 'all' : fbFilter,
    })
    // Default gallery hides published items; keep them visible when searching or filtering by status.
    if (fbFilter === 'all' && !searchActive) {
      return items.filter((a) => a.facebookPublishStatus !== 'published')
    }
    return items
  }, [all, search, selectedAlbumId, fbFilter, searchActive])

  const galleryPool = useMemo(() => {
    return [...filtered].sort((a, b) => {
      const ta = a.uploadedAt?.getTime() ?? 0
      const tb = b.uploadedAt?.getTime() ?? 0
      return tb - ta
    })
  }, [filtered])

  const galleryCounts = useMemo(
    () => ({
      photos: galleryPool.filter((a) => a.isPhoto).length,
      videos: galleryPool.filter((a) => a.isVideo).length,
    }),
    [galleryPool],
  )

  const galleryItems = useMemo(() => {
    if (searchActive) return galleryPool
    return galleryPool.filter((a) => (galleryKind === 'photos' ? a.isPhoto : a.isVideo))
  }, [galleryPool, galleryKind, searchActive])

  const visibleAlbums = useMemo(
    () => (searchActive ? filterAlbumsBySearch(albums, search) : albums),
    [albums, search, searchActive],
  )

  const selectedItems = useMemo(() => all.filter((a) => selectedIds.has(a.id)), [all, selectedIds])
  const publishableSelected = useMemo(() => selectedItems.filter(canPublishToFacebook), [selectedItems])
  const fbGraphReady = fbConfig?.configured ?? false
  const fbCanPublish =
    isAdmin && (fbConfig?.browser_share_available ?? fbConfig?.publishing_enabled ?? true)

  const showAlbumStrip =
    !selectedAlbumId && fbFilter === 'all' && (!searchActive || visibleAlbums.length > 0)
  const showBestPicks = !selectedAlbumId && fbFilter === 'all' && !searchActive

  const galleryTitle = search.trim() ? 'Search results' : 'Event media'

  function showMsg(msg: string, tone: 'success' | 'error' | 'info' = 'success') {
    showToast(msg, tone)
  }

  function clearOperationBanner() {
    setOperationBanner(null)
  }

  function openPublishModal(items?: MediaAsset[]) {
    if (!isAdmin) {
      showMsg('Only administrators can publish to Facebook.')
      return
    }
    if (!fbCanPublish) {
      showMsg('Facebook publishing is disabled in System Configuration.')
      return
    }
    const targets = items ?? selectedItems
    const publishable = targets.filter(canPublishToFacebook)
    if (publishable.length === 0) {
      showMsg('Mark items as best picks first, then select them to publish.')
      return
    }
    setPublishTargets(publishable)
    setPublishModalOpen(true)
  }

  async function confirmBulkPublish(message: string) {
    const targets = publishTargets.filter(canPublishToFacebook)
    if (targets.length === 0) return

    setPublishing(true)
    setOperationBanner({
      status: 'loading',
      message: `Publishing ${targets.length} item(s) to Facebook…`,
    })
    try {
      if (fbGraphReady) {
        const result = await bulkPublishEventMediaToFacebook({
          media_ids: targets.map((a) => a.id),
          ...(message ? { message } : {}),
        })
        await load()
        setPublishModalOpen(false)
        setPublishTargets([])
        clearSelection()
        const parts = [`${result.succeeded} published`]
        if (result.failed > 0) parts.push(`${result.failed} failed`)
        if (result.skipped > 0) parts.push(`${result.skipped} skipped`)
        const firstError = result.results?.find((r) => r.status === 'failed' && r.error)?.error
        const groupedNote =
          result.feed_grid && result.group_size
            ? result.feed_post_count && result.feed_post_count > 1
              ? ` as ${result.feed_post_count} Facebook grid posts (${result.group_size} photos, max 10 per post)`
              : ` as one Facebook grid post (${result.group_size} photos)`
            : result.grouped && result.group_size
              ? ` in your Page album (${result.group_size} photos, may show separately on feed)`
              : result.fallback_sequential
                ? ' (grouped publish unavailable; published as separate posts)'
                : ''
        const summary = firstError
          ? `Facebook publish: ${parts.join(', ')}. ${firstError}`
          : `Facebook publish complete: ${parts.join(', ')}${groupedNote}.`
        const hadFailure = result.failed > 0 || Boolean(firstError)
        setOperationBanner({
          status: hadFailure ? 'error' : 'success',
          message: summary,
        })
        showMsg(summary, hadFailure ? 'error' : 'success')
        return
      }

      if (targets.length > 1) {
        const msg =
          'Bulk auto-post needs FACEBOOK_PAGE_ACCESS_TOKEN in access_backend/.env. Publish one best pick at a time with browser share, or add the token and restart the backend.'
        setOperationBanner({ status: 'error', message: msg })
        showMsg(msg, 'error')
        return
      }

      const item = targets[0]!
      const result = await publishOneToFacebookBrowser({
        id: item.id,
        fileName: item.fileName,
        thumbnailUrl: item.thumbnailUrl,
        captionPrefix: message,
      })
      await load()
      setPublishModalOpen(false)
      setPublishTargets([])
      clearSelection()
      setOperationBanner({
        status: result.opened ? 'success' : 'error',
        message: result.message,
      })
      showMsg(result.message, result.opened ? 'success' : 'error')
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Facebook publish failed'
      setOperationBanner({ status: 'error', message: msg })
      showMsg(msg, 'error')
    } finally {
      setPublishing(false)
    }
  }

  function toggleSelect(item: MediaAsset) {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (next.has(item.id)) next.delete(item.id)
      else next.add(item.id)
      return next
    })
  }

  function clearSelection() {
    setSelectedIds(new Set())
  }

  function downloadItem(item: MediaAsset) {
    if (!item.thumbnailUrl) {
      showMsg('No download URL available')
      return
    }
    window.open(item.thumbnailUrl, '_blank', 'noopener,noreferrer')
  }

  async function handleUpload(files: FileList | null) {
    if (!files?.length) return
    if (!isAdmin) {
      showMsg('Only administrators can upload media.')
      return
    }
    if (requests.length === 0) {
      showMsg('Approve a documentation request before uploading event media.')
      return
    }
    const requestId = Number(requests[0].request_id ?? requests[0].id ?? 0)
    if (!requestId) return

    const fileList = Array.from(files)
    setUploading(true)
    setOperationBanner({
      status: 'loading',
      message: `Uploading ${fileList.length} file(s)…`,
    })
    try {
      let count = 0
      for (const file of fileList) {
        count++
        setOperationBanner({
          status: 'loading',
          message: `Uploading file ${count} of ${fileList.length}…`,
        })
        await uploadMediaFile(file, requestId, file.name)
      }
      await load()
      const msg = `Uploaded ${count} file(s) to the gallery`
      setOperationBanner({ status: 'success', message: msg })
      showMsg(msg, 'success')
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Upload failed'
      setOperationBanner({ status: 'error', message: msg })
      showMsg(msg, 'error')
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  function requestDeleteItem(item: MediaAsset) {
    if (!isAdmin) {
      showMsg('Only administrators can delete media.', 'error')
      return
    }
    setConfirmDialog({ kind: 'delete-one', item })
  }

  async function deleteItem(item: MediaAsset) {
    setDialogBusy(true)
    setOperationBanner({ status: 'loading', message: `Deleting "${item.fileName}"…` })
    try {
      await deleteMedia(item.id)
      setSelectedIds((prev) => {
        const next = new Set(prev)
        next.delete(item.id)
        return next
      })
      if (previewItem?.id === item.id) setPreviewItem(null)
      await load()
      const msg = `"${item.fileName}" deleted permanently`
      setOperationBanner({ status: 'success', message: msg })
      showMsg(msg, 'success')
      setConfirmDialog(null)
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Delete failed'
      setOperationBanner({ status: 'error', message: msg })
      showMsg(msg, 'error')
    } finally {
      setDialogBusy(false)
    }
  }

  function requestArchiveItem(item: MediaAsset) {
    if (!isAdmin) return
    setConfirmDialog({ kind: 'archive-one', item })
  }

  async function archiveItem(item: MediaAsset) {
    setDialogBusy(true)
    try {
      await archiveMediaFile(item.id)
      setSelectedIds((prev) => {
        const next = new Set(prev)
        next.delete(item.id)
        return next
      })
      if (previewItem?.id === item.id) setPreviewItem(null)
      await load()
      showMsg('Media archived')
      setConfirmDialog(null)
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Archive failed', 'error')
    } finally {
      setDialogBusy(false)
    }
  }

  async function handleToggleBestShot(item: MediaAsset) {
    if (!isAdmin) return
    if (item.facebookPublishStatus === 'published') {
      showMsg('Published items are no longer best picks')
      return
    }
    const nextBest = !item.isBestShot
    try {
      await updateEventMediaCuration(item.id, { is_best_shot: nextBest })
      await load()
      showMsg(nextBest ? 'Marked as best pick' : 'Removed from best picks')
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Could not update best pick', 'error')
    }
  }

  async function bulkMarkBestPick() {
    if (!isAdmin || selectedIds.size === 0) return
    const eventIds = [...selectedIds].filter((id) => {
      const item = all.find((a) => a.id === id)
      return item?.mediaCategory === 'event_documentation' && item.facebookPublishStatus !== 'published'
    })
    if (eventIds.length === 0) {
      showMsg('Only unpublished event media can be marked as best picks')
      return
    }
    try {
      for (const id of eventIds) {
        await updateEventMediaCuration(id, { is_best_shot: true })
      }
      await load()
      showMsg(`Marked ${eventIds.length} item(s) as best picks`)
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Could not mark best picks', 'error')
    }
  }

  function showMoveAlbumDialog(items: MediaAsset[]) {
    if (albums.length === 0) {
      showMsg('No albums available yet')
      return
    }
    setMoveAlbumItems(items)
  }

  async function confirmMoveAlbum(targetName: string) {
    const items = moveAlbumItems
    if (!items?.length) return
    setDialogBusy(true)
    try {
      for (const item of items) {
        await updateEventMediaCuration(item.id, { album_name_override: targetName })
      }
      await load()
      showMsg(`${items.length} item(s) moved to "${targetName}"`)
      setMoveAlbumItems(null)
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Could not move to album', 'error')
    } finally {
      setDialogBusy(false)
    }
  }

  function requestBulkDelete() {
    if (!isAdmin || selectedIds.size === 0) return
    setConfirmDialog({ kind: 'delete-bulk', count: selectedIds.size })
  }

  async function bulkDelete() {
    const ids = [...selectedIds]
    setDialogBusy(true)
    setOperationBanner({ status: 'loading', message: `Deleting ${ids.length} item(s)…` })
    let deleted = 0
    let lastError: string | null = null
    try {
      for (const id of ids) {
        try {
          await deleteMedia(id)
          deleted++
        } catch (e) {
          lastError = e instanceof Error ? e.message : 'Delete failed'
        }
      }
      clearSelection()
      if (previewItem && ids.includes(previewItem.id)) setPreviewItem(null)
      await load()
      if (deleted === ids.length) {
        const msg = `Deleted ${deleted} item(s) permanently`
        setOperationBanner({ status: 'success', message: msg })
        showMsg(msg, 'success')
        setConfirmDialog(null)
      } else if (deleted > 0) {
        const msg = `Deleted ${deleted} of ${ids.length}. ${lastError ?? 'Some items could not be deleted.'}`
        setOperationBanner({ status: 'error', message: msg })
        showMsg(msg, 'error')
      } else {
        const msg = lastError ?? 'Delete failed'
        setOperationBanner({ status: 'error', message: msg })
        showMsg(msg, 'error')
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Bulk delete failed'
      setOperationBanner({ status: 'error', message: msg })
      showMsg(msg, 'error')
    } finally {
      setDialogBusy(false)
    }
  }

  function albumMediaIds(album: MediaAlbum) {
    return all.filter((item) => albumKey(item.albumName, item.requestId) === album.id).map((item) => item.id)
  }

  function requestDeleteAlbum(album: MediaAlbum) {
    if (!isAdmin) return
    const ids = albumMediaIds(album)
    if (ids.length === 0) {
      showMsg('This album has no files to delete.', 'info')
      return
    }
    setConfirmDialog({ kind: 'delete-album', albumId: album.id, name: album.name, ids })
  }

  function requestArchiveAlbum(album: MediaAlbum) {
    if (!isAdmin) return
    const ids = albumMediaIds(album)
    if (ids.length === 0) {
      showMsg('This album has no files to archive.', 'info')
      return
    }
    setConfirmDialog({ kind: 'archive-album', albumId: album.id, name: album.name, ids })
  }

  function clearAlbumIfDeleted(albumId: string) {
    if (selectedAlbumId === albumId) {
      setSelectedAlbumId(null)
      setSelectedAlbumName(null)
    }
  }

  async function deleteAlbum(albumId: string, name: string, ids: number[]) {
    setDialogBusy(true)
    setOperationBanner({ status: 'loading', message: `Deleting album "${name}"…` })
    let deleted = 0
    let lastError: string | null = null
    try {
      for (const id of ids) {
        try {
          await deleteMedia(id)
          deleted++
        } catch (e) {
          lastError = e instanceof Error ? e.message : 'Delete failed'
        }
      }
      setSelectedIds((prev) => {
        const next = new Set(prev)
        for (const id of ids) next.delete(id)
        return next
      })
      if (previewItem && ids.includes(previewItem.id)) setPreviewItem(null)
      clearAlbumIfDeleted(albumId)
      await load()
      if (deleted === ids.length) {
        const msg = `Deleted album "${name}" (${deleted} file${deleted === 1 ? '' : 's'})`
        setOperationBanner({ status: 'success', message: msg })
        showMsg(msg, 'success')
        setConfirmDialog(null)
      } else if (deleted > 0) {
        const msg = `Deleted ${deleted} of ${ids.length} files in "${name}". ${lastError ?? 'Some files could not be deleted.'}`
        setOperationBanner({ status: 'error', message: msg })
        showMsg(msg, 'error')
      } else {
        const msg = lastError ?? 'Delete failed'
        setOperationBanner({ status: 'error', message: msg })
        showMsg(msg, 'error')
      }
    } finally {
      setDialogBusy(false)
    }
  }

  async function archiveAlbum(albumId: string, name: string, ids: number[]) {
    setDialogBusy(true)
    setOperationBanner({ status: 'loading', message: `Archiving album "${name}"…` })
    try {
      for (const id of ids) {
        await archiveMediaFile(id)
      }
      setSelectedIds((prev) => {
        const next = new Set(prev)
        for (const id of ids) next.delete(id)
        return next
      })
      if (previewItem && ids.includes(previewItem.id)) setPreviewItem(null)
      clearAlbumIfDeleted(albumId)
      await load()
      const msg = `Archived album "${name}"`
      setOperationBanner({ status: 'success', message: msg })
      showMsg(msg, 'success')
      setConfirmDialog(null)
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Archive failed'
      setOperationBanner({ status: 'error', message: msg })
      showMsg(msg, 'error')
    } finally {
      setDialogBusy(false)
    }
  }

  async function bulkArchive() {
    if (!isAdmin || selectedIds.size === 0) return
    setDialogBusy(true)
    const ids = [...selectedIds]
    try {
      for (const id of ids) {
        await archiveMediaFile(id)
      }
      clearSelection()
      await load()
      showMsg(`Archived ${ids.length} item(s)`)
    } catch (e) {
      showMsg(e instanceof Error ? e.message : 'Bulk archive failed', 'error')
    } finally {
      setDialogBusy(false)
    }
  }

  return (
    <div className="space-y-4 pb-24">
      <AdminPageHeader
        title="Media Gallery"
        subtitle="Event documentation photos and videos. Star best picks, then publish to your org page."
        backTo="/"
        actions={
          <>
            <button type="button" onClick={load} disabled={loading} className={pageToolbarBtnClass}>
              <RefreshCw size={16} className={loading ? 'animate-spin' : 'shrink-0 text-[var(--color-text-secondary)]'} />
              Refresh
            </button>
            {isAdmin && (
              <>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*,video/*"
                  multiple
                  className="hidden"
                  onChange={(e) => handleUpload(e.target.files)}
                />
                <button
                  type="button"
                  disabled={uploading || publishing}
                  onClick={() => fileInputRef.current?.click()}
                  className="inline-flex h-10 shrink-0 items-center gap-2 whitespace-nowrap rounded-xl bg-[var(--color-accent-blue)] px-4 text-sm font-bold text-white hover:opacity-95 disabled:opacity-50"
                >
                  {uploading ? <Loader2 size={16} className="animate-spin" /> : <Upload size={16} />}
                  {uploading ? 'Uploading…' : 'Upload'}
                </button>
                <button
                  type="button"
                  disabled={publishing || uploading || !fbCanPublish || publishableSelected.length === 0}
                  title={
                    !fbCanPublish
                      ? 'Facebook publishing is disabled in System Configuration.'
                      : !fbGraphReady
                        ? 'Browser share (one item). Add Page token for bulk auto-post.'
                        : undefined
                  }
                  onClick={() => openPublishModal()}
                  className="inline-flex h-10 shrink-0 items-center gap-2 whitespace-nowrap rounded-xl bg-[#1877F2] px-4 text-sm font-bold text-white hover:opacity-95 disabled:opacity-50"
                >
                  {publishing ? <Loader2 size={16} className="animate-spin" /> : <FacebookIcon size={16} />}
                  {publishing ? 'Publishing…' : 'Publish'}
                </button>
              </>
            )}
          </>
        }
      />

      <AdminOperationBanner banner={operationBanner} onDismiss={clearOperationBanner} />

      {fbConfig && fbCanPublish && !fbConfig.configured && (
        <FacebookCredentialsReminder config={fbConfig} />
      )}

      {error ? <AdminErrorBanner>{error}</AdminErrorBanner> : null}

      <div className="flex flex-col gap-2 rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
          <div className="relative min-w-0 flex-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search event, album, member, file name, date…"
              className="admin-input w-full rounded-xl py-2 pl-9 pr-3 text-sm"
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <AdminSelect
              value={fbFilter}
              onChange={(v) => setFbFilter(v as FbChip)}
              aria-label="Filter by publish status"
              className="min-w-[11rem]"
              options={PUBLISH_STATUS_OPTIONS.map((o) => ({ value: o.id, label: o.label }))}
            />
          </div>
        </div>
        <p className="text-xs text-[var(--color-text-muted)]">
          {stats.totalAlbums} albums · {bestPickItems.length} best picks · {stats.storageUsedLabel} est. storage
        </p>
      </div>

      {loading && all.length === 0 ? (
        <div className="flex justify-center py-16">
          <Loader2 className="animate-spin text-[var(--color-text-muted)]" size={28} />
        </div>
      ) : (
        <>
          {showAlbumStrip ? (
            <EventAlbumsSection
              albums={visibleAlbums}
              selectedAlbumId={selectedAlbumId}
              isAdmin={isAdmin}
              onAlbumTap={(a) => {
                setSelectedAlbumId(a.id)
                setSelectedAlbumName(a.name)
              }}
              onClearAlbum={() => {
                setSelectedAlbumId(null)
                setSelectedAlbumName(null)
              }}
              onDeleteAlbum={requestDeleteAlbum}
              onArchiveAlbum={requestArchiveAlbum}
            />
          ) : null}

          {showBestPicks ? (
            <BestPicksSection
              items={bestPickItems}
              isAdmin={isAdmin}
              onPreview={setPreviewItem}
              onToggleBestShot={handleToggleBestShot}
              onPublishAll={() => openPublishModal(bestPickItems.filter(canPublishToFacebook))}
              publishReadyCount={bestPickPublishReady}
              facebookReady={fbCanPublish}
              facebookGraphReady={fbGraphReady}
            />
          ) : null}

          <div>
            {selectedAlbumId ? (
              <button
                type="button"
                onClick={() => {
                  setSelectedAlbumId(null)
                  setSelectedAlbumName(null)
                }}
                className="mb-2 inline-flex items-center gap-1.5 rounded-lg px-1 py-1 text-sm font-semibold text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)]"
              >
                <ArrowLeft size={16} strokeWidth={2.25} />
                Back
              </button>
            ) : null}
            <div className="mb-2 flex flex-wrap items-end justify-between gap-2">
              <div className="min-w-0">
                {selectedAlbumName ? (
                  <p className="truncate text-base font-bold text-[var(--color-text-primary)]" title={selectedAlbumName}>
                    {selectedAlbumName}
                  </p>
                ) : null}
                <h2 className="text-sm font-bold text-[var(--color-text-primary)]">{galleryTitle}</h2>
              </div>
              {(selectedAlbumId || search.trim() || fbFilter !== 'all') && (
                <button
                  type="button"
                  onClick={() => {
                    setSelectedAlbumId(null)
                    setSelectedAlbumName(null)
                    setSearch('')
                    setGalleryKind('photos')
                    setFbFilter('all')
                  }}
                  className="text-xs font-semibold text-[var(--color-accent-blue)] hover:underline"
                >
                  Clear filters
                </button>
              )}
            </div>

            {!searchActive ? (
            <div
              className="mb-2 inline-flex rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-0.5"
              role="tablist"
              aria-label="Event media type"
            >
              {([
                ['photos', 'Photos', galleryCounts.photos],
                ['videos', 'Videos', galleryCounts.videos],
              ] as const).map(([id, label, count]) => {
                const active = galleryKind === id
                return (
                  <button
                    key={id}
                    type="button"
                    role="tab"
                    aria-selected={active}
                    onClick={() => setGalleryKind(id)}
                    className={[
                      'rounded-md px-3 py-1 text-xs font-bold transition',
                      active
                        ? 'bg-[var(--color-accent-blue)] text-white'
                        : 'text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)]',
                    ].join(' ')}
                  >
                    {label} ({count})
                  </button>
                )
              })}
            </div>
            ) : (
              <p className="mb-2 text-xs text-[var(--color-text-secondary)]">
                Showing photos and videos matching your search.
              </p>
            )}

            {galleryItems.length === 0 ? (
              <AdminCard dashed padding="lg" className="text-center">
                <FolderOpen size={32} className="mx-auto text-[var(--color-text-muted)]" />
                <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">No media found</p>
                <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
                  Upload event photos and videos or adjust your filters.
                </p>
                {isAdmin && (
                  <button
                    type="button"
                    disabled={uploading}
                    onClick={() => fileInputRef.current?.click()}
                    className="mt-4 rounded-xl bg-[var(--color-accent-blue)] px-4 py-2 text-sm font-bold text-white"
                  >
                    Upload event media
                  </button>
                )}
              </AdminCard>
            ) : (
              <MediaTileGrid
                items={galleryItems}
                selectedIds={selectedIds}
                isAdmin={isAdmin}
                onPreview={setPreviewItem}
                onToggleSelect={toggleSelect}
                onToggleBestShot={handleToggleBestShot}
                onDelete={isAdmin ? requestDeleteItem : undefined}
              />
            )}
          </div>

          {showBestPicks && (
            <FacebookHistoryCollapsible
              items={publishedItems}
              failedHistory={fbHistory.filter((row) => row.status === 'failed')}
              onPreview={setPreviewItem}
            />
          )}
        </>
      )}

      {previewItem && (
        <MediaPreviewDrawer
          item={previewItem}
          isAdmin={isAdmin}
          publishing={publishing}
          onClose={() => setPreviewItem(null)}
          onDownload={() => downloadItem(previewItem)}
          onMoveToAlbum={() => showMoveAlbumDialog([previewItem])}
          onArchive={() => requestArchiveItem(previewItem)}
          onDelete={() => requestDeleteItem(previewItem)}
          onToggleBestShot={() => handleToggleBestShot(previewItem)}
          onPublishFacebook={() => openPublishModal([previewItem])}
        />
      )}

      <FacebookPublishModal
        items={publishModalOpen ? publishTargets : []}
        open={publishModalOpen}
        publishing={publishing}
        useGraphApi={fbGraphReady}
        onClose={() => !publishing && setPublishModalOpen(false)}
        onConfirm={confirmBulkPublish}
      />

      <MediaBulkToolbar
        count={selectedIds.size}
        publishableCount={publishableSelected.length}
        isAdmin={isAdmin}
        publishing={publishing}
        uploading={uploading}
        facebookReady={fbCanPublish}
        facebookGraphReady={fbGraphReady}
        facebookReminder={fbConfig?.reminder}
        showFacebook
        onClear={clearSelection}
        onMarkBestPick={bulkMarkBestPick}
        onDownload={() => {
          for (const id of selectedIds) {
            const item = all.find((a) => a.id === id)
            if (item) downloadItem(item)
          }
        }}
        onMove={() => showMoveAlbumDialog(all.filter((a) => selectedIds.has(a.id)))}
        onArchive={bulkArchive}
        onDelete={requestBulkDelete}
        onPublish={() => openPublishModal()}
      />

      <MoveAlbumModal
        open={moveAlbumItems != null}
        albums={albums}
        itemCount={moveAlbumItems?.length ?? 0}
        loading={dialogBusy}
        onClose={() => !dialogBusy && setMoveAlbumItems(null)}
        onConfirm={confirmMoveAlbum}
      />

      <AdminConfirmDialog
        open={confirmDialog?.kind === 'delete-one'}
        title="Delete permanently?"
        message={
          confirmDialog?.kind === 'delete-one'
            ? `"${confirmDialog.item.fileName}" will be removed from the server. This cannot be undone.`
            : ''
        }
        confirmLabel="Delete"
        tone="danger"
        loading={dialogBusy}
        onCancel={() => !dialogBusy && setConfirmDialog(null)}
        onConfirm={() => confirmDialog?.kind === 'delete-one' && deleteItem(confirmDialog.item)}
      />

      <AdminConfirmDialog
        open={confirmDialog?.kind === 'archive-one'}
        title="Archive media?"
        message={
          confirmDialog?.kind === 'archive-one'
            ? `"${confirmDialog.item.fileName}" will be hidden from the gallery for all admins. The file stays on the server. Use Delete permanently to remove it for everyone.`
            : ''
        }
        confirmLabel="Archive"
        loading={dialogBusy}
        onCancel={() => !dialogBusy && setConfirmDialog(null)}
        onConfirm={() => confirmDialog?.kind === 'archive-one' && archiveItem(confirmDialog.item)}
      />

      <AdminConfirmDialog
        open={confirmDialog?.kind === 'delete-bulk'}
        title="Delete selected items?"
        message={
          confirmDialog?.kind === 'delete-bulk'
            ? `${confirmDialog.count} item(s) will be removed from the server permanently. This cannot be undone.`
            : ''
        }
        confirmLabel="Delete all"
        tone="danger"
        loading={dialogBusy}
        onCancel={() => !dialogBusy && setConfirmDialog(null)}
        onConfirm={() => confirmDialog?.kind === 'delete-bulk' && bulkDelete()}
      />

      <AdminConfirmDialog
        open={confirmDialog?.kind === 'delete-album'}
        title="Delete album?"
        message={
          confirmDialog?.kind === 'delete-album'
            ? `"${confirmDialog.name}" and its ${confirmDialog.ids.length} file${confirmDialog.ids.length === 1 ? '' : 's'} will be removed from the server. This cannot be undone.`
            : ''
        }
        confirmLabel="Delete album"
        tone="danger"
        loading={dialogBusy}
        onCancel={() => !dialogBusy && setConfirmDialog(null)}
        onConfirm={() =>
          confirmDialog?.kind === 'delete-album' &&
          deleteAlbum(confirmDialog.albumId, confirmDialog.name, confirmDialog.ids)
        }
      />

      <AdminConfirmDialog
        open={confirmDialog?.kind === 'archive-album'}
        title="Archive album?"
        message={
          confirmDialog?.kind === 'archive-album'
            ? `"${confirmDialog.name}" will be hidden from the gallery. The ${confirmDialog.ids.length} file${confirmDialog.ids.length === 1 ? '' : 's'} stay on the server.`
            : ''
        }
        confirmLabel="Archive album"
        loading={dialogBusy}
        onCancel={() => !dialogBusy && setConfirmDialog(null)}
        onConfirm={() =>
          confirmDialog?.kind === 'archive-album' &&
          archiveAlbum(confirmDialog.albumId, confirmDialog.name, confirmDialog.ids)
        }
      />
    </div>
  )
}

function FacebookCredentialsReminder({ config }: { config: FacebookConfigStatus }) {
  const wrongToken = config.access_token_set && config.page_token_valid === false
  const title = wrongToken ? 'Facebook token needs to be a Page token' : 'Facebook auto-post not configured'

  return (
    <div className="flex gap-3 rounded-xl border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm text-amber-100">
      <AlertCircle size={20} className="mt-0.5 shrink-0 text-amber-400" />
      <div>
        <p className="font-bold">{title}</p>
        <p className="mt-1 text-xs leading-relaxed">{config.reminder}</p>
        {wrongToken && (
          <ol className="mt-2 list-decimal space-y-1 pl-4 text-xs leading-relaxed">
            <li>Open Meta Graph API Explorer for your app.</li>
            <li>Add permissions: pages_manage_posts, pages_show_list.</li>
            <li>Generate token, then run query: me/accounts</li>
            <li>
              Copy the <strong>access_token</strong> inside your ACCESS Page row (not the top-level user token).
            </li>
            <li>
              Paste into <code className="rounded bg-amber-500/20 px-1 text-amber-50">FACEBOOK_PAGE_ACCESS_TOKEN</code> in{' '}
              <code className="rounded bg-amber-500/20 px-1 text-amber-50">access_backend/.env</code>, then restart the backend.
            </li>
          </ol>
        )}
        <p className="mt-1.5 text-xs leading-relaxed">
          You can still publish <strong>one best pick at a time</strong> using browser share (opens Facebook in a new
          tab). Allow pop-ups for this site.
        </p>
        {config.missing.length > 0 && (
          <p className="mt-1.5 text-xs font-semibold">
            Add to <code className="rounded bg-amber-500/20 px-1 text-amber-50">access_backend/.env</code>: {config.missing.join(', ')}
          </p>
        )}
        <button
          type="button"
          onClick={() => openFacebookPage()}
          className="mt-2 text-xs font-bold text-[#1877F2] hover:underline"
        >
          Open Facebook Page (ACCESS)
        </button>
      </div>
    </div>
  )
}

function FacebookIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
    </svg>
  )
}
