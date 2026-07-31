begin;

select plan(8);

select has_schema(
  'private',
  'private schema should exist'
);

select has_type(
  'public',
  'league_member_role',
  'league_member_role enum should exist'
);

select results_eq(
  $$
    select enum_value::text
    from unnest(enum_range(null::public.league_member_role))
      with ordinality as values_with_order(enum_value, position)
    order by position
  $$,
  $$ values ('member'::text), ('commissioner'::text) $$,
  'league_member_role labels should remain ordered'
);

select has_type(
  'public',
  'membership_status',
  'membership_status enum should exist'
);

select has_type(
  'public',
  'season_status',
  'season_status enum should exist'
);

select has_domain(
  'public',
  'nonnegative_money_cents',
  'nonnegative_money_cents domain should exist'
);

select has_function(
  'private',
  'set_updated_at',
  array[]::text[],
  'set_updated_at trigger function should exist'
);

select function_returns(
  'private',
  'set_updated_at',
  array[]::text[],
  'trigger',
  'set_updated_at should return trigger'
);

select * from finish();

rollback;
