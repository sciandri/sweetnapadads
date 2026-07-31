begin;

select plan(34);

select has_type(
  'public',
  'espn_sync_status',
  'ESPN sync status enum should exist'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'espn_sync_runs',
        'espn_raw_payloads',
        'espn_standings_snapshots',
        'espn_standing_entries'
      )
      and pg_class.relkind = 'r'
  ),
  4::bigint,
  'ESPN sync and standings tables should exist'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'espn_sync_runs',
        'espn_raw_payloads',
        'espn_standings_snapshots',
        'espn_standing_entries'
      )
      and pg_class.relrowsecurity
  ),
  4::bigint,
  'every ESPN source table should have RLS enabled'
);

select is(
  (
    select reloptions @> array['security_invoker=true']
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'current_espn_standings'
  ),
  true,
  'current ESPN standings should use caller RLS'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.espn_standing_entries',
    'insert'
  ),
  'authenticated callers should not write ESPN facts directly'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.get_commissioner_message_context(uuid,integer)',
    'execute'
  ),
  'authenticated commissioners should be able to request message context'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  'f1000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'Official Order Opponent',
  'official-order-opponent',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_teams (
  id,
  league_id,
  season_id,
  team_id,
  name,
  abbreviation,
  espn_team_id,
  status,
  created_by
)
values (
  'f1000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'f1000000-0000-4000-8000-000000000001',
  'Official Order Opponent 2026',
  'ORD',
  2,
  'active',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.espn_sync_runs (
  id,
  league_id,
  season_id,
  sync_kind,
  scoring_period,
  source_revision,
  idempotency_key,
  status,
  started_at,
  finished_at,
  created_by
)
values (
  'f2000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'standings',
  8,
  'espn-revision-1',
  'standings:2026:8:revision-1',
  'succeeded',
  '2026-10-27 12:00:00+00',
  '2026-10-27 12:00:02+00',
  'd0000000-0000-4000-8000-000000000001'
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
)
values (
  'f3000000-0000-4000-8000-000000000001',
  'f2000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'standings',
  '/apis/v3/games/ffl/seasons/2026/segments/0/leagues/12345',
  200,
  '{"id":12345,"status":"success","teams":[1,2]}'::jsonb,
  repeat('a', 64),
  '2026-10-27 12:00:01+00'
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
)
values (
  'f4000000-0000-4000-8000-000000000001',
  'f2000000-0000-4000-8000-000000000001',
  'f3000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  12345,
  8,
  'espn-revision-1',
  'espn:12345:2026:standings:8:revision-1',
  '2026-10-27 12:00:01+00'
);

insert into public.espn_standing_entries (
  id,
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
values
  (
    'f5000000-0000-4000-8000-000000000001',
    'f4000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'f1000000-0000-4000-8000-000000000002',
    2,
    1,
    1,
    5,
    3,
    0,
    799.25,
    780.75,
    'W2',
    '5-3',
    '{"rankCalculatedFinal":1,"id":2}'::jsonb
  ),
  (
    'f5000000-0000-4000-8000-000000000002',
    'f4000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000008',
    1,
    2,
    2,
    7,
    1,
    0,
    901.50,
    710.10,
    'W5',
    '7-1',
    '{"rankCalculatedFinal":2,"id":1}'::jsonb
  );

select is(
  (select count(*) from public.current_espn_standings),
  2::bigint,
  'current standings should expose every entry from the latest success'
);

select is(
  (
    select season_team_id
    from public.current_espn_standings
    order by official_rank
    limit 1
  ),
  'f1000000-0000-4000-8000-000000000002'::uuid,
  'standings should preserve ESPN rank instead of ordering by local wins'
);

select is(
  (
    select record_summary
    from public.current_espn_standings
    where official_rank = 1
  ),
  '5-3',
  'standings should preserve ESPN record text exactly'
);

select is(
  (
    select points_for::text
    from public.current_espn_standings
    where official_rank = 2
  ),
  '901.50',
  'standings should preserve exact source points'
);

select is(
  (
    select raw_payload_id
    from public.current_espn_standings
    limit 1
  ),
  'f3000000-0000-4000-8000-000000000001'::uuid,
  'normalized standings should trace to raw ESPN evidence'
);

select throws_ok(
  $$
    update public.espn_raw_payloads
    set payload = '{"changed":true}'::jsonb
    where id = 'f3000000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'ESPN source snapshots and payloads are immutable',
  'raw ESPN payloads should be immutable'
);

select throws_ok(
  $$
    delete from public.espn_raw_payloads
    where id = 'f3000000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'ESPN source snapshots and payloads are immutable',
  'raw ESPN payloads should not be deleted'
);

select throws_ok(
  $$
    update public.espn_standings_snapshots
    set captured_at = now()
    where id = 'f4000000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'ESPN source snapshots and payloads are immutable',
  'official standings snapshots should be immutable'
);

select throws_ok(
  $$
    update public.espn_standing_entries
    set official_rank = 2
    where id = 'f5000000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'ESPN source snapshots and payloads are immutable',
  'official standings entries should be immutable'
);

select throws_ok(
  $$
    insert into public.espn_sync_runs (
      league_id,
      season_id,
      sync_kind,
      source_revision,
      idempotency_key,
      created_by
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'standings',
      'duplicate',
      'standings:2026:8:revision-1',
      'd0000000-0000-4000-8000-000000000001'
    )
  $$,
  '23505',
  null,
  'sync idempotency keys should prevent duplicate runs'
);

select throws_ok(
  $$
    insert into public.espn_standing_entries (
      snapshot_id,
      league_id,
      season_id,
      season_team_id,
      espn_team_id,
      official_rank,
      wins,
      losses,
      ties,
      points_for,
      points_against,
      record_summary,
      source_record
    )
    values (
      'f4000000-0000-4000-8000-000000000001',
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'd0000000-0000-4000-8000-000000000008',
      99,
      1,
      0,
      0,
      0,
      0,
      0,
      '0-0',
      '{}'::jsonb
    )
  $$,
  '23505',
  null,
  'one ESPN rank should identify only one team per snapshot'
);

select throws_ok(
  $$
    insert into public.espn_standing_entries (
      snapshot_id,
      league_id,
      season_id,
      season_team_id,
      espn_team_id,
      official_rank,
      wins,
      losses,
      ties,
      points_for,
      points_against,
      record_summary,
      source_record
    )
    values (
      'f4000000-0000-4000-8000-000000000001',
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'f1000000-0000-4000-8000-000000000002',
      99,
      3,
      0,
      0,
      0,
      0,
      0,
      '0-0',
      '{}'::jsonb
    )
  $$,
  '23505',
  null,
  'one team should appear only once in a standings snapshot'
);

insert into public.espn_sync_runs (
  id,
  league_id,
  season_id,
  sync_kind,
  scoring_period,
  source_revision,
  idempotency_key,
  created_by
)
values (
  'f2000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'standings',
  9,
  'espn-revision-2',
  'standings:2026:9:revision-2',
  'd0000000-0000-4000-8000-000000000001'
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
)
values (
  'f3000000-0000-4000-8000-000000000002',
  'f2000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'standings',
  '/apis/v3/games/ffl/seasons/2026/segments/0/leagues/12345',
  200,
  '{"id":12345,"status":"success","week":9}'::jsonb,
  repeat('b', 64),
  '2026-11-03 12:00:01+00'
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
)
values (
  'f4000000-0000-4000-8000-000000000002',
  'f2000000-0000-4000-8000-000000000002',
  'f3000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  12345,
  9,
  'espn-revision-2',
  'espn:12345:2026:standings:9:revision-2',
  '2026-11-03 12:00:01+00'
);

insert into public.espn_standing_entries (
  snapshot_id,
  league_id,
  season_id,
  season_team_id,
  espn_team_id,
  official_rank,
  wins,
  losses,
  ties,
  points_for,
  points_against,
  record_summary,
  source_record
)
values
  (
    'f4000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000008',
    1,
    1,
    8,
    1,
    0,
    1010.10,
    800.20,
    '8-1',
    '{"rankCalculatedFinal":1,"id":1}'::jsonb
  ),
  (
    'f4000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'f1000000-0000-4000-8000-000000000002',
    2,
    2,
    5,
    4,
    0,
    900.30,
    899.10,
    '5-4',
    '{"rankCalculatedFinal":2,"id":2}'::jsonb
  );

select is(
  (
    select snapshot_id
    from public.current_espn_standings
    limit 1
  ),
  'f4000000-0000-4000-8000-000000000001'::uuid,
  'a newer running snapshot should not replace the last success'
);

update public.espn_sync_runs
set
  status = 'succeeded',
  finished_at = '2026-11-03 12:00:02+00'
where id = 'f2000000-0000-4000-8000-000000000002';

select is(
  (
    select snapshot_id
    from public.current_espn_standings
    limit 1
  ),
  'f4000000-0000-4000-8000-000000000002'::uuid,
  'the latest successful snapshot should become current atomically'
);

insert into public.matchups (
  id,
  league_id,
  season_id,
  week,
  phase,
  source_type,
  source_key,
  created_by
)
values (
  'f7000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  9,
  'regular_season',
  'espn',
  'espn:test:matchup:9:1:2',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.weekly_results (
  matchup_id,
  league_id,
  season_id,
  season_team_id,
  opponent_season_team_id,
  score,
  result,
  source_type,
  source_key,
  created_by
)
values
  (
    'f7000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000008',
    'f1000000-0000-4000-8000-000000000002',
    111.11,
    'win',
    'espn',
    'espn:test:weekly_result:9:1',
    'd0000000-0000-4000-8000-000000000001'
  ),
  (
    'f7000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'f1000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000008',
    99.99,
    'loss',
    'espn',
    'espn:test:weekly_result:9:2',
    'd0000000-0000-4000-8000-000000000001'
  );

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    'f6000000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    'espn-member@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"ESPN Member"}',
    timezone('utc', statement_timestamp()),
    timezone('utc', statement_timestamp())
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'f6000000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    'espn-outsider@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"ESPN Outsider"}',
    timezone('utc', statement_timestamp()),
    timezone('utc', statement_timestamp())
  );

insert into public.league_memberships (
  league_id,
  user_id,
  role,
  status,
  joined_at,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000002',
  'f6000000-0000-4000-8000-000000000001',
  'member',
  'active',
  timezone('utc', statement_timestamp()),
  'd0000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

select is(
  (select count(*) from public.current_espn_standings),
  2::bigint,
  'commissioners should read current ESPN standings'
);

select is(
  (select count(*) from public.espn_raw_payloads),
  2::bigint,
  'commissioners should inspect raw ESPN evidence'
);

select is(
  public.get_commissioner_message_context(
    'd0000000-0000-4000-8000-000000000004',
    9
  ) #>> '{league,name}',
  'Sweet Looking Napa Dads Development',
  'message context should include the authorized league identity'
);

select is(
  public.get_commissioner_message_context(
    'd0000000-0000-4000-8000-000000000004',
    9
  ) #>> '{standings,official_order,0,team_name}',
  'Development Franchise 2026',
  'message context should preserve current ESPN order'
);

select is(
  public.get_commissioner_message_context(
    'd0000000-0000-4000-8000-000000000004',
    9
  ) #>> '{standings,source}',
  'espn',
  'message context should identify ESPN as standings authority'
);

select is(
  jsonb_array_length(
    public.get_commissioner_message_context(
      'd0000000-0000-4000-8000-000000000004',
      9
    ) -> 'results'
  ),
  1,
  'message context should collapse reciprocal rows into one matchup'
);

select is(
  public.get_commissioner_message_context(
    'd0000000-0000-4000-8000-000000000004',
    9
  ) #>> '{results,0,teams,0,score}',
  '111.11',
  'message context should preserve exact selected-week scores'
);

select is(
  (
    public.get_commissioner_message_context(
      'd0000000-0000-4000-8000-000000000004',
      9
    ) ->> 'financial_context_included'
  )::boolean,
  false,
  'initial message context should exclude financial information'
);

select throws_ok(
  $$
    select public.get_commissioner_message_context(
      'd0000000-0000-4000-8000-000000000004',
      0
    )
  $$,
  '22023',
  'message context week must be between 1 and 30',
  'message context should validate the selected week'
);

select set_config(
  'request.jwt.claim.sub',
  'f6000000-0000-4000-8000-000000000001',
  true
);

select is(
  (select count(*) from public.current_espn_standings),
  2::bigint,
  'members should read official current standings'
);

select is(
  (select count(*) from public.espn_raw_payloads),
  0::bigint,
  'ordinary members should not read private raw ESPN payloads'
);

select throws_ok(
  $$
    select public.get_commissioner_message_context(
      'd0000000-0000-4000-8000-000000000004',
      9
    )
  $$,
  '42501',
  'only an active league commissioner can assemble message context',
  'ordinary members should not assemble AI message context'
);

select set_config(
  'request.jwt.claim.sub',
  'f6000000-0000-4000-8000-000000000002',
  true
);

select is(
  (select count(*) from public.current_espn_standings),
  0::bigint,
  'outsiders should not read standings'
);

select is(
  (select count(*) from public.espn_raw_payloads),
  0::bigint,
  'outsiders should not read raw ESPN evidence'
);

reset role;

select * from finish();
rollback;
