import { useCallback, useEffect, useMemo, useState } from 'react'
import { Loader2, RefreshCw } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { useToast } from '../context/ToastContext'
import {
  fetchSystemSettings,
  resetGeneralSettings,
  saveAiEvaluationSettings,
  saveGeneralSettings,
  saveMediaSettings,
  saveNotificationSettings,
  saveSecuritySettings,
} from '../api/systemSettings'
import { AdminConfirmDialog } from '../components/AdminConfirmDialog'
import { AdminPageHeader } from '../components/AdminPageHeader'
import { pageToolbarBtnClass } from '../components/PageToolbar'
import { SecurityConfirmModal } from '../components/system-configuration/SecurityConfirmModal'
import {
  AiEvaluationSettingsSection,
  GeneralSettingsSection,
  MediaSettingsSection,
  NotificationsSettingsSection,
  SecuritySettingsSection,
} from '../components/system-configuration/SettingsSections'
import { SystemConfigNav } from '../components/system-configuration/SystemConfigNav'
import { SystemMonitorSection } from '../components/system-configuration/SystemMonitorSection'
import {
  SYSTEM_CONFIG_SECTIONS,
  buildSecurityChangeSummary,
  formsEqual,
  savedAiValues,
  savedGeneralValues,
  savedMediaValues,
  savedNotificationsValues,
  savedSecurityValues,
  sectionFromHash,
  validateGeneralForm,
  validateMediaForm,
  validateSecurityForm,
  type AiFormValues,
  type GeneralFormValues,
  type MediaFormValues,
  type NotificationsFormValues,
  type SectionSaveState,
  type SecurityFormValues,
  type SystemConfigSectionId,
  type SystemSettingsConfig,
} from '../lib/systemConfiguration'
import '../../components/system-configuration.css'

type Drafts = {
  general: GeneralFormValues | null
  notifications: NotificationsFormValues | null
  ai_evaluation: AiFormValues | null
  media: MediaFormValues | null
  security: SecurityFormValues | null
}

const EMPTY_DRAFTS: Drafts = {
  general: null,
  notifications: null,
  ai_evaluation: null,
  media: null,
  security: null,
}

export function SystemConfigurationPage() {
  const { user } = useAuth()
  const { showToast } = useToast()
  const [config, setConfig] = useState<SystemSettingsConfig | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [activeSection, setActiveSection] = useState<SystemConfigSectionId>(() =>
    sectionFromHash(window.location.hash),
  )
  const [drafts, setDrafts] = useState<Drafts>(EMPTY_DRAFTS)
  const [sectionState, setSectionState] = useState<Record<SystemConfigSectionId, SectionSaveState>>({
    general: 'idle',
    notifications: 'idle',
    ai_evaluation: 'idle',
    media: 'idle',
    security: 'idle',
    monitor: 'idle',
  })
  const [sectionError, setSectionError] = useState<Record<SystemConfigSectionId, string | null>>({
    general: null,
    notifications: null,
    ai_evaluation: null,
    media: null,
    security: null,
    monitor: null,
  })
  const [generalErrors, setGeneralErrors] = useState<
    Partial<Record<keyof GeneralFormValues, string>>
  >({})
  const [mediaErrors, setMediaErrors] = useState<Partial<Record<keyof MediaFormValues, string>>>({})
  const [securityErrors, setSecurityErrors] = useState<
    Partial<Record<keyof SecurityFormValues, string>>
  >({})
  const [generalResetting, setGeneralResetting] = useState(false)
  const [securityConfirm, setSecurityConfirm] = useState<{
    body: SecurityFormValues
    summary: string
  } | null>(null)
  const [pendingConfirm, setPendingConfirm] = useState<
    | { kind: 'leave'; next: SystemConfigSectionId; label: string; skipHashUpdate?: boolean }
    | { kind: 'refresh'; label: string }
    | { kind: 'reset' }
    | null
  >(null)

  const loadConfig = useCallback(async () => {
    setLoading(true)
    setLoadError(null)
    setDrafts(EMPTY_DRAFTS)
    setGeneralErrors({})
    setMediaErrors({})
    setSecurityErrors({})
    setSecurityConfirm(null)
    try {
      const data = await fetchSystemSettings()
      setConfig(data)
    } catch (e) {
      setLoadError(e instanceof Error ? e.message : 'Failed to load settings')
      setConfig(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadConfig()
  }, [loadConfig])

  const getSectionValues = useCallback(
    (section: SystemConfigSectionId) => {
      if (!config) return null
      switch (section) {
        case 'general':
          return drafts.general ?? savedGeneralValues(config)
        case 'notifications':
          return drafts.notifications ?? savedNotificationsValues(config)
        case 'ai_evaluation':
          return drafts.ai_evaluation ?? savedAiValues(config)
        case 'media':
          return drafts.media ?? savedMediaValues(config)
        case 'security':
          return drafts.security ?? savedSecurityValues(config)
        default:
          return null
      }
    },
    [config, drafts],
  )

  const dirtySections = useMemo(() => {
    const dirty = new Set<SystemConfigSectionId>()
    if (!config) return dirty
    for (const section of SYSTEM_CONFIG_SECTIONS) {
      const current = getSectionValues(section.id)
      if (!current) continue
      let saved: Record<string, unknown>
      switch (section.id) {
        case 'general':
          saved = savedGeneralValues(config) as unknown as Record<string, unknown>
          break
        case 'notifications':
          saved = savedNotificationsValues(config) as unknown as Record<string, unknown>
          break
        case 'ai_evaluation':
          saved = savedAiValues(config) as unknown as Record<string, unknown>
          break
        case 'media':
          saved = savedMediaValues(config) as unknown as Record<string, unknown>
          break
        case 'security':
          saved = savedSecurityValues(config) as unknown as Record<string, unknown>
          break
        default:
          continue
      }
      if (!formsEqual(current as unknown as Record<string, unknown>, saved)) {
        dirty.add(section.id)
      }
    }
    return dirty
  }, [config, getSectionValues])

  function updateSectionHash(section: SystemConfigSectionId) {
    window.history.replaceState(null, '', `${window.location.pathname}${window.location.search}#${section}`)
  }

  function completeSectionLeave(next: SystemConfigSectionId, opts?: { skipHashUpdate?: boolean }) {
    setDrafts((prev) => ({ ...prev, [activeSection]: null }))
    setSectionState((prev) => ({ ...prev, [activeSection]: 'idle' }))
    setSectionError((prev) => ({ ...prev, [activeSection]: null }))
    setActiveSection(next)
    if (!opts?.skipHashUpdate) updateSectionHash(next)
  }

  function tryNavigateSection(next: SystemConfigSectionId, opts?: { skipHashUpdate?: boolean }) {
    if (next === activeSection) return
    if (dirtySections.has(activeSection)) {
      const label = SYSTEM_CONFIG_SECTIONS.find((s) => s.id === activeSection)?.label || activeSection
      setPendingConfirm({ kind: 'leave', next, label, skipHashUpdate: opts?.skipHashUpdate })
      if (!opts?.skipHashUpdate) updateSectionHash(activeSection)
      return
    }
    setActiveSection(next)
    if (!opts?.skipHashUpdate) updateSectionHash(next)
  }

  useEffect(() => {
    function onHashChange() {
      const next = sectionFromHash(window.location.hash)
      if (next !== activeSection) {
        tryNavigateSection(next, { skipHashUpdate: true })
      }
    }
    window.addEventListener('hashchange', onHashChange)
    if (!window.location.hash) {
      updateSectionHash(activeSection)
    }
    return () => window.removeEventListener('hashchange', onHashChange)
    // eslint-disable-next-line react-hooks/exhaustive-deps -- hash listener uses latest navigate guard
  }, [activeSection, dirtySections])

  function markSectionSuccess(section: SystemConfigSectionId, message?: string) {
    setSectionState((prev) => ({ ...prev, [section]: 'success' }))
    if (message) showToast(message)
    window.setTimeout(() => {
      setSectionState((prev) =>
        prev[section] === 'success' ? { ...prev, [section]: 'idle' } : prev,
      )
    }, 2500)
  }

  function markSectionError(section: SystemConfigSectionId, message: string) {
    setSectionState((prev) => ({ ...prev, [section]: 'error' }))
    setSectionError((prev) => ({ ...prev, [section]: message }))
    showToast(message, 'error')
  }

  function handleRefresh() {
    if (dirtySections.has(activeSection)) {
      const label = SYSTEM_CONFIG_SECTIONS.find((s) => s.id === activeSection)?.label || activeSection
      setPendingConfirm({ kind: 'refresh', label })
      return
    }
    loadConfig()
  }

  function handlePendingConfirm() {
    if (!pendingConfirm) return
    if (pendingConfirm.kind === 'leave') {
      completeSectionLeave(pendingConfirm.next, { skipHashUpdate: pendingConfirm.skipHashUpdate })
      setPendingConfirm(null)
      return
    }
    if (pendingConfirm.kind === 'refresh') {
      setPendingConfirm(null)
      loadConfig()
      return
    }
    if (pendingConfirm.kind === 'reset') {
      setPendingConfirm(null)
      void runResetGeneral()
    }
  }

  async function handleSaveGeneral() {
    if (!config) return
    const form = getSectionValues('general') as GeneralFormValues
    const errors = validateGeneralForm(form)
    if (Object.keys(errors).length) {
      setGeneralErrors(errors)
      setDrafts((prev) => ({ ...prev, general: form }))
      markSectionError('general', 'Fix the highlighted fields before saving.')
      return
    }
    setGeneralErrors({})
    setSectionState((prev) => ({ ...prev, general: 'saving' }))
    setSectionError((prev) => ({ ...prev, general: null }))
    try {
      const data = await saveGeneralSettings({
        app_name: form.app_name.trim(),
        organization: form.organization.trim(),
        system_description: form.system_description.trim(),
      })
      setConfig(data)
      setDrafts((prev) => ({ ...prev, general: null }))
      markSectionSuccess('general', data.message || 'Settings saved')
    } catch (e) {
      markSectionError('general', e instanceof Error ? e.message : 'Save failed')
    }
  }

  function handleResetGeneral() {
    setPendingConfirm({ kind: 'reset' })
  }

  async function runResetGeneral() {
    setGeneralResetting(true)
    setGeneralErrors({})
    setSectionError((prev) => ({ ...prev, general: null }))
    try {
      const data = await resetGeneralSettings()
      setConfig(data)
      setDrafts((prev) => ({ ...prev, general: null }))
      markSectionSuccess('general', data.message || 'General settings reset to defaults')
    } catch (e) {
      markSectionError('general', e instanceof Error ? e.message : 'Reset failed')
    } finally {
      setGeneralResetting(false)
    }
  }

  async function handleSaveNotifications() {
    if (!config) return
    const form = getSectionValues('notifications') as NotificationsFormValues
    setSectionState((prev) => ({ ...prev, notifications: 'saving' }))
    setSectionError((prev) => ({ ...prev, notifications: null }))
    try {
      const data = await saveNotificationSettings(form as unknown as Record<string, boolean>)
      setConfig(data)
      setDrafts((prev) => ({ ...prev, notifications: null }))
      markSectionSuccess('notifications', data.message || 'Settings saved')
    } catch (e) {
      markSectionError('notifications', e instanceof Error ? e.message : 'Save failed')
    }
  }

  async function handleSaveAi() {
    if (!config) return
    const form = getSectionValues('ai_evaluation') as AiFormValues
    setSectionState((prev) => ({ ...prev, ai_evaluation: 'saving' }))
    setSectionError((prev) => ({ ...prev, ai_evaluation: null }))
    try {
      const data = await saveAiEvaluationSettings({ enabled: form.enabled })
      setConfig(data)
      setDrafts((prev) => ({ ...prev, ai_evaluation: null }))
      markSectionSuccess('ai_evaluation', data.message || 'Settings saved')
    } catch (e) {
      markSectionError('ai_evaluation', e instanceof Error ? e.message : 'Save failed')
    }
  }

  async function handleSaveMedia() {
    if (!config) return
    const form = getSectionValues('media') as MediaFormValues
    const errors = validateMediaForm(form)
    if (Object.keys(errors).length) {
      setMediaErrors(errors)
      setDrafts((prev) => ({ ...prev, media: form }))
      markSectionError('media', 'Fix the highlighted fields before saving.')
      return
    }
    setMediaErrors({})
    setSectionState((prev) => ({ ...prev, media: 'saving' }))
    setSectionError((prev) => ({ ...prev, media: null }))
    try {
      const data = await saveMediaSettings({
        event_max_upload_mb: form.event_max_upload_mb,
        evaluation_max_upload_mb: form.evaluation_max_upload_mb,
        max_evaluation_uploads_per_day: form.max_evaluation_uploads_per_day,
        event_allowed_image_formats: form.event_allowed_image_formats,
        event_allowed_video_formats: form.event_allowed_video_formats,
        evaluation_allowed_image_formats: form.evaluation_allowed_image_formats,
        evaluation_allowed_video_formats: form.evaluation_allowed_video_formats,
        enable_facebook_publishing: form.enable_facebook_publishing,
      })
      setConfig(data)
      setDrafts((prev) => ({ ...prev, media: null }))
      markSectionSuccess('media', data.message || 'Settings saved')
    } catch (e) {
      markSectionError('media', e instanceof Error ? e.message : 'Save failed')
    }
  }

  function handleSaveSecurityClick() {
    if (!config) return
    const form = getSectionValues('security') as SecurityFormValues
    const ranges = (config.security?.ranges || {}) as Record<string, { min: number; max: number }>
    const errors = validateSecurityForm(form, ranges)
    if (Object.keys(errors).length) {
      setSecurityErrors(errors)
      setDrafts((prev) => ({ ...prev, security: form }))
      markSectionError('security', 'Fix the highlighted fields before saving.')
      return
    }
    const saved = savedSecurityValues(config)
    const summary = buildSecurityChangeSummary(form, saved)
    if (!summary) {
      showToast('No security changes to save.', 'error')
      return
    }
    setSecurityErrors({})
    setDrafts((prev) => ({ ...prev, security: form }))
    setSecurityConfirm({ body: form, summary })
  }

  async function handleConfirmSecuritySave() {
    if (!securityConfirm) return
    setSectionState((prev) => ({ ...prev, security: 'saving' }))
    setSectionError((prev) => ({ ...prev, security: null }))
    try {
      const data = await saveSecuritySettings(securityConfirm.body as unknown as Record<string, number>)
      setConfig(data)
      setDrafts((prev) => ({ ...prev, security: null }))
      setSecurityConfirm(null)
      markSectionSuccess('security', data.message || 'Settings saved')
    } catch (e) {
      setSecurityConfirm(null)
      markSectionError('security', e instanceof Error ? e.message : 'Save failed')
    }
  }

  if (user && user.role !== 'Admin') {
    return (
      <div className="sys-config sys-config__page">
        <div className="sys-config__banner sys-config__banner--error">
          Administrator access required. System Configuration is only available to administrators.
        </div>
      </div>
    )
  }

  if (loading) {
    return (
      <div className="sys-config sys-config__page">
        <div className="sys-config__loading">
          <Loader2 size={28} className="animate-spin" aria-hidden />
          <span>Loading system settings…</span>
        </div>
      </div>
    )
  }

  if (loadError || !config) {
    return (
      <div className="sys-config sys-config__page">
        <div className="sys-config__banner sys-config__banner--error">{loadError || 'Failed to load settings'}</div>
        <button type="button" className="sys-config__btn sys-config__btn--primary" onClick={loadConfig}>
          Retry
        </button>
      </div>
    )
  }

  const generalValues = getSectionValues('general') as GeneralFormValues
  const notificationsValues = getSectionValues('notifications') as NotificationsFormValues
  const aiValues = getSectionValues('ai_evaluation') as AiFormValues
  const mediaValues = getSectionValues('media') as MediaFormValues
  const securityValues = getSectionValues('security') as SecurityFormValues
  const activeLabel = SYSTEM_CONFIG_SECTIONS.find((s) => s.id === activeSection)?.label || 'This section'

  return (
    <div className="sys-config sys-config__page">
      <AdminPageHeader
        title="System Configuration"
        subtitle="Configure system-wide settings and administrative preferences for ACCESS VisionCheck."
        backTo="/"
        actions={
          <button type="button" className={pageToolbarBtnClass} onClick={handleRefresh}>
            <RefreshCw size={16} className="shrink-0 text-[var(--color-text-secondary)]" aria-hidden />
            Refresh
          </button>
        }
      />

      <div className="sys-config__layout">
        <SystemConfigNav
          activeSection={activeSection}
          dirtySections={dirtySections}
          onNavigate={tryNavigateSection}
        />
        <main className="sys-config__panel">
          {dirtySections.has(activeSection) ? (
            <div className="sys-config__banner sys-config__banner--warning">
              You have unsaved changes in <strong>{activeLabel}</strong>. Save your changes before
              leaving this section.
            </div>
          ) : null}

          {activeSection === 'general' ? (
            <GeneralSettingsSection
              config={config}
              values={generalValues}
              errors={generalErrors}
              saveState={sectionState.general}
              saveError={sectionError.general}
              resetting={generalResetting}
              onChange={(field, value) => {
                setDrafts((prev) => ({
                  ...prev,
                  general: { ...(prev.general ?? savedGeneralValues(config)), [field]: value },
                }))
                if (generalErrors[field]) {
                  setGeneralErrors((prev) => {
                    const next = { ...prev }
                    delete next[field]
                    return next
                  })
                }
                setSectionState((prev) => ({ ...prev, general: 'idle' }))
                setSectionError((prev) => ({ ...prev, general: null }))
              }}
              onSave={handleSaveGeneral}
              onReset={handleResetGeneral}
            />
          ) : null}

          {activeSection === 'notifications' ? (
            <NotificationsSettingsSection
              config={config}
              values={notificationsValues}
              saveState={sectionState.notifications}
              saveError={sectionError.notifications}
              onChange={(key, value) => {
                setDrafts((prev) => ({
                  ...prev,
                  notifications: {
                    ...(prev.notifications ?? savedNotificationsValues(config)),
                    [key]: value,
                  },
                }))
                setSectionState((prev) => ({ ...prev, notifications: 'idle' }))
                setSectionError((prev) => ({ ...prev, notifications: null }))
              }}
              onSave={handleSaveNotifications}
            />
          ) : null}

          {activeSection === 'ai_evaluation' ? (
            <AiEvaluationSettingsSection
              config={config}
              values={aiValues}
              saveState={sectionState.ai_evaluation}
              saveError={sectionError.ai_evaluation}
              onChange={(enabled) => {
                setDrafts((prev) => ({
                  ...prev,
                  ai_evaluation: { enabled },
                }))
                setSectionState((prev) => ({ ...prev, ai_evaluation: 'idle' }))
                setSectionError((prev) => ({ ...prev, ai_evaluation: null }))
              }}
              onSave={handleSaveAi}
            />
          ) : null}

          {activeSection === 'media' ? (
            <MediaSettingsSection
              config={config}
              values={mediaValues}
              errors={mediaErrors}
              saveState={sectionState.media}
              saveError={sectionError.media}
              onChange={(field, value) => {
                setDrafts((prev) => ({
                  ...prev,
                  media: { ...(prev.media ?? savedMediaValues(config)), [field]: value },
                }))
                if (mediaErrors[field]) {
                  setMediaErrors((prev) => {
                    const next = { ...prev }
                    delete next[field]
                    return next
                  })
                }
                setSectionState((prev) => ({ ...prev, media: 'idle' }))
                setSectionError((prev) => ({ ...prev, media: null }))
              }}
              onSave={handleSaveMedia}
            />
          ) : null}

          {activeSection === 'monitor' ? <SystemMonitorSection /> : null}

          {activeSection === 'security' ? (
            <SecuritySettingsSection
              values={securityValues}
              errors={securityErrors}
              saveState={sectionState.security}
              saveError={sectionError.security}
              onChange={(field, value) => {
                setDrafts((prev) => ({
                  ...prev,
                  security: { ...(prev.security ?? savedSecurityValues(config)), [field]: value },
                }))
                if (securityErrors[field]) {
                  setSecurityErrors((prev) => {
                    const next = { ...prev }
                    delete next[field]
                    return next
                  })
                }
                setSectionState((prev) => ({ ...prev, security: 'idle' }))
                setSectionError((prev) => ({ ...prev, security: null }))
              }}
              onSave={handleSaveSecurityClick}
            />
          ) : null}
        </main>
      </div>

      <SecurityConfirmModal
        open={securityConfirm != null}
        summary={securityConfirm?.summary || ''}
        saving={sectionState.security === 'saving'}
        onConfirm={handleConfirmSecuritySave}
        onCancel={() => setSecurityConfirm(null)}
      />

      <AdminConfirmDialog
        open={pendingConfirm != null}
        title={
          pendingConfirm?.kind === 'leave'
            ? 'Leave without saving?'
            : pendingConfirm?.kind === 'refresh'
              ? 'Discard changes and refresh?'
              : 'Reset general settings?'
        }
        message={
          pendingConfirm?.kind === 'leave'
            ? `You have unsaved changes in ${pendingConfirm.label}. Leave this section without saving?`
            : pendingConfirm?.kind === 'refresh'
              ? `Discard unsaved changes in ${pendingConfirm.label} and reload from the server?`
              : 'Reset general settings to the default values from the server?'
        }
        confirmLabel={
          pendingConfirm?.kind === 'leave'
            ? 'Leave section'
            : pendingConfirm?.kind === 'refresh'
              ? 'Discard and refresh'
              : 'Reset defaults'
        }
        tone={pendingConfirm?.kind === 'reset' ? 'danger' : 'default'}
        loading={pendingConfirm?.kind === 'reset' && generalResetting}
        onConfirm={handlePendingConfirm}
        onCancel={() => setPendingConfirm(null)}
      />
    </div>
  )
}
