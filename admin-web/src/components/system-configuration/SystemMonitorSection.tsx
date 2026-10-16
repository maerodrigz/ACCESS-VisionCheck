import { useCallback, useEffect, useState } from 'react'
import { Activity, Database, Loader2, RefreshCw } from 'lucide-react'
import { fetchSystemMonitor, type SystemMonitorPayload } from '../../api/adminIntegrations'
import { AdminErrorBanner } from '../AdminAlert'
import { ConfigCard } from './ConfigParts'

function StatusPill({ ok, label }: { ok: boolean; label: string }) {
  return (
    <span
      className={[
        'inline-flex rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase',
        ok
          ? 'border border-[color-mix(in_srgb,var(--color-success)_35%,transparent)] bg-[var(--color-success-surface)] text-[var(--color-success-text)]'
          : 'border border-[color-mix(in_srgb,var(--color-danger)_35%,transparent)] bg-[var(--color-danger-surface)] text-[var(--color-danger-text)]',
      ].join(' ')}
    >
      {label}
    </span>
  )
}

export function SystemMonitorSection() {
  const [data, setData] = useState<SystemMonitorPayload | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      setData(await fetchSystemMonitor())
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load system monitor')
      setData(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  return (
    <ConfigCard
      icon={<Activity size={22} strokeWidth={2} />}
      title="System Monitor"
      description="Live health snapshot for the ACCESS backend, database, and recent audit activity."
      footer={
        <button
          type="button"
          className="sys-config__btn sys-config__btn--ghost inline-flex items-center gap-2"
          onClick={() => void load()}
          disabled={loading}
        >
          {loading ? <Loader2 size={16} className="animate-spin" /> : <RefreshCw size={16} />}
          Refresh monitor
        </button>
      }
    >
      {error ? (
        <div className="mb-3">
          <AdminErrorBanner>{error}</AdminErrorBanner>
        </div>
      ) : null}

      {loading && !data ? (
        <div className="flex items-center gap-2 py-8 text-sm text-[var(--color-text-secondary)]">
          <Loader2 size={18} className="animate-spin" />
          Loading monitor…
        </div>
      ) : data ? (
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs font-bold text-[var(--color-text-primary)]">API</span>
                <StatusPill ok={data.api_status === 'ok'} label={data.api_status} />
              </div>
              <p className="mt-2 text-xs text-[var(--color-text-secondary)]">
                Response {data.response_ms} ms · {data.public_url || 'Local API'}
              </p>
            </div>
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)] p-3">
              <div className="flex items-center justify-between gap-2">
                <span className="inline-flex items-center gap-1.5 text-xs font-bold text-[var(--color-text-primary)]">
                  <Database size={14} />
                  Database
                </span>
                <StatusPill ok={data.database.connected} label={data.database.connected ? 'Connected' : 'Error'} />
              </div>
              <p className="mt-2 text-xs text-[var(--color-text-secondary)]">
                {data.database.name}
                {data.database.error ? ` · ${data.database.error}` : ''}
              </p>
            </div>
          </div>

          <div>
            <h3 className="text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
              Table counts
            </h3>
            <div className="mt-2 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
              {Object.entries(data.table_counts).map(([key, value]) => (
                <div
                  key={key}
                  className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface-muted)] px-3 py-2"
                >
                  <div className="text-[10px] font-semibold uppercase text-[var(--color-text-secondary)]">
                    {key.replace(/_/g, ' ')}
                  </div>
                  <div className="text-lg font-extrabold text-[var(--color-text-primary)]">{value}</div>
                </div>
              ))}
            </div>
          </div>

          <div>
            <h3 className="text-xs font-bold uppercase tracking-wide text-[var(--color-text-secondary)]">
              Recent audit log
            </h3>
            <div className="mt-2 overflow-hidden rounded-xl border border-[var(--color-border)]">
              <table className="w-full text-left text-xs">
                <thead className="bg-[var(--color-surface-muted)] text-[10px] font-bold uppercase text-[var(--color-text-secondary)]">
                  <tr>
                    <th className="px-3 py-2">Action</th>
                    <th className="px-3 py-2">User</th>
                    <th className="px-3 py-2">When</th>
                  </tr>
                </thead>
                <tbody>
                  {data.audit_logs.length === 0 ? (
                    <tr>
                      <td colSpan={3} className="px-3 py-4 text-[var(--color-text-secondary)]">
                        No audit entries yet.
                      </td>
                    </tr>
                  ) : (
                    data.audit_logs.map((log) => (
                      <tr key={log.id} className="border-t border-[var(--color-border-subtle)]">
                        <td className="px-3 py-2">
                          <div className="font-semibold text-[var(--color-text-primary)]">{log.action}</div>
                          <div className="text-[var(--color-text-secondary)]">{log.description}</div>
                        </td>
                        <td className="px-3 py-2 text-[var(--color-text-secondary)]">{log.user_name}</td>
                        <td className="px-3 py-2 whitespace-nowrap text-[var(--color-text-secondary)]">
                          {log.created_at ? new Date(log.created_at).toLocaleString() : 'N/A'}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      ) : null}
    </ConfigCard>
  )
}
