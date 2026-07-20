-- ============================================================
-- vkv.form — Supabase schema
-- Run this once in the Supabase SQL editor (Project → SQL Editor → New query).
-- Free tier is plenty for this: 500MB database, 1GB file storage,
-- 50k monthly active users on Auth. See README.md for setup order.
-- ============================================================

-- ---------- profiles ----------
-- One row per auth user. role='admin' unlocks /admin.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  role text not null default 'customer' check (role in ('customer', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are readable by their owner"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Profiles are editable by their owner"
  on public.profiles for update
  using (auth.uid() = id);

-- Auto-create a profile row whenever someone signs up.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- products ----------
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  price_cents integer not null check (price_cents >= 0),
  currency text not null default 'EUR',
  description text not null default '',
  materials text,
  dimensions text,
  stock integer not null default 0,
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.products enable row level security;

create policy "Products are readable by everyone"
  on public.products for select
  using (true);

create policy "Products are writable by admins only"
  on public.products for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  )
  with check (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ---------- orders ----------
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  email text not null,
  status text not null default 'pending' check (status in ('pending', 'paid', 'shipped', 'cancelled')),
  total_cents integer not null default 0,
  currency text not null default 'EUR',
  stripe_session_id text,
  created_at timestamptz not null default now()
);

alter table public.orders enable row level security;

create policy "Users can read their own orders"
  on public.orders for select
  using (auth.uid() = user_id);

create policy "Admins can read all orders"
  on public.orders for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- Orders are written by the Stripe webhook using the service-role key,
-- which bypasses RLS entirely — no insert policy needed for anon/auth roles.

-- ---------- contact_messages ----------
create table if not exists public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  message text not null,
  created_at timestamptz not null default now()
);

alter table public.contact_messages enable row level security;

create policy "Admins can read contact messages"
  on public.contact_messages for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- Inserted via the service-role key from app/api/contact/route.ts.

-- ---------- newsletter_subscribers ----------
create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  created_at timestamptz not null default now()
);

alter table public.newsletter_subscribers enable row level security;

create policy "Anyone can subscribe"
  on public.newsletter_subscribers for insert
  with check (true);

create policy "Admins can read subscribers"
  on public.newsletter_subscribers for select
  using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- Storage: bucket for product photos, uploaded from /admin.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

create policy "Product images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'product-images');

create policy "Admins can upload product images"
  on storage.objects for insert
  with check (
    bucket_id = 'product-images'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

create policy "Admins can delete product images"
  on storage.objects for delete
  using (
    bucket_id = 'product-images'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- After running this file:
-- 1. Sign up once through /account on your running site.
-- 2. In Table Editor → profiles, find your row and change role to 'admin'.
-- 3. Reload /admin — you can now add products and upload images.
-- ============================================================
