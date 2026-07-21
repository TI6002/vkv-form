-- ============================================================
-- Migration: make products multi-language (run this ONCE)
-- ------------------------------------------------------------
-- You already ran the original supabase/schema.sql, which created
-- products.name/description/materials/dimensions as plain text. This
-- migration converts them to jsonb (one translation per language) without
-- losing any existing products — old text is kept as the "en" entry, and
-- the admin dashboard will fill in the rest next time you edit and save
-- that object.
--
-- Run this in Supabase → SQL Editor → New query → Run, once.
-- ============================================================

alter table public.products
  alter column name type jsonb using jsonb_build_object('en', name),
  alter column description type jsonb using jsonb_build_object('en', description),
  alter column materials type jsonb using (
    case when materials is null then null else jsonb_build_object('en', materials) end
  ),
  alter column dimensions type jsonb using (
    case when dimensions is null then null else jsonb_build_object('en', dimensions) end
  );

alter table public.products alter column name set default '{}'::jsonb;
alter table public.products alter column description set default '{}'::jsonb;

-- Done. Existing products now show their old text under English and
-- fall back to it in every other language until you re-save them from
-- /admin (which will translate them into all seven languages at once).
