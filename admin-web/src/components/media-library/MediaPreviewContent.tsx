import { Image, Video } from 'lucide-react'
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

  if (!url) {
    return (
      <div
        className={`flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-200 text-[var(--color-text-secondary)] ${className}`}
      >
        {video ? <Video size={36} strokeWidth={1.5} /> : <Image size={36} strokeWidth={1.5} />}
      </div>
    )
  }

  if (video) {
    return (
      <video
        src={url}
        controls={!isThumbnail}
        muted={isThumbnail}
        playsInline
        preload={isThumbnail ? 'metadata' : 'auto'}
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
      className={[
        isThumbnail
          ? 'h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]'
          : 'max-h-72 w-full object-contain',
        className,
      ].join(' ')}
    />
  )
}
