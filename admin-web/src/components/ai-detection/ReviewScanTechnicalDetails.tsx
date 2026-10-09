import type { ReactNode } from 'react'
import type { AiDetectionRow } from '../../api/media'
import {
  PROBE_DETECTOR_DISPLAY_NAME,
  type CameraFileDisplayRow,
  cameraFileDisplayRows,
  probeRawPFakePercent,
} from '../../lib/reviewScanPresentation'

function SectionHeading({ children, withTopRule }: { children: ReactNode; withTopRule?: boolean }) {
  return (
    <div
      className={[
        'col-span-2 text-[11px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]',
        withTopRule ? 'mt-3 border-t border-[var(--color-border)] pt-3' : '',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      {children}
    </div>
  )
}

function DetailCells({ label, value, divider }: { label: string; value: ReactNode; divider?: boolean }) {
  const rule = divider ? 'border-t border-[var(--color-border-subtle)]' : ''
  return (
    <>
      <dt className={`py-1 text-xs text-[var(--color-text-secondary)] ${rule}`}>{label}</dt>
      <dd
        className={`m-0 min-w-0 py-1 text-xs font-semibold leading-snug text-[var(--color-text-primary)] break-words [overflow-wrap:anywhere] [text-align:end] ${rule}`}
      >
        {value}
      </dd>
    </>
  )
}

/** Internal content for Review Scan → Technical Details collapsible only. */
export function ReviewScanTechnicalDetails({ row }: { row: AiDetectionRow }) {
  const meta = row.exif_metadata
  const pFake = probeRawPFakePercent(row)
  const cameraRows = cameraFileDisplayRows(meta)

  return (
    <dl className="grid w-full min-w-0 grid-cols-[max-content_minmax(0,1fr)] items-start gap-x-4 [&>dd]:max-w-full [&>dd]:justify-self-stretch">
      <SectionHeading>Detection Information</SectionHeading>
      <DetailCells label="Detector Name" value={PROBE_DETECTOR_DISPLAY_NAME} />
      <DetailCells label="AI Probability" value={pFake ?? 'N/A'} divider />

      <SectionHeading withTopRule>Camera &amp; File Information</SectionHeading>
      {cameraRows.length > 0 ? (
        cameraRows.map((r: CameraFileDisplayRow, index) => (
          <DetailCells key={r.label} label={r.label} value={r.value} divider={index > 0} />
        ))
      ) : (
        <p className="col-span-2 mt-1 text-xs text-[var(--color-text-secondary)]">Not available</p>
      )}
    </dl>
  )
}
