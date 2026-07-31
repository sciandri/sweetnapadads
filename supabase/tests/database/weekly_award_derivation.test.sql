begin;

select plan(20);

select has_type(
  'public',
  'weekly_award_tie_policy',
  'weekly award tie policy should be season-scoped data'
);

select has_column(
  'public',
  'season_settings',
  'weekly_award_tie_policy',
  'season settings should record the tie policy'
);

select has_function(
  'public',
  'derive_weekly_award',
  array['uuid', 'integer'],
  'weekly award derivation function should exist'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.derive_weekly_award(uuid,integer)',
    'execute'
  ),
  'service role should derive weekly awards'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.derive_weekly_award(uuid,integer)',
    'execute'
  ),
  'authenticated callers should not derive financial events directly'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  'f0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'Award Test Opponent',
  'award-test-opponent',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_teams (
  id, league_id, season_id, team_id, name, espn_team_id, status, created_by
) values (
  'f0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'f0000000-0000-4000-8000-000000000001',
  'Award Test Opponent 2026',
  2,
  'active',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.matchups (
  id, league_id, season_id, week, phase, source_type, source_key
) values
  (
    'f0000000-0000-4000-8000-000000000003',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    1,
    'regular_season',
    'espn',
    'espn:award-test:matchup:1'
  ),
  (
    'f0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    2,
    'regular_season',
    'espn',
    'espn:award-test:matchup:2'
  );

insert into public.weekly_results (
  league_id, season_id, matchup_id, season_team_id,
  opponent_season_team_id, score, result, source_type, source_key
) values
  (
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'f0000000-0000-4000-8000-000000000003',
    'd0000000-0000-4000-8000-000000000008',
    'f0000000-0000-4000-8000-000000000002',
    125.50,
    'win',
    'espn',
    'espn:award-test:result:1:team:1'
  ),
  (
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'f0000000-0000-4000-8000-000000000003',
    'f0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000008',
    99.25,
    'loss',
    'espn',
    'espn:award-test:result:1:team:2'
  ),
  (
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'f0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000008',
    'f0000000-0000-4000-8000-000000000002',
    110.00,
    'tie',
    'espn',
    'espn:award-test:result:2:team:1'
  ),
  (
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'f0000000-0000-4000-8000-000000000004',
    'f0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000008',
    110.00,
    'tie',
    'espn',
    'espn:award-test:result:2:team:2'
  );

create temporary table award_result as
select public.derive_weekly_award(
  'd0000000-0000-4000-8000-000000000004',
  1
) as result;

select is(
  (select result ->> 'status' from award_result),
  'derived',
  'a complete unique-score week should derive an award'
);

select is(
  (select count(*) from public.weekly_awards where week = 1),
  1::bigint,
  'derivation should store one weekly award'
);

select is(
  (
    select count(*)
    from public.financial_obligations
    where category in ('weekly_high_score', 'weekly_low_score_penalty')
  ),
  2::bigint,
  'derivation should create exactly two rule obligations'
);

select is(
  (
    select amount_cents::bigint
    from public.financial_obligations
    where category = 'weekly_high_score'
  ),
  2500::bigint,
  'the high-score payout should use the season rule in cents'
);

select is(
  (
    select direction::text
    from public.financial_obligations
    where category = 'weekly_high_score'
  ),
  'league_owes_team',
  'the high-score obligation should be owed by the league'
);

select is(
  (
    select amount_cents::bigint
    from public.financial_obligations
    where category = 'weekly_low_score_penalty'
  ),
  1000::bigint,
  'the low-score penalty should use the season rule in cents'
);

select is(
  (
    select direction::text
    from public.financial_obligations
    where category = 'weekly_low_score_penalty'
  ),
  'team_owes_league',
  'the low-score obligation should be owed by the team'
);

select is(
  (
    select occurred_on
    from public.financial_obligations
    where category = 'weekly_high_score'
  ),
  '2026-09-07'::date,
  'the obligation date should be the deterministic end of the configured week'
);

select is(
  (
    select jsonb_array_length(source_refs)
    from public.weekly_awards
    where week = 1
  ),
  2,
  'the award should reference both accepted result rows'
);

select public.derive_weekly_award(
  'd0000000-0000-4000-8000-000000000004',
  1
);

select is(
  (
    select count(*)
    from public.financial_obligations
    where category in ('weekly_high_score', 'weekly_low_score_penalty')
  ),
  2::bigint,
  'an exact retry should not duplicate financial obligations'
);

select throws_ok(
  $$
    select public.derive_weekly_award(
      'd0000000-0000-4000-8000-000000000004',
      2
    )
  $$,
  '22023',
  'weekly award tie requires commissioner review',
  'a tied high or low score should fail closed under the season policy'
);

select is(
  (select count(*) from public.weekly_awards where week = 2),
  0::bigint,
  'a tied week should not create a partial award'
);

create temporary table available_awards_result as
select public.derive_available_weekly_awards(
  'd0000000-0000-4000-8000-000000000004'
) as result;

select is(
  (
    select (result ->> 'award_week_count')::integer
    from available_awards_result
  ),
  1,
  'available derivation should process the complete unique-score week'
);

select is(
  (
    select result -> 'pending_tie_weeks'
    from available_awards_result
  ),
  '[2]'::jsonb,
  'available derivation should report the tied week for commissioner review'
);

select is(
  (select count(*) from public.weekly_awards),
  1::bigint,
  'batch derivation should not create an award for a pending tied week'
);

select * from finish();
rollback;
