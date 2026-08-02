-- 202607200002_avatar_frames_novel_1_only.sql
-- Registers the avatar_frames table and sets Novel Level 1 as the
-- ONLY available frame. All other frames are marked isAvailable = false.
-- To restore later, UPDATE avatar_frames SET is_available = true WHERE id = '...';

-- ══════════════════════════════════════════════════════════════
-- 1. Create avatar_frames catalog table (if not exists)
-- ══════════════════════════════════════════════════════════════
create table if not exists public.avatar_frames (
  id            text        primary key,
  name          text        not null unique,
  type          text        not null default 'novel',   -- 'novel' | 'vip' | 'event' | 'free'
  level         int         not null default 1,
  asset_path    text        not null default '',
  rarity        text        not null default 'Common',
  is_available  boolean     not null default false,
  is_default    boolean     not null default false,
  created_at    timestamptz not null default now()
);

-- Enable RLS
alter table public.avatar_frames enable row level security;

-- Create policies (safe — skips if already exists)
do $$ begin
  create policy "Read available frames"
    on public.avatar_frames for select
    using (is_available = true);
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "Admin manage frames"
    on public.avatar_frames for all
    using (auth.role() = 'service_role');
exception when duplicate_object then null;
end $$;

-- ══════════════════════════════════════════════════════════════
-- 2. Seed all frames — only Novel Level 1 is available
-- ══════════════════════════════════════════════════════════════
insert into public.avatar_frames (id, name, type, level, asset_path, rarity, is_available, is_default)
values
  -- ✅ ACTIVE
  ('novel_1',   'Novel Level 1',           'novel', 1, 'assets/avtarframes/novel/novel_1.png',  'Rare',      true,  false),

  -- ── DISABLED (restore by setting is_available = true) ──
  -- VIP Frames
  ('vip_1',     'Royal Frame',             'vip',   1, '',  'Rare',      false, false),
  ('vip_2',     'Neon Frame',              'vip',   2, '',  'Epic',      false, false),
  ('vip_3',     'Gold Glow Frame',         'vip',   3, '',  'Epic',      false, false),
  ('vip_4',     'Diamond Frame',           'vip',   4, '',  'Legendary', false, false),
  ('vip_5',     'Crystal Cyan Frame',      'vip',   5, '',  'Legendary', false, false),
  ('vip_6',     'Rainbow Frame',           'vip',   6, '',  'Mythic',    false, false),
  ('vip_7',     'Royal Crown',             'vip',   7, '',  'Mythic',    false, false),
  -- Novel Frames (2-7)
  ('novel_2',   'Galaxy Orbit',            'novel', 2, '',  'Mythic',    false, false),
  ('novel_3',   'Royal Gold Palace',       'novel', 3, '',  'Legendary', false, false),
  ('novel_4',   'Dragon Fire Frame',       'novel', 4, '',  'Limited',   false, false),
  ('novel_5',   'Phoenix Flame',           'novel', 5, '',  'Mythic',    false, false),
  ('novel_6',   'Celestial Sky Frame',     'novel', 6, '',  'Mythic',    false, false),
  ('novel_7',   'Cosmic Emperor',          'novel', 7, '',  'Mythic',    false, false),
  -- Free/Event
  ('free_none', 'Normal',                  'free',  0, '',  'Common',    true,  true ),
  ('free_explorer', 'Early Explorer Frame','free',  0, '',  'Rare',      false, false)
on conflict (id) do update set
  name         = excluded.name,
  is_available = excluded.is_available,
  asset_path   = excluded.asset_path,
  rarity       = excluded.rarity;

-- ══════════════════════════════════════════════════════════════
-- 3. Safety: disable any user_customizations that reference
--    frames that are no longer available (except Normal/Novel Level 1)
-- ══════════════════════════════════════════════════════════════
update public.user_customizations
set is_equipped = false
where type = 'Avatar Frame'
  and name not in ('Normal', 'Novel Level 1');
