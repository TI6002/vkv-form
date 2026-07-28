-- ============================================================
-- vkv.form — full, current database schema
-- ------------------------------------------------------------
-- This is everything the site needs, combined into one file and written
-- so it's safe to run in one go even if some of it already exists
-- (every CREATE TABLE / ADD COLUMN / POLICY is written to skip quietly
-- instead of erroring if it's already there).
--
-- Run in Supabase → SQL Editor → New query → paste this whole file → Run.
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

drop policy if exists "Profiles are readable by their owner" on public.profiles;
create policy "Profiles are readable by their owner"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "Profiles are editable by their owner" on public.profiles;
create policy "Profiles are editable by their owner"
  on public.profiles for update
  using (auth.uid() = id);

-- Auto-create a profile row whenever someone signs up.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- products ----------
-- name/description/materials/height/circumference/depth/weight are jsonb,
-- one translation per language, e.g. {"en": "Vase", "ru": "Ваза"}. Filled
-- in automatically by /admin's translate-on-save.
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name jsonb not null default '{}'::jsonb,
  price_cents integer not null check (price_cents >= 0),
  currency text not null default 'EUR',
  description jsonb not null default '{}'::jsonb,
  materials jsonb,
  stock integer not null default 0,
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

-- Physical measurements — each its own field (added after the first
-- version, which only had a single combined "dimensions" field).
alter table public.products add column if not exists height jsonb;
alter table public.products add column if not exists circumference jsonb;
alter table public.products add column if not exists depth jsonb;
alter table public.products add column if not exists weight jsonb;

-- On/off availability switch, independent of stock count.
alter table public.products add column if not exists available boolean not null default true;

alter table public.products enable row level security;

drop policy if exists "Products are readable by everyone" on public.products;
create policy "Products are readable by everyone"
  on public.products for select
  using (true);

drop policy if exists "Products are writable by admins only" on public.products;
create policy "Products are writable by admins only"
  on public.products for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

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

-- Human-friendly sequential order number ("Order #1042").
alter table public.orders add column if not exists order_number bigserial;

-- What was actually bought + who it's going to — filled in by the Stripe
-- webhook once payment completes.
alter table public.orders add column if not exists items jsonb not null default '[]'::jsonb;
alter table public.orders add column if not exists customer_details jsonb;

alter table public.orders enable row level security;

drop policy if exists "Users can read their own orders" on public.orders;
create policy "Users can read their own orders"
  on public.orders for select
  using (auth.uid() = user_id);

drop policy if exists "Admins can read all orders" on public.orders;
create policy "Admins can read all orders"
  on public.orders for select
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

drop policy if exists "Admins can update orders" on public.orders;
create policy "Admins can update orders"
  on public.orders for update
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

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

drop policy if exists "Admins can read contact messages" on public.contact_messages;
create policy "Admins can read contact messages"
  on public.contact_messages for select
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ---------- newsletter_subscribers ----------
create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  created_at timestamptz not null default now()
);

alter table public.newsletter_subscribers enable row level security;

drop policy if exists "Anyone can subscribe" on public.newsletter_subscribers;
create policy "Anyone can subscribe"
  on public.newsletter_subscribers for insert
  with check (true);

drop policy if exists "Admins can read subscribers" on public.newsletter_subscribers;
create policy "Admins can read subscribers"
  on public.newsletter_subscribers for select
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ---------- favorites ("like / save" button) ----------
create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

alter table public.favorites enable row level security;

drop policy if exists "Users can read their own favorites" on public.favorites;
create policy "Users can read their own favorites"
  on public.favorites for select
  using (auth.uid() = user_id);

drop policy if exists "Users can add their own favorites" on public.favorites;
create policy "Users can add their own favorites"
  on public.favorites for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can remove their own favorites" on public.favorites;
create policy "Users can remove their own favorites"
  on public.favorites for delete
  using (auth.uid() = user_id);

-- ---------- Collection Book (archive of sold/past pieces) ----------
create table if not exists public.collection_items (
  id uuid primary key default gen_random_uuid(),
  name jsonb not null default '{}'::jsonb,
  description jsonb not null default '{}'::jsonb,
  images text[] not null default '{}',
  sold_year text,
  created_at timestamptz not null default now()
);

alter table public.collection_items enable row level security;

drop policy if exists "Collection items are readable by everyone" on public.collection_items;
create policy "Collection items are readable by everyone"
  on public.collection_items for select
  using (true);

drop policy if exists "Collection items are writable by admins only" on public.collection_items;
create policy "Collection items are writable by admins only"
  on public.collection_items for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ---------- editable About page content ----------
create table if not exists public.about_content (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.about_content enable row level security;

drop policy if exists "About content is readable by everyone" on public.about_content;
create policy "About content is readable by everyone"
  on public.about_content for select
  using (true);

drop policy if exists "About content is writable by admins only" on public.about_content;
create policy "About content is writable by admins only"
  on public.about_content for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ---------- studio journal posts ----------
create table if not exists public.about_posts (
  id uuid primary key default gen_random_uuid(),
  title jsonb not null default '{}'::jsonb,
  body jsonb not null default '{}'::jsonb,
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.about_posts enable row level security;

drop policy if exists "Posts are readable by everyone" on public.about_posts;
create policy "Posts are readable by everyone"
  on public.about_posts for select
  using (true);

drop policy if exists "Posts are writable by admins only" on public.about_posts;
create policy "Posts are writable by admins only"
  on public.about_posts for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ---------- realtime sync for live availability updates ----------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'products'
  ) then
    alter publication supabase_realtime add table public.products;
  end if;
end $$;

-- ============================================================
-- Storage: bucket for product/post/collection photos, uploaded from /admin.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

drop policy if exists "Product images are publicly readable" on storage.objects;
create policy "Product images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'product-images');

drop policy if exists "Admins can upload product images" on storage.objects;
create policy "Admins can upload product images"
  on storage.objects for insert
  with check (
    bucket_id = 'product-images'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

drop policy if exists "Admins can delete product images" on storage.objects;
create policy "Admins can delete product images"
  on storage.objects for delete
  using (
    bucket_id = 'product-images'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ============================================================
-- One-time step NOT included above (only needed once, long done for you):
-- converting products.name/description/materials from plain text to
-- jsonb. If you ever start a brand-new project from scratch instead of
-- this one, see supabase/migration-i18n-products.sql for that step.
-- ============================================================
