begin;

select plan(16);

select has_view(
  'public',
  'obligation_reconciliation',
  'obligation reconciliation view should exist'
);

select has_view(
  'public',
  'payment_reconciliation',
  'payment reconciliation view should exist'
);

select has_view(
  'public',
  'team_financial_balances',
  'team financial balance view should exist'
);

select is(
  (
    select balance_cents
    from public.team_financial_balances
    where season_team_id = 'd0000000-0000-4000-8000-000000000008'
  ),
  14000::bigint,
  'seeded team balance should follow the canonical team-perspective formula'
);

select is(
  (
    select allocated_cents
    from public.obligation_reconciliation
    where obligation_id = 'd0000000-0000-4000-8000-000000000009'
  ),
  5000::bigint,
  'obligation reconciliation should total applied allocations'
);

select is(
  (
    select outstanding_cents
    from public.obligation_reconciliation
    where obligation_id = 'd0000000-0000-4000-8000-000000000009'
  ),
  15000::bigint,
  'obligation reconciliation should derive the outstanding amount'
);

select is(
  (
    select reconciliation_status
    from public.obligation_reconciliation
    where obligation_id = 'd0000000-0000-4000-8000-000000000009'
  ),
  'partial',
  'partially allocated obligation should be marked partial'
);

select is(
  (
    select unallocated_cents
    from public.payment_reconciliation
    where payment_id = 'd0000000-0000-4000-8000-000000000010'
  ),
  0::bigint,
  'payment reconciliation should derive the unallocated amount'
);

select is(
  (
    select reconciliation_status
    from public.payment_reconciliation
    where payment_id = 'd0000000-0000-4000-8000-000000000010'
  ),
  'allocated',
  'fully allocated payment should be marked allocated'
);

select is(
  (
    select count(*)
    from public.obligation_reconciliation
    where obligation_cents <> allocated_cents + outstanding_cents
  ),
  0::bigint,
  'every obligation should reconcile exactly'
);

select is(
  (
    select count(*)
    from public.payment_reconciliation
    where payment_cents <> allocated_cents + unallocated_cents
  ),
  0::bigint,
  'every payment should reconcile exactly'
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
  '88888888-8888-4888-8888-888888888888',
  'authenticated',
  'authenticated',
  'balance-member@example.test',
  '',
  timezone('utc', statement_timestamp()),
  '',
  '',
  '',
  '',
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"Balance Member"}',
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
  '88888888-8888-4888-8888-888888888888',
  'member',
  'active',
  timezone('utc', statement_timestamp()),
  'd0000000-0000-4000-8000-000000000001'
);

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
  2000,
  'test:view-allocation-reversal',
  'd0000000-0000-4000-8000-000000000011',
  'Verify reconciliation view reversal propagation',
  'd0000000-0000-4000-8000-000000000001'
);

select is(
  (
    select outstanding_cents
    from public.obligation_reconciliation
    where obligation_id = 'd0000000-0000-4000-8000-000000000009'
  ),
  17000::bigint,
  'allocation reversal should restore obligation outstanding value'
);

select is(
  (
    select unallocated_cents
    from public.payment_reconciliation
    where payment_id = 'd0000000-0000-4000-8000-000000000010'
  ),
  2000::bigint,
  'allocation reversal should restore payment unallocated value'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

select is(
  (select count(*) from public.team_financial_balances),
  1::bigint,
  'commissioner should see balances in their league'
);

select set_config(
  'request.jwt.claim.sub',
  '88888888-8888-4888-8888-888888888888',
  true
);

select is(
  (select count(*) from public.obligation_reconciliation),
  1::bigint,
  'active member should see obligation reconciliation in their league'
);

select set_config(
  'request.jwt.claim.sub',
  '99999999-9999-4999-8999-999999999999',
  true
);

select is(
  (select count(*) from public.team_financial_balances),
  0::bigint,
  'outsider should not see team balances'
);

reset role;

select *
from finish();

rollback;
