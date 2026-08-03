create table public.manual_result_batches (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  week smallint not null check (week between 1 and 30),
  phase public.competition_phase not null,
  reason text not null check (length(btrim(reason)) between 10 and 500),
  request_key text not null check (
    request_key = btrim(request_key)
    and request_key ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$'
  ),
  matchups jsonb not null check (
    jsonb_typeof(matchups) = 'array'
    and jsonb_array_length(matchups) between 1 and 50
  ),
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  foreign key (season_id, league_id)
    references public.seasons (id, league_id) on delete restrict,
  unique (season_id, request_key),
  unique (id, league_id, season_id)
);

comment on table public.manual_result_batches is
  'Immutable commissioner evidence for one complete manually accepted competition week.';

create index manual_result_batches_season_week_created_idx
  on public.manual_result_batches (season_id, week, created_at desc);

alter table public.matchups add column manual_result_batch_id uuid;
alter table public.weekly_results add column manual_result_batch_id uuid;

alter table public.matchups
  add constraint matchups_manual_result_batch_fkey
  foreign key (manual_result_batch_id, league_id, season_id)
  references public.manual_result_batches (id, league_id, season_id)
  on delete restrict;

alter table public.weekly_results
  add constraint weekly_results_manual_result_batch_fkey
  foreign key (manual_result_batch_id, league_id, season_id)
  references public.manual_result_batches (id, league_id, season_id)
  on delete restrict;

create index matchups_manual_result_batch_idx
  on public.matchups (manual_result_batch_id)
  where manual_result_batch_id is not null;

create index weekly_results_manual_result_batch_idx
  on public.weekly_results (manual_result_batch_id)
  where manual_result_batch_id is not null;

create or replace function private.prevent_manual_result_batch_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'manual result batches are immutable';
end;
$$;

create trigger prevent_manual_result_batch_mutation
before update or delete on public.manual_result_batches
for each row execute function private.prevent_manual_result_batch_mutation();

create or replace function private.prevent_imported_competition_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.source_type = 'import' then
    raise exception using
      errcode = '55000',
      message = 'imported competition history is immutable';
  end if;

  if old.source_type = 'manual' then
    raise exception using
      errcode = '55000',
      message = 'manual competition history is immutable';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

alter table public.manual_result_batches enable row level security;

revoke all on table public.manual_result_batches from public, anon, authenticated;
grant select on table public.manual_result_batches to authenticated;
grant all on table public.manual_result_batches to service_role;

create policy manual_result_batches_select_commissioner
on public.manual_result_batches
for select to authenticated
using ((select private.is_league_commissioner(league_id)));

create or replace function public.record_manual_week_results(
  target_season_id uuid,
  target_week integer,
  target_reason text,
  target_request_key text,
  target_matchups jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  target_league_id uuid;
  regular_season_week_count integer;
  target_phase public.competition_phase;
  active_team_count integer;
  input_team_count integer;
  matched_team_count integer;
  payload_hash text;
  existing_batch public.manual_result_batches%rowtype;
  batch_id uuid;
  matchup_item jsonb;
  matchup_position bigint;
  matchup_id uuid;
  home_team_id uuid;
  away_team_id uuid;
  home_score_value numeric(8, 2);
  away_score_value numeric(8, 2);
  home_result public.competition_result;
  away_result public.competition_result;
  matchup_count integer := 0;
  award_result jsonb := null;
  pending_tie boolean := false;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'manual results require an authenticated actor';
  end if;

  if target_week is null or target_week < 1 or target_week > 30
     or target_reason is null
     or length(btrim(target_reason)) not between 10 and 500
     or target_reason <> btrim(target_reason)
     or target_request_key is null
     or target_request_key !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$'
     or jsonb_typeof(target_matchups) <> 'array'
     or jsonb_array_length(target_matchups) not between 1 and 50 then
    raise exception using errcode = '22023', message = 'manual result request is invalid';
  end if;

  select season.league_id, settings.regular_season_weeks
  into target_league_id, regular_season_week_count
  from public.seasons as season
  join public.season_settings as settings on settings.season_id = season.id
  where season.id = target_season_id;

  if target_league_id is null then
    raise exception using errcode = '23503', message = 'manual result season was not found';
  end if;

  if not private.is_league_commissioner(target_league_id) then
    raise exception using errcode = '42501', message = 'only an active commissioner may record manual results';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_season_id::text || ':' || target_week::text, 0)
  );

  target_phase := (case
    when target_week <= regular_season_week_count then 'regular_season'
    else 'postseason'
  end)::public.competition_phase;
  payload_hash := pg_catalog.encode(
    extensions.digest(pg_catalog.convert_to(target_matchups::text, 'UTF8'), 'sha256'),
    'hex'
  );

  select * into existing_batch
  from public.manual_result_batches
  where season_id = target_season_id and request_key = target_request_key;

  if found then
    if existing_batch.week <> target_week
       or existing_batch.reason <> target_reason
       or existing_batch.payload_sha256 <> payload_hash then
      raise exception using errcode = '23505', message = 'manual result request key was reused with different evidence';
    end if;
    return jsonb_build_object(
      'status', 'already_recorded',
      'batch_id', existing_batch.id,
      'week', target_week,
      'phase', existing_batch.phase,
      'matchup_count', jsonb_array_length(existing_batch.matchups)
    );
  end if;

  if exists (
    select 1 from public.matchups
    where season_id = target_season_id and week = target_week
  ) then
    raise exception using
      errcode = '23505',
      message = 'accepted results already exist for this week; use the correction workflow';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(target_matchups) as item(
      home_season_team_id uuid,
      away_season_team_id uuid,
      home_score numeric,
      away_score numeric
    )
    where item.home_season_team_id is null
      or item.away_season_team_id is null
      or item.home_season_team_id = item.away_season_team_id
      or item.home_score is null or item.away_score is null
      or item.home_score < 0 or item.away_score < 0
      or item.home_score > 999999.99 or item.away_score > 999999.99
      or item.home_score * 100 <> trunc(item.home_score * 100)
      or item.away_score * 100 <> trunc(item.away_score * 100)
  ) then
    raise exception using errcode = '22023', message = 'manual matchup scores or teams are invalid';
  end if;

  with input_teams as (
    select item.home_season_team_id as season_team_id
    from jsonb_to_recordset(target_matchups) as item(home_season_team_id uuid)
    union all
    select item.away_season_team_id
    from jsonb_to_recordset(target_matchups) as item(away_season_team_id uuid)
  )
  select count(*), count(distinct season_team_id)
  into input_team_count, matched_team_count
  from input_teams;

  if input_team_count <> matched_team_count then
    raise exception using errcode = '22023', message = 'each active team must appear exactly once';
  end if;

  select count(*) into active_team_count
  from public.season_teams
  where season_id = target_season_id
    and league_id = target_league_id
    and status = 'active';

  with input_teams as (
    select item.home_season_team_id as season_team_id
    from jsonb_to_recordset(target_matchups) as item(home_season_team_id uuid)
    union all
    select item.away_season_team_id
    from jsonb_to_recordset(target_matchups) as item(away_season_team_id uuid)
  )
  select count(*) into matched_team_count
  from input_teams
  join public.season_teams as team
    on team.id = input_teams.season_team_id
   and team.season_id = target_season_id
   and team.league_id = target_league_id
   and team.status = 'active';

  if active_team_count < 2
     or active_team_count <> input_team_count
     or matched_team_count <> input_team_count then
    raise exception using errcode = '22023', message = 'manual results must exactly cover every active season team';
  end if;

  insert into public.manual_result_batches (
    league_id, season_id, week, phase, reason, request_key, matchups,
    payload_sha256, created_by
  ) values (
    target_league_id, target_season_id, target_week, target_phase,
    target_reason, target_request_key, target_matchups, payload_hash, actor_id
  ) returning id into batch_id;

  for matchup_item, matchup_position in
    select value, ordinality
    from jsonb_array_elements(target_matchups) with ordinality
  loop
    home_team_id := (matchup_item ->> 'home_season_team_id')::uuid;
    away_team_id := (matchup_item ->> 'away_season_team_id')::uuid;
    home_score_value := (matchup_item ->> 'home_score')::numeric(8, 2);
    away_score_value := (matchup_item ->> 'away_score')::numeric(8, 2);
    home_result := (case when home_score_value > away_score_value then 'win' when home_score_value < away_score_value then 'loss' else 'tie' end)::public.competition_result;
    away_result := (case when away_score_value > home_score_value then 'win' when away_score_value < home_score_value then 'loss' else 'tie' end)::public.competition_result;

    insert into public.matchups (
      league_id, season_id, week, phase, source_type, source_key,
      source_updated_at, created_by, manual_result_batch_id
    ) values (
      target_league_id, target_season_id, target_week, target_phase, 'manual',
      format('manual:%s:matchup:%s', batch_id, matchup_position),
      timezone('utc', statement_timestamp()), actor_id, batch_id
    ) returning id into matchup_id;

    insert into public.weekly_results (
      league_id, season_id, matchup_id, season_team_id,
      opponent_season_team_id, score, result, notes, source_type, source_key,
      source_updated_at, created_by, manual_result_batch_id
    ) values
    (
      target_league_id, target_season_id, matchup_id, home_team_id,
      away_team_id, home_score_value, home_result, target_reason, 'manual',
      format('manual:%s:result:%s', batch_id, home_team_id),
      timezone('utc', statement_timestamp()), actor_id, batch_id
    ),
    (
      target_league_id, target_season_id, matchup_id, away_team_id,
      home_team_id, away_score_value, away_result, target_reason, 'manual',
      format('manual:%s:result:%s', batch_id, away_team_id),
      timezone('utc', statement_timestamp()), actor_id, batch_id
    );
    matchup_count := matchup_count + 1;
  end loop;

  if target_phase = 'regular_season' then
    begin
      award_result := public.derive_weekly_award(target_season_id, target_week);
    exception when invalid_parameter_value then
      if sqlerrm = 'weekly award tie requires commissioner review' then
        pending_tie := true;
      else
        raise;
      end if;
    end;
  end if;

  return jsonb_build_object(
    'status', 'recorded',
    'batch_id', batch_id,
    'week', target_week,
    'phase', target_phase,
    'matchup_count', matchup_count,
    'result_count', matchup_count * 2,
    'award', award_result,
    'pending_tie', pending_tie
  );
end;
$$;

revoke all on function private.prevent_manual_result_batch_mutation()
from public, anon, authenticated;
grant execute on function private.prevent_manual_result_batch_mutation()
to service_role;

revoke all on function public.record_manual_week_results(
  uuid, integer, text, text, jsonb
) from public, anon;
grant execute on function public.record_manual_week_results(
  uuid, integer, text, text, jsonb
) to authenticated, service_role;

revoke insert on public.matchups, public.weekly_results, public.weekly_awards
from authenticated;

comment on function public.record_manual_week_results(
  uuid, integer, text, text, jsonb
) is
  'Atomically records one previously missing complete week from commissioner evidence and derives configured weekly awards.';
