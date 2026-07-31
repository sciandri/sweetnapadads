begin;

select plan(16);

select has_column(
  'public',
  'matchups',
  'espn_sync_run_id',
  'matchups should reference their latest accepted ESPN evidence run'
);

select has_function(
  'public',
  'upsert_espn_matchup_results',
  array['uuid', 'uuid', 'uuid', 'jsonb'],
  'ESPN matchup ingestion function should exist'
);

select has_function(
  'public',
  'record_espn_competition_snapshot',
  array[
    'uuid', 'uuid', 'integer', 'text', 'text', 'text', 'integer', 'jsonb',
    'text', 'timestamp with time zone', 'bigint', 'text',
    'timestamp with time zone', 'jsonb', 'jsonb'
  ],
  'atomic ESPN competition wrapper should exist'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.upsert_espn_matchup_results(uuid,uuid,uuid,jsonb)',
    'execute'
  ),
  'service role should ingest ESPN matchups'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.upsert_espn_matchup_results(uuid,uuid,uuid,jsonb)',
    'execute'
  ),
  'authenticated users should not ingest ESPN matchups directly'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  'e0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'ESPN Test Opponent',
  'espn-test-opponent',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_teams (
  id, league_id, season_id, team_id, name, espn_team_id, status, created_by
) values (
  'e0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'e0000000-0000-4000-8000-000000000001',
  'ESPN Test Opponent 2026',
  2,
  'active',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.espn_sync_runs (
  id, league_id, season_id, sync_kind, scoring_period, source_revision,
  idempotency_key, status, finished_at
) values (
  'e0000000-0000-4000-8000-000000000003',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'standings',
  1,
  'sha256:test-matchups',
  'espn:test-matchups',
  'succeeded',
  '2026-09-09 12:00:00+00'
);

create temporary table matchup_ingest_result as
select public.upsert_espn_matchup_results(
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'e0000000-0000-4000-8000-000000000003',
  '[{
    "espn_matchup_id":1,
    "week":1,
    "phase":"regular_season",
    "source_key":"espn:12345:2026:matchup:1",
    "source_updated_at":"2026-09-09T12:00:00Z",
    "results":[
      {
        "season_team_id":"d0000000-0000-4000-8000-000000000008",
        "opponent_season_team_id":"e0000000-0000-4000-8000-000000000002",
        "espn_team_id":1,
        "score":121.25,
        "result":"win",
        "source_key":"espn:12345:2026:matchup:1:team:1"
      },
      {
        "season_team_id":"e0000000-0000-4000-8000-000000000002",
        "opponent_season_team_id":"d0000000-0000-4000-8000-000000000008",
        "espn_team_id":2,
        "score":99.50,
        "result":"loss",
        "source_key":"espn:12345:2026:matchup:1:team:2"
      }
    ]
  }]'::jsonb
) as result;

select is(
  (select (result ->> 'matchup_count')::integer from matchup_ingest_result),
  1,
  'ingestion should report one completed matchup'
);

select is(
  (select (result ->> 'result_count')::integer from matchup_ingest_result),
  2,
  'ingestion should report two reciprocal results'
);

select is(
  (select count(*) from public.matchups where source_type = 'espn'),
  1::bigint,
  'ingestion should store one ESPN matchup'
);

select is(
  (select count(*) from public.weekly_results where source_type = 'espn'),
  2::bigint,
  'ingestion should store both ESPN results'
);

select is(
  (
    select espn_sync_run_id
    from public.matchups
    where source_key = 'espn:12345:2026:matchup:1'
  ),
  'e0000000-0000-4000-8000-000000000003'::uuid,
  'the matchup should retain its supporting raw-evidence run'
);

select public.upsert_espn_matchup_results(
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'e0000000-0000-4000-8000-000000000003',
  '[{
    "week":1,
    "phase":"regular_season",
    "source_key":"espn:12345:2026:matchup:1",
    "source_updated_at":"2026-09-09T12:00:00Z",
    "results":[
      {"season_team_id":"d0000000-0000-4000-8000-000000000008","opponent_season_team_id":"e0000000-0000-4000-8000-000000000002","espn_team_id":1,"score":121.25,"result":"win","source_key":"espn:12345:2026:matchup:1:team:1"},
      {"season_team_id":"e0000000-0000-4000-8000-000000000002","opponent_season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":2,"score":99.50,"result":"loss","source_key":"espn:12345:2026:matchup:1:team:2"}
    ]
  }]'::jsonb
);

select is(
  (select count(*) from public.weekly_results where source_type = 'espn'),
  2::bigint,
  'an exact retry should not duplicate results'
);

select throws_ok(
  $$
    select public.upsert_espn_matchup_results(
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'e0000000-0000-4000-8000-000000000003',
      '[{
        "week":2,
        "phase":"regular_season",
        "source_key":"espn:12345:2026:matchup:2",
        "results":[
          {"season_team_id":"d0000000-0000-4000-8000-000000000008","opponent_season_team_id":"e0000000-0000-4000-8000-000000000002","espn_team_id":1,"score":80,"result":"win","source_key":"espn:12345:2026:matchup:2:team:1"},
          {"season_team_id":"e0000000-0000-4000-8000-000000000002","opponent_season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":2,"score":100,"result":"loss","source_key":"espn:12345:2026:matchup:2:team:2"}
        ]
      }]'::jsonb
    )
  $$,
  '22023',
  'ESPN matchup outcomes must agree with accepted scores',
  'outcomes that disagree with scores should fail closed'
);

select is(
  (select count(*) from public.matchups where source_type = 'espn'),
  1::bigint,
  'a rejected batch should leave no partial matchup'
);

select throws_ok(
  $$
    select public.record_espn_competition_snapshot(
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      2,
      'sha256:atomic-failure',
      'espn:atomic-failure',
      '/espn/atomic-test',
      200,
      '{"id":12345,"schedule":[]}'::jsonb,
      repeat('f', 64),
      '2026-09-16 12:00:00+00',
      12345,
      'espn:12345:2026:standings:2:atomic-failure',
      '2026-09-16 12:00:00+00',
      '[
        {"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":1,"official_rank":1,"playoff_seed":1,"wins":2,"losses":0,"ties":0,"points_for":220,"points_against":180,"streak":"W2","record_summary":"2-0","source_record":{}},
        {"season_team_id":"e0000000-0000-4000-8000-000000000002","espn_team_id":2,"official_rank":2,"playoff_seed":2,"wins":0,"losses":2,"ties":0,"points_for":180,"points_against":220,"streak":"L2","record_summary":"0-2","source_record":{}}
      ]'::jsonb,
      '[{
        "week":2,
        "phase":"regular_season",
        "source_key":"espn:12345:2026:matchup:atomic-failure",
        "results":[
          {"season_team_id":"d0000000-0000-4000-8000-000000000008","opponent_season_team_id":"e0000000-0000-4000-8000-000000000002","espn_team_id":1,"score":80,"result":"win","source_key":"espn:12345:2026:matchup:atomic-failure:team:1"},
          {"season_team_id":"e0000000-0000-4000-8000-000000000002","opponent_season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":2,"score":100,"result":"loss","source_key":"espn:12345:2026:matchup:atomic-failure:team:2"}
        ]
      }]'::jsonb
    )
  $$,
  '22023',
  'ESPN matchup outcomes must agree with accepted scores',
  'the competition wrapper should surface a matchup validation failure'
);

select is(
  (select count(*) from public.espn_sync_runs),
  1::bigint,
  'a matchup failure should roll back the new standings run'
);

select is(
  (select count(*) from public.espn_standings_snapshots),
  0::bigint,
  'a matchup failure should roll back the new standings snapshot'
);

select * from finish();
rollback;
