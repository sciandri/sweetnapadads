begin;

select plan(16);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-4111-8111-111111111111',
    'authenticated',
    'authenticated',
    'commissioner@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Commissioner"}',
    timezone('utc', statement_timestamp()),
    timezone('utc', statement_timestamp())
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-4222-8222-222222222222',
    'authenticated',
    'authenticated',
    'member@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Member"}',
    timezone('utc', statement_timestamp()),
    timezone('utc', statement_timestamp())
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '33333333-3333-4333-8333-333333333333',
    'authenticated',
    'authenticated',
    'outsider@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Outsider"}',
    timezone('utc', statement_timestamp()),
    timezone('utc', statement_timestamp())
  );

select is(
  (select count(*) from public.profiles),
  3::bigint,
  'auth user inserts should create profiles'
);

insert into public.leagues (id, name, slug, created_by)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Test League',
  'test-league',
  '11111111-1111-4111-8111-111111111111'
);

insert into public.league_memberships (
  league_id,
  user_id,
  role,
  status,
  joined_at,
  created_by
)
values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '11111111-1111-4111-8111-111111111111',
    'commissioner',
    'active',
    timezone('utc', statement_timestamp()),
    '11111111-1111-4111-8111-111111111111'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '22222222-2222-4222-8222-222222222222',
    'member',
    'active',
    timezone('utc', statement_timestamp()),
    '11111111-1111-4111-8111-111111111111'
  );

insert into public.seasons (
  id,
  league_id,
  year,
  name,
  status,
  created_by
)
values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  2026,
  '2026 Season',
  'setup',
  '11111111-1111-4111-8111-111111111111'
);

insert into public.season_settings (
  season_id,
  buy_in_cents,
  draft_fee_cents,
  weekly_high_score_payout_cents,
  weekly_low_score_penalty_cents,
  regular_season_weeks,
  playoff_team_count,
  created_by
)
values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  20000,
  5000,
  2500,
  1000,
  14,
  6,
  '11111111-1111-4111-8111-111111111111'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'league_memberships',
        'leagues',
        'profiles',
        'season_settings',
        'seasons'
      )
      and pg_class.relrowsecurity
  ),
  5::bigint,
  'every platform table should have RLS enabled'
);

select ok(
  not has_table_privilege('authenticated', 'public.leagues', 'delete'),
  'authenticated users should not have league deletion privileges'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-4111-8111-111111111111',
  true
);

select ok(
  private.is_league_commissioner(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ),
  'commissioner helper should recognize an active commissioner'
);

select is(
  (select count(*) from public.leagues),
  1::bigint,
  'commissioner should see their league'
);

update public.leagues
set name = 'Commissioner Updated'
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

select is(
  (
    select name
    from public.leagues
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ),
  'Commissioner Updated',
  'commissioner should update their league'
);

select set_config(
  'request.jwt.claim.sub',
  '22222222-2222-4222-8222-222222222222',
  true
);

select ok(
  private.is_active_league_member(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ),
  'member helper should recognize an active member'
);

select ok(
  not private.is_league_commissioner(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ),
  'member helper should reject a non-commissioner'
);

select is(
  (select count(*) from public.leagues),
  1::bigint,
  'member should see their league'
);

select is(
  (select count(*) from public.season_settings),
  1::bigint,
  'member should see settings for their league'
);

select is(
  (select count(*) from public.profiles),
  2::bigint,
  'member should see profiles that share an active league'
);

select is(
  (select count(*) from public.league_memberships),
  2::bigint,
  'member should see memberships in their league'
);

update public.leagues
set name = 'Unauthorized Update'
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

select is(
  (
    select name
    from public.leagues
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ),
  'Commissioner Updated',
  'member should not update their league'
);

select set_config(
  'request.jwt.claim.sub',
  '33333333-3333-4333-8333-333333333333',
  true
);

select ok(
  not private.is_active_league_member(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ),
  'outsider should not be recognized as a member'
);

select is(
  (select count(*) from public.leagues),
  0::bigint,
  'outsider should not see the league'
);

select is(
  (select count(*) from public.profiles),
  1::bigint,
  'outsider should see only their own profile'
);

select * from finish();

rollback;
