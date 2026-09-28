import type { ExifMetadata, ExifMetadataFlag } from '../../api/media'

const FLAG_STYLES: Record<string, string> = {
  danger: 'border-red-500/30 bg-red-500/10 text-red-300',
  warning: 'admin-callout-warning',
  info: 'border-sky-500/30 bg-sky-500/10 text-sky-200',
}

function flagClass(severity: string) {
  return FLAG_STYLES[severity] ?? FLAG_STYLES.info
}

interface Props {
  metadata?: ExifMetadata
}

export function ExifMetadataPanel({ metadata }: Props) {
  if (!metadata) {
    return (
      <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3 text-sm text-[var(--color-text-secondary)]">
        <div className="mb-1 text-xs font-bold uppercase tracking-wide text-[var(--color-text-primary)]">
          File metadata (EXIF)
        </div>
        Metadata is not available for this scan.
      </div>
    )
  }

  const flags = metadata.flags ?? []
  const fields = metadata.fields ?? []

  return (
    <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-4 py-3">
      <div className="mb-2 flex flex-wrap items-start justify-between gap-2">
        <div>
          <div className="text-xs font-bold uppercase tracking-wide text-[var(--color-text-primary)]">
            File metadata (EXIF)
          </div>
          <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
            Camera and file tags help corroborate authenticity. Missing EXIF alone does not prove AI.
          </p>
        </div>
        <div className="flex flex-wrap gap-2 text-[10px] font-semibold uppercase tracking-wide">
          {metadata.format && (
            <span className="rounded-md border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-2 py-1 text-[var(--color-text-secondary)]">
              {metadata.format}
            </span>
          )}
          <span className="rounded-md border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-2 py-1 text-[var(--color-text-secondary)]">
            {metadata.has_exif ? `${metadata.field_count} tags` : 'No EXIF'}
          </span>
        </div>
      </div>

      {(metadata.camera_provenance_strength || metadata.visual_risk_level) && (
        <div className="mb-3 grid gap-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2 text-xs sm:grid-cols-2">
          <div>
            <span className="font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
              AI visual risk
            </span>
            <p className="mt-1 font-semibold text-[var(--color-text-primary)]">
              {metadata.visual_ai_probability != null
                ? `${Math.round(metadata.visual_ai_probability * 100)}% P(fake)`
                : metadata.visual_risk_level ?? '—'}
              {metadata.visual_risk_level ? ` (${metadata.visual_risk_level})` : ''}
            </p>
          </div>
          <div>
            <span className="font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
              Camera provenance
            </span>
            <p className="mt-1 font-semibold capitalize text-[var(--color-text-primary)]">
              {metadata.camera_provenance_strength ?? '—'}
            </p>
          </div>
          {metadata.camera_provenance_reasons && metadata.camera_provenance_reasons.length > 0 ? (
            <p className="sm:col-span-2 text-[var(--color-text-secondary)]">
              {metadata.camera_provenance_reasons.join(' ')}
            </p>
          ) : null}
        </div>
      )}

      {metadata.summary && (
        <p className="mb-3 text-sm font-medium text-[var(--color-text-primary)]">{metadata.summary}</p>
      )}

      {flags.length > 0 && (
        <ul className="mb-3 space-y-2">
          {flags.map((flag: ExifMetadataFlag) => (
            <li
              key={flag.code}
              className={`rounded-lg border px-3 py-2 text-xs font-semibold ${flagClass(flag.severity)}`}
            >
              {flag.label}
            </li>
          ))}
        </ul>
      )}

      {fields.length > 0 ? (
        <dl className="grid gap-2 sm:grid-cols-2">
          {fields.map((field) => (
            <div
              key={field.key}
              className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-elevated)] px-3 py-2"
            >
              <dt className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
                {field.label}
              </dt>
              <dd className="mt-0.5 break-words text-xs font-semibold text-[var(--color-text-primary)]">
                {field.value}
              </dd>
            </div>
          ))}
        </dl>
      ) : (
        !metadata.is_video && (
          <p className="text-xs text-[var(--color-text-secondary)]">
            No readable EXIF tags were found. Compare with zoom inspection and detection notes.
          </p>
        )
      )}
    </div>
  )
}
