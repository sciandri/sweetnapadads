alter table public.matchups
  add column espn_sync_run_id uuid;

alter table public.matchups
  add constraint matchups_espn_sync_run_fkey
  foreign key (espn_sync_run_id, league_id, season_id)
  references public.espn_sync_runs (id, league_id, season_id)
  on delete restrict;

comment on column public.matchups.espn_sync_run_id is
  'Latest accepted ESPN raw-evidence run supporting this source-owned matchup.';

create or replace function public.upsert_espn_matchup_results(
  target_league_id uuid,
  target_season_id uuid,
  target_sync_run_id uuid,
  target_matchups jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  matchup_item jsonb;
  first_result jsonb;
  second_result jsonb;
  result_item jsonb;
  target_matchup_id uuid;
  saved_result_id uuid;
  matchup_count integer := 0;
  result_count integer := 0;
  first_team_id uuid;
  second_team_id uuid;
  first_opponent_id uuid;
  second_opponent_id uuid;
  first_score numeric(8, 2);
  second_score numeric(8, 2);
  first_outcome public.competition_result;
  second_outcome public.competition_result;
  result_team_id uuid;
  result_opponent_id uuid;
  result_espn_team_id integer;
  result_source_key text;
begin
  if jsonb_typeof(target_matchups) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'ESPN matchups must be an array';
  end if;

  if not exists (
    select 1
    from public.espn_sync_runs as run
    where run.id = target_sync_run_id
      and run.league_id = target_league_id
      and run.season_id = target_season_id
      and run.status = 'succeeded'
  ) then
    raise exception using
      errcode = '23503',
      message = 'ESPN matchup evidence must reference a successful sync run';
  end if;

  for matchup_item in
    select value from jsonb_array_elements(target_matchups)
  loop
    if jsonb_typeof(matchup_item) <> 'object'
       or jsonb_typeof(matchup_item -> 'results') <> 'array'
       or jsonb_array_length(matchup_item -> 'results') <> 2 then
      raise exception using
        errcode = '22023',
        message = 'each ESPN matchup must contain exactly two results';
    end if;

    first_result := matchup_item -> 'results' -> 0;
    second_result := matchup_item -> 'results' -> 1;
    first_team_id := (first_result ->> 'season_team_id')::uuid;
    second_team_id := (second_result ->> 'season_team_id')::uuid;
    first_opponent_id := (first_result ->> 'opponent_season_team_id')::uuid;
    second_opponent_id := (second_result ->> 'opponent_season_team_id')::uuid;
    first_score := (first_result ->> 'score')::numeric(8, 2);
    second_score := (second_result ->> 'score')::numeric(8, 2);
    first_outcome := (first_result ->> 'result')::public.competition_result;
    second_outcome := (second_result ->> 'result')::public.competition_result;

    if first_team_id = second_team_id
       or first_opponent_id <> second_team_id
       or second_opponent_id <> first_team_id then
      raise exception using
        errcode = '22023',
        message = 'ESPN matchup results must be reciprocal distinct teams';
    end if;

    if not (
      (first_score > second_score and first_outcome = 'win' and second_outcome = 'loss')
      or (first_score < second_score and first_outcome = 'loss' and second_outcome = 'win')
      or (first_score = second_score and first_outcome = 'tie' and second_outcome = 'tie')
    ) then
      raise exception using
        errcode = '22023',
        message = 'ESPN matchup outcomes must agree with accepted scores';
    end if;

    insert into public.matchups (
      league_id,
      season_id,
      week,
      phase,
      source_type,
      source_key,
      source_updated_at,
      espn_sync_run_id
    ) values (
      target_league_id,
      target_season_id,
      (matchup_item ->> 'week')::smallint,
      (matchup_item ->> 'phase')::public.competition_phase,
      'espn',
      matchup_item ->> 'source_key',
      (matchup_item ->> 'source_updated_at')::timestamptz,
      target_sync_run_id
    )
    on conflict (season_id, source_key) do update
    set
      week = excluded.week,
      phase = excluded.phase,
      source_updated_at = excluded.source_updated_at,
      espn_sync_run_id = excluded.espn_sync_run_id
    where public.matchups.source_type = 'espn'
    returning id into target_matchup_id;

    if target_matchup_id is null then
      raise exception using
        errcode = '23505',
        message = 'ESPN matchup source key conflicts with non-ESPN history';
    end if;

    for result_item in
      select value from jsonb_array_elements(matchup_item -> 'results')
    loop
      result_team_id := (result_item ->> 'season_team_id')::uuid;
      result_opponent_id := (result_item ->> 'opponent_season_team_id')::uuid;
      result_espn_team_id := (result_item ->> 'espn_team_id')::integer;
      result_source_key := result_item ->> 'source_key';

      if not exists (
        select 1
        from public.season_teams as season_team
        where season_team.id = result_team_id
          and season_team.league_id = target_league_id
          and season_team.season_id = target_season_id
          and season_team.status = 'active'
          and season_team.espn_team_id = result_espn_team_id
      ) then
        raise exception using
          errcode = '23503',
          message = 'ESPN result team does not match an active season mapping';
      end if;

      if exists (
        select 1
        from public.weekly_results as existing
        where existing.season_id = target_season_id
          and existing.source_key = result_source_key
          and (
            existing.matchup_id <> target_matchup_id
            or existing.season_team_id <> result_team_id
            or existing.opponent_season_team_id <> result_opponent_id
            or existing.source_type <> 'espn'
          )
      ) then
        raise exception using
          errcode = '23505',
          message = 'ESPN result source key conflicts with different history';
      end if;

      insert into public.weekly_results (
        league_id,
        season_id,
        matchup_id,
        season_team_id,
        opponent_season_team_id,
        score,
        result,
        source_type,
        source_key,
        source_updated_at
      ) values (
        target_league_id,
        target_season_id,
        target_matchup_id,
        result_team_id,
        result_opponent_id,
        (result_item ->> 'score')::numeric(8, 2),
        (result_item ->> 'result')::public.competition_result,
        'espn',
        result_source_key,
        (matchup_item ->> 'source_updated_at')::timestamptz
      )
      on conflict (season_id, source_key) do update
      set
        score = excluded.score,
        result = excluded.result,
        source_updated_at = excluded.source_updated_at
      where public.weekly_results.source_type = 'espn'
      returning id into saved_result_id;

      if saved_result_id is null then
        raise exception using
          errcode = '23505',
          message = 'ESPN result source key conflicts with non-ESPN history';
      end if;

      result_count := result_count + 1;
    end loop;

    matchup_count := matchup_count + 1;
  end loop;

  return jsonb_build_object(
    'matchup_count', matchup_count,
    'result_count', result_count
  );
end;
$$;

create or replace function public.record_espn_competition_snapshot(
  target_league_id uuid,
  target_season_id uuid,
  target_scoring_period integer,
  target_source_revision text,
  target_idempotency_key text,
  target_endpoint_path text,
  target_http_status integer,
  target_raw_payload jsonb,
  target_payload_sha256 text,
  target_fetched_at timestamptz,
  target_espn_league_id bigint,
  target_source_key text,
  target_captured_at timestamptz,
  target_entries jsonb,
  target_matchups jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  standings_result jsonb;
  matchups_result jsonb;
begin
  standings_result := public.record_espn_standings_snapshot(
    target_league_id,
    target_season_id,
    target_scoring_period,
    target_source_revision,
    target_idempotency_key,
    target_endpoint_path,
    target_http_status,
    target_raw_payload,
    target_payload_sha256,
    target_fetched_at,
    target_espn_league_id,
    target_source_key,
    target_captured_at,
    target_entries
  );

  matchups_result := public.upsert_espn_matchup_results(
    target_league_id,
    target_season_id,
    (standings_result ->> 'run_id')::uuid,
    target_matchups
  );

  return standings_result || matchups_result;
end;
$$;

revoke all on function public.upsert_espn_matchup_results(
  uuid, uuid, uuid, jsonb
) from public, anon, authenticated;
grant execute on function public.upsert_espn_matchup_results(
  uuid, uuid, uuid, jsonb
) to service_role;

revoke all on function public.record_espn_competition_snapshot(
  uuid, uuid, integer, text, text, text, integer, jsonb, text, timestamptz,
  bigint, text, timestamptz, jsonb, jsonb
) from public, anon, authenticated;
grant execute on function public.record_espn_competition_snapshot(
  uuid, uuid, integer, text, text, text, integer, jsonb, text, timestamptz,
  bigint, text, timestamptz, jsonb, jsonb
) to service_role;

comment on function public.record_espn_competition_snapshot(
  uuid, uuid, integer, text, text, text, integer, jsonb, text, timestamptz,
  bigint, text, timestamptz, jsonb, jsonb
) is
  'Atomically records ESPN raw evidence, official standings, and completed matchup results.';
