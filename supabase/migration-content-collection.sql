-- ============================================================
-- Migration: product weight, Collection Book, editable About page,
-- studio journal posts. Run once in Supabase → SQL Editor.
-- ============================================================

-- ---------- product weight ----------
-- Same pattern as materials/dimensions: one translation per language.
alter table public.products
  add column if not exists weight jsonb;

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

create policy "Collection items are readable by everyone"
  on public.collection_items for select
  using (true);

create policy "Collection items are writable by admins only"
  on public.collection_items for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ---------- Editable About page content ----------
-- One row per named field (e.g. "authorTitle", "philosophyBody1"). The
-- admin panel's About tab edits these directly; the public /about page
-- reads them, falling back to the built-in English copy if a key is
-- missing (so the page never looks broken while it's being filled in).
create table if not exists public.about_content (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.about_content enable row level security;

create policy "About content is readable by everyone"
  on public.about_content for select
  using (true);

create policy "About content is writable by admins only"
  on public.about_content for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ---------- Studio journal posts (client's growing "biography") ----------
create table if not exists public.about_posts (
  id uuid primary key default gen_random_uuid(),
  title jsonb not null default '{}'::jsonb,
  body jsonb not null default '{}'::jsonb,
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.about_posts enable row level security;

create policy "Posts are readable by everyone"
  on public.about_posts for select
  using (true);

create policy "Posts are writable by admins only"
  on public.about_posts for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ---------- realtime sync for live availability updates ----------
-- Lets the product page pick up an admin's availability change instantly,
-- without the customer needing to refresh. Safe to run even if it's
-- already enabled.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'products'
  ) then
    alter publication supabase_realtime add table public.products;
  end if;
end $$;
