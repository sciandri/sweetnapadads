begin;

select plan(20);

select has_type(
  'public',
  'season_financial_rule_kind',
  'season financial rule kinds should be explicit data'
);

select has_table(
  'public',
  'season_financial_rules',
  'season payout and penalty configuration should exist'
);

select has_table(
  'public',
  'season_financial_rule_changes',
  'financial rule audit snapshots should exist'
);

select has_function(
  'public',
  'set_season_financial_rules',
  array['uuid', 'jsonb'],
  'audited financial rule replacement should exist'
);

select is(
  (
    select count(*)
    from public.season_financial_rules
    where season_id = 'd0000000-0000-4000-8000-000000000004'
      and enabled
  ),
  2::bigint,
  'new season settings should initialize both configured weekly rules'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.season_financial_rules',
    'insert'
  ),
  'authenticated callers should not bypass the audited write boundary'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.set_season_financial_rules(uuid,jsonb)',
    'execute'
  ),
  'authenticated callers should reach PostgreSQL commissioner authorization'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

create temporary table rule_result as
select public.set_season_financial_rules(
  'd0000000-0000-4000-8000-000000000004',
  '[
    {"rule_key":"weekly_high_score","rule_kind":"weekly_high_score","label":"Weekly high score","direction":"league_owes_team","amount_cents":3000},
    {"rule_key":"weekly_low_score_penalty","rule_kind":"weekly_low_score_penalty","label":"Weekly low score penalty","direction":"team_owes_league","amount_cents":1200},
    {"rule_key":"first_place","rule_kind":"placement_payout","label":"Champion","direction":"league_owes_team","amount_cents":80000,"recipient_rank":1},
    {"rule_key":"season_high_score","rule_kind":"season_award","label":"Season high score","direction":"league_owes_team","amount_cents":5000},
    {"rule_key":"late_payment","rule_kind":"penalty","label":"Late payment penalty","direction":"team_owes_league","amount_cents":1000}
  ]'::jsonb
) as result;

select is(
  (select result ->> 'status' from rule_result),
  'saved',
  'commissioner should save a complete configured rule batch'
);

select is(
  (select (result ->> 'rule_count')::integer from rule_result),
  5,
  'save result should report every configured rule'
);

select is(
  (
    select count(*)
    from public.season_financial_rules
    where season_id = 'd0000000-0000-4000-8000-000000000004'
      and enabled
  ),
  5::bigint,
  'the canonical enabled set should contain every submitted rule'
);

select is(
  (
    select amount_cents::bigint
    from public.season_financial_rules
    where season_id = 'd0000000-0000-4000-8000-000000000004'
      and rule_key = 'first_place'
  ),
  80000::bigint,
  'placement payouts should be stored as configured integer cents'
);

select is(
  (
    select weekly_high_score_payout_cents::bigint
    from public.season_settings
    where season_id = 'd0000000-0000-4000-8000-000000000004'
  ),
  3000::bigint,
  'the legacy weekly high field should mirror the canonical rule'
);

select is(
  (
    select weekly_low_score_penalty_cents::bigint
    from public.season_settings
    where season_id = 'd0000000-0000-4000-8000-000000000004'
  ),
  1200::bigint,
  'the legacy weekly low field should mirror the canonical rule'
);

select is(
  (select count(*) from public.season_financial_rule_changes),
  1::bigint,
  'saving rules should create one immutable audit snapshot'
);

select is(
  (select changed_by from public.season_financial_rule_changes),
  'd0000000-0000-4000-8000-000000000001'::uuid,
  'the audit snapshot should record the commissioner actor'
);

select throws_ok(
  $$
    select public.set_season_financial_rules(
      'd0000000-0000-4000-8000-000000000004',
      '[
        {"rule_key":"weekly_high_score","rule_kind":"weekly_high_score","label":"High","direction":"league_owes_team","amount_cents":3000},
        {"rule_key":"weekly_low_score_penalty","rule_kind":"weekly_low_score_penalty","label":"Low","direction":"team_owes_league","amount_cents":1200},
        {"rule_key":"first_place","rule_kind":"placement_payout","label":"First","direction":"league_owes_team","amount_cents":80000,"recipient_rank":1},
        {"rule_key":"champion_bonus","rule_kind":"placement_payout","label":"Duplicate rank","direction":"league_owes_team","amount_cents":5000,"recipient_rank":1}
      ]'::jsonb
    )
  $$,
  '22023',
  'financial rules are invalid or duplicated',
  'duplicate placement ranks should fail closed'
);

select set_config(
  'request.jwt.claim.sub',
  '55555555-5555-4555-8555-555555555555',
  true
);

select throws_ok(
  $$
    select public.set_season_financial_rules(
      'd0000000-0000-4000-8000-000000000004',
      '[
        {"rule_key":"weekly_high_score","rule_kind":"weekly_high_score","label":"High","direction":"league_owes_team","amount_cents":3000},
        {"rule_key":"weekly_low_score_penalty","rule_kind":"weekly_low_score_penalty","label":"Low","direction":"team_owes_league","amount_cents":1200}
      ]'::jsonb
    )
  $$,
  '42501',
  'only an active commissioner may change financial rules',
  'non-members should not change season financial configuration'
);

select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

select is(
  (select count(*) from public.season_financial_rule_changes),
  1::bigint,
  'rejected changes should not create audit snapshots'
);

set local role service_role;

select throws_ok(
  $$ update public.season_financial_rule_changes set rules = rules $$,
  '55000',
  'season financial rule audit batches are immutable',
  'audit snapshots should reject updates even for service operations'
);

select throws_ok(
  $$ delete from public.season_financial_rule_changes $$,
  '55000',
  'season financial rule audit batches are immutable',
  'audit snapshots should reject deletes even for service operations'
);

select * from finish();
rollback;
