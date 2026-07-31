begin;

select plan(18);

select has_table(
  'public',
  'espn_team_mapping_changes',
  'ESPN mapping audit batches should exist'
);

select has_function(
  'public',
  'set_espn_season_team_mappings',
  array['uuid', 'jsonb'],
  'atomic ESPN mapping function should exist'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.set_espn_season_team_mappings(uuid,jsonb)',
    'execute'
  ),
  'authenticated callers should reach the authorization boundary'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.set_espn_season_team_mappings(uuid,jsonb)',
    'execute'
  ),
  'anonymous callers should not execute mapping changes'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  'd0000000-0000-4000-8000-000000000020',
  'd0000000-0000-4000-8000-000000000002',
  'Second Development Franchise',
  'second-development-franchise',
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
) values (
  'd0000000-0000-4000-8000-000000000021',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000020',
  'Second Development Team',
  'SDT',
  2,
  'active',
  'd0000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

create temporary table mapping_result as
select public.set_espn_season_team_mappings(
  'd0000000-0000-4000-8000-000000000004',
  '[
    {"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":2},
    {"season_team_id":"d0000000-0000-4000-8000-000000000021","espn_team_id":1}
  ]'::jsonb
) as result;

select is(
  (select result ->> 'status' from mapping_result),
  'saved',
  'commissioner should save an exact mapping batch'
);

select is(
  (select (result ->> 'mapped_count')::integer from mapping_result),
  2,
  'mapping result should report every active team'
);

select is(
  (
    select espn_team_id
    from public.season_teams
    where id = 'd0000000-0000-4000-8000-000000000008'
  ),
  2,
  'mapping replacement should safely swap the first ESPN identifier'
);

select is(
  (
    select espn_team_id
    from public.season_teams
    where id = 'd0000000-0000-4000-8000-000000000021'
  ),
  1,
  'mapping replacement should safely swap the second ESPN identifier'
);

select is(
  (select count(*) from public.espn_team_mapping_changes),
  1::bigint,
  'mapping replacement should create one immutable audit batch'
);

select is(
  (select changed_by from public.espn_team_mapping_changes),
  'd0000000-0000-4000-8000-000000000001'::uuid,
  'mapping audit should record the commissioner actor'
);

select throws_ok(
  $$
    select public.set_espn_season_team_mappings(
      'd0000000-0000-4000-8000-000000000004',
      '[{"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":1}]'::jsonb
    )
  $$,
  '22023',
  'ESPN mappings must exactly cover every active season team',
  'partial mapping batches should fail closed'
);

select throws_ok(
  $$
    select public.set_espn_season_team_mappings(
      'd0000000-0000-4000-8000-000000000004',
      '[
        {"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":1},
        {"season_team_id":"d0000000-0000-4000-8000-000000000021","espn_team_id":1}
      ]'::jsonb
    )
  $$,
  '22023',
  'ESPN mapping team identifiers must be positive and unique',
  'duplicate ESPN identifiers should fail closed'
);

select set_config(
  'request.jwt.claim.sub',
  '55555555-5555-4555-8555-555555555555',
  true
);

select throws_ok(
  $$
    select public.set_espn_season_team_mappings(
      'd0000000-0000-4000-8000-000000000004',
      '[
        {"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":1},
        {"season_team_id":"d0000000-0000-4000-8000-000000000021","espn_team_id":2}
      ]'::jsonb
    )
  $$,
  '23503',
  'ESPN mapping season was not found',
  'RLS should hide the target season from non-members before any mapping change'
);

select is(
  (select count(*) from public.espn_team_mapping_changes),
  0::bigint,
  'outsiders should not read mapping audit batches'
);

select set_config(
  'request.jwt.claim.sub',
  'd0000000-0000-4000-8000-000000000001',
  true
);

select is(
  (select count(*) from public.espn_team_mapping_changes),
  1::bigint,
  'commissioners should read mapping audit batches for their league'
);

select is(
  (
    select count(*)
    from public.espn_team_mapping_changes
    where mappings = '[
      {"season_team_id":"d0000000-0000-4000-8000-000000000008","espn_team_id":2},
      {"season_team_id":"d0000000-0000-4000-8000-000000000021","espn_team_id":1}
    ]'::jsonb
  ),
  1::bigint,
  'audit batch should preserve the exact accepted mapping evidence'
);

set local role service_role;

select throws_ok(
  $$
    update public.espn_team_mapping_changes
    set mappings = mappings
  $$,
  '55000',
  'ESPN team mapping audit batches are immutable',
  'even service operations should not update mapping audit evidence'
);

select throws_ok(
  $$
    delete from public.espn_team_mapping_changes
  $$,
  '55000',
  'ESPN team mapping audit batches are immutable',
  'even service operations should not delete mapping audit evidence'
);

select * from finish();

rollback;
