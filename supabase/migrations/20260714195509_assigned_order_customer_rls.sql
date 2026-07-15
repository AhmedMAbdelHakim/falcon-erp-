create or replace function private.has_active_role(
  p_organization_id uuid,
  p_role_keys text[]
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select p_organization_id = private.current_organization_id()
    and exists(
      select 1
      from private.user_roles ur
      join private.roles r
        on r.organization_id=ur.organization_id and r.id=ur.role_id
      where ur.organization_id=p_organization_id
        and ur.user_id=auth.uid()
        and ur.revoked_at is null
        and ur.effective_from<=statement_timestamp()
        and (ur.effective_to is null or ur.effective_to>statement_timestamp())
        and r.is_active
        and r.role_key=any(p_role_keys)
    )
$$;

create or replace function private.can_read_order_row(
  p_organization_id uuid,
  p_order_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select p_organization_id=private.current_organization_id()
    and (
      private.has_active_role(
        p_organization_id,
        array['super_admin','finance_manager','operations','partner','auditor','read_only']
      )
      or exists(
        select 1 from public.orders o
        where o.organization_id=p_organization_id
          and o.id=p_order_id
          and o.assigned_moderator_id=auth.uid()
      )
    )
$$;

create or replace function private.can_read_customer_row(
  p_organization_id uuid,
  p_customer_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select p_organization_id=private.current_organization_id()
    and (
      private.has_active_role(
        p_organization_id,
        array['super_admin','finance_manager','operations','partner','auditor','read_only']
      )
      or exists(
        select 1 from public.customers c
        where c.organization_id=p_organization_id
          and c.id=p_customer_id
          and c.assigned_to_user_id=auth.uid()
      )
      or exists(
        select 1 from public.orders o
        where o.organization_id=p_organization_id
          and o.customer_id=p_customer_id
          and o.assigned_moderator_id=auth.uid()
      )
    )
$$;

revoke all on function private.has_active_role(uuid,text[]) from public,anon,authenticated;
revoke all on function private.can_read_order_row(uuid,uuid) from public,anon,authenticated;
revoke all on function private.can_read_customer_row(uuid,uuid) from public,anon,authenticated;
grant execute on function private.has_active_role(uuid,text[]) to authenticated;
grant execute on function private.can_read_order_row(uuid,uuid) to authenticated;
grant execute on function private.can_read_customer_row(uuid,uuid) to authenticated;

drop policy falcon_select on public.customers;
create policy customers_select_scoped on public.customers for select to authenticated
using(private.can_read_customer_row(organization_id,id));

drop policy falcon_select on public.customer_addresses;
create policy customer_addresses_select_scoped on public.customer_addresses for select to authenticated
using(private.can_read_customer_row(organization_id,customer_id));

drop policy falcon_select on public.orders;
create policy orders_select_scoped on public.orders for select to authenticated
using(private.can_read_order_row(organization_id,id));

drop policy falcon_select on public.order_items;
create policy order_items_select_scoped on public.order_items for select to authenticated
using(private.can_read_order_row(organization_id,order_id));

drop policy falcon_select on public.order_status_history;
create policy order_status_history_select_scoped on public.order_status_history for select to authenticated
using(private.can_read_order_row(organization_id,order_id));

drop policy falcon_select on public.order_exceptions;
create policy order_exceptions_select_scoped on public.order_exceptions for select to authenticated
using(private.can_read_order_row(organization_id,order_id));

drop policy falcon_select on public.order_discounts;
create policy order_discounts_select_scoped on public.order_discounts for select to authenticated
using(private.can_read_order_row(organization_id,order_id));

drop policy falcon_select on public.order_discount_allocations;
create policy order_discount_allocations_select_scoped on public.order_discount_allocations for select to authenticated
using(private.can_read_order_row(organization_id,order_id));

drop policy falcon_select on public.order_problems;
create policy order_problems_select_scoped on public.order_problems for select to authenticated
using(private.can_read_order_row(organization_id,order_id));

drop policy falcon_select on public.order_problem_costs;
create policy order_problem_costs_select_scoped on public.order_problem_costs for select to authenticated
using(private.can_read_order_row(organization_id,order_id));
