begin;

select plan(19);

select has_table('public', 'manual_result_batches', 'manual result audit table should exist');
select has_function(
  'public',
  'record_manual_week_results',
  array['uuid', 'integer', 'text', 'text', 'jsonb'],
  'atomic manual result function should exist'
);
select ok(
  not has_table_privilege('authenticated', 'public.matchups', 'insert')
  and not has_table_privilege('authenticated', 'public.weekly_results', 'insert'),
  'authenticated callers should not bypass the audited function'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  'a1000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'Manual Results Opponent',
  'manual-results-opponent',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_teams (
  id, league_id, season_id, team_id, name, status, created_by
) values (
  'a1000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'a1000000-0000-4000-8000-000000000001',
  'Manual Results Opponent 2026',
  'active',
  'd0000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);

select is(
  public.record_manual_week_results(
    'd0000000-0000-4000-8000-000000000004',
    2,
    'ESPN did not publish final results for this week.',
    'manual:test:week-2',
    jsonb_build_array(jsonb_build_object(
      'home_season_team_id', 'd0000000-0000-4000-8000-000000000008',
      'away_season_team_id', 'a1000000-0000-4000-8000-000000000002',
      'home_score', 121.25,
      'away_score', 98.75
    ))
  ) ->> 'status',
  'recorded',
  'commissioner should record a previously missing complete week'
);

reset role;

select is((select count(*) from public.manual_result_batches), 1::bigint, 'one immutable audit batch should be stored');
select is((select count(*) from public.matchups where week = 2), 1::bigint, 'one manual matchup should be stored');
select is((select count(*) from public.weekly_results where source_type = 'manual'), 2::bigint, 'two reciprocal results should be stored');
select is(
  (select result::text from public.weekly_results where score = 121.25),
  'win',
  'outcome should be derived from the accepted score'
);
select is(
  (select opponent_season_team_id from public.weekly_results where score = 121.25),
  'a1000000-0000-4000-8000-000000000002'::uuid,
  'manual result opponents should be reciprocal'
);
select is((select count(*) from public.weekly_awards where week = 2), 1::bigint, 'regular-season results should derive one weekly award');
select is(
  (select count(*) from public.financial_obligations where source_key in ('rule:weekly-high:2', 'rule:weekly-low:2')),
  2::bigint,
  'configured weekly award obligations should be generated'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);

select is(
  public.record_manual_week_results(
    'd0000000-0000-4000-8000-000000000004', 2,
    'ESPN did not publish final results for this week.',
    'manual:test:week-2',
    '[{"home_season_team_id":"d0000000-0000-4000-8000-000000000008","away_season_team_id":"a1000000-0000-4000-8000-000000000002","home_score":121.25,"away_score":98.75}]'::jsonb
  ) ->> 'status',
  'already_recorded',
  'exact retries should be idempotent'
);

select throws_ok(
  $$ select public.record_manual_week_results(
    'd0000000-0000-4000-8000-000000000004', 2,
    'A changed reason is deliberately rejected here.',
    'manual:test:week-2',
    '[{"home_season_team_id":"d0000000-0000-4000-8000-000000000008","away_season_team_id":"a1000000-0000-4000-8000-000000000002","home_score":121.25,"away_score":98.75}]'::jsonb
  ) $$,
  '23505',
  'manual result request key was reused with different evidence',
  'changed idempotency evidence should fail closed'
);

select throws_ok(
  $$ select public.record_manual_week_results(
    'd0000000-0000-4000-8000-000000000004', 2,
    'A second submission must use the correction workflow.',
    'manual:test:week-2-second',
    '[{"home_season_team_id":"d0000000-0000-4000-8000-000000000008","away_season_team_id":"a1000000-0000-4000-8000-000000000002","home_score":121.25,"away_score":98.75}]'::jsonb
  ) $$,
  '23505',
  'accepted results already exist for this week; use the correction workflow',
  'accepted weeks should not be overwritten'
);

select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
select throws_ok(
  $$ select public.record_manual_week_results(
    'd0000000-0000-4000-8000-000000000004', 3,
    'An outsider must never record league results.',
    'manual:test:outsider',
    '[{"home_season_team_id":"d0000000-0000-4000-8000-000000000008","away_season_team_id":"a1000000-0000-4000-8000-000000000002","home_score":1,"away_score":2}]'::jsonb
  ) $$,
  '42501',
  'only an active commissioner may record manual results',
  'outsiders should be rejected inside PostgreSQL'
);

reset role;

select throws_ok(
  $$ update public.manual_result_batches set reason = 'This mutation must be rejected.' $$,
  '55000',
  'manual result batches are immutable',
  'audit batches should be immutable even to privileged callers'
);

select throws_ok(
  $$ update public.matchups set week = 4 where source_type = 'manual' $$,
  '55000',
  'manual competition history is immutable',
  'manual matchups should be immutable even to privileged callers'
);

select throws_ok(
  $$ delete from public.weekly_results where source_type = 'manual' $$,
  '55000',
  'manual competition history is immutable',
  'manual results should be immutable even to privileged callers'
);

select is((select count(*) from public.manual_result_batches), 1::bigint, 'rejections and retries should create no duplicate batches');

select * from finish();
rollback;
