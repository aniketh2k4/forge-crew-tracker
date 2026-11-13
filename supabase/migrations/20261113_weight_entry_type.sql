-- Mark optional weekly readings separately so they can smooth charts without
-- replacing the required monthly check-in or changing nutrition targets.
alter table public.weight_entries
  add column if not exists entry_type text not null default 'monthly'
  check (entry_type in ('monthly','weekly'));
