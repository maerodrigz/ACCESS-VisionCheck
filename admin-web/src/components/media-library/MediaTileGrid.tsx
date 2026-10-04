import type { MediaAsset } from '../../lib/mediaLibrary'
import { MediaTile } from './MediaTile'

/** Uniform responsive grid for gallery tiles. */
export const MEDIA_GALLERY_GRID_CLASS =
  'grid grid-cols-[repeat(auto-fill,minmax(148px,1fr))] gap-2'

export function MediaTileGrid({
  items,
  selectedIds,
  isAdmin,
  onPreview,
  onToggleSelect,
  onToggleBestShot,
  onDelete,
}: {
  items: MediaAsset[]
  selectedIds: Set<number>
  isAdmin: boolean
  onPreview: (item: MediaAsset) => void
  onToggleSelect: (item: MediaAsset) => void
  onToggleBestShot: (item: MediaAsset) => void
  onDelete?: (item: MediaAsset) => void
}) {
  return (
    <div className={MEDIA_GALLERY_GRID_CLASS}>
      {items.map((item) => (
        <MediaTile
          key={item.id}
          item={item}
          selected={selectedIds.has(item.id)}
          isAdmin={isAdmin}
          onTap={() => onPreview(item)}
          onSelectToggle={() => onToggleSelect(item)}
          onToggleBestShot={() => onToggleBestShot(item)}
          onDelete={onDelete ? () => onDelete(item) : undefined}
        />
      ))}
    </div>
  )
}
