begin;

select plan(29);

select has_type(
  'public',
  'historical_committed_record_kind',
  'historical committed record kind enum should exist'
);

select has_table(
  'public',
  'historical_import_commits',
  'historical import commits table should exist'
);

select has_table(
  'public',
  'historical_import_committed_records',
  'historical committed records table should exist'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'historical_import_commits',
        'historical_import_committed_records'
      )
      and pg_class.relrowsecurity
  ),
  2::bigint,
  'historical commit tables should have RLS enabled'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.commit_historical_import(uuid,jsonb)',
    'execute'
  ),
  'authenticated users should be able to invoke the commit RPC'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  'e0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'Commit Opponent',
  'unrelated-franchise',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_teams (
  id,
  league_id,
  season_id,
  team_id,
  name,
  abbreviation,
  status,
  created_by
)
values (
  'e0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'e0000000-0000-4000-8000-000000000001',
  'Commit Opponent 2026',
  'CMT',
  'active',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.historical_import_batches (
  id,
  league_id,
  season_id,
  source_filename,
  source_sha256,
  source_manifest,
  created_by
)
values
  (
    'e0000000-0000-4000-8000-000000000003',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'commit-success.xlsx',
    repeat('d', 64),
    '{"test":true}'::jsonb,
    'd0000000-0000-4000-8000-000000000001'
  ),
  (
    'e0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'commit-rollback.xlsx',
    repeat('e', 64),
    '{"test":true}'::jsonb,
    'd0000000-0000-4000-8000-000000000001'
  );

insert into public.historical_import_rows (
  batch_id,
  league_id,
  season_id,
  source_sheet,
  source_row_number,
  raw_values,
  row_sha256,
  created_by
)
values
  (
    'e0000000-0000-4000-8000-000000000003',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'Test',
    1,
    '["success"]'::jsonb,
    repeat('1', 64),
    'd0000000-0000-4000-8000-000000000001'
  ),
  (
    'e0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'Test',
    1,
    '["rollback"]'::jsonb,
    repeat('2', 64),
    'd0000000-0000-4000-8000-000000000001'
  );

insert into public.historical_team_mappings (
  id,
  batch_id,
  league_id,
  season_id,
  identifier_kind,
  source_value,
  status,
  season_team_id,
  decision_note,
  decided_by,
  decided_at,
  created_by
)
values (
  'e0000000-0000-4000-8000-000000000006',
  'e0000000-0000-4000-8000-000000000003',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'team_name',
  'Commit Opponent',
  'mapped',
  'e0000000-0000-4000-8000-000000000002',
  'Explicit preview key mapping.',
  'd0000000-0000-4000-8000-000000000001',
  timezone('utc', statement_timestamp()),
  'd0000000-0000-4000-8000-000000000001'
);

update public.historical_import_batches
set status = 'reviewing'
where id in (
  'e0000000-0000-4000-8000-000000000003',
  'e0000000-0000-4000-8000-000000000004'
);

update public.historical_import_batches
set
  status = 'approved',
  approved_by = 'd0000000-0000-4000-8000-000000000001',
  approved_at = timezone('utc', statement_timestamp())
where id in (
  'e0000000-0000-4000-8000-000000000003',
  'e0000000-0000-4000-8000-000000000004'
);

create temporary table commit_test_previews (
  name text primary key,
  payload jsonb not null
);

insert into commit_test_previews (name, payload)
values (
  'success',
  jsonb_build_object(
    'status', 'review_only',
    'committed', false,
    'source', jsonb_build_object('sha256', repeat('d', 64)),
    'approval', jsonb_build_object('decision_queue_status', 'approved'),
    'commit_gate', jsonb_build_object(
      'ready_for_domain_commit', true,
      'blocking_issues', jsonb_build_array()
    ),
    'season', jsonb_build_object('year', 2026),
    'teams', jsonb_build_array(
      jsonb_build_object('team_key', 'development-franchise'),
      jsonb_build_object('team_key', 'commit-opponent')
    ),
    'financial_obligations', jsonb_build_array(
      jsonb_build_object(
        'preview_id', 'obligation:weekly_high:1',
        'source_key', 'import:2026:obligation:weekly_high:1',
        'team_key', 'development-franchise',
        'direction', 'league_owes_team',
        'amount_cents', 2500,
        'category', 'weekly_high_score',
        'description', 'Week 1 high score payout',
        'occurred_on', '2026-09-08',
        'source_refs', jsonb_build_array('Weekly Results!A2:F2')
      ),
      jsonb_build_object(
        'preview_id', 'obligation:weekly_low:1',
        'source_key', 'import:2026:obligation:weekly_low:1',
        'team_key', 'commit-opponent',
        'direction', 'team_owes_league',
        'amount_cents', 1000,
        'category', 'weekly_low_score_penalty',
        'description', 'Week 1 low score penalty',
        'occurred_on', '2026-09-08',
        'source_refs', jsonb_build_array('Weekly Results!A3:F3')
      )
    ),
    'payments', jsonb_build_array(
      jsonb_build_object(
        'preview_id', 'payment:weekly_high:1',
        'source_key', 'import:2026:payment:weekly_high:1',
        'team_key', 'development-franchise',
        'direction', 'to_team',
        'amount_cents', 2500,
        'paid_on', '2026-09-09',
        'method', 'cash',
        'reference', 'ledger:1',
        'note', 'Week 1 payout',
        'source_refs', jsonb_build_array('League Ledger!A2:F2')
      ),
      jsonb_build_object(
        'preview_id', 'payment:weekly_low:1',
        'source_key', 'import:2026:payment:weekly_low:1',
        'team_key', 'commit-opponent',
        'direction', 'from_team',
        'amount_cents', 1000,
        'paid_on', '2026-09-09',
        'method', 'cash',
        'reference', 'ledger:2',
        'note', 'Week 1 penalty',
        'source_refs', jsonb_build_array('League Ledger!A3:F3')
      )
    ),
    'payment_allocations', jsonb_build_array(
      jsonb_build_object(
        'source_key', 'import:2026:allocation:weekly_high:1',
        'payment_preview_id', 'payment:weekly_high:1',
        'obligation_preview_id', 'obligation:weekly_high:1',
        'amount_cents', 2500
      ),
      jsonb_build_object(
        'source_key', 'import:2026:allocation:weekly_low:1',
        'payment_preview_id', 'payment:weekly_low:1',
        'obligation_preview_id', 'obligation:weekly_low:1',
        'amount_cents', 1000
      )
    ),
    'external_cash_events', jsonb_build_array(
      jsonb_build_object(
        'source_key', 'import:2026:external_cash:draft',
        'direction', 'cash_out',
        'amount_cents', 500,
        'category', 'draft_party_expense',
        'counterparty', null,
        'description', 'Test external expense',
        'occurred_on', null,
        'source_refs', jsonb_build_array('Net Cash!A2:B2')
      )
    ),
    'weekly_results', jsonb_build_array(
      jsonb_build_object(
        'week', 1,
        'phase', 'regular_season',
        'team_key', 'development-franchise',
        'opponent_team_key', 'commit-opponent',
        'score', 101.25,
        'result', 'win',
        'notes', null,
        'source_ref', 'Weekly Results!A2:F2'
      ),
      jsonb_build_object(
        'week', 1,
        'phase', 'regular_season',
        'team_key', 'commit-opponent',
        'opponent_team_key', 'development-franchise',
        'score', 99.75,
        'result', 'loss',
        'notes', null,
        'source_ref', 'Weekly Results!A3:F3'
      )
    ),
    'weekly_awards', jsonb_build_array(
      jsonb_build_object(
        'week', 1,
        'high_team_key', 'development-franchise',
        'high_score', 101.25,
        'payout_cents', 2500,
        'low_team_key', 'commit-opponent',
        'low_score', 99.75,
        'penalty_cents', 1000,
        'source_refs', jsonb_build_array(
          'Weekly Results!A2:F2',
          'Weekly Results!A3:F3'
        )
      )
    ),
    'reconciliation', jsonb_build_object(
      'totals', jsonb_build_object(
        'team_obligations_cents', 1000,
        'payments_from_team_cents', 1000,
        'league_obligations_cents', 2500,
        'payments_to_team_cents', 2500,
        'net_team_balance_cents', 0,
        'payment_cents', 3500,
        'allocated_payment_cents', 3500,
        'unallocated_payment_cents', 0
      ),
      'cash', jsonb_build_object(
        'team_cash_in_cents', 1000,
        'team_cash_out_cents', 2500,
        'external_cash_in_cents', 0,
        'external_cash_out_cents', 500,
        'cash_balance_cents', -2000
      )
    )
  )
), (
  'rollback',
  jsonb_build_object(
    'status', 'review_only',
    'committed', false,
    'source', jsonb_build_object('sha256', repeat('e', 64)),
    'approval', jsonb_build_object('decision_queue_status', 'approved'),
    'commit_gate', jsonb_build_object(
      'ready_for_domain_commit', true,
      'blocking_issues', jsonb_build_array()
    ),
    'season', jsonb_build_object('year', 2026),
    'teams', jsonb_build_array(
      jsonb_build_object('team_key', 'development-franchise')
    ),
    'financial_obligations', jsonb_build_array(
      jsonb_build_object(
        'preview_id', 'obligation:atomic',
        'source_key', 'import:2026:obligation:atomic-rollback',
        'team_key', 'development-franchise',
        'direction', 'team_owes_league',
        'amount_cents', 100,
        'category', 'test_atomicity',
        'description', 'Must roll back',
        'occurred_on', '2026-09-10',
        'source_refs', jsonb_build_array('Atomic!A1')
      )
    ),
    'payments', jsonb_build_array(),
    'payment_allocations', jsonb_build_array(),
    'external_cash_events', jsonb_build_array(),
    'weekly_results', jsonb_build_array(),
    'weekly_awards', jsonb_build_array(),
    'reconciliation', jsonb_build_object(
      'totals', jsonb_build_object(
        'team_obligations_cents', 999,
        'payments_from_team_cents', 0,
        'league_obligations_cents', 0,
        'payments_to_team_cents', 0,
        'net_team_balance_cents', 999,
        'payment_cents', 0,
        'allocated_payment_cents', 0,
        'unallocated_payment_cents', 0
      ),
      'cash', jsonb_build_object(
        'team_cash_in_cents', 0,
        'team_cash_out_cents', 0,
        'external_cash_in_cents', 0,
        'external_cash_out_cents', 0,
        'cash_balance_cents', 0
      )
    )
  )
);

grant select on table commit_test_previews to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

select is(
  public.commit_historical_import(
    'e0000000-0000-4000-8000-000000000003',
    (select payload from commit_test_previews where name = 'success')
  ) ->> 'status',
  'committed',
  'commissioner should atomically commit an approved preview'
);

reset role;

select is(
  (
    select status::text
    from public.historical_import_batches
    where id = 'e0000000-0000-4000-8000-000000000003'
  ),
  'committed',
  'commit should move the batch to its committed terminal state'
);

select is(
  (select count(*) from public.historical_import_commits),
  1::bigint,
  'commit should preserve the canonical normalized preview'
);

select is(
  (
    select record_counts ->> 'weekly_results'
    from public.historical_import_commits
    where batch_id = 'e0000000-0000-4000-8000-000000000003'
  ),
  '2',
  'commit should record deterministic domain counts'
);

select is(
  (
    select count(*)
    from public.historical_import_committed_records
    where batch_id = 'e0000000-0000-4000-8000-000000000003'
  ),
  11::bigint,
  'commit should preserve provenance for every created record'
);

select is(
  (select count(*) from public.financial_obligations where source_key like 'import:2026:%'),
  2::bigint,
  'commit should create separate obligations'
);

select is(
  (select count(*) from public.payments where source_key like 'import:2026:%'),
  2::bigint,
  'commit should create separate payments'
);

select is(
  (select count(*) from public.payment_allocations where source_key like 'import:2026:%'),
  2::bigint,
  'commit should allocate every imported payment'
);

select is(
  (select count(*) from public.external_cash_events where source_key like 'import:2026:%'),
  1::bigint,
  'commit should create the external cash event'
);

select is(
  (select count(*) from public.matchups where source_key like 'import:2026:%'),
  1::bigint,
  'commit should create one matchup from reciprocal results'
);

select is(
  (select count(*) from public.weekly_results where source_key like 'import:2026:%'),
  2::bigint,
  'commit should create both weekly result rows'
);

select is(
  (select count(*) from public.weekly_awards where source_key like 'import:2026:%'),
  1::bigint,
  'commit should create the linked weekly award'
);

select is(
  (
    select score::text
    from public.weekly_results
    where source_key = 'import:2026:weekly_result:1:development-franchise'
  ),
  '101.25',
  'commit should preserve exact source scores'
);

select ok(
  (
    select award.high_score_obligation_id = obligation.id
    from public.weekly_awards as award
    join public.financial_obligations as obligation
      on obligation.id = award.high_score_obligation_id
    where award.source_key = 'import:2026:weekly_award:1'
      and obligation.amount_cents = 2500
  ),
  'weekly award should link to its exact payout obligation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

select is(
  public.commit_historical_import(
    'e0000000-0000-4000-8000-000000000003',
    (select payload from commit_test_previews where name = 'success')
  ) ->> 'status',
  'already_committed',
  'repeating the same preview should be idempotent'
);

reset role;

select is(
  (
    select count(*)
    from public.historical_import_committed_records
    where batch_id = 'e0000000-0000-4000-8000-000000000003'
  ),
  11::bigint,
  'idempotent replay should not duplicate provenance'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

select throws_ok(
  format(
    'select public.commit_historical_import(%L, %L::jsonb)',
    'e0000000-0000-4000-8000-000000000003',
    jsonb_set(
      (select payload from commit_test_previews where name = 'success'),
      '{weekly_results,0,score}',
      '102'::jsonb
    )::text
  ),
  '55000',
  'normalized preview does not match committed preview',
  'idempotent replay should reject a changed preview'
);

select throws_ok(
  format(
    'select public.commit_historical_import(%L, %L::jsonb)',
    'e0000000-0000-4000-8000-000000000004',
    (select payload::text from commit_test_previews where name = 'rollback')
  ),
  '55000',
  'normalized preview reconciliation failed',
  'failed reconciliation should abort the commit'
);

reset role;

select is(
  (
    select count(*)
    from public.financial_obligations
    where source_key = 'import:2026:obligation:atomic-rollback'
  ),
  0::bigint,
  'failed commit should roll back domain records'
);

select is(
  (
    select status::text
    from public.historical_import_batches
    where id = 'e0000000-0000-4000-8000-000000000004'
  ),
  'approved',
  'failed commit should leave its batch approved'
);

select is(
  (
    select count(*)
    from public.historical_import_commits
    where batch_id = 'e0000000-0000-4000-8000-000000000004'
  ),
  0::bigint,
  'failed commit should not create a canonical commit record'
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
  'e0000000-0000-4000-8000-000000000005',
  'authenticated',
  'authenticated',
  'commit-member@example.test',
  '',
  timezone('utc', statement_timestamp()),
  '',
  '',
  '',
  '',
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"Commit Member"}',
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
  'e0000000-0000-4000-8000-000000000005',
  'member',
  'active',
  timezone('utc', statement_timestamp()),
  'd0000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e0000000-0000-4000-8000-000000000005',
  true
);

select throws_ok(
  format(
    'select public.commit_historical_import(%L, %L::jsonb)',
    'e0000000-0000-4000-8000-000000000004',
    (select payload::text from commit_test_previews where name = 'rollback')
  ),
  '42501',
  'only an active league commissioner can commit history',
  'ordinary members should not commit history'
);

select is(
  (select count(*) from public.historical_import_commits),
  0::bigint,
  'ordinary members should not read canonical historical commits'
);

reset role;

select is(
  (
    select source_refs ->> 0
    from public.historical_import_committed_records
    where batch_id = 'e0000000-0000-4000-8000-000000000003'
      and record_kind = 'weekly_result'
      and source_key = 'import:2026:weekly_result:1:development-franchise'
  ),
  'Weekly Results!A2:F2',
  'provenance should preserve raw source references'
);

select * from finish();
rollback;
