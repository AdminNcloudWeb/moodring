-- ===== Moodring — Supabase schema =====
-- Run this in your Supabase project: Dashboard → SQL Editor → New query → Run.
--
-- One row per user holding their entire app state as JSON (logs, boosters,
-- emojis, settings). Row Level Security ensures each user can only read/write
-- their own row.

create table if not exists public.moodring_state (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.moodring_state enable row level security;

-- A user may only see their own row.
drop policy if exists "own row select" on public.moodring_state;
create policy "own row select"
  on public.moodring_state for select
  using (auth.uid() = user_id);

-- A user may only insert a row for themselves.
drop policy if exists "own row insert" on public.moodring_state;
create policy "own row insert"
  on public.moodring_state for insert
  with check (auth.uid() = user_id);

-- A user may only update their own row.
drop policy if exists "own row update" on public.moodring_state;
create policy "own row update"
  on public.moodring_state for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
