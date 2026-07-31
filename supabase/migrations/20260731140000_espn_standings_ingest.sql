create or replace function public.record_espn_standings_snapshot(
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
  target_entries jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_run public.espn_sync_runs%rowtype;
  existing_snapshot public.espn_standings_snapshots%rowtype;
  existing_payload public.espn_raw_payloads%rowtype;
  new_run_id uuid := gen_random_uuid();
  new_payload_id uuid := gen_random_uuid();
  new_snapshot_id uuid := gen_random_uuid();
  entry_count integer;
  mapped_entry_count integer;
  active_mapped_team_count integer;
begin
  if target_scoring_period is not null and target_scoring_period <= 0 then
    raise exception using
      errcode = '22023',
      message = 'ESPN scoring period must be positive';
  end if;

  if target_http_status < 200 or target_http_status >= 300 then
    raise exception using
      errcode = '22023',
      message = 'a successful standings snapshot requires a 2xx response';
  end if;

  if jsonb_typeof(target_entries) <> 'array'
     or jsonb_array_length(target_entries) = 0 then
    raise exception using
      errcode = '22023',
      message = 'ESPN standings entries must be a non-empty array';
  end if;

  if not exists (
    select 1
    from public.seasons as season
    where season.id = target_season_id
      and season.league_id = target_league_id
  ) then
    raise exception using
      errcode = '23503',
      message = 'ESPN standings season does not belong to the supplied league';
  end if;

  select run.*
  into existing_run
  from public.espn_sync_runs as run
  where run.season_id = target_season_id
    and run.sync_kind = 'standings'
    and run.idempotency_key = target_idempotency_key;

  if found then
    select snapshot.*
    into existing_snapshot
    from public.espn_standings_snapshots as snapshot
    where snapshot.run_id = existing_run.id;

    select payload.*
    into existing_payload
    from public.espn_raw_payloads as payload
    where payload.run_id = existing_run.id
      and payload.payload_kind = 'standings';

    if existing_run.status <> 'succeeded'
       or existing_snapshot.id is null
       or existing_payload.id is null then
      raise exception using
        errcode = '55000',
        message = 'ESPN idempotency key belongs to an incomplete sync run';
    end if;

    if existing_run.league_id <> target_league_id
       or existing_run.scoring_period is distinct from target_scoring_period
       or existing_run.source_revision <> target_source_revision
       or existing_payload.payload_sha256 <> target_payload_sha256
       or existing_snapshot.espn_league_id <> target_espn_league_id
       or existing_snapshot.source_key <> target_source_key
       or existing_snapshot.captured_at <> target_captured_at then
      raise exception using
        errcode = '23505',
        message = 'ESPN idempotency key was reused with different source evidence';
    end if;

    return jsonb_build_object(
      'status', 'already_recorded',
      'run_id', existing_run.id,
      'raw_payload_id', existing_payload.id,
      'snapshot_id', existing_snapshot.id,
      'entry_count', (
        select count(*)
        from public.espn_standing_entries as entry
        where entry.snapshot_id = existing_snapshot.id
      )
    );
  end if;

  with entries as (
    select *
    from jsonb_to_recordset(target_entries) as entry(
      season_team_id uuid,
      espn_team_id integer,
      official_rank integer,
      playoff_seed integer,
      wins integer,
      losses integer,
      ties integer,
      points_for numeric(10, 2),
      points_against numeric(10, 2),
      streak text,
      record_summary text,
      source_record jsonb
    )
  )
  select count(*)
  into entry_count
  from entries;

  if entry_count <> jsonb_array_length(target_entries) then
    raise exception using
      errcode = '22023',
      message = 'every ESPN standings entry must be an object';
  end if;

  if exists (
    with entries as (
      select *
      from jsonb_to_recordset(target_entries) as entry(
        season_team_id uuid,
        espn_team_id integer,
        official_rank integer
      )
    )
    select 1
    from entries
    group by official_rank
    having count(*) > 1
  ) or exists (
    with entries as (
      select *
      from jsonb_to_recordset(target_entries) as entry(
        season_team_id uuid,
        espn_team_id integer,
        official_rank integer
      )
    )
    select 1
    from entries
    group by season_team_id
    having count(*) > 1
  ) or exists (
    with entries as (
      select *
      from jsonb_to_recordset(target_entries) as entry(
        season_team_id uuid,
        espn_team_id integer,
        official_rank integer
      )
    )
    select 1
    from entries
    group by espn_team_id
    having count(*) > 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'ESPN standings ranks and team identifiers must be unique';
  end if;

  if (
    select min((item ->> 'official_rank')::integer) <> 1
      or max((item ->> 'official_rank')::integer) <> entry_count
    from jsonb_array_elements(target_entries) as item
  ) then
    raise exception using
      errcode = '22023',
      message = 'ESPN official ranks must be contiguous from one';
  end if;

  with entries as (
    select *
    from jsonb_to_recordset(target_entries) as entry(
      season_team_id uuid,
      espn_team_id integer
    )
  )
  select count(*)
  into mapped_entry_count
  from entries
  join public.season_teams as season_team
    on season_team.id = entries.season_team_id
   and season_team.league_id = target_league_id
   and season_team.season_id = target_season_id
   and season_team.espn_team_id = entries.espn_team_id
   and season_team.status = 'active';

  select count(*)
  into active_mapped_team_count
  from public.season_teams as season_team
  where season_team.league_id = target_league_id
    and season_team.season_id = target_season_id
    and season_team.status = 'active'
    and season_team.espn_team_id is not null;

  if mapped_entry_count <> entry_count
     or active_mapped_team_count <> entry_count then
    raise exception using
      errcode = '23503',
      message = 'ESPN standings must exactly match active mapped season teams';
  end if;

  insert into public.espn_sync_runs (
    id,
    league_id,
    season_id,
    sync_kind,
    scoring_period,
    source_revision,
    idempotency_key,
    status
  ) values (
    new_run_id,
    target_league_id,
    target_season_id,
    'standings',
    target_scoring_period,
    target_source_revision,
    target_idempotency_key,
    'running'
  );

  insert into public.espn_raw_payloads (
    id,
    run_id,
    league_id,
    season_id,
    payload_kind,
    endpoint_path,
    http_status,
    payload,
    payload_sha256,
    fetched_at
  ) values (
    new_payload_id,
    new_run_id,
    target_league_id,
    target_season_id,
    'standings',
    target_endpoint_path,
    target_http_status,
    target_raw_payload,
    target_payload_sha256,
    target_fetched_at
  );

  insert into public.espn_standings_snapshots (
    id,
    run_id,
    raw_payload_id,
    league_id,
    season_id,
    espn_league_id,
    scoring_period,
    source_revision,
    source_key,
    captured_at
  ) values (
    new_snapshot_id,
    new_run_id,
    new_payload_id,
    target_league_id,
    target_season_id,
    target_espn_league_id,
    target_scoring_period,
    target_source_revision,
    target_source_key,
    target_captured_at
  );

  insert into public.espn_standing_entries (
    snapshot_id,
    league_id,
    season_id,
    season_team_id,
    espn_team_id,
    official_rank,
    playoff_seed,
    wins,
    losses,
    ties,
    points_for,
    points_against,
    streak,
    record_summary,
    source_record
  )
  select
    new_snapshot_id,
    target_league_id,
    target_season_id,
    entry.season_team_id,
    entry.espn_team_id,
    entry.official_rank,
    entry.playoff_seed,
    entry.wins,
    entry.losses,
    entry.ties,
    entry.points_for,
    entry.points_against,
    entry.streak,
    entry.record_summary,
    entry.source_record
  from jsonb_to_recordset(target_entries) as entry(
    season_team_id uuid,
    espn_team_id integer,
    official_rank integer,
    playoff_seed integer,
    wins integer,
    losses integer,
    ties integer,
    points_for numeric(10, 2),
    points_against numeric(10, 2),
    streak text,
    record_summary text,
    source_record jsonb
  );

  update public.espn_sync_runs
  set
    status = 'succeeded',
    finished_at = timezone('utc', statement_timestamp())
  where id = new_run_id;

  return jsonb_build_object(
    'status', 'recorded',
    'run_id', new_run_id,
    'raw_payload_id', new_payload_id,
    'snapshot_id', new_snapshot_id,
    'entry_count', entry_count
  );
end;
$$;

comment on function public.record_espn_standings_snapshot(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  integer,
  jsonb,
  text,
  timestamptz,
  bigint,
  text,
  timestamptz,
  jsonb
) is
  'Atomically records raw ESPN evidence and a complete official-order standings snapshot.';

revoke all on function public.record_espn_standings_snapshot(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  integer,
  jsonb,
  text,
  timestamptz,
  bigint,
  text,
  timestamptz,
  jsonb
) from public, anon, authenticated;

grant execute on function public.record_espn_standings_snapshot(
  uuid,
  uuid,
  integer,
  text,
  text,
  text,
  integer,
  jsonb,
  text,
  timestamptz,
  bigint,
  text,
  timestamptz,
  jsonb
) to service_role;
