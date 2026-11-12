-- FORGE / CREW: shared gym tracker schema for Supabase.
-- Apply this once in Supabase SQL Editor. The browser must only use the anon/publishable key.

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Athlete',
  training_experience text not null default 'Just starting',
  training_start_date date,
  calorie_goal integer not null default 2200 check (calorie_goal between 500 and 10000),
  protein_goal_g integer not null default 150 check (protein_goal_g between 10 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crews (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.crew_members (
  crew_id uuid not null references public.crews(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (crew_id, user_id)
);
create index if not exists crew_members_user_idx on public.crew_members(user_id, joined_at desc);

create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  crew_id uuid not null references public.crews(id) on delete cascade,
  activity_date date not null default current_date,
  split text,
  checkin_at timestamptz,
  checkout_at timestamptz,
  status text not null default 'in_progress' check (status in ('in_progress', 'completed', 'skipped')),
  note text,
  created_at timestamptz not null default now()
);
create index if not exists workout_sessions_crew_date_idx on public.workout_sessions(crew_id, activity_date desc);
create index if not exists workout_sessions_user_date_idx on public.workout_sessions(user_id, activity_date desc);

create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  name text not null,
  equipment text not null default 'Other',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists workout_exercises_session_idx on public.workout_exercises(session_id, sort_order);

create table if not exists public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.workout_exercises(id) on delete cascade,
  set_number integer not null check (set_number between 1 and 50),
  weight_kg numeric(7,2) not null default 0 check (weight_kg between 0 and 2000),
  reps integer not null check (reps between 0 and 1000),
  created_at timestamptz not null default now(),
  unique (exercise_id, set_number)
);
create index if not exists workout_sets_exercise_idx on public.workout_sets(exercise_id, set_number);

create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_date date not null default current_date,
  meal_type text not null default 'Snack' check (meal_type in ('Breakfast', 'Lunch', 'Dinner', 'Snack', 'Post-workout')),
  food_name text not null,
  quantity numeric(9,2) not null check (quantity > 0),
  unit text not null default 'g',
  calories integer not null check (calories between 0 and 20000),
  protein_g numeric(8,2) not null check (protein_g between 0 and 1000),
  estimate_source text not null default 'manual',
  created_at timestamptz not null default now()
);
create index if not exists meals_user_date_idx on public.meals(user_id, meal_date desc);

create or replace function public.handle_new_forge_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (user_id, display_name, training_experience, training_start_date)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(new.email, '@', 1), 'Athlete'),
    coalesce(nullif(new.raw_user_meta_data ->> 'training_experience', ''), 'Just starting'),
    nullif(new.raw_user_meta_data ->> 'training_start_date', '')::date
  ) on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_forge_auth_user_created on auth.users;
create trigger on_forge_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_forge_user();

create or replace function public.is_crew_member(p_crew_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.crew_members cm
    where cm.crew_id = p_crew_id and cm.user_id = auth.uid()
  );
$$;

create or replace function public.create_crew(p_name text default 'Iron Circle')
returns table (crew_id uuid, crew_name text, invite_code text)
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_name text; v_code text;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  v_name := coalesce(nullif(trim(p_name), ''), 'Iron Circle');
  insert into public.crews (name, owner_id) values (v_name, auth.uid())
  returning id, name, crews.invite_code into v_id, v_name, v_code;
  insert into public.crew_members (crew_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return query select v_id, v_name, v_code;
end;
$$;

create or replace function public.join_crew_by_code(p_code text)
returns table (crew_id uuid, crew_name text, invite_code text)
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_name text; v_code text;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  select c.id, c.name, c.invite_code into v_id, v_name, v_code
  from public.crews c where upper(c.invite_code) = upper(trim(p_code)) limit 1;
  if v_id is null then raise exception 'That invite code was not found'; end if;
  insert into public.crew_members (crew_id, user_id, role)
  values (v_id, auth.uid(), 'member') on conflict (crew_id, user_id) do nothing;
  return query select v_id, v_name, v_code;
end;
$$;

create or replace function public.get_my_crews()
returns table (crew_id uuid, crew_name text, invite_code text, role text, joined_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select c.id, c.name, c.invite_code, cm.role, cm.joined_at
  from public.crew_members cm join public.crews c on c.id = cm.crew_id
  where cm.user_id = auth.uid()
  order by cm.joined_at desc;
$$;

create or replace function public.get_crew_roster(p_crew_id uuid)
returns table (user_id uuid, display_name text, joined_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select cm.user_id, p.display_name, cm.joined_at
  from public.crew_members cm join public.profiles p on p.user_id = cm.user_id
  where cm.crew_id = p_crew_id and public.is_crew_member(p_crew_id)
  order by cm.joined_at;
$$;

alter table public.profiles enable row level security;
alter table public.crews enable row level security;
alter table public.crew_members enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_sets enable row level security;
alter table public.meals enable row level security;

revoke all on public.profiles, public.crews, public.crew_members, public.workout_sessions,
  public.workout_exercises, public.workout_sets, public.meals from anon, authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select on public.crews, public.crew_members to authenticated;
grant select, insert, update, delete on public.workout_sessions,
  public.workout_exercises, public.workout_sets to authenticated;
grant select, insert, update, delete on public.meals to authenticated;

create policy "Profile owner can read" on public.profiles for select to authenticated using (user_id = (select auth.uid()));
create policy "Profile owner can create" on public.profiles for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Profile owner can update" on public.profiles for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Crew members can read their crews" on public.crews for select to authenticated using (public.is_crew_member(id));
create policy "Users can read their memberships" on public.crew_members for select to authenticated using (user_id = (select auth.uid()));

create policy "Crew members can read shared workout sessions" on public.workout_sessions for select to authenticated using (public.is_crew_member(crew_id));
create policy "Users can create own workout sessions" on public.workout_sessions for insert to authenticated with check (user_id = (select auth.uid()) and public.is_crew_member(crew_id));
create policy "Users can update own workout sessions" on public.workout_sessions for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and public.is_crew_member(crew_id));
create policy "Users can delete own workout sessions" on public.workout_sessions for delete to authenticated using (user_id = (select auth.uid()));

create policy "Crew can read exercises" on public.workout_exercises for select to authenticated using (
  exists (select 1 from public.workout_sessions s where s.id = session_id and public.is_crew_member(s.crew_id))
);
create policy "Owner can add exercises" on public.workout_exercises for insert to authenticated with check (
  exists (select 1 from public.workout_sessions s where s.id = session_id and s.user_id = (select auth.uid()))
);
create policy "Owner can update exercises" on public.workout_exercises for update to authenticated using (
  exists (select 1 from public.workout_sessions s where s.id = session_id and s.user_id = (select auth.uid()))
) with check (
  exists (select 1 from public.workout_sessions s where s.id = session_id and s.user_id = (select auth.uid()))
);
create policy "Owner can delete exercises" on public.workout_exercises for delete to authenticated using (
  exists (select 1 from public.workout_sessions s where s.id = session_id and s.user_id = (select auth.uid()))
);

create policy "Crew can read sets" on public.workout_sets for select to authenticated using (
  exists (select 1 from public.workout_exercises e join public.workout_sessions s on s.id = e.session_id
    where e.id = exercise_id and public.is_crew_member(s.crew_id))
);
create policy "Owner can add sets" on public.workout_sets for insert to authenticated with check (
  exists (select 1 from public.workout_exercises e join public.workout_sessions s on s.id = e.session_id
    where e.id = exercise_id and s.user_id = (select auth.uid()))
);
create policy "Owner can update sets" on public.workout_sets for update to authenticated using (
  exists (select 1 from public.workout_exercises e join public.workout_sessions s on s.id = e.session_id
    where e.id = exercise_id and s.user_id = (select auth.uid()))
) with check (
  exists (select 1 from public.workout_exercises e join public.workout_sessions s on s.id = e.session_id
    where e.id = exercise_id and s.user_id = (select auth.uid()))
);
create policy "Owner can delete sets" on public.workout_sets for delete to authenticated using (
  exists (select 1 from public.workout_exercises e join public.workout_sessions s on s.id = e.session_id
    where e.id = exercise_id and s.user_id = (select auth.uid()))
);

create policy "Meal owner can read" on public.meals for select to authenticated using (user_id = (select auth.uid()));
create policy "Meal owner can create" on public.meals for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Meal owner can update" on public.meals for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Meal owner can delete" on public.meals for delete to authenticated using (user_id = (select auth.uid()));

revoke execute on function public.is_crew_member(uuid) from public, anon;
revoke execute on function public.create_crew(text) from public, anon;
revoke execute on function public.join_crew_by_code(text) from public, anon;
revoke execute on function public.get_my_crews() from public, anon;
revoke execute on function public.get_crew_roster(uuid) from public, anon;
grant execute on function public.is_crew_member(uuid) to authenticated;
grant execute on function public.create_crew(text) to authenticated;
grant execute on function public.join_crew_by_code(text) to authenticated;
grant execute on function public.get_my_crews() to authenticated;
grant execute on function public.get_crew_roster(uuid) to authenticated;
