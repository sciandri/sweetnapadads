-- Synthetic local-development data only. This file runs after every migration
-- during `supabase db reset`; never place production identities or data here.

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
  'd0000000-0000-4000-8000-000000000001',
  'authenticated',
  'authenticated',
  'dev-commissioner@sweetnapadads.test',
  '',
  '2026-07-30 00:00:00+00',
  '',
  '',
  '',
  '',
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"Development Commissioner"}',
  '2026-07-30 00:00:00+00',
  '2026-07-30 00:00:00+00'
);

insert into public.leagues (id, name, slug, created_by)
values (
  'd0000000-0000-4000-8000-000000000002',
  'Sweet Looking Napa Dads Development',
  'sweet-looking-napa-dads-dev',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.league_memberships (
  id,
  league_id,
  user_id,
  role,
  status,
  joined_at,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000003',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000001',
  'commissioner',
  'active',
  '2026-07-30 00:00:00+00',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.seasons (
  id,
  league_id,
  year,
  name,
  status,
  starts_on,
  ends_on,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000002',
  2026,
  '2026 Development Season',
  'setup',
  '2026-09-01',
  '2027-01-15',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_settings (
  season_id,
  currency_code,
  buy_in_cents,
  draft_fee_cents,
  weekly_high_score_payout_cents,
  weekly_low_score_penalty_cents,
  regular_season_weeks,
  playoff_team_count,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000004',
  'USD',
  20000,
  5000,
  2500,
  1000,
  14,
  6,
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  'd0000000-0000-4000-8000-000000000005',
  'd0000000-0000-4000-8000-000000000002',
  'Development Franchise',
  'development-franchise',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.owners (
  id,
  league_id,
  user_id,
  display_name,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000006',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000001',
  'Development Commissioner',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.team_owners (
  id,
  league_id,
  team_id,
  owner_id,
  started_on,
  is_primary,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000007',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000005',
  'd0000000-0000-4000-8000-000000000006',
  '2026-07-30',
  true,
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_teams (
  id,
  league_id,
  season_id,
  team_id,
  name,
  abbreviation,
  espn_team_id,
  status,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000008',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000005',
  'Development Franchise 2026',
  'DEV',
  1,
  'active',
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
values (
  'd0000000-0000-4000-8000-000000000009',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000008',
  'team_owes_league',
  20000,
  'season_buy_in',
  '2026 development season buy-in',
  'rule',
  'rule:season-buy-in:team:1',
  '2026-09-01',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.payments (
  id,
  league_id,
  season_id,
  season_team_id,
  direction,
  amount_cents,
  paid_on,
  method,
  reference,
  note,
  source_type,
  source_key,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000010',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000008',
  'from_team',
  5000,
  '2026-09-02',
  'cash',
  'dev-payment-1',
  'Synthetic partial payment',
  'manual',
  'manual:payment:dev-1',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.payment_allocations (
  id,
  league_id,
  season_id,
  season_team_id,
  payment_id,
  obligation_id,
  amount_cents,
  source_key,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000011',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000008',
  'd0000000-0000-4000-8000-000000000010',
  'd0000000-0000-4000-8000-000000000009',
  5000,
  'manual:allocation:dev-1',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.financial_adjustments (
  id,
  league_id,
  season_id,
  season_team_id,
  direction,
  amount_cents,
  reason,
  source_type,
  source_key,
  occurred_on,
  related_obligation_id,
  created_by
)
values (
  'd0000000-0000-4000-8000-000000000012',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000008',
  'decrease_team_balance',
  1000,
  'Synthetic commissioner credit for local reconciliation testing',
  'manual',
  'manual:adjustment:dev-1',
  '2026-09-03',
  'd0000000-0000-4000-8000-000000000009',
  'd0000000-0000-4000-8000-000000000001'
);
