import { Home, Bell, Shield, Image, Lock } from 'lucide-react'
import {
  ConfigCard,
  ConfigToggle,
  FieldError,
  SectionStatus,
} from './ConfigParts'
import {
  NOTIFICATION_ITEMS,
  SECURITY_ITEMS,
  generalDefaultsHint,
  type GeneralFormValues,
  type NotificationsFormValues,
  type AiFormValues,
  type MediaFormValues,
  type SecurityFormValues,
  type SectionSaveState,
  type SystemSettingsConfig,
} from '../../lib/systemConfiguration'
import { BrandingLogoPanel } from './BrandingLogoPanel'

function AiModelBlock({
  title,
  modelName,
  description,
  available,
  locked = true,
}: {
  title: string
  modelName: string
  description: string
  available?: boolean
  locked?: boolean
}) {
  return (
    <div className="sys-config__model-block">
      <div className="sys-config__model-head">
        <div>
          <div className="sys-config__model-title">{title}</div>
          <div className="sys-config__model-name">{modelName}</div>
        </div>
        <div className="sys-config__model-badges">
          {locked ? <span className="sys-config__model-badge">Fixed model</span> : null}
          {available === true ? (
            <span className="sys-config__model-badge sys-config__model-badge--success">
              Available on server
            </span>
          ) : available === false ? (
            <span className="sys-config__model-badge sys-config__model-badge--warning">
              Weights not loaded
            </span>
          ) : null}
        </div>
      </div>
      <p className="sys-config__model-desc">{description}</p>
    </div>
  )
}

export function GeneralSettingsSection({
  config,
  values,
  errors,
  saveState,
  saveError,
  resetting,
  onChange,
  onSave,
  onReset,
}: {
  config: SystemSettingsConfig
  values: GeneralFormValues
  errors: Partial<Record<keyof GeneralFormValues, string>>
  saveState: SectionSaveState
  saveError: string | null
  resetting: boolean
  onChange: (field: keyof GeneralFormValues, value: string) => void
  onSave: () => void
  onReset: () => void
}) {
  const saving = saveState === 'saving'
  const disabled = saving || resetting

  return (
    <ConfigCard
      icon={<Home size={22} strokeWidth={2} />}
      title="General Settings"
      description="Platform identity shown across ACCESS VisionCheck login, navigation, and member apps."
      footer={
        <>
          <button
            type="button"
            className="sys-config__btn sys-config__btn--primary"
            onClick={onSave}
            disabled={disabled}
          >
            {saving ? 'Saving…' : 'Save Changes'}
          </button>
          <button
            type="button"
            className="sys-config__btn sys-config__btn--ghost"
            onClick={onReset}
            disabled={disabled}
          >
            {resetting ? 'Resetting…' : 'Reset'}
          </button>
          <SectionStatus state={saveState} error={saveError} />
        </>
      }
    >
      <div className="sys-config__banner sys-config__banner--info">{generalDefaultsHint(config)}</div>
      <BrandingLogoPanel />
      {(['app_name', 'organization'] as const).map((field) => (
        <div key={field} className={`sys-config__field${errors[field] ? ' has-error' : ''}`}>
          <label className="sys-config__label" htmlFor={field}>
            {field === 'app_name' ? 'System Name' : 'Organization Name'}{' '}
            <span className="sys-config__required">*</span>
          </label>
          <span className="sys-config__hint">
            {field === 'app_name'
              ? 'Displayed as the product title in admin and mobile apps.'
              : 'Institution name shown on dashboards and profile screens.'}
          </span>
          <input
            className="sys-config__input"
            type="text"
            id={field}
            value={values[field]}
            maxLength={120}
            onChange={(e) => onChange(field, e.target.value)}
          />
          <FieldError message={errors[field]} />
        </div>
      ))}
      <div className={`sys-config__field${errors.system_description ? ' has-error' : ''}`}>
        <label className="sys-config__label" htmlFor="system_description">
          System Description <span className="sys-config__required">*</span>
        </label>
        <span className="sys-config__hint">Short description shown on login and branding panels.</span>
        <textarea
          className="sys-config__input sys-config__textarea"
          id="system_description"
          rows={3}
          maxLength={255}
          value={values.system_description}
          onChange={(e) => onChange('system_description', e.target.value)}
        />
        <FieldError message={errors.system_description} />
      </div>
    </ConfigCard>
  )
}

export function NotificationsSettingsSection({
  config,
  values,
  saveState,
  saveError,
  onChange,
  onSave,
}: {
  config: SystemSettingsConfig
  values: NotificationsFormValues
  saveState: SectionSaveState
  saveError: string | null
  onChange: (key: keyof NotificationsFormValues, value: boolean) => void
  onSave: () => void
}) {
  const emailAvailable = Boolean(config.notifications?.email_available)
  const channelNote = emailAvailable
    ? 'Configure in-app and email delivery for each notification type.'
    : 'In-app notifications only. Email delivery is not configured on this server.'

  return (
    <ConfigCard
      icon={<Bell size={22} strokeWidth={2} />}
      title="Notification Settings"
      description="Control which platform events create in-app alerts for administrators and members."
      wide
      footer={
        <>
          <button
            type="button"
            className="sys-config__btn sys-config__btn--primary"
            onClick={onSave}
            disabled={saveState === 'saving'}
          >
            {saveState === 'saving' ? 'Saving…' : 'Save Changes'}
          </button>
          <SectionStatus state={saveState} error={saveError} />
        </>
      }
    >
      <div className="sys-config__banner sys-config__banner--info">{channelNote}</div>
      <div className="sys-config__notify-group">
        <div className="sys-config__notify-group-head">
          <span className="sys-config__notify-channel">In-App Notifications</span>
        </div>
        {NOTIFICATION_ITEMS.map((item) => (
          <ConfigToggle
            key={item.key}
            id={item.key}
            label={item.label}
            hint={item.hint}
            checked={values[item.key]}
            onChange={(checked) => onChange(item.key, checked)}
          />
        ))}
      </div>
    </ConfigCard>
  )
}

export function AiEvaluationSettingsSection({
  config,
  values,
  saveState,
  saveError,
  onChange,
  onSave,
}: {
  config: SystemSettingsConfig
  values: AiFormValues
  saveState: SectionSaveState
  saveError: string | null
  onChange: (enabled: boolean) => void
  onSave: () => void
}) {
  const ai = config.ai_evaluation || {}
  const quality = (ai.quality_model || {}) as Record<string, unknown>
  const feedback = (ai.feedback_generation || {}) as Record<string, unknown>

  return (
    <ConfigCard
      icon={<Shield size={22} strokeWidth={2} />}
      title="AI Evaluation Settings"
      description="Member media quality scoring (EfficientNet-B0) and human-friendly feedback (Gemini). Upload limits are configured in Media Settings."
      footer={
        <>
          <button
            type="button"
            className="sys-config__btn sys-config__btn--primary"
            onClick={onSave}
            disabled={saveState === 'saving'}
          >
            {saveState === 'saving' ? 'Saving…' : 'Save Changes'}
          </button>
          <SectionStatus state={saveState} error={saveError} />
        </>
      }
    >
      <ConfigToggle
        id="ai_media_evaluation_enabled"
        label="AI Media Evaluation"
        hint={
          values.enabled
            ? 'EfficientNet-B0 scoring and Gemini feedback are active for member evaluation uploads.'
            : 'Member evaluation scoring is paused. Uploads that require AI evaluation will be rejected.'
        }
        checked={values.enabled}
        onChange={onChange}
      />
      <AiModelBlock
        title="Quality Evaluation Model"
        modelName={String(quality.name || 'EfficientNet-B0')}
        description={String(
          quality.description ||
            'EfficientNet-B0 performs technical media quality evaluation and scoring for member uploads.',
        )}
        available={quality.available_on_server as boolean | undefined}
        locked={quality.configurable === false}
      />
      <AiModelBlock
        title="Feedback Generation"
        modelName={String(feedback.name || 'Gemini')}
        description={String(
          feedback.description ||
            'Gemini receives EfficientNet-B0 evaluation results and generates encouraging, human-friendly feedback. It does not change or invent scores.',
        )}
        locked={feedback.configurable === false}
      />
    </ConfigCard>
  )
}

export function MediaSettingsSection({
  config,
  values,
  errors,
  saveState,
  saveError,
  onChange,
  onSave,
}: {
  config: SystemSettingsConfig
  values: MediaFormValues
  errors: Partial<Record<keyof MediaFormValues, string>>
  saveState: SectionSaveState
  saveError: string | null
  onChange: <K extends keyof MediaFormValues>(field: K, value: MediaFormValues[K]) => void
  onSave: () => void
}) {
  const fb = (config.media?.facebook || {}) as Record<string, unknown>
  const fbBanner = fb.configured ? (
    <div className="sys-config__banner sys-config__banner--success">
      Facebook Graph API credentials are configured on the server.
    </div>
  ) : (
    <div className="sys-config__banner sys-config__banner--warning">
      Facebook publishing requires FACEBOOK_PAGE_ID and FACEBOOK_PAGE_ACCESS_TOKEN in
      access_backend/.env. Missing:{' '}
      {Array.isArray(fb.missing) && fb.missing.length
        ? (fb.missing as string[]).join(', ')
        : 'credentials'}
      .
    </div>
  )

  return (
    <ConfigCard
      icon={<Image size={22} strokeWidth={2} />}
      title="Media Settings"
      description="Upload rules for event documentation and member AI evaluation. These are separate workflows and are enforced independently by the backend."
      wide
      footer={
        <>
          <button
            type="button"
            className="sys-config__btn sys-config__btn--primary"
            onClick={onSave}
            disabled={saveState === 'saving'}
          >
            {saveState === 'saving' ? 'Saving…' : 'Save Changes'}
          </button>
          <SectionStatus state={saveState} error={saveError} />
        </>
      }
    >
      <div className="sys-config__media-grid">
        <section className="sys-config__workflow">
          <div className="sys-config__workflow-head">
            <h3 className="sys-config__workflow-title">Event Documentation</h3>
            <p className="sys-config__workflow-desc">
              Media uploaded for events, albums, and Facebook publishing approval. Never mixed with
              member practice evaluations.
            </p>
          </div>
          <div className={`sys-config__field${errors.event_max_upload_mb ? ' has-error' : ''}`}>
            <label className="sys-config__label" htmlFor="event_max_upload_mb">
              Maximum Upload File Size
            </label>
            <span className="sys-config__hint">Applies to event documentation uploads only.</span>
            <div className="sys-config__inline-number">
              <input
                className="sys-config__input"
                type="number"
                id="event_max_upload_mb"
                value={values.event_max_upload_mb}
                min={1}
                max={500}
                onChange={(e) => onChange('event_max_upload_mb', Number(e.target.value))}
              />
              <span>MB</span>
            </div>
            <FieldError message={errors.event_max_upload_mb} />
          </div>
          {(
            [
              ['event_allowed_image_formats', 'Allowed Image Formats', '.jpg, .jpeg, .png'],
              ['event_allowed_video_formats', 'Allowed Video Formats', '.mp4, .mov'],
            ] as const
          ).map(([field, label, example]) => (
            <div key={field} className={`sys-config__field${errors[field] ? ' has-error' : ''}`}>
              <label className="sys-config__label" htmlFor={field}>
                {label}
              </label>
              <span className="sys-config__hint">Comma-separated extensions, e.g. {example}</span>
              <input
                className="sys-config__input"
                type="text"
                id={field}
                value={values[field]}
                onChange={(e) => onChange(field, e.target.value)}
              />
              <FieldError message={errors[field]} />
            </div>
          ))}
          <ConfigToggle
            id="enable_facebook_publishing"
            label="Enable Facebook Publishing"
            hint="Allow administrators to publish approved event media to Facebook."
            checked={values.enable_facebook_publishing}
            onChange={(checked) => onChange('enable_facebook_publishing', checked)}
          />
          {fbBanner}
        </section>

        <section className="sys-config__workflow sys-config__workflow--evaluation">
          <div className="sys-config__workflow-head">
            <h3 className="sys-config__workflow-title">Member AI Quality Evaluation</h3>
            <p className="sys-config__workflow-desc">
              Practice uploads scored by EfficientNet-B0 on the server. Gemini feedback is generated
              separately and never applies to event documentation media.
            </p>
          </div>
          <div className={`sys-config__field${errors.evaluation_max_upload_mb ? ' has-error' : ''}`}>
            <label className="sys-config__label" htmlFor="evaluation_max_upload_mb">
              Maximum Upload File Size
            </label>
            <span className="sys-config__hint">Applies to member evaluation uploads only.</span>
            <div className="sys-config__inline-number">
              <input
                className="sys-config__input"
                type="number"
                id="evaluation_max_upload_mb"
                value={values.evaluation_max_upload_mb}
                min={1}
                max={500}
                onChange={(e) => onChange('evaluation_max_upload_mb', Number(e.target.value))}
              />
              <span>MB</span>
            </div>
            <FieldError message={errors.evaluation_max_upload_mb} />
          </div>
          <div
            className={`sys-config__field${errors.max_evaluation_uploads_per_day ? ' has-error' : ''}`}
          >
            <label className="sys-config__label" htmlFor="max_evaluation_uploads_per_day">
              Maximum Evaluation Files
            </label>
            <span className="sys-config__hint">Daily limit per member for AI evaluation submissions.</span>
            <div className="sys-config__inline-number">
              <input
                className="sys-config__input"
                type="number"
                id="max_evaluation_uploads_per_day"
                value={values.max_evaluation_uploads_per_day}
                min={1}
                max={100}
                onChange={(e) =>
                  onChange('max_evaluation_uploads_per_day', Number(e.target.value))
                }
              />
              <span>files / day</span>
            </div>
            <FieldError message={errors.max_evaluation_uploads_per_day} />
          </div>
          {(
            [
              ['evaluation_allowed_image_formats', 'Allowed Image Formats', 'evaluation photos'],
              ['evaluation_allowed_video_formats', 'Allowed Video Formats', 'evaluation videos'],
            ] as const
          ).map(([field, label, hint]) => (
            <div key={field} className={`sys-config__field${errors[field] ? ' has-error' : ''}`}>
              <label className="sys-config__label" htmlFor={field}>
                {label}
              </label>
              <span className="sys-config__hint">Comma-separated extensions for {hint}</span>
              <input
                className="sys-config__input"
                type="text"
                id={field}
                value={values[field]}
                onChange={(e) => onChange(field, e.target.value)}
              />
              <FieldError message={errors[field]} />
            </div>
          ))}
        </section>
      </div>
    </ConfigCard>
  )
}

export function SecuritySettingsSection({
  values,
  errors,
  saveState,
  saveError,
  onChange,
  onSave,
}: {
  values: SecurityFormValues
  errors: Partial<Record<keyof SecurityFormValues, string>>
  saveState: SectionSaveState
  saveError: string | null
  onChange: (field: keyof SecurityFormValues, value: number) => void
  onSave: () => void
}) {
  return (
    <ConfigCard
      icon={<Lock size={22} strokeWidth={2} />}
      title="Security Settings"
      description="Configure session lifetime, password requirements, and account lockout after failed sign-in attempts."
      wide
      footer={
        <>
          <button
            type="button"
            className="sys-config__btn sys-config__btn--primary"
            onClick={onSave}
            disabled={saveState === 'saving'}
          >
            {saveState === 'saving' ? 'Saving…' : 'Save Changes'}
          </button>
          <SectionStatus state={saveState} error={saveError} />
        </>
      }
    >
      <div className="sys-config__banner sys-config__banner--info">
        Administrator-only. Changes are stored on the server and enforced at sign-in. No passwords,
        hashes, or tokens are ever displayed here.
      </div>
      <div className="sys-config__security-grid">
        {SECURITY_ITEMS.map((item) => (
          <div
            key={item.key}
            className={`sys-config__field${errors[item.key] ? ' has-error' : ''}`}
          >
            <label className="sys-config__label" htmlFor={item.key}>
              {item.label}
            </label>
            <span className="sys-config__hint">{item.hint}</span>
            <div className="sys-config__inline-number">
              <input
                className="sys-config__input"
                type="number"
                id={item.key}
                value={values[item.key]}
                min={item.min}
                max={item.max}
                onChange={(e) => onChange(item.key, Number(e.target.value))}
              />
              <span>{item.suffix}</span>
            </div>
            <FieldError message={errors[item.key]} />
          </div>
        ))}
      </div>
    </ConfigCard>
  )
}
