-- The payment intake implementation was added after the original command grants.
grant execute on function private.command_record_customer_payment(
  uuid, uuid, uuid, uuid, bigint, text, text, text, timestamptz, uuid,
  text, text, uuid
) to authenticated;

grant execute on function private.command_confirm_order(
  uuid, uuid, bigint, text, text, uuid
) to authenticated;

grant execute on function private.command_grant_order_discount(
  uuid, uuid, bigint, boolean, text, text, bigint, uuid, text, text, uuid
) to authenticated;
