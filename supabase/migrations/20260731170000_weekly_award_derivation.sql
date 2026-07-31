create type public.weekly_award_tie_policy as enum (
  'commissioner_review'
);

revoke all on type public.weekly_award_tie_policy from public;
grant usage on type public.weekly_award_tie_policy to authenticated, service_role;

alter table public.season_settings
  add column weekly_award_tie_policy public.weekly_award_tie_policy
  not null default 'commissioner_review';

comment on column public.season_settings.weekly_award_tie_policy is
  'Season-scoped handling for tied weekly high or low scores; review is fail-closed.';

create or replace function public.derive_weekly_award(
  target_season_id uuid,
  target_week integer
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_season public.seasons%rowtype;
  target_settings public.season_settings%rowtype;
  existing_award public.weekly_awards%rowtype;
  high_team_id uuid;
  low_team_id uuid;
  high_score_value numeric(8, 2);
  low_score_value numeric(8, 2);
  high_count integer;
  low_count integer;
  active_team_count integer;
  result_count integer;
  high_obligation_id uuid;
  low_obligation_id uuid;
  award_id uuid;
  occurred_on_value date;
  source_refs_value jsonb;
begin
  select * into target_season
  from public.seasons
  where id = target_season_id;

  if not found then
    raise exception using errcode = '23503', message = 'award season does not exist';
  end if;

  select * into target_settings
  from public.season_settings
  where season_id = target_season_id;

  if not found then
    raise exception using errcode = '23503', message = 'award season settings do not exist';
  end if;

  if target_week < 1 or target_week > target_settings.regular_season_weeks then
    raise exception using
      errcode = '22023',
      message = 'weekly awards require a configured regular-season week';
  end if;

  if target_season.starts_on is null then
    raise exception using
      errcode = '22023',
      message = 'weekly awards require a season start date';
  end if;

  if target_settings.weekly_high_score_payout_cents <= 0
     or target_settings.weekly_low_score_penalty_cents <= 0 then
    raise exception using
      errcode = '22023',
      message = 'weekly award amounts must be positive season rules';
  end if;

  select count(*) into active_team_count
  from public.season_teams
  where season_id = target_season_id
    and status = 'active';

  select count(*) into result_count
  from public.weekly_results as result
  join public.matchups as matchup on matchup.id = result.matchup_id
  where result.season_id = target_season_id
    and matchup.week = target_week
    and matchup.phase = 'regular_season';

  if active_team_count < 2 or result_count <> active_team_count then
    raise exception using
      errcode = '22023',
      message = 'weekly awards require exactly one result for every active team';
  end if;

  select max(result.score), min(result.score)
  into high_score_value, low_score_value
  from public.weekly_results as result
  join public.matchups as matchup on matchup.id = result.matchup_id
  where result.season_id = target_season_id
    and matchup.week = target_week
    and matchup.phase = 'regular_season';

  select count(*), min(result.season_team_id::text)::uuid
  into high_count, high_team_id
  from public.weekly_results as result
  join public.matchups as matchup on matchup.id = result.matchup_id
  where result.season_id = target_season_id
    and matchup.week = target_week
    and matchup.phase = 'regular_season'
    and result.score = high_score_value;

  select count(*), min(result.season_team_id::text)::uuid
  into low_count, low_team_id
  from public.weekly_results as result
  join public.matchups as matchup on matchup.id = result.matchup_id
  where result.season_id = target_season_id
    and matchup.week = target_week
    and matchup.phase = 'regular_season'
    and result.score = low_score_value;

  if high_count <> 1 or low_count <> 1 then
    raise exception using
      errcode = '22023',
      message = 'weekly award tie requires commissioner review';
  end if;

  select * into existing_award
  from public.weekly_awards
  where season_id = target_season_id
    and week = target_week;

  if found then
    if existing_award.high_score_season_team_id <> high_team_id
       or existing_award.low_score_season_team_id <> low_team_id
       or existing_award.high_score <> high_score_value
       or existing_award.low_score <> low_score_value then
      raise exception using
        errcode = '23505',
        message = 'weekly award already exists with different accepted results';
    end if;

    return jsonb_build_object(
      'status', 'already_derived',
      'award_id', existing_award.id,
      'week', target_week
    );
  end if;

  occurred_on_value := target_season.starts_on + ((target_week - 1) * 7 + 6);

  insert into public.financial_obligations (
    league_id, season_id, season_team_id, direction, amount_cents, category,
    description, source_type, source_key, occurred_on
  ) values (
    target_season.league_id,
    target_season_id,
    high_team_id,
    'league_owes_team',
    target_settings.weekly_high_score_payout_cents,
    'weekly_high_score',
    format('Week %s high score payout', target_week),
    'rule',
    format('rule:weekly-high:%s', target_week),
    occurred_on_value
  )
  returning id into high_obligation_id;

  insert into public.financial_obligations (
    league_id, season_id, season_team_id, direction, amount_cents, category,
    description, source_type, source_key, occurred_on
  ) values (
    target_season.league_id,
    target_season_id,
    low_team_id,
    'team_owes_league',
    target_settings.weekly_low_score_penalty_cents,
    'weekly_low_score_penalty',
    format('Week %s low score penalty', target_week),
    'rule',
    format('rule:weekly-low:%s', target_week),
    occurred_on_value
  )
  returning id into low_obligation_id;

  select jsonb_agg(
    jsonb_build_object('matchup_id', matchup.id, 'result_id', result.id)
    order by matchup.id, result.id
  )
  into source_refs_value
  from public.weekly_results as result
  join public.matchups as matchup on matchup.id = result.matchup_id
  where result.season_id = target_season_id
    and matchup.week = target_week
    and matchup.phase = 'regular_season';

  insert into public.weekly_awards (
    league_id, season_id, week,
    high_score_season_team_id, high_score, high_score_obligation_id,
    low_score_season_team_id, low_score, low_score_obligation_id,
    source_type, source_key, source_refs
  ) values (
    target_season.league_id,
    target_season_id,
    target_week,
    high_team_id,
    high_score_value,
    high_obligation_id,
    low_team_id,
    low_score_value,
    low_obligation_id,
    'system',
    format('rule:weekly-awards:%s', target_week),
    source_refs_value
  )
  returning id into award_id;

  return jsonb_build_object(
    'status', 'derived',
    'award_id', award_id,
    'week', target_week,
    'high_score_obligation_id', high_obligation_id,
    'low_score_obligation_id', low_obligation_id
  );
end;
$$;

revoke all on function public.derive_weekly_award(uuid, integer)
from public, anon, authenticated;
grant execute on function public.derive_weekly_award(uuid, integer)
to service_role;

comment on function public.derive_weekly_award(uuid, integer) is
  'Derives one unique high and low weekly award plus immutable rule obligations; ties fail closed for commissioner review.';

create or replace function public.derive_available_weekly_awards(
  target_season_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_week integer;
  active_team_count integer;
  processed_count integer := 0;
  pending_tie_weeks integer[] := array[]::integer[];
begin
  select count(*) into active_team_count
  from public.season_teams
  where season_id = target_season_id
    and status = 'active';

  for target_week in
    select matchup.week
    from public.matchups as matchup
    join public.weekly_results as result on result.matchup_id = matchup.id
    where matchup.season_id = target_season_id
      and matchup.phase = 'regular_season'
    group by matchup.week
    having count(result.id) = active_team_count
    order by matchup.week
  loop
    begin
      perform public.derive_weekly_award(target_season_id, target_week);
      processed_count := processed_count + 1;
    exception
      when invalid_parameter_value then
        if sqlerrm = 'weekly award tie requires commissioner review' then
          pending_tie_weeks := array_append(pending_tie_weeks, target_week);
        else
          raise;
        end if;
    end;
  end loop;

  return jsonb_build_object(
    'award_week_count', processed_count,
    'pending_tie_weeks', to_jsonb(pending_tie_weeks)
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
  awards_result jsonb;
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

  awards_result := public.derive_available_weekly_awards(target_season_id);

  return standings_result || matchups_result || awards_result;
end;
$$;

revoke all on function public.derive_available_weekly_awards(uuid)
from public, anon, authenticated;
grant execute on function public.derive_available_weekly_awards(uuid)
to service_role;

comment on function public.derive_available_weekly_awards(uuid) is
  'Derives complete unique-score regular-season weeks and reports tied weeks for commissioner review.';
