begin;
set local search_path = public, extensions;
select plan(5);

select ok(
  exists (select 1 from pg_constraint where conrelid = 'private.command_executions'::regclass and contype = 'u'),
  'command executions have an idempotency uniqueness constraint'
);
select ok(
  exists (select 1 from pg_attribute where attrelid = 'private.command_executions'::regclass and attname = 'request_fingerprint' and not attisdropped),
  'command executions bind idempotency to request hash'
);
select ok(
  exists (select 1 from pg_attribute where attrelid = 'private.command_executions'::regclass and attname = 'result_reference' and not attisdropped),
  'successful command responses can be replayed'
);
select ok(
  exists (select 1 from pg_index where indrelid = 'private.command_executions'::regclass and indisunique),
  'concurrent command claims are protected by a unique index'
);
select is(
  (select count(*)::integer from private.command_executions where status = 'succeeded' and result_reference is null),
  0,
  'successful commands retain their response'
);

select * from finish();
rollback;
