export function createIdempotencyKey(prefix: string): string {
  return `${prefix}:${crypto.randomUUID()}`
}

export function createCorrelationId(): string {
  return crypto.randomUUID()
}
