create table public.espn_team_mapping_changes (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete restrict,
  season_id uuid not null,
  mappings jsonb not null check (
    jsonb_typeof(mappings) = 'array'
    and jsonb_array_length(mappings) > 0
  ),
  changed_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  foreign key (season_id, league_id)
    references public.seasons (id, league_id) on delete restrict
);

comment on table public.espn_team_mapping_changes is
  'Immutable commissioner audit batches for season-team ESPN identifier mappings.';

create index espn_team_mapping_changes_season_created_idx
  on public.espn_team_mapping_changes (season_id, created_at desc);

create or replace function private.prevent_espn_mapping_change_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'ESPN team mapping audit batches are immutable';
end;
$$;

create trigger prevent_espn_mapping_change_mutation
before update or delete on public.espn_team_mapping_changes
for each row execute function private.prevent_espn_mapping_change_mutation();

revoke all on function private.prevent_espn_mapping_change_mutation()
  from public, anon, authenticated;
grant execute on function private.prevent_espn_mapping_change_mutation()
  to service_role;

alter table public.espn_team_mapping_changes enable row level security;

revoke all on table public.espn_team_mapping_changes from public, anon, authenticated;
grant select on table public.espn_team_mapping_changes to authenticated;
grant insert (league_id, season_id, mappings)
  on table public.espn_team_mapping_changes to authenticated;
grant all on table public.espn_team_mapping_changes to service_role;

create policy espn_team_mapping_changes_select_commissioner
on public.espn_team_mapping_changes
for select
to authenticated
using (private.is_league_commissioner(league_id));

create policy espn_team_mapping_changes_insert_commissioner
on public.espn_team_mapping_changes
for insert
to authenticated
with check (private.is_league_commissioner(league_id));

create or replace function public.set_espn_season_team_mappings(
  target_season_id uuid,
  target_mappings jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_league_id uuid;
  expected_team_count integer;
  input_count integer;
  matched_team_count integer;
  change_id uuid;
begin
  if jsonb_typeof(target_mappings) <> 'array'
     or jsonb_array_length(target_mappings) = 0 then
    raise exception using
      errcode = '22023',
      message = 'ESPN team mappings must be a non-empty array';
  end if;

  select season.league_id
  into target_league_id
  from public.seasons as season
  where season.id = target_season_id;

  if target_league_id is null then
    raise exception using
      errcode = '23503',
      message = 'ESPN mapping season was not found';
  end if;

  if not private.is_league_commissioner(target_league_id) then
    raise exception using
      errcode = '42501',
      message = 'only an active commissioner may change ESPN team mappings';
  end if;

  input_count := jsonb_array_length(target_mappings);

  select count(*)
  into expected_team_count
  from public.season_teams as season_team
  where season_team.season_id = target_season_id
    and season_team.league_id = target_league_id
    and season_team.status = 'active';

  if expected_team_count = 0 or input_count <> expected_team_count then
    raise exception using
      errcode = '22023',
      message = 'ESPN mappings must exactly cover every active season team';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(target_mappings) as mapping(
      season_team_id uuid,
      espn_team_id integer
    )
    where mapping.season_team_id is null
      or mapping.espn_team_id is null
      or mapping.espn_team_id <= 0
  ) or exists (
    select 1
    from jsonb_to_recordset(target_mappings) as mapping(
      season_team_id uuid,
      espn_team_id integer
    )
    group by mapping.season_team_id
    having count(*) > 1
  ) or exists (
    select 1
    from jsonb_to_recordset(target_mappings) as mapping(
      season_team_id uuid,
      espn_team_id integer
    )
    group by mapping.espn_team_id
    having count(*) > 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'ESPN mapping team identifiers must be positive and unique';
  end if;

  with mappings as (
    select *
    from jsonb_to_recordset(target_mappings) as mapping(
      season_team_id uuid,
      espn_team_id integer
    )
  )
  select count(*)
  into matched_team_count
  from mappings
  join public.season_teams as season_team
    on season_team.id = mappings.season_team_id
   and season_team.season_id = target_season_id
   and season_team.league_id = target_league_id
   and season_team.status = 'active';

  if matched_team_count <> input_count then
    raise exception using
      errcode = '22023',
      message = 'ESPN mappings must exactly cover every active season team';
  end if;

  update public.season_teams as season_team
  set espn_team_id = null
  where season_team.season_id = target_season_id
    and season_team.league_id = target_league_id
    and season_team.status = 'active';

  update public.season_teams as season_team
  set espn_team_id = mappings.espn_team_id
  from jsonb_to_recordset(target_mappings) as mappings(
    season_team_id uuid,
    espn_team_id integer
  )
  where season_team.id = mappings.season_team_id
    and season_team.season_id = target_season_id
    and season_team.league_id = target_league_id
    and season_team.status = 'active';

  insert into public.espn_team_mapping_changes (
    league_id,
    season_id,
    mappings
  ) values (
    target_league_id,
    target_season_id,
    target_mappings
  )
  returning id into change_id;

  return jsonb_build_object(
    'status', 'saved',
    'season_id', target_season_id,
    'mapped_count', input_count,
    'change_id', change_id
  );
end;
$$;

comment on function public.set_espn_season_team_mappings(uuid, jsonb) is
  'Atomically replaces every active season-team ESPN mapping and records an immutable commissioner audit batch.';

revoke all on function public.set_espn_season_team_mappings(uuid, jsonb)
  from public, anon;
grant execute on function public.set_espn_season_team_mappings(uuid, jsonb)
  to authenticated, service_role;
