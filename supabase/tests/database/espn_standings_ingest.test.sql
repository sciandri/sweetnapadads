begin;

select plan(20);

select has_function(
  'public',
  'record_espn_standings_snapshot',
  array[
    'uuid', 'uuid', 'integer', 'text', 'text', 'text', 'integer',
    'jsonb', 'text', 'timestamp with time zone', 'bigint', 'text',
    'timestamp with time zone', 'jsonb'
  ],
  'atomic ESPN standings ingestion function should exist'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.record_espn_standings_snapshot(uuid,uuid,integer,text,text,text,integer,jsonb,text,timestamptz,bigint,text,timestamptz,jsonb)',
    'execute'
  ),
  'service role should execute ESPN ingestion'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.record_espn_standings_snapshot(uuid,uuid,integer,text,text,text,integer,jsonb,text,timestamptz,bigint,text,timestamptz,jsonb)',
    'execute'
  ),
  'authenticated users should not execute ESPN ingestion'
);

create temporary table ingest_result as
select public.record_espn_standings_snapshot(
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  1,
  'revision-ingest-1',
  'standings:2026:1:ingest-test',
  '/apis/v3/games/ffl/seasons/2026/segments/0/leagues/12345',
  200,
  '{"id":12345,"teams":[{"id":1}]}'::jsonb,
  repeat('b', 64),
  '2026-09-09 12:00:00+00',
  12345,
  'espn:12345:2026:standings:1:revision-ingest-1',
  '2026-09-09 12:00:00+00',
  '[{
    "season_team_id":"d0000000-0000-4000-8000-000000000008",
    "espn_team_id":1,
    "official_rank":1,
    "playoff_seed":1,
    "wins":1,
    "losses":0,
    "ties":0,
    "points_for":121.25,
    "points_against":99.50,
    "streak":"W1",
    "record_summary":"1-0",
    "source_record":{"id":1,"rankCalculatedFinal":1}
  }]'::jsonb
) as result;

select is(
  (select result ->> 'status' from ingest_result),
  'recorded',
  'first ingestion should record a new snapshot'
);

select is(
  (select (result ->> 'entry_count')::integer from ingest_result),
  1,
  'ingestion should report the exact entry count'
);

select is(
  (
    select status::text
    from public.espn_sync_runs
    where id = ((select result ->> 'run_id' from ingest_result)::uuid)
  ),
  'succeeded',
  'ingestion should finish the run only after all records exist'
);

select is(
  (select count(*) from public.espn_raw_payloads),
  1::bigint,
  'ingestion should preserve one raw payload'
);

select is(
  (select count(*) from public.espn_standings_snapshots),
  1::bigint,
  'ingestion should create one normalized snapshot'
);

select is(
  (select count(*) from public.espn_standing_entries),
  1::bigint,
  'ingestion should create every normalized entry'
);

select is(
  (
    select season_team_id
    from public.current_espn_standings
    where season_id = 'd0000000-0000-4000-8000-000000000004'
  ),
  'd0000000-0000-4000-8000-000000000008'::uuid,
  'the successful snapshot should become current'
);

create temporary table retry_result as
select public.record_espn_standings_snapshot(
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  1,
  'revision-ingest-1',
  'standings:2026:1:ingest-test',
  '/apis/v3/games/ffl/seasons/2026/segments/0/leagues/12345',
  200,
  '{"id":12345,"teams":[{"id":1}]}'::jsonb,
  repeat('b', 64),
  '2026-09-09 12:00:00+00',
  12345,
  'espn:12345:2026:standings:1:revision-ingest-1',
  '2026-09-09 12:00:00+00',
  '[{
    "season_team_id":"d0000000-0000-4000-8000-000000000008",
    "espn_team_id":1,
    "official_rank":1,
    "playoff_seed":1,
    "wins":1,
    "losses":0,
    "ties":0,
    "points_for":121.25,
    "points_against":99.50,
    "streak":"W1",
    "record_summary":"1-0",
    "source_record":{"id":1,"rankCalculatedFinal":1}
  }]'::jsonb
) as result;

select is(
  (select result ->> 'status' from retry_result),
  'already_recorded',
  'an exact retry should be an idempotent success'
);

select is(
  (select result ->> 'snapshot_id' from retry_result),
  (select result ->> 'snapshot_id' from ingest_result),
  'an exact retry should return the original snapshot'
);

select is(
  (select count(*) from public.espn_sync_runs),
  1::bigint,
  'an exact retry should not create another run'
);

select throws_ok(
  $$
    select public.record_espn_standings_snapshot(
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      1,
      'revision-ingest-1',
      'standings:2026:1:ingest-test',
      '/apis/v3/games/ffl/seasons/2026/segments/0/leagues/12345',
      200,
      '{"changed":true}'::jsonb,
      repeat('c', 64),
      '2026-09-09 12:00:00+00',
      12345,
      'espn:12345:2026:standings:1:revision-ingest-1',
      '2026-09-09 12:00:00+00',
      '[]'::jsonb
    )
  $$,
  '22023',
  'ESPN standings entries must be a non-empty array',
  'input validation should run before resolving an existing retry'
);

select throws_ok(
  $$
    select public.record_espn_standings_snapshot(
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      1,
      'revision-ingest-1',
      'standings:2026:1:ingest-test',
      '/apis/v3/games/ffl/seasons/2026/segments/0/leagues/12345',
      200,
      '{"changed":true}'::jsonb,
      repeat('c', 64),
      '2026-09-09 12:00:00+00',
      12345,
      'espn:12345:2026:standings:1:revision-ingest-1',
      '2026-09-09 12:00:00+00',
      '[{"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":1,"official_rank":1,"wins":1,"losses":0,"ties":0,"points_for":1,"points_against":1,"record_summary":"1-0","source_record":{}}]'::jsonb
    )
  $$,
  '23505',
  'ESPN idempotency key was reused with different source evidence',
  'a changed retry should fail closed'
);

select throws_ok(
  $$
    select public.record_espn_standings_snapshot(
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      2,
      'revision-ingest-gap',
      'standings:2026:2:gap',
      '/espn/test',
      200,
      '{}'::jsonb,
      repeat('d', 64),
      now(),
      12345,
      'espn:gap',
      now(),
      '[{"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":1,"official_rank":2,"wins":1,"losses":0,"ties":0,"points_for":1,"points_against":1,"record_summary":"1-0","source_record":{}}]'::jsonb
    )
  $$,
  '22023',
  'ESPN official ranks must be contiguous from one',
  'official ranks should reject gaps instead of being recalculated'
);

select throws_ok(
  $$
    select public.record_espn_standings_snapshot(
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      2,
      'revision-ingest-map',
      'standings:2026:2:mapping',
      '/espn/test',
      200,
      '{}'::jsonb,
      repeat('e', 64),
      now(),
      12345,
      'espn:mapping',
      now(),
      '[{"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":999,"official_rank":1,"wins":1,"losses":0,"ties":0,"points_for":1,"points_against":1,"record_summary":"1-0","source_record":{}}]'::jsonb
    )
  $$,
  '23503',
  'ESPN standings must exactly match active mapped season teams',
  'ingestion should reject a mismatched ESPN team mapping'
);

select throws_ok(
  $$
    select public.record_espn_standings_snapshot(
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      2,
      'revision-ingest-http',
      'standings:2026:2:http',
      '/espn/test',
      503,
      '{}'::jsonb,
      repeat('f', 64),
      now(),
      12345,
      'espn:http',
      now(),
      '[{}]'::jsonb
    )
  $$,
  '22023',
  'a successful standings snapshot requires a 2xx response',
  'failed HTTP responses should not be recorded as successful snapshots'
);

select throws_ok(
  $$
    select public.record_espn_standings_snapshot(
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      2,
      'revision-ingest-invalid',
      'standings:2026:2:invalid',
      '/espn/test',
      200,
      '{}'::jsonb,
      repeat('1', 64),
      now(),
      12345,
      'espn:invalid',
      now(),
      '[{"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":1,"official_rank":1,"wins":1,"losses":0,"ties":0,"points_for":-1,"points_against":1,"record_summary":"1-0","source_record":{}}]'::jsonb
    )
  $$,
  '23514',
  null,
  'entry constraints should reject invalid normalized source values'
);

select is(
  (select count(*) from public.espn_sync_runs),
  1::bigint,
  'failed ingestion should leave no partial run or source records'
);

select * from finish();
rollback;
