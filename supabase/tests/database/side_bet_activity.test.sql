begin;

select plan(11);

select has_table('public', 'side_bets', 'side-bet activity table should exist');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.side_bets'::regclass),
  'side-bet activity should enforce RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.side_bets', 'select')
  and has_column_privilege('authenticated', 'public.side_bets', 'description', 'insert')
  and not has_table_privilege('authenticated', 'public.side_bets', 'update')
  and not has_table_privilege('authenticated', 'public.side_bets', 'delete'),
  'authenticated access should be read/commissioner-insert only'
);

insert into public.teams (id, league_id, name, slug, created_by)
values (
  '51000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'Side Bet Opponent',
  'side-bet-opponent',
  'd0000000-0000-4000-8000-000000000001'
);

insert into public.season_teams (
  id, league_id, season_id, team_id, name, status, created_by
)
values (
  '51000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  '51000000-0000-4000-8000-000000000001',
  'Side Bet Opponent 2026',
  'active',
  'd0000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);

insert into public.side_bets (
  league_id, season_id, party_one_season_team_id,
  party_two_season_team_id, description, amount_cents,
  source_type, source_key, source_refs
)
values (
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000004',
  'd0000000-0000-4000-8000-000000000008',
  '51000000-0000-4000-8000-000000000002',
  'Development side bet',
  2000,
  'manual',
  'manual:side-bet:test',
  '["test"]'::jsonb
);

select is((select count(*) from public.side_bets), 1::bigint, 'commissioner should insert side-bet evidence');
select is((select amount_cents::bigint from public.side_bets), 2000::bigint, 'side-bet amount should remain integer cents');
select is((select description from public.side_bets), 'Development side bet', 'member should read the exact description');

select set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
select is((select count(*) from public.side_bets), 0::bigint, 'outsider should not read side-bet evidence');
select throws_ok(
  $$ insert into public.side_bets (
    league_id, season_id, party_one_season_team_id,
    party_two_season_team_id, description, amount_cents,
    source_type, source_key, source_refs
  ) values (
    'd0000000-0000-4000-8000-000000000002',
    'd0000000-0000-4000-8000-000000000004',
    'd0000000-0000-4000-8000-000000000008',
    '51000000-0000-4000-8000-000000000002',
    'Unauthorized side bet', 2000, 'manual',
    'manual:side-bet:outsider', '["test"]'::jsonb
  ) $$,
  '42501',
  null,
  'outsider should not insert side-bet evidence'
);

reset role;
select throws_ok(
  $$ update public.side_bets set description = 'Mutated' $$,
  '55000',
  'side-bet evidence is immutable',
  'side-bet evidence should reject updates'
);
select throws_ok(
  $$ delete from public.side_bets $$,
  '55000',
  'side-bet evidence is immutable',
  'side-bet evidence should reject deletes'
);
select is((select count(*) from public.side_bets), 1::bigint, 'failed mutations should preserve the record');

select * from finish();
rollback;
