-- 202607250002_add_asset_columns_to_user_customizations.sql
-- Add asset_id and path columns to user_customizations table for tracking equipped cosmetic details

alter table public.user_customizations 
  add column if not exists asset_id uuid,
  add column if not exists path text;
