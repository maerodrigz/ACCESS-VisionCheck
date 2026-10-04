import type { ExifMetadata, ExifMetadataFlag } from '../../api/media'

const FLAG_STYLES: Record<string, string> = {
  danger: 'border-[color-mix(in_srgb,var(--color-danger)_30%,transparent)] bg-[color-mix(in_srgb,var(--color-danger)_8%,transparent)] text-[var(--color-danger)]',
  warning: 'border-[color-mix(in_srgb,var(--color-warning)_35%,transparent)] bg-[color-mix(in_srgb,var(--color-warning)_10%,transparent)] text-[var(--color-warning)]',
  info: 'border-[var(--color-border)] bg-[var(--color-surface-muted)] text-[var(--color-text-secondary)]',
}

function flagClass(severity: string) {
  return FLAG_STYLES[severity] ?? FLAG_STYLES.info
}

interface Props {
  metadata?: ExifMetadata
}

export function ExifMetadataPanel({ metadata }: Props) {
  if (!metadata) {
    return <p className="text-xs text-[var(--color-text-secondary)]">File metadata is not available for this scan.</p>
  }

  const summaryText = metadata.summary?.trim().toLowerCase()
  const reasonTexts = new Set((metadata.camera_provenance_reasons ?? []).map((r) => r.trim().toLowerCase()))
  const flags = (metadata.flags ?? []).filter((f) => {
    const text = f.label.trim().toLowerCase()
    return text !== summaryText && !reasonTexts.has(text)
  })
  const fields = metadata.fields ?? []

  return (
    <div className="space-y-2.5">
      <div className="flex flex-wrap items-center gap-1.5 text-[10px] font-semibold uppercase tracking-wide">
        <span className="text-xs font-bold normal-case tracking-normal text-[var(--color-text-primary)]">
          File metadata (EXIF)
        </span>
        {metadata.format && (
          <span className="rounded border border-[var(--color-border)] px-1.5 py-0.5 text-[var(--color-text-secondary)]">
            {metadata.format}
          </span>
        )}
        <span className="rounded border border-[var(--color-border)] px-1.5 py-0.5 text-[var(--color-text-secondary)]">
          {metadata.has_exif ? `${metadata.field_count} tags` : 'No EXIF'}
        </span>
      </div>

      {(metadata.camera_provenance_strength || metadata.visual_risk_level || metadata.visual_ai_probability != null) && (
        <dl className="grid gap-2 text-xs sm:grid-cols-2">
          <div className="rounded-lg border border-[var(--color-border)] px-2.5 py-1.5">
            <dt className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
              PROBE visual AI probability
            </dt>
            <dd className="mt-0.5 font-semibold text-[var(--color-text-primary)]">
              {metadata.visual_ai_probability != null
                ? `${Math.round(metadata.visual_ai_probability * 100)}%`
                : 'N/A'}
              {metadata.visual_risk_level ? ` (${metadata.visual_risk_level})` : ''}
            </dd>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] px-2.5 py-1.5">
            <dt className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
              Camera provenance
            </dt>
            <dd className="mt-0.5 font-semibold capitalize text-[var(--color-text-primary)]">
              {metadata.camera_provenance_strength ?? 'N/A'}
            </dd>
          </div>
          {metadata.provenance_policy_outcome ? (
            <div className="rounded-lg border border-[var(--color-border)] px-2.5 py-1.5 sm:col-span-2">
              <dt className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                Provenance policy outcome
              </dt>
              <dd className="mt-0.5 font-semibold text-[var(--color-text-primary)]">
                {metadata.provenance_policy_outcome.replace(/_/g, ' ')}
              </dd>
            </div>
          ) : null}
          {metadata.camera_provenance_reasons && metadata.camera_provenance_reasons.length > 0 ? (
            <p className="text-[11px] leading-relaxed text-[var(--color-text-secondary)] sm:col-span-2">
              {metadata.camera_provenance_reasons.join(' ')}
            </p>
          ) : null}
        </dl>
      )}

      {metadata.summary && (
        <p className="text-xs leading-relaxed text-[var(--color-text-primary)]">{metadata.summary}</p>
      )}

      {flags.length > 0 && (
        <ul className="flex flex-wrap gap-1.5">
          {flags.map((flag: ExifMetadataFlag) => (
            <li
              key={flag.code}
              className={`rounded-md border px-2 py-1 text-[11px] font-semibold ${flagClass(flag.severity)}`}
            >
              {flag.label}
            </li>
          ))}
        </ul>
      )}

      {fields.length > 0 ? (
        <dl className="grid gap-1.5 sm:grid-cols-2">
          {fields.map((field) => (
            <div key={field.key} className="rounded-lg bg-[var(--color-surface-muted)] px-2.5 py-1.5">
              <dt className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                {field.label}
              </dt>
              <dd className="mt-0.5 break-words text-xs font-semibold text-[var(--color-text-primary)]">
                {field.value}
              </dd>
            </div>
          ))}
        </dl>
      ) : null}
    </div>
  )
}
