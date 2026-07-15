create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;

create schema if not exists api;
create schema if not exists accounting;
create schema if not exists private;
create schema if not exists audit;

comment on schema api is 'Exposed thin RPC wrappers; no tables.';
comment on schema accounting is 'Non-exposed double-entry ledger and accounting periods.';
comment on schema private is 'Non-exposed authorization, command, settings, and outbox implementation.';
comment on schema audit is 'Append-only financial and security audit events.';

revoke all on schema api from public;
revoke all on schema accounting from public;
revoke all on schema private from public;
revoke all on schema audit from public;

create type public.user_status as enum ('pending', 'active', 'suspended', 'disabled');
create type public.approval_status as enum ('draft', 'submitted', 'approved', 'rejected', 'expired', 'cancelled', 'consumed');
create type public.approval_action_type as enum ('approve', 'reject', 'cancel');
create type public.order_status as enum (
  'new', 'waiting_customer', 'waiting_deposit', 'confirmed', 'in_print_batch',
  'printing', 'received_from_printer', 'quality_check', 'ready_to_ship',
  'shipped', 'partially_delivered', 'delivered', 'partially_returned',
  'returned', 'cancelled', 'problem', 'financially_settled'
);
create type public.payment_status as enum (
  'no_payment', 'partial', 'required_deposit_paid', 'fully_prepaid',
  'cash_on_delivery', 'overpaid', 'refund_due', 'partially_refunded', 'fully_refunded'
);
create type public.payment_review_status as enum ('pending_review', 'confirmed', 'rejected', 'reversed');
create type public.item_type as enum (
  'paid_product', 'accessory', 'gift', 'design_service', 'replacement',
  'free_reprint', 'paid_reprint', 'packaging'
);
create type public.supply_method as enum (
  'supplier_case_and_print', 'falcon_case_print_only', 'ready_stock',
  'free_reprint', 'paid_reprint', 'no_production'
);
create type public.fulfillment_status as enum (
  'draft', 'planned', 'queued', 'in_production', 'partially_fulfilled',
  'fulfilled', 'partially_returned', 'returned', 'cancelled', 'problem'
);
create type public.print_batch_status as enum (
  'draft', 'sent', 'acknowledged', 'in_production', 'partially_received',
  'fully_received', 'quality_check', 'issue_detected', 'ready_for_invoice',
  'partially_paid', 'fully_paid', 'closed', 'cancelled'
);
create type public.qc_status as enum ('pending', 'accepted', 'partially_accepted', 'rejected');
create type public.shipment_status as enum (
  'draft', 'dispatched', 'partially_delivered', 'delivered', 'returned',
  'problem', 'cancelled'
);
create type public.settlement_status as enum (
  'draft', 'prepared', 'reviewed', 'approved', 'posted', 'disputed', 'cancelled'
);
create type public.return_disposition as enum (
  'pending_inspection', 'resellable', 'damaged', 'reprint', 'discarded', 'not_returned'
);
create type public.expense_status as enum ('draft', 'submitted', 'approved', 'partially_paid', 'paid', 'cancelled', 'reversed');
create type public.payroll_status as enum ('draft', 'calculated', 'approved', 'partially_paid', 'paid', 'overdue', 'cancelled', 'reversed');
create type public.withdrawal_status as enum ('draft', 'submitted', 'approved', 'rejected', 'executed', 'cancelled', 'expired', 'reversed');
create type public.journal_status as enum ('draft', 'posted', 'reversed');
create type public.accounting_period_status as enum ('open', 'closing', 'closed', 'reopened_exceptionally');
create type public.command_status as enum ('in_progress', 'succeeded', 'failed_terminal');

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

comment on function private.set_updated_at() is 'Maintains updated_at without granting business authority.';
revoke all on function private.set_updated_at() from public, anon, authenticated;
