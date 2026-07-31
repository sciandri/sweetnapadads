begin;

select plan(19);

select has_type(
  'public',
  'competition_phase',
  'competition phase enum should exist'
);

select has_type(
  'public',
  'competition_result',
  'competition result enum should exist'
);

select has_type(
  'public',
  'competition_source_type',
  'competition source enum should exist'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in ('matchups', 'weekly_awards', 'weekly_results')
      and pg_class.relrowsecurity
  ),
  3::bigint,
  'every competition table should have RLS enabled'
);

select ok(
  not has_table_privilege('authenticated', 'public.weekly_results', 'update'),
  'authenticated users should not update results directly'
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
  'c0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  1,
  'regular_season',
  'import',
  'import:test:matchup:1',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  'c0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'Competition Opponent',
  'competition-opponent',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_teams (
  id,
  league_id,
  season_id,
  team_id,
  name,
  status,
  created_by
)
values (
  'c0000000-0000-4000-8000-000000000003',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'c0000000-0000-4000-8000-000000000002',
  'Competition Opponent 2026',
  'active',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.weekly_results (
  id,
  league_id,
  season_id,
  matchup_id,
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
    'c0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'c0000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000008',
    'c0000000-0000-4000-8000-000000000003',
    101.25,
    'win',
    'import',
    'import:test:result:team-one',
    'd0000000-0000-4000-8000-000000000001'
  ),
  (
    'c0000000-0000-4000-8000-000000000005',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'c0000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000003',
    'd0000000-0000-4000-8000-000000000008',
    99.75,
    'loss',
    'import',
    'import:test:result:team-two',
    'd0000000-0000-4000-8000-000000000001'
  );

insert into public.financial_obligations (
  id,
  league_id,
  season_id,
  season_team_id,
  direction,
  amount_cents,
  category,
  description,
  source_type,
  source_key,
  occurred_on,
  created_by
)
values
  (
    'c0000000-0000-4000-8000-000000000006',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000008',
    'league_owes_team',
    2500,
    'weekly_high_score',
    'Competition high-score award',
    'import',
    'import:test:competition-high',
    '2026-09-08',
    'd0000000-0000-4000-8000-000000000001'
  ),
  (
    'c0000000-0000-4000-8000-000000000007',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'c0000000-0000-4000-8000-000000000003',
    'team_owes_league',
    1000,
    'weekly_low_score_penalty',
    'Competition low-score penalty',
    'import',
    'import:test:competition-low',
    '2026-09-08',
    'd0000000-0000-4000-8000-000000000001'
  );

insert into public.weekly_awards (
  id,
  league_id,
  season_id,
  week,
  high_score_season_team_id,
  high_score,
  high_score_obligation_id,
  low_score_season_team_id,
  low_score,
  low_score_obligation_id,
  source_type,
  source_key,
  source_refs,
  created_by
)
values (
  'c0000000-0000-4000-8000-000000000008',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  1,
  'd0000000-0000-4000-8000-000000000008',
  101.25,
  'c0000000-0000-4000-8000-000000000006',
  'c0000000-0000-4000-8000-000000000003',
  99.75,
  'c0000000-0000-4000-8000-000000000007',
  'import',
  'import:test:weekly-award:1',
  '["Weekly Results!A2:F3"]'::jsonb,
  'd0000000-0000-4000-8000-000000000001'
);

select is(
  (select count(*) from public.matchups),
  1::bigint,
  'competition matchup should be stored'
);

select is(
  (select count(*) from public.weekly_results),
  2::bigint,
  'matchup should retain both team result rows'
);

select is(
  (select score from public.weekly_results where result = 'win'),
  101.25::numeric,
  'scores should retain exact hundredths'
);

select is(
  (select count(*) from public.weekly_awards),
  1::bigint,
  'weekly award should be stored'
);

select throws_ok(
  $$
    update public.weekly_results
    set score = 0
    where id = 'c0000000-0000-4000-8000-000000000004'
  $$,
  '55000',
  'imported competition history is immutable',
  'imported results should be immutable'
);

select throws_ok(
  $$
    insert into public.weekly_results (
      league_id,
      season_id,
      matchup_id,
      season_team_id,
      opponent_season_team_id,
      score,
      result,
      source_type,
      source_key
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'c0000000-0000-4000-8000-000000000001',
      'd0000000-0000-4000-8000-000000000008',
      'c0000000-0000-4000-8000-000000000003',
      88,
      'loss',
      'import',
      'import:test:duplicate-team'
    )
  $$,
  '23505',
  null,
  'a matchup should have only one result per team'
);

select throws_ok(
  $$
    insert into public.weekly_results (
      league_id,
      season_id,
      matchup_id,
      season_team_id,
      opponent_season_team_id,
      score,
      result,
      source_type,
      source_key
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'c0000000-0000-4000-8000-000000000001',
      'd0000000-0000-4000-8000-000000000008',
      'd0000000-0000-4000-8000-000000000008',
      88,
      'loss',
      'import',
      'import:test:self-opponent'
    )
  $$,
  '23514',
  null,
  'a team cannot be its own opponent'
);

select throws_ok(
  $$
    insert into public.matchups (
      league_id,
      season_id,
      week,
      phase,
      source_type,
      source_key
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      1,
      'regular_season',
      'import',
      'import:test:matchup:1'
    )
  $$,
  '23505',
  null,
  'matchup source keys should be idempotent within a season'
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
values (
  '00000000-0000-0000-0000-000000000000',
  'c0000000-0000-4000-8000-000000000009',
  'authenticated',
  'authenticated',
  'competition-member@example.test',
  '',
  timezone('utc', statement_timestamp()),
  '',
  '',
  '',
  '',
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"Competition Member"}',
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
  'c0000000-0000-4000-8000-000000000009',
  'member',
  'active',
  timezone('utc', statement_timestamp()),
  'd0000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c0000000-0000-4000-8000-000000000009',
  true
);

select is(
  (select count(*) from public.matchups),
  1::bigint,
  'active members should see league matchups'
);

select is(
  (select count(*) from public.weekly_results),
  2::bigint,
  'active members should see league results'
);

select is(
  (select count(*) from public.weekly_awards),
  1::bigint,
  'active members should see league awards'
);

select set_config(
  'request.jwt.claim.sub',
  '99999999-9999-4999-8999-999999999999',
  true
);

select is(
  (select count(*) from public.matchups),
  0::bigint,
  'outsiders should not see matchups'
);

select is(
  (select count(*) from public.weekly_results),
  0::bigint,
  'outsiders should not see results'
);

select is(
  (select count(*) from public.weekly_awards),
  0::bigint,
  'outsiders should not see awards'
);

reset role;

select *
from finish();

rollback;
