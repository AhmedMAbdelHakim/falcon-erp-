import { useMemo, useRef, useState } from 'react'
import { CheckCircle2, Play, X } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { useToast } from '../context/ToastContext'
import { workflowActions, type WorkflowAction, type WorkflowField } from '../features/workflows/actions'
import { createCorrelationId, createIdempotencyKey } from '../lib/idempotency'
import { supabase } from '../lib/supabase'
import type { Json } from '../types/database.generated'

export function WorkflowActions({ resourceKey, onComplete }: { resourceKey: string; onComplete?: () => void }) {
  const { access, hasPermission } = useAuth()
  const { showToast } = useToast()
  const dialog = useRef<HTMLDialogElement>(null)
  const [selected, setSelected] = useState<WorkflowAction | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [result, setResult] = useState<{ correlationId: string; message: string } | null>(null)
  const actions = useMemo(() => (workflowActions[resourceKey] ?? []).filter((item) => hasPermission(item.permission)), [hasPermission, resourceKey])
  const organizationId = access?.organization_id
  if (!organizationId || actions.length === 0) return null

  function open(action: WorkflowAction) { setSelected(action); setResult(null); dialog.current?.showModal() }
  function close() { if (!submitting) dialog.current?.close() }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (!selected) return
    setSubmitting(true); setResult(null)
    const form = new FormData(event.currentTarget)
    try {
      const payload: Record<string, unknown> = { organization_id: organizationId }
      for (const field of selected.fields) payload[field.name] = readField(form, field)
      const { data: fingerprint, error: fingerprintError } = await supabase.schema('api').rpc('compute_request_fingerprint', { p_command_type: selected.commandType, p_payload: payload as Json })
      if (fingerprintError) throw fingerprintError
      const correlationId = createCorrelationId()
      const args: Record<string, unknown> = { p_organization_id: organizationId, p_correlation_id: correlationId, p_idempotency_key: createIdempotencyKey(selected.commandType), p_request_fingerprint: fingerprint }
      for (const [key, value] of Object.entries(payload)) if (key !== 'organization_id') args[`p_${key}`] = value
      // The command name is selected from the closed local catalog above; generated
      // overloads cannot represent a runtime union of all verified RPC signatures.
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { data, error } = await (supabase.schema('api').rpc as any)(selected.rpc, args)
      if (error) throw error
      const envelope = data && typeof data === 'object' && !Array.isArray(data) ? data as Record<string, unknown> : {}
      const message = String(envelope.message_key ?? envelope.current_state ?? 'تم تنفيذ الأمر بنجاح')
      setResult({ correlationId, message }); notify(message); onComplete?.()
    } catch (caught) {
      notify(caught instanceof Error ? caught.message : 'تعذر تنفيذ الأمر', true)
    } finally { setSubmitting(false) }
  }

  function notify(message: string, failed = false) { showToast(message, failed ? 'error' : 'success') }

  return <>
    <div className="workflow-actions" aria-label="إجراءات متاحة">{actions.map((action) => <button key={action.rpc} type="button" className={`button ${action.tone === 'danger' ? 'danger' : action.tone ?? 'secondary'}`} onClick={() => open(action)}><Play size={14} />{action.label}</button>)}</div>
    <dialog ref={dialog} className="command-dialog" onCancel={(event) => { if (submitting) event.preventDefault() }}>
      {selected ? <form onSubmit={submit}>
        <header><div><span className="eyebrow">أمر معاملاتي معتمد</span><h2>{selected.label}</h2></div><button type="button" className="icon-button" onClick={close} aria-label="إغلاق" title="إغلاق"><X size={18} /></button></header>
        {result ? <div className="command-result" role="status"><CheckCircle2 size={22} /><strong>{result.message}</strong><span>معرف التتبع</span><code>{result.correlationId}</code></div> : <div className="command-fields">{selected.fields.map((field) => <Field key={field.name} field={field} />)}</div>}
        <footer>{result ? <button className="button primary" type="button" onClick={close}>تم</button> : <><button className="button secondary" type="button" onClick={close} disabled={submitting}>إلغاء</button><button className="button primary" type="submit" disabled={submitting}>{submitting ? 'جارٍ التنفيذ...' : 'تنفيذ'}</button></>}</footer>
      </form> : null}
    </dialog>
  </>
}

function Field({ field }: { field: WorkflowField }) {
  if (field.kind === 'boolean') return <label className="check-field"><input name={field.name} type="checkbox" />{field.label}</label>
  const common = { name: field.name, required: !field.optional, 'aria-label': field.label }
  return <label className={field.kind === 'json' ? 'wide' : ''}><span>{field.label}{field.optional ? ' (اختياري)' : ''}</span>{field.kind === 'json' ? <textarea {...common} defaultValue={field.name === 'items' || field.name === 'allocations' || field.name === 'lines' ? '[]' : '{}'} rows={4} dir="ltr" /> : <input {...common} type={field.kind === 'number' ? 'number' : field.kind === 'datetime' ? 'datetime-local' : field.kind === 'date' ? 'date' : 'text'} dir={field.kind === 'text' ? 'auto' : 'ltr'} step="1" />}</label>
}

function readField(form: FormData, field: WorkflowField): unknown {
  if (field.kind === 'boolean') return form.get(field.name) === 'on'
  const raw = String(form.get(field.name) ?? '').trim()
  if (!raw && field.optional) return null
  if (field.kind === 'json') return JSON.parse(raw)
  if (field.kind === 'number') { const value = Number(raw); if (!Number.isSafeInteger(value)) throw new Error(`${field.label}: يجب إدخال عدد صحيح آمن`); return value }
  if (field.kind === 'datetime') return new Date(raw).toISOString()
  return raw
}
