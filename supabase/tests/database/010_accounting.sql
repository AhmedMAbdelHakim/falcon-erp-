begin;
set local search_path = public, extensions;
select plan(7);

select ok(
  exists (select 1 from pg_constraint where conrelid = 'accounting.journal_lines'::regclass and contype in ('c', 'f')),
  'journal lines are constrained'
);
select ok(
  exists (select 1 from pg_trigger where tgrelid = 'accounting.journal_entries'::regclass and not tgisinternal),
  'journal entries have invariant triggers'
);
select ok(
  exists (select 1 from pg_trigger where tgrelid = 'accounting.journal_lines'::regclass and not tgisinternal),
  'journal lines have invariant triggers'
);
select ok(
  exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'post_journal_entry'),
  'posting function exists'
);
select ok(
  exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'reverse_journal_entry'),
  'reversal function exists'
);
select ok(
  exists (select 1 from pg_constraint where conrelid = 'accounting.accounting_periods'::regclass),
  'accounting periods are constrained'
);
select is(
  (select count(*)::integer from accounting.journal_entries je where je.status = 'posted' and not exists (
    select 1 from accounting.journal_lines jl where jl.journal_entry_id = je.id
    group by jl.journal_entry_id having sum(jl.debit_minor) = sum(jl.credit_minor) and sum(jl.debit_minor) > 0
  )),
  0,
  'no posted journal is unbalanced'
);

select * from finish();
rollback;
