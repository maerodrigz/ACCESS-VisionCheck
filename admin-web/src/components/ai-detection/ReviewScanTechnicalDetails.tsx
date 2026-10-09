import type { ReactNode } from 'react'
import { ChevronDown } from 'lucide-react'
import type { AiDetectionRow, ExifMetadata } from '../../api/media'
import {
  AI_GENERATION_RISK_HINT,
  PROBE_DETECTOR_DISPLAY_NAME,
  cameraOriginLabel,
  formatProvenancePolicyDisplay,
  probeRawPFakePercent,
  technicalProvenanceExplanation,
  visualAiRiskBand,
  visualAiRiskColor,
} from '../../lib/reviewScanPresentation'

function MetaRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-3 py-1 text-xs">
      <span className="shrink-0 text-[var(--color-text-secondary)]">{label}</span>
      <span className="min-w-0 text-right font-semibold text-[var(--color-text-primary)]">{children}</span>
    </div>
  )
}

function AdvancedExifSection({ metadata }: { metadata: ExifMetadata }) {
  const fields = metadata.fields ?? []
  return (
    <details className="group rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)]/40">
      <summary className="flex cursor-pointer list-none items-center justify-between gap-2 px-3 py-2 text-xs font-bold text-[var(--color-text-primary)] [&::-webkit-details-marker]:hidden">
        Advanced EXIF Metadata
        <ChevronDown size={14} className="text-[var(--color-text-muted)] transition group-open:rotate-180" />
      </summary>
      <div className="border-t border-[var(--color-border)] px-3 py-2">
        <p className="mb-2 text-[11px] text-[var(--color-text-secondary)]">
          {metadata.format ? metadata.format : 'Unknown format'}
          {' · '}
          {metadata.has_exif ? `${metadata.field_count} metadata tags` : 'No EXIF tags'}
        </p>
        {fields.length > 0 ? (
          <dl className="grid gap-1 sm:grid-cols-2">
            {fields.map((field) => (
              <div
                key={field.key}
                className="flex flex-col gap-0.5 rounded-md bg-[var(--color-surface)] px-2 py-1.5"
              >
                <dt className="text-[10px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {field.label}
                </dt>
                <dd className="break-words text-[11px] font-medium leading-snug text-[var(--color-text-primary)]">
                  {field.value}
                </dd>
              </div>
            ))}
          </dl>
        ) : (
          <p className="text-[11px] text-[var(--color-text-secondary)]">No EXIF fields were extracted.</p>
        )}
      </div>
    </details>
  )
}

/** Internal content for Review Scan → Technical Details collapsible only. */
export function ReviewScanTechnicalDetails({ row }: { row: AiDetectionRow }) {
  const meta = row.exif_metadata
  const band = visualAiRiskBand(row)
  const color = visualAiRiskColor(band)
  const pFake = probeRawPFakePercent(row)

  return (
    <div className="space-y-3">
      <section>
        <h4 className="text-[11px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
          AI-Generation Risk
        </h4>
        <p className="mt-1 text-[11px] text-[var(--color-text-secondary)]">
          Detector:{' '}
          <span className="font-semibold text-[var(--color-text-primary)]">{PROBE_DETECTOR_DISPLAY_NAME}</span>
        </p>
        <div className="mt-1.5 flex flex-wrap items-center gap-2">
          <span
            className="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-[11px] font-extrabold uppercase tracking-wide"
            style={{
              color,
              backgroundColor: `color-mix(in srgb, ${color} 12%, transparent)`,
            }}
          >
            <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: color }} aria-hidden />
            {band}
          </span>
          {pFake != null ? (
            <span className="text-xs text-[var(--color-text-secondary)]">
              Raw P(fake):{' '}
              <span className="font-bold tabular-nums text-[var(--color-text-primary)]">{pFake}</span>
            </span>
          ) : (
            <span className="text-xs text-[var(--color-text-muted)]">Raw P(fake): N/A</span>
          )}
        </div>
        <p className="mt-1.5 text-[11px] leading-snug text-[var(--color-text-muted)]">{AI_GENERATION_RISK_HINT}</p>
      </section>

      <div className="border-t border-[var(--color-border)] pt-3">
        <h4 className="text-[11px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
          Source Verification
        </h4>
        <div className="mt-1 divide-y divide-[var(--color-border-subtle)]">
          <MetaRow label="Camera Origin">{cameraOriginLabel(meta)}</MetaRow>
          <MetaRow label="EXIF Metadata">{meta?.has_exif ? 'Present' : 'Absent'}</MetaRow>
          <MetaRow label="Source Verification">{formatProvenancePolicyDisplay(meta?.provenance_policy_outcome)}</MetaRow>
        </div>
        <p className="mt-2 text-[11px] leading-relaxed text-[var(--color-text-secondary)]">
          {technicalProvenanceExplanation(meta)}
        </p>
      </div>

      {meta ? (
        <div className="border-t border-[var(--color-border)] pt-3">
          <AdvancedExifSection metadata={meta} />
        </div>
      ) : (
        <p className="border-t border-[var(--color-border)] pt-3 text-[11px] text-[var(--color-text-secondary)]">
          Advanced EXIF metadata is not available for this scan.
        </p>
      )}
    </div>
  )
}
