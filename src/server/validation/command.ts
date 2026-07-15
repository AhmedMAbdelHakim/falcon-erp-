export interface CommandEnvelope<TPayload> {
  organizationId: string
  idempotencyKey: string
  payload: TPayload
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

export function validateCommandEnvelope<TPayload>(value: CommandEnvelope<TPayload>): CommandEnvelope<TPayload> {
  if (!UUID.test(value.organizationId)) throw new TypeError('organizationId must be a UUID')
  if (value.idempotencyKey.length < 16 || value.idempotencyKey.length > 128) {
    throw new RangeError('idempotencyKey must be 16-128 characters')
  }
  return value
}
