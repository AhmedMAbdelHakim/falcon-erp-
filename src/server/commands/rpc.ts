import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '../../types/database.generated'
import { validateCommandEnvelope } from '../validation/command'

type RpcCommandArgs = {
  p_organization_id: string
  p_idempotency_key: string
} & Record<string, unknown>

export async function invokeCommand<TResult, TArgs extends RpcCommandArgs>(
  client: SupabaseClient<Database>,
  rpcName: string,
  args: TArgs,
): Promise<TResult> {
  validateCommandEnvelope({
    organizationId: args.p_organization_id,
    idempotencyKey: args.p_idempotency_key,
    payload: args,
  })
  const { data, error } = await client.schema('api').rpc(rpcName as never, args as never)
  if (error) throw error
  return data as TResult
}
