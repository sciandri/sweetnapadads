begin;

select plan(17);

select has_type(
  'public',
  'external_cash_direction',
  'external cash direction enum should exist'
);

select has_table(
  'public',
  'external_cash_events',
  'external cash events table should exist'
);

select has_view(
  'public',
  'season_cash_balances',
  'season cash balance view should exist'
);

select ok(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname = 'external_cash_events'
  ),
  'external cash events should have RLS enabled'
);

insert into public.external_cash_events (
  id,
  league_id,
  season_id,
  direction,
  amount_cents,
  category,
  counterparty,
  description,
  source_type,
  source_key,
  occurred_on
)
values (
  'f0000000-0000-4000-8000-000000000100',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'cash_out',
  7000,
  'venue_expense',
  'Synthetic Venue',
  'Synthetic external expense',
  'manual',
  'test:external-venue-expense',
  '2026-09-15'
);

select is(
  (
    select amount_cents::bigint
    from public.external_cash_events
    where id = 'f0000000-0000-4000-8000-000000000100'
  ),
  7000::bigint,
  'external cash event should retain integer cents'
);

select throws_ok(
  $$
    insert into public.external_cash_events (
      league_id,
      season_id,
      direction,
      amount_cents,
      category,
      description,
      source_type,
      source_key,
      occurred_on
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'cash_out',
      1,
      'venue_expense',
      'Duplicate source key',
      'manual',
      'test:external-venue-expense',
      '2026-09-15'
    )
  $$,
  '23505',
  null,
  'external event source keys should be idempotent within a season'
);

select throws_ok(
  $$
    insert into public.external_cash_events (
      league_id,
      season_id,
      direction,
      amount_cents,
      category,
      description,
      source_type,
      source_key
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'cash_out',
      100,
      'venue_expense',
      'Undated manual event',
      'manual',
      'test:undated-manual-event'
    )
  $$,
  '23514',
  null,
  'only imported evidence may omit an exact date'
);

select lives_ok(
  $$
    insert into public.external_cash_events (
      league_id,
      season_id,
      direction,
      amount_cents,
      category,
      description,
      source_type,
      source_key
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'cash_in',
      100,
      'historical_rebate',
      'Imported event with unknown exact date',
      'import',
      'test:undated-import-event'
    )
  $$,
  'historical imported evidence may have an unknown exact date'
);

select throws_ok(
  $$
    update public.external_cash_events
    set amount_cents = 1
    where id = 'f0000000-0000-4000-8000-000000000100'
  $$,
  '55000',
  'financial events are immutable; append a correction instead',
  'external cash events should be immutable'
);

select is(
  (
    select team_cash_in_cents
    from public.season_cash_balances
    where season_id = 'd0000000-0000-4000-8000-000000000004'
  ),
  5000::bigint,
  'cash view should include team payments into the league'
);

select is(
  (
    select external_cash_out_cents
    from public.season_cash_balances
    where season_id = 'd0000000-0000-4000-8000-000000000004'
  ),
  7000::bigint,
  'cash view should include external cash paid out'
);

select is(
  (
    select cash_balance_cents
    from public.season_cash_balances
    where season_id = 'd0000000-0000-4000-8000-000000000004'
  ),
  (-1900)::bigint,
  'cash view should derive team and external movements without obligations'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.external_cash_events',
    'update'
  ),
  'authenticated users should not update external cash events'
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
  '77777777-7777-4777-8777-777777777777',
  'authenticated',
  'authenticated',
  'cash-member@example.test',
  '',
  timezone('utc', statement_timestamp()),
  '',
  '',
  '',
  '',
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"Cash Member"}',
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
  '77777777-7777-4777-8777-777777777777',
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
  (select count(*) from public.external_cash_events),
  2::bigint,
  'commissioner should see external events in their league'
);

select set_config(
  'request.jwt.claim.sub',
  '77777777-7777-4777-8777-777777777777',
  true
);

select is(
  (select count(*) from public.external_cash_events),
  2::bigint,
  'active member should see external events in their league'
);

select set_config(
  'request.jwt.claim.sub',
  '99999999-9999-4999-8999-999999999999',
  true
);

select is(
  (select count(*) from public.external_cash_events),
  0::bigint,
  'outsider should not see external cash events'
);

select is(
  (select count(*) from public.season_cash_balances),
  0::bigint,
  'outsider should not see season cash balances'
);

reset role;

select *
from finish();

rollback;
