-- Private monthly weigh-ins and body data used to estimate calorie/protein goals.
alter table public.profiles
  add column if not exists age smallint check (age between 18 and 80),
  add column if not exists sex_calc text not null default 'average' check (sex_calc in ('male','female','average')),
  add column if not exists height_cm numeric(5,1) check (height_cm between 100 and 250),
  add column if not exists activity_level text not null default 'moderate' check (activity_level in ('sedentary','light','moderate','active')),
  add column if not exists weight_goal text not null default 'maintain' check (weight_goal in ('lose','maintain','gain'));

create table if not exists public.weight_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  weight_kg numeric(6,2) not null check (weight_kg between 25 and 350),
  measured_on date not null default current_date,
  created_at timestamptz not null default now(),
  unique (user_id, measured_on)
);
create index if not exists weight_entries_user_date_idx on public.weight_entries(user_id, measured_on desc);

alter table public.weight_entries enable row level security;
revoke all on public.weight_entries from anon, authenticated;
grant select, insert, update, delete on public.weight_entries to authenticated;
drop policy if exists "Weight owner can read" on public.weight_entries;
drop policy if exists "Weight owner can create" on public.weight_entries;
drop policy if exists "Weight owner can update" on public.weight_entries;
drop policy if exists "Weight owner can delete" on public.weight_entries;
create policy "Weight owner can read" on public.weight_entries for select to authenticated using (user_id = (select auth.uid()));
create policy "Weight owner can create" on public.weight_entries for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Weight owner can update" on public.weight_entries for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Weight owner can delete" on public.weight_entries for delete to authenticated using (user_id = (select auth.uid()));
