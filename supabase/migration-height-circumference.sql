-- ============================================================
-- Migration: split "dimensions" into separate Height / Circumference
-- fields (Weight already exists from an earlier migration).
-- Run once in Supabase → SQL Editor.
-- ============================================================

alter table public.products
  add column if not exists height jsonb,
  add column if not exists circumference jsonb;

-- The old "dimensions" column is left in place (harmless, just unused
-- going forward) so nothing is destroyed — feel free to drop it later
-- with: alter table public.products drop column if exists dimensions;
