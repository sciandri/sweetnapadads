create table public.result_correction_batches (
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
  prior_source_refs jsonb not null check (jsonb_typeof(prior_source_refs) = 'array'),
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  foreign key (season_id, league_id)
    references public.seasons (id, league_id) on delete restrict,
  unique (season_id, request_key),
  unique (id, league_id, season_id)
);

comment on table public.result_correction_batches is
  'Immutable commissioner evidence for a complete accepted-week correction.';

create index result_correction_batches_season_week_created_idx
  on public.result_correction_batches (season_id, week, created_at desc, id desc);

alter table public.matchups add column result_correction_batch_id uuid;
alter table public.weekly_results add column result_correction_batch_id uuid;
alter table public.weekly_awards add column result_correction_batch_id uuid;

alter table public.matchups
  add constraint matchups_result_correction_batch_fkey
  foreign key (result_correction_batch_id, league_id, season_id)
  references public.result_correction_batches (id, league_id, season_id)
  on delete restrict;

alter table public.weekly_results
  add constraint weekly_results_result_correction_batch_fkey
  foreign key (result_correction_batch_id, league_id, season_id)
  references public.result_correction_batches (id, league_id, season_id)
  on delete restrict;

alter table public.weekly_awards
  add constraint weekly_awards_result_correction_batch_fkey
  foreign key (result_correction_batch_id, league_id, season_id)
  references public.result_correction_batches (id, league_id, season_id)
  on delete restrict;

create index matchups_result_correction_batch_idx
  on public.matchups (result_correction_batch_id)
  where result_correction_batch_id is not null;

create index weekly_results_result_correction_batch_idx
  on public.weekly_results (result_correction_batch_id)
  where result_correction_batch_id is not null;

alter table public.weekly_awards drop constraint weekly_awards_week_key;

create unique index weekly_awards_base_week_key
  on public.weekly_awards (season_id, week)
  where result_correction_batch_id is null;

create unique index weekly_awards_result_correction_batch_key
  on public.weekly_awards (result_correction_batch_id)
  where result_correction_batch_id is not null;

create or replace function private.prevent_result_correction_batch_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'result correction batches are immutable';
end;
$$;

create trigger prevent_result_correction_batch_mutation
before update or delete on public.result_correction_batches
for each row execute function private.prevent_result_correction_batch_mutation();

alter table public.result_correction_batches enable row level security;

revoke all on table public.result_correction_batches from public, anon, authenticated;
grant select on table public.result_correction_batches to authenticated;
grant all on table public.result_correction_batches to service_role;

create policy result_correction_batches_select_member
on public.result_correction_batches
for select to authenticated
using ((select private.is_active_league_member(league_id)));

drop policy manual_result_batches_select_commissioner
on public.manual_result_batches;

create policy manual_result_batches_select_member
on public.manual_result_batches
for select to authenticated
using ((select private.is_active_league_member(league_id)));

create view public.accepted_matchups
with (security_invoker = true)
as
with latest_correction as (
  select distinct on (season_id, week)
    id,
    season_id,
    week
  from public.result_correction_batches
  order by season_id, week, created_at desc, id desc
), manual_week as (
  select distinct season_id, week
  from public.manual_result_batches
)
select matchup.*
from public.matchups as matchup
left join latest_correction as correction
  on correction.season_id = matchup.season_id
 and correction.week = matchup.week
left join manual_week
  on manual_week.season_id = matchup.season_id
 and manual_week.week = matchup.week
where (
  correction.id is not null
  and matchup.result_correction_batch_id = correction.id
) or (
  correction.id is null
  and manual_week.season_id is not null
  and matchup.manual_result_batch_id is not null
) or (
  correction.id is null
  and manual_week.season_id is null
  and matchup.result_correction_batch_id is null
);

create view public.accepted_weekly_results
with (security_invoker = true)
as
select result.*
from public.weekly_results as result
join public.accepted_matchups as matchup on matchup.id = result.matchup_id;

create view public.accepted_weekly_awards
with (security_invoker = true)
as
with latest_correction as (
  select distinct on (season_id, week)
    id,
    season_id,
    week
  from public.result_correction_batches
  order by season_id, week, created_at desc, id desc
)
select award.*
from public.weekly_awards as award
left join latest_correction as correction
  on correction.season_id = award.season_id
 and correction.week = award.week
where (
  correction.id is not null
  and award.result_correction_batch_id = correction.id
) or (
  correction.id is null
  and award.result_correction_batch_id is null
);

comment on view public.accepted_matchups is
  'Member-readable matchup projection with the latest commissioner correction taking precedence.';
comment on view public.accepted_weekly_results is
  'Member-readable result projection limited to accepted matchup versions.';
comment on view public.accepted_weekly_awards is
  'Member-readable weekly award projection aligned with the latest accepted result version.';

grant select on table
  public.accepted_matchups,
  public.accepted_weekly_results,
  public.accepted_weekly_awards
to authenticated, service_role;

create or replace function public.record_week_result_correction(
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
  target_season public.seasons%rowtype;
  target_settings public.season_settings%rowtype;
  target_phase public.competition_phase;
  active_team_count integer;
  input_team_count integer;
  matched_team_count integer;
  accepted_result_count integer;
  payload_hash text;
  prior_refs jsonb;
  existing_batch public.result_correction_batches%rowtype;
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
  high_team_id uuid;
  low_team_id uuid;
  high_score_value numeric(8, 2);
  low_score_value numeric(8, 2);
  high_count integer;
  low_count integer;
  prior_award public.accepted_weekly_awards%rowtype;
  prior_high_obligation public.financial_obligations%rowtype;
  prior_low_obligation public.financial_obligations%rowtype;
  high_obligation_id uuid;
  low_obligation_id uuid;
  award_id uuid;
  occurred_on_value date;
  source_refs_value jsonb;
  pending_tie boolean := false;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'result correction requires an authenticated actor';
  end if;

  if target_week is null or target_week < 1 or target_week > 30
     or target_reason is null
     or length(btrim(target_reason)) not between 10 and 500
     or target_reason <> btrim(target_reason)
     or target_request_key is null
     or target_request_key !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$'
     or jsonb_typeof(target_matchups) <> 'array'
     or jsonb_array_length(target_matchups) not between 1 and 50 then
    raise exception using errcode = '22023', message = 'result correction request is invalid';
  end if;

  select * into target_season
  from public.seasons where id = target_season_id;

  if not found then
    raise exception using errcode = '23503', message = 'result correction season was not found';
  end if;

  if not private.is_league_commissioner(target_season.league_id) then
    raise exception using errcode = '42501', message = 'only an active commissioner may correct results';
  end if;

  select * into target_settings
  from public.season_settings where season_id = target_season_id;

  if not found then
    raise exception using errcode = '23503', message = 'result correction season settings were not found';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_season_id::text || ':' || target_week::text, 0)
  );

  target_phase := (case
    when target_week <= target_settings.regular_season_weeks then 'regular_season'
    else 'postseason'
  end)::public.competition_phase;
  payload_hash := pg_catalog.encode(
    extensions.digest(pg_catalog.convert_to(target_matchups::text, 'UTF8'), 'sha256'),
    'hex'
  );

  select * into existing_batch
  from public.result_correction_batches
  where season_id = target_season_id and request_key = target_request_key;

  if found then
    if existing_batch.week <> target_week
       or existing_batch.reason <> target_reason
       or existing_batch.payload_sha256 <> payload_hash then
      raise exception using errcode = '23505', message = 'result correction request key was reused with different evidence';
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
    raise exception using errcode = '22023', message = 'corrected matchup scores or teams are invalid';
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
    and league_id = target_season.league_id
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
   and team.league_id = target_season.league_id
   and team.status = 'active';

  if active_team_count < 2
     or active_team_count <> input_team_count
     or matched_team_count <> input_team_count then
    raise exception using errcode = '22023', message = 'corrected results must exactly cover every active season team';
  end if;

  select count(*) into accepted_result_count
  from public.accepted_weekly_results as result
  join public.accepted_matchups as matchup on matchup.id = result.matchup_id
  where matchup.season_id = target_season_id and matchup.week = target_week;

  if accepted_result_count <> active_team_count then
    raise exception using errcode = '22023', message = 'result correction requires one complete accepted week';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object('matchup_id', matchup.id, 'result_id', result.id)
    order by matchup.id, result.id
  ), '[]'::jsonb)
  into prior_refs
  from public.accepted_weekly_results as result
  join public.accepted_matchups as matchup on matchup.id = result.matchup_id
  where matchup.season_id = target_season_id and matchup.week = target_week;

  select * into prior_award
  from public.accepted_weekly_awards
  where season_id = target_season_id and week = target_week;

  insert into public.result_correction_batches (
    league_id, season_id, week, phase, reason, request_key, matchups,
    prior_source_refs, payload_sha256, created_by
  ) values (
    target_season.league_id, target_season_id, target_week, target_phase,
    target_reason, target_request_key, target_matchups, prior_refs,
    payload_hash, actor_id
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
      source_updated_at, created_by, result_correction_batch_id
    ) values (
      target_season.league_id, target_season_id, target_week, target_phase,
      'manual', format('correction:%s:matchup:%s', batch_id, matchup_position),
      timezone('utc', statement_timestamp()), actor_id, batch_id
    ) returning id into matchup_id;

    insert into public.weekly_results (
      league_id, season_id, matchup_id, season_team_id,
      opponent_season_team_id, score, result, notes, source_type, source_key,
      source_updated_at, created_by, result_correction_batch_id
    ) values
    (
      target_season.league_id, target_season_id, matchup_id, home_team_id,
      away_team_id, home_score_value, home_result, target_reason, 'manual',
      format('correction:%s:result:%s', batch_id, home_team_id),
      timezone('utc', statement_timestamp()), actor_id, batch_id
    ),
    (
      target_season.league_id, target_season_id, matchup_id, away_team_id,
      home_team_id, away_score_value, away_result, target_reason, 'manual',
      format('correction:%s:result:%s', batch_id, away_team_id),
      timezone('utc', statement_timestamp()), actor_id, batch_id
    );
    matchup_count := matchup_count + 1;
  end loop;

  if target_phase = 'regular_season' then
    select max(score_row.score), min(score_row.score)
    into high_score_value, low_score_value
    from jsonb_to_recordset(target_matchups) as item(
      home_score numeric,
      away_score numeric
    )
    cross join lateral (values (item.home_score), (item.away_score)) as score_row(score);

    with scores as (
      select item.home_season_team_id as season_team_id, item.home_score as score
      from jsonb_to_recordset(target_matchups) as item(home_season_team_id uuid, home_score numeric)
      union all
      select item.away_season_team_id, item.away_score
      from jsonb_to_recordset(target_matchups) as item(away_season_team_id uuid, away_score numeric)
    )
    select count(*), min(season_team_id::text)::uuid
    into high_count, high_team_id
    from scores where score = high_score_value;

    with scores as (
      select item.home_season_team_id as season_team_id, item.home_score as score
      from jsonb_to_recordset(target_matchups) as item(home_season_team_id uuid, home_score numeric)
      union all
      select item.away_season_team_id, item.away_score
      from jsonb_to_recordset(target_matchups) as item(away_season_team_id uuid, away_score numeric)
    )
    select count(*), min(season_team_id::text)::uuid
    into low_count, low_team_id
    from scores where score = low_score_value;

    pending_tie := high_count <> 1 or low_count <> 1;

    if prior_award.id is not null and (pending_tie or prior_award.high_score_season_team_id <> high_team_id) then
      select * into prior_high_obligation
      from public.financial_obligations where id = prior_award.high_score_obligation_id;

      insert into public.financial_adjustments (
        league_id, season_id, season_team_id, direction, amount_cents, reason,
        source_type, source_key, occurred_on, related_obligation_id, created_by
      ) values (
        target_season.league_id, target_season_id,
        prior_high_obligation.season_team_id, 'increase_team_balance',
        prior_high_obligation.amount_cents,
        format('Correct Week %s high-score result: %s', target_week, target_reason),
        'manual', format('correction:%s:reverse-high', batch_id),
        prior_high_obligation.occurred_on, prior_high_obligation.id, actor_id
      );
    end if;

    if prior_award.id is not null and (pending_tie or prior_award.low_score_season_team_id <> low_team_id) then
      select * into prior_low_obligation
      from public.financial_obligations where id = prior_award.low_score_obligation_id;

      insert into public.financial_adjustments (
        league_id, season_id, season_team_id, direction, amount_cents, reason,
        source_type, source_key, occurred_on, related_obligation_id, created_by
      ) values (
        target_season.league_id, target_season_id,
        prior_low_obligation.season_team_id, 'decrease_team_balance',
        prior_low_obligation.amount_cents,
        format('Correct Week %s low-score result: %s', target_week, target_reason),
        'manual', format('correction:%s:reverse-low', batch_id),
        prior_low_obligation.occurred_on, prior_low_obligation.id, actor_id
      );
    end if;

    if not pending_tie then
      occurred_on_value := target_season.starts_on + ((target_week - 1) * 7 + 6);

      if prior_award.id is not null and prior_award.high_score_season_team_id = high_team_id then
        high_obligation_id := prior_award.high_score_obligation_id;
      else
        insert into public.financial_obligations (
          league_id, season_id, season_team_id, direction, amount_cents,
          category, description, source_type, source_key, occurred_on, created_by
        ) values (
          target_season.league_id, target_season_id, high_team_id,
          'league_owes_team',
          coalesce(prior_high_obligation.amount_cents, target_settings.weekly_high_score_payout_cents),
          'weekly_high_score', format('Week %s corrected high score payout', target_week),
          'manual', format('correction:%s:weekly-high', batch_id),
          coalesce(prior_high_obligation.occurred_on, occurred_on_value), actor_id
        ) returning id into high_obligation_id;
      end if;

      if prior_award.id is not null and prior_award.low_score_season_team_id = low_team_id then
        low_obligation_id := prior_award.low_score_obligation_id;
      else
        insert into public.financial_obligations (
          league_id, season_id, season_team_id, direction, amount_cents,
          category, description, source_type, source_key, occurred_on, created_by
        ) values (
          target_season.league_id, target_season_id, low_team_id,
          'team_owes_league',
          coalesce(prior_low_obligation.amount_cents, target_settings.weekly_low_score_penalty_cents),
          'weekly_low_score_penalty', format('Week %s corrected low score penalty', target_week),
          'manual', format('correction:%s:weekly-low', batch_id),
          coalesce(prior_low_obligation.occurred_on, occurred_on_value), actor_id
        ) returning id into low_obligation_id;
      end if;

      select jsonb_agg(
        jsonb_build_object('matchup_id', matchup.id, 'result_id', result.id)
        order by matchup.id, result.id
      ) into source_refs_value
      from public.weekly_results as result
      join public.matchups as matchup on matchup.id = result.matchup_id
      where matchup.result_correction_batch_id = batch_id;

      insert into public.weekly_awards (
        league_id, season_id, week,
        high_score_season_team_id, high_score, high_score_obligation_id,
        low_score_season_team_id, low_score, low_score_obligation_id,
        source_type, source_key, source_refs, created_by,
        result_correction_batch_id
      ) values (
        target_season.league_id, target_season_id, target_week,
        high_team_id, high_score_value, high_obligation_id,
        low_team_id, low_score_value, low_obligation_id,
        'manual', format('correction:%s:weekly-award', batch_id),
        source_refs_value, actor_id, batch_id
      ) returning id into award_id;
    end if;
  end if;

  return jsonb_build_object(
    'status', 'recorded',
    'batch_id', batch_id,
    'week', target_week,
    'phase', target_phase,
    'matchup_count', matchup_count,
    'result_count', matchup_count * 2,
    'award_id', award_id,
    'pending_tie', pending_tie
  );
end;
$$;

revoke all on function private.prevent_result_correction_batch_mutation()
from public, anon, authenticated;
grant execute on function private.prevent_result_correction_batch_mutation()
to service_role;

revoke all on function public.record_week_result_correction(
  uuid, integer, text, text, jsonb
) from public, anon;
grant execute on function public.record_week_result_correction(
  uuid, integer, text, text, jsonb
) to authenticated, service_role;

comment on function public.record_week_result_correction(
  uuid, integer, text, text, jsonb
) is
  'Appends one complete accepted-week correction and reconciles affected immutable weekly obligations.';

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
      and not exists (
        select 1 from public.manual_result_batches as manual_batch
        where manual_batch.season_id = target_season_id
          and manual_batch.week = matchup.week
      )
      and not exists (
        select 1 from public.result_correction_batches as correction
        where correction.season_id = target_season_id
          and correction.week = matchup.week
      )
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

comment on function public.derive_available_weekly_awards(uuid) is
  'Derives unoverridden complete ESPN weeks while preserving manual and corrected accepted versions.';

create or replace function public.get_commissioner_message_context(
  target_season_id uuid,
  target_week integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  season_record record;
  standings_value jsonb;
  results_value jsonb;
  awards_value jsonb;
begin
  if actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'message context requires an authenticated actor';
  end if;

  if target_week is null or target_week < 1 or target_week > 30 then
    raise exception using
      errcode = '22023',
      message = 'message context week must be between 1 and 30';
  end if;

  select
    season.id,
    season.league_id,
    season.year,
    season.name,
    league.name as league_name
  into season_record
  from public.seasons as season
  join public.leagues as league on league.id = season.league_id
  where season.id = target_season_id;

  if not found then
    raise exception 'season % does not exist', target_season_id;
  end if;

  if not private.is_league_commissioner(season_record.league_id) then
    raise exception using
      errcode = '42501',
      message = 'only an active league commissioner can assemble message context';
  end if;

  select jsonb_build_object(
    'source', 'espn',
    'available', count(*) > 0,
    'snapshot_id', min(standing.snapshot_id::text)::uuid,
    'captured_at', min(standing.captured_at),
    'scoring_period', min(standing.scoring_period),
    'official_order', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'rank', standing.official_rank,
          'team_key', team.slug,
          'team_name', season_team.name,
          'espn_team_id', standing.espn_team_id,
          'record', standing.record_summary,
          'wins', standing.wins,
          'losses', standing.losses,
          'ties', standing.ties,
          'points_for', standing.points_for,
          'points_against', standing.points_against,
          'streak', standing.streak,
          'playoff_seed', standing.playoff_seed
        )
        order by standing.official_rank
      ) filter (where standing.snapshot_id is not null),
      '[]'::jsonb
    )
  )
  into standings_value
  from public.current_espn_standings as standing
  join public.season_teams as season_team
    on season_team.id = standing.season_team_id
  join public.teams as team on team.id = season_team.team_id
  where standing.season_id = target_season_id;

  select coalesce(
    jsonb_agg(matchup_context order by matchup_week, matchup_source_key),
    '[]'::jsonb
  )
  into results_value
  from (
    select
      matchup.week as matchup_week,
      matchup.source_key as matchup_source_key,
      jsonb_build_object(
        'week', matchup.week,
        'phase', matchup.phase,
        'source_key', matchup.source_key,
        'teams', jsonb_agg(
          jsonb_build_object(
            'team_key', team.slug,
            'team_name', season_team.name,
            'score', result_row.score,
            'result', result_row.result,
            'notes', result_row.notes
          )
          order by result_row.score desc, season_team.name
        )
      ) as matchup_context
    from public.accepted_matchups as matchup
    join public.accepted_weekly_results as result_row
      on result_row.matchup_id = matchup.id
    join public.season_teams as season_team
      on season_team.id = result_row.season_team_id
    join public.teams as team on team.id = season_team.team_id
    where matchup.season_id = target_season_id
      and matchup.week = target_week
    group by matchup.id, matchup.week, matchup.phase, matchup.source_key
  ) as selected_matchups;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'week', award.week,
        'high_team_key', high_team.slug,
        'high_team_name', high_season_team.name,
        'high_score', award.high_score,
        'low_team_key', low_team.slug,
        'low_team_name', low_season_team.name,
        'low_score', award.low_score
      )
      order by award.week
    ),
    '[]'::jsonb
  )
  into awards_value
  from public.accepted_weekly_awards as award
  join public.season_teams as high_season_team
    on high_season_team.id = award.high_score_season_team_id
  join public.teams as high_team on high_team.id = high_season_team.team_id
  join public.season_teams as low_season_team
    on low_season_team.id = award.low_score_season_team_id
  join public.teams as low_team on low_team.id = low_season_team.team_id
  where award.season_id = target_season_id
    and award.week = target_week;

  return jsonb_build_object(
    'league', jsonb_build_object(
      'id', season_record.league_id,
      'name', season_record.league_name
    ),
    'season', jsonb_build_object(
      'id', season_record.id,
      'year', season_record.year,
      'name', season_record.name
    ),
    'selected_week', target_week,
    'standings', standings_value,
    'results', results_value,
    'awards', awards_value,
    'financial_context_included', false
  );
end;
$$;

comment on function public.get_commissioner_message_context(uuid, integer) is
  'Commissioner-only normalized ESPN and accepted competition facts for message drafting.';
