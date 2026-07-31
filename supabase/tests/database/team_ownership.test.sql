begin;

select plan(20);

select has_type(
  'public',
  'season_team_status',
  'season_team_status enum should exist'
);

select results_eq(
  $$
    select enum_value::text
    from unnest(enum_range(null::public.season_team_status))
      with ordinality as values_with_order(enum_value, position)
    order by position
  $$,
  $$ values ('active'::text), ('inactive'::text) $$,
  'season_team_status labels should remain ordered'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'owners',
        'season_teams',
        'team_owners',
        'teams'
      )
      and pg_class.relrowsecurity
  ),
  4::bigint,
  'every team and ownership table should have RLS enabled'
);

select ok(
  not has_table_privilege('authenticated', 'public.teams', 'delete'),
  'authenticated users should not have team deletion privileges'
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
    '44444444-4444-4444-8444-444444444444',
    'authenticated',
    'authenticated',
    'team-member@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Team Member"}',
    timezone('utc', statement_timestamp()),
    timezone('utc', statement_timestamp())
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '55555555-5555-4555-8555-555555555555',
    'authenticated',
    'authenticated',
    'team-outsider@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Team Outsider"}',
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
  '44444444-4444-4444-8444-444444444444',
  'member',
  'active',
  timezone('utc', statement_timestamp()),
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.leagues (id, name, slug, created_by)
values (
  'e0000000-0000-4000-8000-000000000001',
  'Other Test League',
  'other-test-league',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.owners (
  id,
  league_id,
  display_name,
  created_by
)
values (
  'e0000000-0000-4000-8000-000000000002',
  'e0000000-0000-4000-8000-000000000001',
  'Other League Owner',
  'd0000000-0000-4000-8000-000000000001'
);

select throws_ok(
  $$
    insert into public.team_owners (
      league_id,
      team_id,
      owner_id,
      started_on,
      is_primary,
      created_by
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000005',
      'e0000000-0000-4000-8000-000000000002',
      '2026-07-30',
      false,
      'd0000000-0000-4000-8000-000000000001'
    )
  $$
);

insert into public.owners (
  id,
  league_id,
  display_name,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000009',
  'd0000000-0000-4000-8000-000000000002',
  'Second Primary Owner',
  'd0000000-0000-4000-8000-000000000001'
);

select throws_ok(
  $$
    insert into public.team_owners (
      league_id,
      team_id,
      owner_id,
      started_on,
      is_primary,
      created_by
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000005',
      'd0000000-0000-4000-8000-000000000009',
      '2026-07-30',
      true,
      'd0000000-0000-4000-8000-000000000001'
    )
  $$
);

select is(
  (
    select count(*)
    from public.team_owners
    where team_id = 'd0000000-0000-4000-8000-000000000005'
      and ended_on is null
      and is_primary
  ),
  1::bigint,
  'team should retain exactly one current primary owner'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

select is(
  (
    select count(*)
    from public.teams
    where league_id = 'd0000000-0000-4000-8000-000000000002'
  ),
  1::bigint,
  'commissioner should see their durable team'
);

update public.teams
set name = 'Commissioner Updated Franchise'
where id = 'd0000000-0000-4000-8000-000000000005';

select is(
  (
    select name
    from public.teams
    where id = 'd0000000-0000-4000-8000-000000000005'
  ),
  'Commissioner Updated Franchise',
  'commissioner should update a team'
);

select set_config(
  'request.jwt.claim.sub',
  '44444444-4444-4444-8444-444444444444',
  true
);

select is(
  (select count(*) from public.teams),
  1::bigint,
  'member should see teams in their league'
);

select is(
  (select count(*) from public.owners),
  2::bigint,
  'member should see owners in their league'
);

select is(
  (select count(*) from public.team_owners),
  1::bigint,
  'member should see ownership history in their league'
);

select is(
  (select count(*) from public.season_teams),
  1::bigint,
  'member should see season team entries in their league'
);

update public.teams
set name = 'Unauthorized Team Update'
where id = 'd0000000-0000-4000-8000-000000000005';

select is(
  (
    select name
    from public.teams
    where id = 'd0000000-0000-4000-8000-000000000005'
  ),
  'Commissioner Updated Franchise',
  'member should not update a team'
);

select throws_ok(
  $$
    insert into public.teams (league_id, name, slug)
    values (
      'd0000000-0000-4000-8000-000000000002',
      'Unauthorized Team',
      'unauthorized-team'
    )
  $$
);

select set_config(
  'request.jwt.claim.sub',
  '55555555-5555-4555-8555-555555555555',
  true
);

select is(
  (select count(*) from public.teams),
  0::bigint,
  'outsider should not see teams'
);

select is(
  (select count(*) from public.owners),
  0::bigint,
  'outsider should not see owners'
);

select is(
  (select count(*) from public.team_owners),
  0::bigint,
  'outsider should not see ownership history'
);

select is(
  (select count(*) from public.season_teams),
  0::bigint,
  'outsider should not see season team entries'
);

select ok(
  not private.is_active_league_member(
    'd0000000-0000-4000-8000-000000000002'
  ),
  'outsider should remain outside the league'
);

select * from finish();

rollback;
