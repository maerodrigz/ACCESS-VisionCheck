import { useCallback, useEffect, useRef, useState, type MouseEvent as ReactMouseEvent, type PointerEvent as ReactPointerEvent, type WheelEvent as ReactWheelEvent } from 'react'
import { ExternalLink, RotateCcw, X, ZoomIn, ZoomOut } from 'lucide-react'
import { isVideoMediaPath, mediaUrl } from '../api/media'

interface Props {
  url: string
  title?: string
  isVideo?: boolean
  onClose: () => void
}

const MIN_SCALE = 1
const MAX_SCALE = 6
const ZOOM_STEP = 0.35

function clampScale(value: number) {
  return Math.min(MAX_SCALE, Math.max(MIN_SCALE, value))
}

function ZoomableImage({ url, title }: { url: string; title?: string }) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [scale, setScale] = useState(1)
  const [position, setPosition] = useState({ x: 0, y: 0 })
  const dragging = useRef(false)
  const dragStart = useRef({ x: 0, y: 0, originX: 0, originY: 0 })

  const resetView = useCallback(() => {
    setScale(1)
    setPosition({ x: 0, y: 0 })
  }, [])

  const zoomBy = useCallback((delta: number, focal?: { x: number; y: number }) => {
    setScale((prev) => {
      const next = clampScale(Number((prev + delta).toFixed(2)))
      if (next === 1) {
        setPosition({ x: 0, y: 0 })
        return next
      }
      if (focal && containerRef.current) {
        const rect = containerRef.current.getBoundingClientRect()
        const offsetX = focal.x - rect.left - rect.width / 2
        const offsetY = focal.y - rect.top - rect.height / 2
        const ratio = next / prev
        setPosition((pos) => ({
          x: pos.x - offsetX * (ratio - 1),
          y: pos.y - offsetY * (ratio - 1),
        }))
      }
      return next
    })
  }, [])

  function onWheel(e: ReactWheelEvent<HTMLDivElement>) {
    e.preventDefault()
    const delta = e.deltaY < 0 ? ZOOM_STEP : -ZOOM_STEP
    zoomBy(delta, { x: e.clientX, y: e.clientY })
  }

  function onPointerDown(e: ReactPointerEvent<HTMLDivElement>) {
    if (scale <= 1) return
    dragging.current = true
    dragStart.current = {
      x: e.clientX,
      y: e.clientY,
      originX: position.x,
      originY: position.y,
    }
    e.currentTarget.setPointerCapture(e.pointerId)
  }

  function onPointerMove(e: ReactPointerEvent<HTMLDivElement>) {
    if (!dragging.current) return
    setPosition({
      x: dragStart.current.originX + (e.clientX - dragStart.current.x),
      y: dragStart.current.originY + (e.clientY - dragStart.current.y),
    })
  }

  function onPointerUp(e: ReactPointerEvent<HTMLDivElement>) {
    dragging.current = false
    e.currentTarget.releasePointerCapture(e.pointerId)
  }

  function onDoubleClick(e: ReactMouseEvent<HTMLDivElement>) {
    if (scale > 1) {
      resetView()
      return
    }
    zoomBy(1.5, { x: e.clientX, y: e.clientY })
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex shrink-0 flex-wrap items-center justify-center gap-2 px-4 pb-3">
        <button
          type="button"
          onClick={() => zoomBy(ZOOM_STEP)}
          className="inline-flex items-center gap-1.5 rounded-lg bg-white/10 px-3 py-1.5 text-xs font-semibold text-white hover:bg-white/15"
          aria-label="Zoom in"
        >
          <ZoomIn size={14} />
          Zoom in
        </button>
        <button
          type="button"
          onClick={() => zoomBy(-ZOOM_STEP)}
          disabled={scale <= 1}
          className="inline-flex items-center gap-1.5 rounded-lg bg-white/10 px-3 py-1.5 text-xs font-semibold text-white hover:bg-white/15 disabled:opacity-40"
          aria-label="Zoom out"
        >
          <ZoomOut size={14} />
          Zoom out
        </button>
        <button
          type="button"
          onClick={resetView}
          disabled={scale <= 1 && position.x === 0 && position.y === 0}
          className="inline-flex items-center gap-1.5 rounded-lg bg-white/10 px-3 py-1.5 text-xs font-semibold text-white hover:bg-white/15 disabled:opacity-40"
          aria-label="Reset zoom"
        >
          <RotateCcw size={14} />
          Reset
        </button>
        <span className="text-[11px] font-medium text-white/70">{Math.round(scale * 100)}%</span>
      </div>

      <p className="shrink-0 px-4 pb-2 text-center text-[11px] text-white/60">
        Scroll or pinch to zoom · Drag to pan · Double-click to toggle zoom
      </p>

      <div
        ref={containerRef}
        className={`relative min-h-0 flex-1 overflow-hidden px-4 pb-6 ${scale > 1 ? 'cursor-grab active:cursor-grabbing' : 'cursor-zoom-in'}`}
        onWheel={onWheel}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onDoubleClick={onDoubleClick}
      >
        <div className="flex h-full w-full items-center justify-center">
          <img
            src={url}
            alt={title ?? ''}
            draggable={false}
            className="max-h-[calc(100vh-11rem)] max-w-[min(96vw,1200px)] select-none rounded-lg object-contain shadow-2xl"
            style={{
              transform: `translate(${position.x}px, ${position.y}px) scale(${scale})`,
              transformOrigin: 'center center',
              transition: dragging.current ? 'none' : 'transform 120ms ease-out',
            }}
          />
        </div>
      </div>
    </div>
  )
}

export function MediaLightbox({ url, title, isVideo, onClose }: Props) {
  const resolvedUrl = mediaUrl(url)
  const video =
    isVideo !== undefined ? isVideo : isVideoMediaPath(title) || isVideoMediaPath(resolvedUrl)

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', onKey)
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = prev
    }
  }, [onClose])

  return (
    <div
      className="fixed inset-0 z-[80] flex flex-col bg-black/92"
      role="dialog"
      aria-modal="true"
      aria-label={title ? `Inspect media: ${title}` : 'Inspect media'}
    >
      <div className="flex shrink-0 items-center justify-between gap-3 px-4 py-3 text-white">
        <div className="min-w-0">
          <p className="truncate text-sm font-semibold">{title ?? 'Media preview'}</p>
          <p className="text-[11px] text-white/60">
            {video ? 'Use video controls for playback' : 'Inspect for AI artifacts, filters, and edits'}
          </p>
        </div>
        <div className="flex shrink-0 items-center gap-1">
          <a
            href={resolvedUrl}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-semibold text-white/90 hover:bg-white/10"
          >
            <ExternalLink size={14} />
            Open in tab
          </a>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-2 text-white/90 hover:bg-white/10"
            aria-label="Close preview"
          >
            <X size={22} />
          </button>
        </div>
      </div>

      {video ? (
        <div className="flex min-h-0 flex-1 items-center justify-center px-4 pb-6">
          <video
            src={resolvedUrl}
            controls
            autoPlay
            className="max-h-[calc(100vh-5rem)] max-w-full rounded-lg shadow-2xl"
          />
        </div>
      ) : (
        <ZoomableImage url={resolvedUrl} title={title} />
      )}
    </div>
  )
}
