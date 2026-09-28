import { useEffect, useRef, useState } from 'react'
import { ImagePlus, Loader2, RotateCcw } from 'lucide-react'
import { AdminConfirmDialog } from '../AdminConfirmDialog'
import { AdminErrorBanner } from '../AdminAlert'
import { fetchAdminBranding, resetAdminLogo, uploadAdminLogo } from '../../api/adminBranding'
import { brandingLogoUrl } from '../../api/branding'
import { useBranding } from '../../context/BrandingContext'
import { AccessBrandMark } from '../AccessBrandMark'

const ACCEPT = 'image/jpeg,image/png,image/webp'

export function BrandingLogoPanel() {
  const { refresh: refreshGlobalBranding } = useBranding()
  const inputRef = useRef<HTMLInputElement>(null)
  const [logoUrl, setLogoUrl] = useState<string | null>(null)
  const [isCustom, setIsCustom] = useState(false)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState<'upload' | 'reset' | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [confirmReset, setConfirmReset] = useState(false)

  async function loadLogo() {
    setLoading(true)
    setError(null)
    try {
      const payload = await fetchAdminBranding()
      setLogoUrl(brandingLogoUrl(payload))
      setIsCustom(Boolean(payload.is_custom))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load logo settings')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void loadLogo()
  }, [])

  async function handleFile(file: File) {
    setBusy('upload')
    setError(null)
    try {
      const payload = await uploadAdminLogo(file)
      setLogoUrl(brandingLogoUrl(payload))
      setIsCustom(Boolean(payload.is_custom))
      await refreshGlobalBranding()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Logo upload failed')
    } finally {
      setBusy(null)
      if (inputRef.current) inputRef.current.value = ''
    }
  }

  async function handleReset() {
    setBusy('reset')
    setError(null)
    try {
      const payload = await resetAdminLogo()
      setLogoUrl(brandingLogoUrl(payload))
      setIsCustom(Boolean(payload.is_custom))
      await refreshGlobalBranding()
      setConfirmReset(false)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to reset logo')
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="sys-config__field">
      <label className="sys-config__label">Platform logo</label>
      <span className="sys-config__hint">
        Shown on login screens and navigation. JPG, PNG, or WEBP up to 5 MB. Leave default to use the
        bundled ACCESS mark.
      </span>

      {error ? (
        <div className="mt-2">
          <AdminErrorBanner>{error}</AdminErrorBanner>
        </div>
      ) : null}

      <div className="mt-3 flex flex-wrap items-center gap-4">
        <div className="flex h-20 w-20 items-center justify-center overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-surface-muted)]">
          {loading ? (
            <Loader2 size={22} className="animate-spin text-[var(--color-text-muted)]" />
          ) : logoUrl ? (
            <img src={logoUrl} alt="Current platform logo" className="h-full w-full object-contain" />
          ) : (
            <AccessBrandMark size={48} />
          )}
        </div>

        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            className="sys-config__btn sys-config__btn--ghost inline-flex items-center gap-2"
            disabled={busy !== null}
            onClick={() => inputRef.current?.click()}
          >
            {busy === 'upload' ? <Loader2 size={16} className="animate-spin" /> : <ImagePlus size={16} />}
            Upload logo
          </button>
          {isCustom ? (
            <button
              type="button"
              className="sys-config__btn sys-config__btn--ghost inline-flex items-center gap-2"
              disabled={busy !== null}
              onClick={() => setConfirmReset(true)}
            >
              {busy === 'reset' ? <Loader2 size={16} className="animate-spin" /> : <RotateCcw size={16} />}
              Reset to default
            </button>
          ) : null}
        </div>

        <input
          ref={inputRef}
          type="file"
          accept={ACCEPT}
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0]
            if (file) void handleFile(file)
          }}
        />
      </div>

      <AdminConfirmDialog
        open={confirmReset}
        title="Reset logo to default?"
        message="The custom uploaded logo will be removed. Login and navigation will use the bundled ACCESS mark again."
        confirmLabel="Reset logo"
        tone="danger"
        loading={busy === 'reset'}
        onConfirm={() => void handleReset()}
        onCancel={() => setConfirmReset(false)}
      />
    </div>
  )
}
