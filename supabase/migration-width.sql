-- Adds a Width field alongside Height/Circumference/Depth/Weight.
-- Run once in Supabase → SQL Editor.
alter table public.products
  add column if not exists width jsonb;
