begin;
set local search_path = public, extensions;
select plan(22);

select is(
  private.canonical_request_fingerprint('test.command', '{"b":2,"a":1}'::jsonb, 1::smallint),
  private.canonical_request_fingerprint('test.command', '{"a":1,"b":2}'::jsonb, 1::smallint),
  'canonical fingerprints ignore JSON object key order'
);

select isnt(
  private.canonical_request_fingerprint('test.command', '{"a":1}'::jsonb, 1::smallint),
  private.canonical_request_fingerprint('test.command', '{"a":2}'::jsonb, 1::smallint),
  'canonical fingerprints bind payload values'
);

select isnt(
  private.canonical_request_fingerprint('test.command', '{"a":1}'::jsonb, 1::smallint),
  private.canonical_request_fingerprint('other.command', '{"a":1}'::jsonb, 1::smallint),
  'canonical fingerprints bind command type'
);

select ok(private.is_retryable_sqlstate('40001'), 'serialization failure is retryable');
select ok(private.is_retryable_sqlstate('40P01'), 'deadlock is retryable');
select ok(not private.is_retryable_sqlstate('23514'), 'constraint failure is terminal');

select has_table('public', 'labels', 'legacy labels compatibility table exists');
select has_table('public', 'shipping_settings', 'legacy shipping settings table exists');
select has_table('public', 'governorate_shipping_fees', 'legacy fee table exists');
select has_column('public', 'profiles', 'full_name', 'legacy profile full_name exists');
select has_column('public', 'profiles', 'role', 'legacy profile role label exists');

select has_function('api', 'confirm_order', array['uuid','uuid','bigint','text','text','uuid'], 'confirm order RPC exists');
select has_function('api', 'grant_order_discount', array['uuid','uuid','bigint','boolean','text','text','bigint','uuid','text','text','uuid'], 'discount RPC exists');
select has_function('api', 'record_customer_payment', array['uuid','uuid','uuid','uuid','bigint','text','text','text','timestamp with time zone','uuid','text','text','uuid'], 'payment intake RPC exists');
select has_function('api', 'attest_monthly_close_item', array['uuid','uuid','text','text','bigint','bigint','jsonb','text','uuid','text','text','uuid'], 'close evidence RPC exists');
select has_function('api', 'cancel_monthly_close', array['uuid','uuid','text','text','text','uuid'], 'close cancellation RPC exists');
select has_function('api', 'recover_monthly_close', array['uuid','uuid','text','text','text','uuid'], 'close recovery RPC exists');
select has_function('api', 'reopen_accounting_period', array['uuid','uuid','text','uuid','text','text','uuid'], 'period reopen RPC exists');
select has_function('api', 'calculate_profit_distribution', array['uuid','uuid','text','bigint','text','text','uuid'], 'profit distribution calculation RPC exists');
select has_function('api', 'approve_profit_distribution', array['uuid','uuid','uuid','text','text','uuid'], 'profit distribution approval RPC exists');
select has_function('api', 'post_profit_distribution', array['uuid','uuid','text','text','uuid'], 'profit distribution posting RPC exists');

select is(
  (
    with target as (
      select c.table_schema, c.table_name, c.column_name
      from information_schema.columns as c
      where c.table_schema in ('public', 'accounting')
        and (
          c.column_name like '%evidence_attachment_id'
          or c.column_name like '%journal_entry_id'
          or c.column_name = 'approval_request_id'
        )
    ), fk_columns as (
      select n.nspname as table_schema, cl.relname as table_name,
             a.attname as column_name
      from pg_constraint as co
      join pg_class as cl on cl.oid = co.conrelid
      join pg_namespace as n on n.oid = cl.relnamespace
      join lateral unnest(co.conkey) as k(attnum) on true
      join pg_attribute as a on a.attrelid = cl.oid and a.attnum = k.attnum
      where co.contype = 'f'
    )
    select count(*)::integer
    from target as t
    left join fk_columns as f using (table_schema, table_name, column_name)
    where f.column_name is null
  ),
  0,
  'approval, evidence, and journal references have foreign keys'
);

select * from finish();
rollback;
