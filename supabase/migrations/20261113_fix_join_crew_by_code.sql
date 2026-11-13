-- Fix PL/pgSQL output parameter ambiguity in ON CONFLICT target.
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
  values (v_id, auth.uid(), 'member') on conflict do nothing;
  return query select v_id, v_name, v_code;
end;
$$;
