import type { ReactNode } from 'react'
import type { AiDetectionRow } from '../../api/media'
import {
  type CameraFileDisplayRow,
  cameraFileDisplayRows,
  detectorAiRiskBand,
  detectorDisplayName,
  probeRawPFakePercent,
  supplementalExifFieldRows,
  visualAiRiskColor,
} from '../../lib/reviewScanPresentation'

function SectionHeading({ children, withTopRule }: { children: ReactNode; withTopRule?: boolean }) {
  return (
    <div
      className={[
        'col-span-2 text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]',
        withTopRule ? 'mt-2 border-t border-[var(--color-border)] pt-2' : '',
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
      <dt
        className={`py-1 pr-2 text-xs leading-snug text-[var(--color-text-secondary)] ${rule}`}
      >
        {label}
      </dt>
      <dd
        className={`m-0 min-w-0 py-1 text-xs font-semibold leading-snug text-[var(--color-text-primary)] ${rule}`}
        title={typeof value === 'string' ? value : undefined}
      >
        <span className="block text-right break-normal">{value}</span>
      </dd>
    </>
  )
}

/** Internal content for Review Scan → Technical Details collapsible only. */
export function ReviewScanTechnicalDetails({ row }: { row: AiDetectionRow }) {
  const meta = row.exif_metadata
  const pFake = probeRawPFakePercent(row)
  const band = detectorAiRiskBand(row)
  const riskLevel = meta?.visual_risk_level
    ? String(meta.visual_risk_level)
    : band.charAt(0) + band.slice(1).toLowerCase()
  const cameraRows = cameraFileDisplayRows(meta)
  const extraExif = supplementalExifFieldRows(meta)
  const policyOutcome = meta?.provenance_policy_outcome
    ? String(meta.provenance_policy_outcome).replace(/_/g, ' ')
    : null

  return (
    <dl className="grid w-full min-w-0 grid-cols-[minmax(7.25rem,38%)_minmax(0,1fr)] items-start gap-x-3">
      <SectionHeading>Automated detector</SectionHeading>
      <DetailCells label="Detector" value={detectorDisplayName(row)} />
      <DetailCells label="P(fake)" value={pFake ?? 'N/A'} divider />
      <DetailCells
        label="Risk level"
        value={
          <span className="inline-flex items-center justify-end gap-1.5">
            <span
              className="h-2 w-2 shrink-0 rounded-full"
              style={{ backgroundColor: visualAiRiskColor(band) }}
              aria-hidden
            />
            {riskLevel}
          </span>
        }
        divider
      />
      {policyOutcome ? (
        <DetailCells label="Policy outcome" value={policyOutcome} divider />
      ) : null}

      <SectionHeading withTopRule>Camera &amp; file metadata</SectionHeading>
      {cameraRows.length > 0 ? (
        cameraRows.map((r: CameraFileDisplayRow, index) => (
          <DetailCells key={r.label} label={r.label} value={r.value} divider={index > 0} />
        ))
      ) : (
        <p className="col-span-2 text-xs text-[var(--color-text-secondary)]">Not available</p>
      )}
      {meta?.is_video &&
      (meta.camera_provenance_strength ?? '').toLowerCase() === 'partial' ? (
        <p className="col-span-2 mt-1 text-[10px] leading-snug text-[var(--color-text-muted)]">
          Recording or container metadata may be present without full device identity. This supports
          provenance review and is separate from automated AI-generation risk.
        </p>
      ) : null}

      {extraExif.length > 0 ? (
        <>
          <SectionHeading withTopRule>Additional EXIF fields</SectionHeading>
          {extraExif.map((r, index) => (
            <DetailCells key={`${r.label}-${index}`} label={r.label} value={r.value} divider={index > 0} />
          ))}
        </>
      ) : null}
    </dl>
  )
}
