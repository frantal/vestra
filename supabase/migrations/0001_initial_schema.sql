-- =============================================================================
-- VESTRA — Initial database schema
-- Target: Supabase (PostgreSQL)
--
-- Conventions:
--   * UUID primary keys (gen_random_uuid()).
--   * Audit fields: created_at, updated_at (auto), deleted_at (soft delete).
--   * Row Level Security (RLS) enabled on every table; users only ever see
--     and mutate their own rows.
-- =============================================================================

-- Required extension for gen_random_uuid().
create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- Utility: keep updated_at fresh on every UPDATE.
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =============================================================================
-- profiles — 1:1 with auth.users
-- =============================================================================
create table if not exists public.profiles (
  id                     uuid primary key references auth.users (id) on delete cascade,
  full_name              text,
  avatar_url             text,
  country                text,
  language               text        not null default 'pt',
  theme                  text        not null default 'dark',
  gender                 text,
  birth_date             date,
  height_cm              integer,
  weight_kg              numeric(5, 2),
  profession             text,
  style_preferences      text[]      not null default '{}',
  favorite_colors        text[]      not null default '{}',
  approx_wardrobe_size   integer,
  onboarding_completed   boolean     not null default false,
  is_premium             boolean     not null default false,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Create a profile row automatically whenever an auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =============================================================================
-- categories
-- =============================================================================
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  name        text        not null,
  icon        text,
  sort_order  integer     not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create index if not exists idx_categories_user on public.categories (user_id);
create unique index if not exists uq_categories_user_name
  on public.categories (user_id, lower(name))
  where deleted_at is null;

create trigger trg_categories_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

-- =============================================================================
-- clothing_items
-- =============================================================================
create table if not exists public.clothing_items (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid        not null references auth.users (id) on delete cascade,
  category_id    uuid        references public.categories (id) on delete set null,
  name           text        not null,
  brand          text,
  color          text,
  colors         text[]      not null default '{}',
  size           text,
  fabric         text,
  seasons        text[]      not null default '{}',
  occasions      text[]      not null default '{}',
  condition      text        not null default 'boa',
  image_url      text,
  image_path     text,
  notes          text,
  purchase_price numeric(10, 2),
  is_favorite    boolean     not null default false,
  times_worn     integer     not null default 0,
  last_worn_at   timestamptz,
  last_washed_at timestamptz,
  last_ironed_at timestamptz,
  needs_wash     boolean     not null default false,
  needs_iron     boolean     not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  constraint chk_condition check (condition in ('nova', 'boa', 'usada', 'velha'))
);

create index if not exists idx_clothing_user on public.clothing_items (user_id);
create index if not exists idx_clothing_category on public.clothing_items (category_id);
create index if not exists idx_clothing_user_favorite
  on public.clothing_items (user_id) where is_favorite = true;

create trigger trg_clothing_items_updated_at
  before update on public.clothing_items
  for each row execute function public.set_updated_at();

-- =============================================================================
-- tags + clothing_item_tags (many-to-many)
-- =============================================================================
create table if not exists public.tags (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid        not null references auth.users (id) on delete cascade,
  name       text        not null,
  created_at timestamptz not null default now()
);

create unique index if not exists uq_tags_user_name
  on public.tags (user_id, lower(name));

create table if not exists public.clothing_item_tags (
  clothing_item_id uuid not null references public.clothing_items (id) on delete cascade,
  tag_id           uuid not null references public.tags (id) on delete cascade,
  primary key (clothing_item_id, tag_id)
);

create index if not exists idx_cit_tag on public.clothing_item_tags (tag_id);

-- =============================================================================
-- outfits + outfit_items
-- =============================================================================
create table if not exists public.outfits (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  name        text        not null,
  occasion    text,
  score       integer,
  image_url   text,
  is_favorite boolean     not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  constraint chk_score check (score is null or (score between 0 and 100))
);

create index if not exists idx_outfits_user on public.outfits (user_id);

create trigger trg_outfits_updated_at
  before update on public.outfits
  for each row execute function public.set_updated_at();

create table if not exists public.outfit_items (
  outfit_id        uuid not null references public.outfits (id) on delete cascade,
  clothing_item_id uuid not null references public.clothing_items (id) on delete cascade,
  primary key (outfit_id, clothing_item_id)
);

create index if not exists idx_outfit_items_item on public.outfit_items (clothing_item_id);

-- =============================================================================
-- usage_history
-- =============================================================================
create table if not exists public.usage_history (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid        not null references auth.users (id) on delete cascade,
  clothing_item_id uuid        not null references public.clothing_items (id) on delete cascade,
  outfit_id        uuid        references public.outfits (id) on delete set null,
  worn_on          date        not null default current_date,
  created_at       timestamptz not null default now()
);

create index if not exists idx_usage_user on public.usage_history (user_id);
create index if not exists idx_usage_item on public.usage_history (clothing_item_id);
create index if not exists idx_usage_worn_on on public.usage_history (worn_on);

-- =============================================================================
-- wash_history (wash + iron events)
-- =============================================================================
create table if not exists public.wash_history (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid        not null references auth.users (id) on delete cascade,
  clothing_item_id uuid        not null references public.clothing_items (id) on delete cascade,
  type             text        not null default 'wash',
  washed_on        date        not null default current_date,
  created_at       timestamptz not null default now(),
  constraint chk_wash_type check (type in ('wash', 'iron'))
);

create index if not exists idx_wash_user on public.wash_history (user_id);
create index if not exists idx_wash_item on public.wash_history (clothing_item_id);

-- =============================================================================
-- Row Level Security
-- =============================================================================
alter table public.profiles            enable row level security;
alter table public.categories          enable row level security;
alter table public.clothing_items      enable row level security;
alter table public.tags                enable row level security;
alter table public.clothing_item_tags  enable row level security;
alter table public.outfits             enable row level security;
alter table public.outfit_items        enable row level security;
alter table public.usage_history       enable row level security;
alter table public.wash_history        enable row level security;

-- profiles: a user can only read/update their own profile row.
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

-- Helper macro (written out per-table): owner-only full access.
create policy "categories_all_own" on public.categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "clothing_all_own" on public.clothing_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "tags_all_own" on public.tags
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "outfits_all_own" on public.outfits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "usage_all_own" on public.usage_history
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "wash_all_own" on public.wash_history
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Join tables: access is derived from ownership of the parent clothing item.
create policy "cit_all_own" on public.clothing_item_tags
  for all using (
    exists (
      select 1 from public.clothing_items ci
      where ci.id = clothing_item_id and ci.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.clothing_items ci
      where ci.id = clothing_item_id and ci.user_id = auth.uid()
    )
  );

create policy "outfit_items_all_own" on public.outfit_items
  for all using (
    exists (
      select 1 from public.outfits o
      where o.id = outfit_id and o.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.outfits o
      where o.id = outfit_id and o.user_id = auth.uid()
    )
  );

-- =============================================================================
-- Storage: private bucket for wardrobe images, owner-scoped by path prefix
-- (paths are expected to start with the user's uid, e.g. "<uid>/<file>").
-- =============================================================================
insert into storage.buckets (id, name, public)
values ('wardrobe', 'wardrobe', false)
on conflict (id) do nothing;

create policy "wardrobe_read_own" on storage.objects
  for select using (
    bucket_id = 'wardrobe'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "wardrobe_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'wardrobe'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "wardrobe_update_own" on storage.objects
  for update using (
    bucket_id = 'wardrobe'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "wardrobe_delete_own" on storage.objects
  for delete using (
    bucket_id = 'wardrobe'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
