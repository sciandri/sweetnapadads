begin;

select plan(29);

select has_type(
  'public',
  'obligation_direction',
  'obligation_direction enum should exist'
);

select has_type(
  'public',
  'payment_direction',
  'payment_direction enum should exist'
);

select has_type(
  'public',
  'balance_adjustment_direction',
  'balance_adjustment_direction enum should exist'
);

select has_type(
  'public',
  'payment_allocation_kind',
  'payment_allocation_kind enum should exist'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'financial_adjustments',
        'financial_obligations',
        'payment_allocations',
        'payments'
      )
      and pg_class.relrowsecurity
  ),
  4::bigint,
  'every financial event table should have RLS enabled'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.financial_obligations',
    'update'
  ),
  'authenticated users should not update obligations'
);

select ok(
  not has_table_privilege('authenticated', 'public.payments', 'delete'),
  'authenticated users should not delete payments'
);

select is(
  (
    select amount_cents::bigint
    from public.financial_obligations
    where id = 'd0000000-0000-4000-8000-000000000009'
  ),
  20000::bigint,
  'seed should contain the synthetic buy-in obligation'
);

select is(
  (
    select amount_cents::bigint
    from public.payments
    where id = 'd0000000-0000-4000-8000-000000000010'
  ),
  5000::bigint,
  'seed should contain the synthetic partial payment'
);

select is(
  (
    select amount_cents::bigint
    from public.payment_allocations
    where id = 'd0000000-0000-4000-8000-000000000011'
  ),
  5000::bigint,
  'seed should allocate the synthetic payment'
);

select is(
  (
    select amount_cents::bigint
    from public.financial_adjustments
    where id = 'd0000000-0000-4000-8000-000000000012'
  ),
  1000::bigint,
  'seed should contain an audited adjustment'
);

select throws_ok(
  $$
    insert into public.financial_obligations (
      league_id,
      season_id,
      season_team_id,
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
      'd0000000-0000-4000-8000-000000000008',
      'team_owes_league',
      100,
      'test_fee',
      'Duplicate source test',
      'rule',
      'rule:season-buy-in:team:1',
      '2026-09-01'
    )
  $$,
  '23505',
  null,
  'obligation source keys should be idempotent within a season'
);

select throws_ok(
  $$
    update public.financial_obligations
    set amount_cents = 19000
    where id = 'd0000000-0000-4000-8000-000000000009'
  $$,
  '55000',
  'financial events are immutable; append a correction instead',
  'posted obligations should be immutable'
);

select throws_ok(
  $$
    delete from public.payments
    where id = 'd0000000-0000-4000-8000-000000000010'
  $$,
  '55000',
  'financial events are immutable; append a correction instead',
  'posted payments should be immutable'
);

select throws_ok(
  $$
    insert into public.payment_allocations (
      league_id,
      season_id,
      season_team_id,
      payment_id,
      obligation_id,
      amount_cents,
      source_key
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'd0000000-0000-4000-8000-000000000008',
      'd0000000-0000-4000-8000-000000000010',
      'd0000000-0000-4000-8000-000000000009',
      1,
      'test:overallocate-payment'
    )
  $$,
  'P0001',
  'allocation exceeds the payment amount',
  'allocations should not exceed their payment'
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
  occurred_on
)
values (
  'f0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000008',
  'league_owes_team',
  2500,
  'weekly_payout',
  'Synthetic payout direction test',
  'rule',
  'test:weekly-payout',
  '2026-09-10'
);

select throws_ok(
  $$
    insert into public.payment_allocations (
      league_id,
      season_id,
      season_team_id,
      payment_id,
      obligation_id,
      amount_cents,
      source_key
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'd0000000-0000-4000-8000-000000000008',
      'd0000000-0000-4000-8000-000000000010',
      'f0000000-0000-4000-8000-000000000001',
      100,
      'test:mismatched-direction'
    )
  $$,
  'P0001',
  'payment direction from_team cannot settle obligation direction league_owes_team',
  'payment and obligation directions should agree'
);

insert into public.payment_allocations (
  id,
  league_id,
  season_id,
  season_team_id,
  payment_id,
  obligation_id,
  kind,
  amount_cents,
  source_key,
  reverses_allocation_id,
  reason,
  created_by
)
values (
  'f0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000008',
  'd0000000-0000-4000-8000-000000000010',
  'd0000000-0000-4000-8000-000000000009',
  'reverse',
  2000,
  'test:reverse-allocation',
  'd0000000-0000-4000-8000-000000000011',
  'Correct a portion of the synthetic allocation',
  'd0000000-0000-4000-8000-000000000001'
);

select throws_ok(
  $$
    insert into public.payment_allocations (
      league_id,
      season_id,
      season_team_id,
      payment_id,
      obligation_id,
      kind,
      amount_cents,
      source_key,
      reverses_allocation_id,
      reason,
      created_by
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'd0000000-0000-4000-8000-000000000008',
      'd0000000-0000-4000-8000-000000000010',
      'd0000000-0000-4000-8000-000000000009',
      'reverse',
      3001,
      'test:over-reverse-allocation',
      'd0000000-0000-4000-8000-000000000011',
      'Attempt to reverse too much',
      'd0000000-0000-4000-8000-000000000001'
    )
  $$,
  'P0001',
  'allocation reversal exceeds the original allocation amount',
  'allocation reversals should not exceed the applied allocation'
);

select throws_ok(
  $$
    insert into public.financial_adjustments (
      league_id,
      season_id,
      season_team_id,
      direction,
      amount_cents,
      reason,
      source_type,
      source_key,
      occurred_on,
      created_by
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'd0000000-0000-4000-8000-000000000008',
      'increase_team_balance',
      100,
      '',
      'manual',
      'test:blank-adjustment-reason',
      '2026-09-12',
      'd0000000-0000-4000-8000-000000000001'
    )
  $$,
  '23514',
  null,
  'adjustments should require an audit reason'
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
    '66666666-6666-4666-8666-666666666666',
    'authenticated',
    'authenticated',
    'finance-member@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Finance Member"}',
    timezone('utc', statement_timestamp()),
    timezone('utc', statement_timestamp())
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '77777777-7777-4777-8777-777777777777',
    'authenticated',
    'authenticated',
    'finance-outsider@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Finance Outsider"}',
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
  '66666666-6666-4666-8666-666666666666',
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
  (select count(*) from public.financial_obligations),
  2::bigint,
  'commissioner should see obligations in their league'
);

insert into public.payments (
  league_id,
  season_id,
  season_team_id,
  direction,
  amount_cents,
  paid_on,
  source_type,
  source_key,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000008',
  'to_team',
  2500,
  '2026-09-11',
  'manual',
  'test:commissioner-payout',
  'd0000000-0000-4000-8000-000000000001'
);

select is(
  (
    select count(*)
    from public.payments
    where source_key = 'test:commissioner-payout'
  ),
  1::bigint,
  'commissioner should create a payment'
);

select set_config(
  'request.jwt.claim.sub',
  '66666666-6666-4666-8666-666666666666',
  true
);

select is(
  (select count(*) from public.financial_obligations),
  2::bigint,
  'member should read obligations in their league'
);

select is(
  (select count(*) from public.payments),
  2::bigint,
  'member should read payments in their league'
);

select is(
  (select count(*) from public.payment_allocations),
  2::bigint,
  'member should read allocations in their league'
);

select is(
  (select count(*) from public.financial_adjustments),
  1::bigint,
  'member should read adjustments in their league'
);

select throws_ok(
  $$
    insert into public.financial_adjustments (
      league_id,
      season_id,
      season_team_id,
      direction,
      amount_cents,
      reason,
      source_type,
      source_key,
      occurred_on,
      created_by
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'd0000000-0000-4000-8000-000000000008',
      'decrease_team_balance',
      100,
      'Member insertion should be rejected',
      'manual',
      'test:member-adjustment',
      '2026-09-13',
      '66666666-6666-4666-8666-666666666666'
    )
  $$,
  '42501',
  null,
  'members should not create adjustments'
);

select set_config(
  'request.jwt.claim.sub',
  '77777777-7777-4777-8777-777777777777',
  true
);

select is(
  (select count(*) from public.financial_obligations),
  0::bigint,
  'outsiders should not read obligations'
);

select is(
  (select count(*) from public.payments),
  0::bigint,
  'outsiders should not read payments'
);

select is(
  (select count(*) from public.payment_allocations),
  0::bigint,
  'outsiders should not read allocations'
);

select is(
  (select count(*) from public.financial_adjustments),
  0::bigint,
  'outsiders should not read adjustments'
);

reset role;

select *
from finish();

rollback;
