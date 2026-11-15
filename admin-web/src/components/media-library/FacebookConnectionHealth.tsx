import { Loader2, RefreshCw } from 'lucide-react'
import type { FacebookConfigStatus, FacebookConnectionHealthInfo } from '../../api/eventMedia'

function statusLabel(status: string | undefined): string {
  switch ((status || 'unknown').toLowerCase()) {
    case 'connected':
      return 'Connected'
    case 'needs_attention':
      return 'Needs Attention'
    case 'disconnected':
      return 'Disconnected'
    default:
      return 'Unknown'
  }
}

function statusClass(status: string | undefined): string {
  switch ((status || 'unknown').toLowerCase()) {
    case 'connected':
      return 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30'
    case 'needs_attention':
      return 'bg-amber-500/15 text-amber-200 border-amber-500/30'
    case 'disconnected':
      return 'bg-rose-500/15 text-rose-200 border-rose-500/30'
    default:
      return 'bg-slate-500/15 text-slate-300 border-slate-500/30'
  }
}

function formatWhen(iso: string | null | undefined): string {
  if (!iso) return 'Not verified yet'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return 'Not verified yet'
  return d.toLocaleString()
}

type Props = {
  config: FacebookConfigStatus | null
  checking: boolean
  onCheckConnection: () => void
}

export function FacebookConnectionHealth({ config, checking, onCheckConnection }: Props) {
  const health: FacebookConnectionHealthInfo | undefined = config?.health
  const status = health?.connection_status || (config?.access_token_set ? 'unknown' : 'disconnected')
  const pageName =
    health?.page_name ||
    config?.token_check?.token_subject_name ||
    (config?.page_id_set ? 'Configured Page' : 'Not set')
  const pageId = health?.page_id || config?.token_check?.token_subject_id || null
  const expiry =
    health?.expiry_label ||
    (health?.expiry_visibility === 'never'
      ? 'Never (confirmed by Meta)'
      : 'Expiration not confirmed')

  return (
    <div className="rounded-[var(--card-radius)] border border-[var(--color-border)] bg-[var(--color-surface)] p-3 md:p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 space-y-1">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">Facebook Connection Health</h3>
            <span
              className={`inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-semibold ${statusClass(status)}`}
            >
              {statusLabel(status)}
            </span>
          </div>
          <p className="text-xs text-[var(--color-text-muted)]">
            Manual verification only. Opening Media Gallery does not call Meta Graph.
          </p>
        </div>
        <button
          type="button"
          onClick={onCheckConnection}
          disabled={checking}
          className="inline-flex items-center gap-1.5 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg)] px-3 py-1.5 text-xs font-semibold text-[var(--color-text-primary)] hover:bg-[var(--color-surface-2)] disabled:opacity-60"
        >
          {checking ? <Loader2 size={14} className="animate-spin" /> : <RefreshCw size={14} />}
          {checking ? 'Checking…' : 'Check Connection'}
        </button>
      </div>

      <dl className="mt-3 grid gap-2 text-xs sm:grid-cols-2 lg:grid-cols-3">
        <div>
          <dt className="text-[var(--color-text-muted)]">Page name</dt>
          <dd className="font-medium text-[var(--color-text-primary)]">{pageName}</dd>
        </div>
        <div>
          <dt className="text-[var(--color-text-muted)]">Page ID</dt>
          <dd className="font-mono text-[var(--color-text-primary)]">{pageId || '—'}</dd>
        </div>
        <div>
          <dt className="text-[var(--color-text-muted)]">Last successful verification</dt>
          <dd className="text-[var(--color-text-primary)]">
            {health?.last_ok
              ? formatWhen(health.last_verified_at)
              : health?.last_verified_at
                ? `Last check ${formatWhen(health.last_verified_at)} (failed)`
                : 'Not verified yet'}
          </dd>
        </div>
        <div>
          <dt className="text-[var(--color-text-muted)]">Token expiration</dt>
          <dd className="text-[var(--color-text-primary)]">{expiry}</dd>
        </div>
        <div className="sm:col-span-2">
          <dt className="text-[var(--color-text-muted)]">Last verification error</dt>
          <dd className="text-[var(--color-text-primary)]">
            {health?.last_error?.trim() ? health.last_error : 'None'}
          </dd>
        </div>
      </dl>
    </div>
  )
}
