-- Thin invoker API wrappers need EXECUTE on their non-exposed implementations.
-- The private schema remains without USAGE for authenticated callers, preventing
-- direct Data API access to these implementation functions.

grant execute on function private.command_allocate_customer_payment(
  uuid, uuid, jsonb, boolean, text, text, uuid
) to authenticated;
grant execute on function private.command_apply_customer_credit(
  uuid, uuid, uuid, bigint, text, text, uuid
) to authenticated;
grant execute on function private.command_request_customer_refund(
  uuid, uuid, uuid, uuid, uuid, bigint, text, text, text, text, text, uuid
) to authenticated;
grant execute on function private.command_approve_customer_refund(
  uuid, uuid, text, text, uuid
) to authenticated;
grant execute on function private.command_execute_customer_refund(
  uuid, uuid, uuid, text, uuid, text, text, uuid
) to authenticated;
grant execute on function private.command_reverse_customer_refund(
  uuid, uuid, text, uuid, text, text, uuid
) to authenticated;
grant execute on function private.command_reverse_customer_payment(
  uuid, uuid, text, uuid, text, text, uuid
) to authenticated;
