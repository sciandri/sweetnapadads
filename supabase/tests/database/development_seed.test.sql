begin;

select plan(14);

select is(
  (
    select email
    from auth.users
    where id = 'd0000000-0000-4000-8000-000000000001'
  ),
  'dev-commissioner@sweetnapadads.test',
  'seed should create the synthetic commissioner auth identity'
);

select is(
  (
    select display_name
    from public.profiles
    where user_id = 'd0000000-0000-4000-8000-000000000001'
  ),
  'Development Commissioner',
  'auth profile trigger should create the commissioner profile'
);

select is(
  (
    select slug
    from public.leagues
    where id = 'd0000000-0000-4000-8000-000000000002'
  ),
  'sweet-looking-napa-dads-dev',
  'seed should create the development league'
);

select is(
  (
    select role::text
    from public.league_memberships
    where id = 'd0000000-0000-4000-8000-000000000003'
  ),
  'commissioner',
  'seeded identity should be the league commissioner'
);

select is(
  (
    select status::text
    from public.league_memberships
    where id = 'd0000000-0000-4000-8000-000000000003'
  ),
  'active',
  'seeded commissioner membership should be active'
);

select is(
  (
    select year
    from public.seasons
    where id = 'd0000000-0000-4000-8000-000000000004'
  ),
  2026::smallint,
  'seed should create the development season'
);

select is(
  (
    select buy_in_cents::bigint
    from public.season_settings
    where season_id = 'd0000000-0000-4000-8000-000000000004'
  ),
  20000::bigint,
  'seed should store the buy-in as integer cents'
);

select is(
  (
    select weekly_low_score_penalty_cents::bigint
    from public.season_settings
    where season_id = 'd0000000-0000-4000-8000-000000000004'
  ),
  1000::bigint,
  'seed should store the weekly penalty as integer cents'
);

select is(
  (
    select slug
    from public.teams
    where id = 'd0000000-0000-4000-8000-000000000005'
  ),
  'development-franchise',
  'seed should create a durable development franchise'
);

select is(
  (
    select display_name
    from public.owners
    where id = 'd0000000-0000-4000-8000-000000000006'
  ),
  'Development Commissioner',
  'seed should create an owner linked to the commissioner'
);

select is(
  (
    select owner_id
    from public.team_owners
    where id = 'd0000000-0000-4000-8000-000000000007'
  ),
  'd0000000-0000-4000-8000-000000000006'::uuid,
  'seed should create current ownership history'
);

select is(
  (
    select espn_team_id
    from public.season_teams
    where id = 'd0000000-0000-4000-8000-000000000008'
  ),
  1,
  'seed should create a season-specific ESPN team mapping'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

select ok(
  private.is_league_commissioner(
    'd0000000-0000-4000-8000-000000000002'
  ),
  'seeded identity should pass commissioner authorization'
);

select is(
  (
    select count(*)
    from public.seasons
    where league_id = 'd0000000-0000-4000-8000-000000000002'
  ),
  1::bigint,
  'seeded commissioner should see the development season through RLS'
);

select * from finish();

rollback;
