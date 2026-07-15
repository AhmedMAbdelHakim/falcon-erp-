begin;
set local search_path = public, extensions;
select plan(10);

select has_schema('public', 'public schema exists');
select has_schema('api', 'api schema exists');
select has_schema('accounting', 'accounting schema exists');
select has_schema('private', 'private schema exists');
select has_schema('audit', 'audit schema exists');
select has_table('public', 'organizations', 'organizations table exists');
select has_table('public', 'orders', 'orders table exists');
select has_table('accounting', 'journal_entries', 'journal entry table exists');
select has_table('accounting', 'journal_lines', 'journal line table exists');
select has_table('private', 'command_executions', 'command execution table exists');

select * from finish();
rollback;
