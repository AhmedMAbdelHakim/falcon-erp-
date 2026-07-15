-- Schema for Falcon Shipping Label System

-- 1. EXTENSIONS
create extension if not exists "uuid-ossp";

-- 2. TABLES

-- Profiles Table (Staff / Admin roles)
create table if not exists public.profiles (
    id uuid primary key references auth.users on delete cascade,
    full_name text,
    role text not null default 'staff' check (role in ('admin', 'staff')),
    created_at timestamp with time zone default now()
);

-- Governorate Shipping Fees Table
create table if not exists public.governorate_shipping_fees (
    id uuid primary key default gen_random_uuid(),
    governorate text unique not null,
    shipping_fee numeric not null default 0,
    created_at timestamp with time zone default now()
);

-- Settings Table (Key-value store for app configuration)
create table if not exists public.shipping_settings (
    id uuid primary key default gen_random_uuid(),
    key text unique not null,
    value jsonb not null,
    updated_at timestamp with time zone default now()
);

-- Labels Table (Waybills)
create table if not exists public.labels (
    id uuid primary key default gen_random_uuid(),
    tracking_number text unique not null,
    customer_name text not null,
    primary_phone text not null,
    secondary_phone text,
    governorate text not null,
    city text not null,
    address text not null,
    landmark text,
    product_name text,
    contents text not null,
    pieces integer not null default 1,
    weight numeric not null default 1.0,
    cod_amount numeric not null default 0,
    shipping_fee numeric not null default 0,
    payment_method text not null default 'COD' check (payment_method in ('COD', 'Paid', 'Partial Deposit')),
    instructions text,
    internal_notes text,
    shipper_id text not null default '6525',
    store_name text not null default 'Falcon store',
    product_type text not null default 'COD',
    status text not null default 'Ready' check (status in ('Draft', 'Ready', 'Printed', 'Cancelled')),
    is_printed boolean not null default false,
    printed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancellation_reason text,
    created_by uuid references auth.users,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone default now()
);

-- 3. INDEXES FOR OPTIMIZATION
create index if not exists idx_labels_tracking_number on public.labels(tracking_number);
create index if not exists idx_labels_primary_phone on public.labels(primary_phone);
create index if not exists idx_labels_governorate on public.labels(governorate);
create index if not exists idx_labels_status on public.labels(status);
create index if not exists idx_labels_created_at on public.labels(created_at desc);

-- 4. TIMESTAMP UPDATE TRIGGER
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger set_updated_at_labels
    before update on public.labels
    for each row execute function public.handle_updated_at();

create trigger set_updated_at_shipping_settings
    before update on public.shipping_settings
    for each row execute function public.handle_updated_at();

-- 5. AUTOMATIC PROFILE CREATION TRIGGER
-- When a user signs up, automatically create a profile record
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, full_name, role)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', 'موظف فلكون'),
        coalesce(new.raw_user_meta_data->>'role', 'staff')
    );
    return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- 5b. PREVENT NON-ADMINS FROM UPDATING ROLES
create or replace function public.check_profile_update()
returns trigger as $$
begin
    if old.role is distinct from new.role then
        if (select role from public.profiles where id = auth.uid()) != 'admin' then
            raise exception 'Only administrators can change roles.';
        end if;
    end if;
    return new;
end;
$$ language plpgsql security definer;

create trigger tr_check_profile_update
    before update on public.profiles
    for each row execute function public.check_profile_update();


-- 6. ROW LEVEL SECURITY (RLS)
alter table public.profiles enable row level security;
alter table public.labels enable row level security;
alter table public.shipping_settings enable row level security;
alter table public.governorate_shipping_fees enable row level security;

-- Role Helper Function
create or replace function public.get_my_role()
returns text as $$
declare
    user_role text;
begin
    select role into user_role from public.profiles where id = auth.uid();
    return coalesce(user_role, 'staff');
end;
$$ language plpgsql security definer;

-- Profiles Policies
create policy "Users can view all profiles"
    on public.profiles for select
    to authenticated
    using (true);

create policy "Users can update their own profile"
    on public.profiles for update
    to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);

create policy "Admins have full access to profiles"
    on public.profiles for all
    to authenticated
    using (public.get_my_role() = 'admin');

-- Governorate Shipping Fees Policies
create policy "Authenticated users can view fees"
    on public.governorate_shipping_fees for select
    to authenticated
    using (true);

create policy "Admins can manage fees"
    on public.governorate_shipping_fees for all
    to authenticated
    using (public.get_my_role() = 'admin');

-- Settings Policies
create policy "Authenticated users can view shipping_settings"
    on public.shipping_settings for select
    to authenticated
    using (true);

create policy "Admins can manage shipping_settings"
    on public.shipping_settings for all
    to authenticated
    using (public.get_my_role() = 'admin');

-- Labels Policies
create policy "Authenticated users can view all labels"
    on public.labels for select
    to authenticated
    using (true);

create policy "Authenticated users can insert labels"
    on public.labels for insert
    to authenticated
    with check (auth.uid() = created_by);

create policy "Authenticated users can update labels"
    on public.labels for update
    to authenticated
    using (true)
    with check (
        -- Staff can update label, but cannot set status to Cancelled without a cancellation reason
        (public.get_my_role() = 'admin') or 
        (status != 'Cancelled' or (cancellation_reason is not null and length(trim(cancellation_reason)) > 0))
    );

create policy "Only admins can delete labels"
    on public.labels for delete
    to authenticated
    using (public.get_my_role() = 'admin');

-- 7. SEED DATA (Default Egyptian governorates and settings)
insert into public.governorate_shipping_fees (governorate, shipping_fee) values
('القاهرة', 45),
('الجيزة', 45),
('الإسكندرية', 50),
('القليوبية', 50),
('المنوفية', 55),
('الغربية', 55),
('الدقهلية', 55),
('الشرقية', 55),
('دمياط', 60),
('البحيرة', 60),
('كفر الشيخ', 60),
('الفيوم', 65),
('بني سويف', 65),
('المنيا', 70),
('أسيوط', 70),
('سوهاج', 75),
('قنا', 80),
('الأقصر', 85),
('أسوان', 90),
('البحر الأحمر', 100),
('الوادي الجديد', 100),
('مطروح', 100),
('شمال سيناء', 100),
('جنوب سيناء', 100),
('بورسعيد', 60),
('الإسماعيلية', 60),
('السويس', 60)
on conflict (governorate) do update set shipping_fee = excluded.shipping_fee;

insert into public.shipping_settings (key, value) values
('store_config', '{
  "store_name": "Falcon store",
  "shipper_id": "6525",
  "default_product_type": "COD",
  "default_weight": 1.0,
  "default_pieces": 1,
  "default_layout": "3",
  "business_phone": "01000000000",
  "barcode_prefix": "FLC",
  "footer_note": "شكراً لاختياركم فلكون"
}'::jsonb)
on conflict (key) do nothing;
