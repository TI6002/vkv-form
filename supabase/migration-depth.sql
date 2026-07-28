-- Adds a Depth field alongside Height/Circumference/Weight.
-- Run once in Supabase → SQL Editor.
alter table public.products
  add column if not exists depth jsonb;
