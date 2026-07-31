begin;

select plan(33);

select has_type(
  'public',
  'historical_import_status',
  'historical import status enum should exist'
);

select has_type(
  'public',
  'historical_mapping_status',
  'historical mapping status enum should exist'
);

select has_type(
  'public',
  'historical_team_identifier_kind',
  'historical team identifier enum should exist'
);

select has_type(
  'public',
  'historical_event_target_kind',
  'historical event target enum should exist'
);

select has_type(
  'public',
  'historical_issue_severity',
  'historical issue severity enum should exist'
);

select has_type(
  'public',
  'historical_issue_status',
  'historical issue status enum should exist'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class
    join pg_catalog.pg_namespace
      on pg_namespace.oid = pg_class.relnamespace
    where pg_namespace.nspname = 'public'
      and pg_class.relname in (
        'historical_event_mappings',
        'historical_import_batches',
        'historical_import_issues',
        'historical_import_rows',
        'historical_team_mappings'
      )
      and pg_class.relrowsecurity
  ),
  5::bigint,
  'every historical import table should have RLS enabled'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.historical_import_batches',
    'delete'
  ),
  'authenticated users should not delete import batches'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.historical_import_rows',
    'update'
  ),
  'authenticated users should not update source evidence'
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
values (
  'a0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'synthetic-history.xlsx',
  repeat('a', 64),
  '{"sheets":[{"name":"League Ledger","range":"A1:F3"}]}'::jsonb,
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.historical_import_rows (
  batch_id,
  league_id,
  season_id,
  source_sheet,
  source_row_number,
  source_range,
  raw_values,
  row_sha256,
  created_by
)
values
  (
    'a0000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'League Ledger',
    2,
    'A2:F2',
    '["member@example.test","Example Team",45967,"Low Score",20,"Penalty Assessed"]',
    repeat('b', 64),
    'd0000000-0000-4000-8000-000000000001'
  ),
  (
    'a0000000-0000-4000-8000-000000000001',
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'League Ledger',
    3,
    'A3:F3',
    '["member@example.test","Example Team",45967,"Low Score",20,"Penalty Assessed"]',
    repeat('b', 64),
    'd0000000-0000-4000-8000-000000000001'
  );

select is(
  (
    select count(*)
    from public.historical_import_rows
    where row_sha256 = repeat('b', 64)
  ),
  2::bigint,
  'duplicate source rows should be preserved as distinct evidence'
);

insert into public.historical_team_mappings (
  id,
  batch_id,
  league_id,
  season_id,
  identifier_kind,
  source_value,
  created_by
)
values (
  'a0000000-0000-4000-8000-000000000002',
  'a0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'team_name',
  'Development Franchise 2026',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.historical_event_mappings (
  id,
  batch_id,
  league_id,
  season_id,
  source_type,
  source_subtype,
  created_by
)
values (
  'a0000000-0000-4000-8000-000000000003',
  'a0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'Penalty Assessed',
  'Low Score',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.historical_import_issues (
  id,
  batch_id,
  league_id,
  season_id,
  source_sheet,
  source_row_number,
  issue_code,
  severity,
  summary,
  evidence,
  created_by
)
values (
  'a0000000-0000-4000-8000-000000000004',
  'a0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'League Ledger',
  2,
  'duplicate_source_row',
  'blocking',
  'Two source rows contain the same evidence.',
  '{"matching_row":3}'::jsonb,
  'd0000000-0000-4000-8000-000000000001'
);

select is(
  (
    select source_row_count
    from public.historical_import_batch_review
    where batch_id = 'a0000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'review view should count source rows'
);

select is(
  (
    select pending_team_mapping_count
    from public.historical_import_batch_review
    where batch_id = 'a0000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'review view should count pending team mappings'
);

select is(
  (
    select pending_event_mapping_count
    from public.historical_import_batch_review
    where batch_id = 'a0000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'review view should count pending event mappings'
);

select is(
  (
    select open_blocking_issue_count
    from public.historical_import_batch_review
    where batch_id = 'a0000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'review view should count open blocking issues'
);

select is(
  (
    select ready_for_approval
    from public.historical_import_batch_review
    where batch_id = 'a0000000-0000-4000-8000-000000000001'
  ),
  false,
  'batch with unresolved review work should not be approval-ready'
);

update public.historical_import_batches
set status = 'reviewing'
where id = 'a0000000-0000-4000-8000-000000000001';

select is(
  (
    select status::text
    from public.historical_import_batches
    where id = 'a0000000-0000-4000-8000-000000000001'
  ),
  'reviewing',
  'staged batch should enter review'
);

select throws_ok(
  $$
    update public.historical_import_batches
    set
      status = 'approved',
      approved_by = 'd0000000-0000-4000-8000-000000000001',
      approved_at = timezone('utc', statement_timestamp())
    where id = 'a0000000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'historical import has unresolved mappings',
  'pending mappings should block approval'
);

update public.historical_team_mappings
set
  status = 'mapped',
  season_team_id = 'd0000000-0000-4000-8000-000000000008',
  decision_note = 'Matched by the canonical season team name.',
  decided_by = 'd0000000-0000-4000-8000-000000000001',
  decided_at = timezone('utc', statement_timestamp())
where id = 'a0000000-0000-4000-8000-000000000002';

update public.historical_event_mappings
set
  status = 'mapped',
  target_kind = 'obligation',
  obligation_direction = 'team_owes_league',
  target_category = 'weekly_low_score_penalty',
  decision_note = 'Workbook label represents a team obligation.',
  decided_by = 'd0000000-0000-4000-8000-000000000001',
  decided_at = timezone('utc', statement_timestamp())
where id = 'a0000000-0000-4000-8000-000000000003';

select throws_ok(
  $$
    update public.historical_import_batches
    set
      status = 'approved',
      approved_by = 'd0000000-0000-4000-8000-000000000001',
      approved_at = timezone('utc', statement_timestamp())
    where id = 'a0000000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'historical import has open blocking issues',
  'open blocking issues should block approval'
);

update public.historical_import_issues
set
  status = 'resolved',
  decision_note = 'Keep both rows as evidence; reject one during preview.',
  decided_by = 'd0000000-0000-4000-8000-000000000001',
  decided_at = timezone('utc', statement_timestamp())
where id = 'a0000000-0000-4000-8000-000000000004';

select is(
  (
    select ready_for_approval
    from public.historical_import_batch_review
    where batch_id = 'a0000000-0000-4000-8000-000000000001'
  ),
  true,
  'resolved mappings and blockers should make the batch approval-ready'
);

update public.historical_import_batches
set
  status = 'approved',
  approved_by = 'd0000000-0000-4000-8000-000000000001',
  approved_at = timezone('utc', statement_timestamp())
where id = 'a0000000-0000-4000-8000-000000000001';

select is(
  (
    select status::text
    from public.historical_import_batches
    where id = 'a0000000-0000-4000-8000-000000000001'
  ),
  'approved',
  'review-complete batch should be approved'
);

select throws_ok(
  $$
    update public.historical_team_mappings
    set decision_note = 'Attempted post-approval rewrite.'
    where id = 'a0000000-0000-4000-8000-000000000002'
  $$,
  '55000',
  'approved, committed, and rejected imports cannot be changed',
  'approved mappings should be frozen'
);

select throws_ok(
  $$
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
    values (
      'a0000000-0000-4000-8000-000000000001',
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'League Ledger',
      4,
      '["late row"]',
      repeat('c', 64),
      'd0000000-0000-4000-8000-000000000001'
    )
  $$,
  '55000',
  'approved, committed, and rejected imports cannot be changed',
  'approved source evidence should be frozen'
);

update public.historical_import_batches
set
  status = 'committed',
  committed_by = 'd0000000-0000-4000-8000-000000000001',
  committed_at = timezone('utc', statement_timestamp())
where id = 'a0000000-0000-4000-8000-000000000001';

select is(
  (
    select status::text
    from public.historical_import_batches
    where id = 'a0000000-0000-4000-8000-000000000001'
  ),
  'committed',
  'approved batch should enter the committed terminal state'
);

select throws_ok(
  $$
    update public.historical_import_batches
    set
      status = 'reviewing',
      approved_by = null,
      approved_at = null,
      committed_by = null,
      committed_at = null
    where id = 'a0000000-0000-4000-8000-000000000001'
  $$,
  '55000',
  'committed and rejected imports are terminal',
  'committed batches should be terminal'
);

select throws_ok(
  $$
    update public.historical_import_rows
    set raw_values = '["changed"]'::jsonb
    where batch_id = 'a0000000-0000-4000-8000-000000000001'
      and source_row_number = 2
  $$,
  '55000',
  'historical source rows are immutable',
  'raw source evidence should be immutable'
);

select throws_ok(
  $$
    insert into public.historical_import_batches (
      league_id,
      season_id,
      source_filename,
      source_sha256,
      source_manifest,
      created_by
    )
    values (
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'same-source-copy.xlsx',
      repeat('a', 64),
      '{}'::jsonb,
      'd0000000-0000-4000-8000-000000000001'
    )
  $$,
  '23505',
  null,
  'the same workbook hash should not be staged twice for a season'
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
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'authenticated',
    'authenticated',
    'history-member@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"History Member"}',
    timezone('utc', statement_timestamp()),
    timezone('utc', statement_timestamp())
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'authenticated',
    'authenticated',
    'history-outsider@example.test',
    '',
    timezone('utc', statement_timestamp()),
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"History Outsider"}',
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
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
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
  (select count(*) from public.historical_import_batches),
  1::bigint,
  'commissioner should see their historical import batch'
);

select is(
  (select count(*) from public.historical_import_batch_review),
  1::bigint,
  'commissioner should see the historical review view'
);

select set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  true
);

select is(
  (select count(*) from public.historical_import_batches),
  0::bigint,
  'ordinary members should not see historical import batches'
);

select is(
  (select count(*) from public.historical_import_rows),
  0::bigint,
  'ordinary members should not see raw workbook evidence'
);

select is(
  (select count(*) from public.historical_team_mappings),
  0::bigint,
  'ordinary members should not see historical mappings'
);

select throws_ok(
  $$
    insert into public.historical_import_issues (
      batch_id,
      league_id,
      season_id,
      issue_code,
      severity,
      summary,
      created_by
    )
    values (
      'a0000000-0000-4000-8000-000000000001',
      'd0000000-0000-4000-8000-000000000002',
      'd0000000-0000-4000-8000-000000000004',
      'member_write_attempt',
      'warning',
      'Member should not create this issue.',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
    )
  $$,
  '42501',
  null,
  'ordinary members should not create historical review records'
);

select set_config(
  'request.jwt.claim.sub',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  true
);

select is(
  (select count(*) from public.historical_import_batch_review),
  0::bigint,
  'outsiders should not see historical review state'
);

reset role;

select *
from finish();

rollback;
