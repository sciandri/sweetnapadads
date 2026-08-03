begin;

select plan(23);

select has_table('public', 'result_correction_batches', 'result correction audit table should exist');
select has_view('public', 'accepted_matchups', 'accepted matchup projection should exist');
select has_view('public', 'accepted_weekly_results', 'accepted result projection should exist');
select has_view('public', 'accepted_weekly_awards', 'accepted award projection should exist');
select has_function(
  'public',
  'record_week_result_correction',
  array['uuid', 'integer', 'text', 'text', 'jsonb'],
  'atomic accepted-week correction function should exist'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  'a2000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'Correction Opponent',
  'correction-opponent',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_teams (
  id, league_id, season_id, team_id, name, status, created_by
) values (
  'a2000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'a2000000-0000-4000-8000-000000000001',
  'Correction Opponent 2026',
  'active',
  'd0000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);

select is(
  public.record_manual_week_results(
    'd0000000-0000-4000-8000-000000000004',
    4,
    'ESPN did not supply the original accepted week.',
    'correction:test:original',
    '[{"home_season_team_id":"d0000000-0000-4000-8000-000000000008","away_season_team_id":"a2000000-0000-4000-8000-000000000002","home_score":120,"away_score":90}]'::jsonb
  ) ->> 'status',
  'recorded',
  'test setup should create the original accepted week'
);

select is(
  public.record_week_result_correction(
    'd0000000-0000-4000-8000-000000000004',
    4,
    'The original scores were transposed by the commissioner.',
    'correction:test:week-4:v1',
    '[{"home_season_team_id":"d0000000-0000-4000-8000-000000000008","away_season_team_id":"a2000000-0000-4000-8000-000000000002","home_score":90,"away_score":120}]'::jsonb
  ) ->> 'status',
  'recorded',
  'commissioner should append a complete accepted-week correction'
);

reset role;

select is((select count(*) from public.result_correction_batches), 1::bigint, 'one correction audit batch should be stored');
select is((select count(*) from public.weekly_results where season_id = 'd0000000-0000-4000-8000-000000000004' and source_type = 'manual'), 4::bigint, 'original and corrected result evidence should both remain stored');
select is((select count(*) from public.accepted_weekly_results where season_id = 'd0000000-0000-4000-8000-000000000004'), 2::bigint, 'accepted projection should expose one corrected result per active team');
select is(
  (select score from public.accepted_weekly_results where season_team_id = 'a2000000-0000-4000-8000-000000000002'),
  120.00::numeric,
  'accepted projection should expose the corrected score'
);
select is(
  (select high_score_season_team_id from public.accepted_weekly_awards where week = 4),
  'a2000000-0000-4000-8000-000000000002'::uuid,
  'accepted award should follow the corrected high score'
);
select is((select count(*) from public.financial_adjustments where source_key like 'correction:%'), 2::bigint, 'correction should neutralize both displaced obligations');
select is((select count(*) from public.financial_obligations where source_key like 'correction:%'), 2::bigint, 'correction should append replacement obligations');
select is(
  (select balance_cents from public.team_financial_balances where season_team_id = 'd0000000-0000-4000-8000-000000000008'),
  15000::bigint,
  'corrected former winner balance should retain seed finance and add only the new low penalty'
);
select is(
  (select balance_cents from public.team_financial_balances where season_team_id = 'a2000000-0000-4000-8000-000000000002'),
  (-2500)::bigint,
  'corrected former low team should receive only the replacement high payout'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);

select is(
  public.record_week_result_correction(
    'd0000000-0000-4000-8000-000000000004', 4,
    'The original scores were transposed by the commissioner.',
    'correction:test:week-4:v1',
    '[{"home_season_team_id":"d0000000-0000-4000-8000-000000000008","away_season_team_id":"a2000000-0000-4000-8000-000000000002","home_score":90,"away_score":120}]'::jsonb
  ) ->> 'status',
  'already_recorded',
  'exact correction retry should be idempotent'
);

select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
select throws_ok(
  $$ select public.record_week_result_correction(
    'd0000000-0000-4000-8000-000000000004', 4,
    'An outsider must not append a correction batch.',
    'correction:test:outsider',
    '[{"home_season_team_id":"d0000000-0000-4000-8000-000000000008","away_season_team_id":"a2000000-0000-4000-8000-000000000002","home_score":90,"away_score":120}]'::jsonb
  ) $$,
  '42501',
  'only an active commissioner may correct results',
  'outsiders should be rejected inside PostgreSQL'
);

reset role;

select throws_ok(
  $$ update public.result_correction_batches set reason = 'This change must be rejected.' $$,
  '55000',
  'result correction batches are immutable',
  'correction audit batches should be immutable'
);
select throws_ok(
  $$ update public.weekly_results set score = 1 where result_correction_batch_id is not null $$,
  '55000',
  'manual competition history is immutable',
  'corrected result evidence should be immutable'
);
select is((select count(*) from public.result_correction_batches), 1::bigint, 'retries and rejections should create no duplicate correction batches');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);
select is((select count(*) from public.result_correction_batches), 1::bigint, 'commissioner should read correction audit evidence through RLS');
select is((select count(*) from public.accepted_matchups where week = 4), 1::bigint, 'commissioner should read the corrected accepted matchup through RLS');

select * from finish();
rollback;
