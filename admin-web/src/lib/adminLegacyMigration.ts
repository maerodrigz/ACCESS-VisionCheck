import {
  fetchEventMedia,
  updateEventMediaCuration,
} from '../api/eventMedia'
import { archiveMediaFile, fetchFeedback, fetchMedia, updateFeedbackAdminReview } from '../api/admin'
import {
  clearLegacyFeedbackLocalStorage,
  migrateLegacyFeedbackLocalStorage,
} from './requesterFeedback'
import {
  clearLegacyArchivedMediaIds,
  clearLegacyMediaCurationLocalStorage,
  loadLegacyAlbumOverrides,
  loadLegacyArchivedMediaIds,
  loadLegacyBestShotIds,
} from './mediaLibrary'

const MIGRATION_FLAG = 'access_admin_legacy_migration_v2'

/** One-time push of browser-only admin data to the server after login. */
export async function runAdminLegacyMigration(): Promise<void> {
  if (localStorage.getItem(MIGRATION_FLAG) === 'done') return

  try {
    await migrateMediaCuration()
    await migrateArchivedMedia()
    const feedbackRows = await fetchFeedback()
    await migrateLegacyFeedbackLocalStorage(feedbackRows, updateFeedbackAdminReview)
    localStorage.setItem(MIGRATION_FLAG, 'done')
  } catch {
    /* Retry on next admin session if backend was offline. */
  }
}

async function migrateMediaCuration(): Promise<void> {
  const localBest = loadLegacyBestShotIds()
  const localAlbums = loadLegacyAlbumOverrides()
  if (localBest.size === 0 && localAlbums.size === 0) return

  const eventRows = await fetchEventMedia()
  const byId = new Map(eventRows.map((row) => [row.id, row]))

  for (const [mediaId, albumName] of localAlbums) {
    const row = byId.get(mediaId)
    if (!row?.album_name_override && albumName.trim()) {
      await updateEventMediaCuration(mediaId, { album_name_override: albumName.trim() })
    }
  }
  for (const mediaId of localBest) {
    const row = byId.get(mediaId)
    if (row && !row.is_best_shot && row.facebook_publish_status !== 'published') {
      await updateEventMediaCuration(mediaId, { is_best_shot: true })
    }
  }
  clearLegacyMediaCurationLocalStorage()
}

async function migrateArchivedMedia(): Promise<void> {
  const ids = loadLegacyArchivedMediaIds()
  if (ids.size === 0) return

  const existing = await fetchMedia()
  const known = new Set(existing.map((row) => Number(row.id ?? row.media_id ?? 0)))

  for (const mediaId of ids) {
    if (!known.has(mediaId)) continue
    try {
      await archiveMediaFile(mediaId)
    } catch {
      /* Skip rows already archived or deleted. */
    }
  }
  clearLegacyArchivedMediaIds()
}

/** Clears feedback legacy keys when migration already ran elsewhere. */
export function clearAllLegacyAdminStorage() {
  clearLegacyMediaCurationLocalStorage()
  clearLegacyFeedbackLocalStorage()
  clearLegacyArchivedMediaIds()
}
