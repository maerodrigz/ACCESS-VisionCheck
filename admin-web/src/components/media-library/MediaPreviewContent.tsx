import { useEffect, useState } from 'react'
import { ImageOff, Video } from 'lucide-react'
import { isVideoMedia, isVideoMediaPath } from '../../api/media'

interface Props {
  url: string
  isVideo: boolean
  fileName?: string
  fileType?: string
  /** Full preview with controls (drawer/lightbox). */
  mode?: 'preview' | 'thumbnail'
  className?: string
}

function inferVideo(isVideo: boolean, url: string, fileName?: string, fileType?: string) {
  return isVideo || isVideoMedia(fileType, fileName, url) || isVideoMediaPath(url) || isVideoMediaPath(fileName)
}

export function MediaThumbnailPlaceholder({
  isVideo,
  className = '',
  compact,
}: {
  isVideo: boolean
  className?: string
  compact?: boolean
}) {
  const Icon = isVideo ? Video : ImageOff
  return (
    <div
      className={[
        'flex flex-col items-center justify-center gap-1.5 bg-[var(--color-surface-muted)] text-[var(--color-text-muted)]',
        className,
      ].join(' ')}
    >
      <Icon size={compact ? 22 : 32} strokeWidth={1.5} />
      <span className={compact ? 'text-[9px] font-medium' : 'text-[10px] font-medium'}>
        {isVideo && !compact ? 'Video unavailable' : 'No preview'}
      </span>
    </div>
  )
}

export function MediaPreviewContent({
  url,
  isVideo,
  fileName,
  fileType,
  mode = 'preview',
  className = '',
}: Props) {
  const video = inferVideo(isVideo, url, fileName, fileType)
  const isThumbnail = mode === 'thumbnail'
  const [mediaFailed, setMediaFailed] = useState(false)
  useEffect(() => setMediaFailed(false), [url])

  if (!url || mediaFailed) {
    return <MediaThumbnailPlaceholder isVideo={video} className={className} compact={isThumbnail} />
  }

  if (video) {
    return (
      <video
        src={url}
        controls={!isThumbnail}
        muted={isThumbnail}
        playsInline
        preload={isThumbnail ? 'metadata' : 'auto'}
        onError={() => setMediaFailed(true)}
        className={[
          isThumbnail
            ? 'pointer-events-none h-full w-full object-cover'
            : 'max-h-96 w-full max-w-full bg-black object-contain',
          className,
        ].join(' ')}
      />
    )
  }

  return (
    <img
      src={url}
      alt=""
      onError={() => setMediaFailed(true)}
      className={[
        isThumbnail
          ? 'h-full w-full object-cover transition duration-300 group-hover:scale-[1.02]'
          : 'max-h-72 w-full object-contain',
        className,
      ].join(' ')}
    />
  )
}
