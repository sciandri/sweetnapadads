create type public.season_financial_rule_kind as enum (
  'weekly_high_score',
  'weekly_low_score_penalty',
  'placement_payout',
  'season_award',
  'penalty'
);

revoke all on type public.season_financial_rule_kind from public;
grant usage on type public.season_financial_rule_kind to authenticated, service_role;

create table public.season_financial_rules (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  rule_key text not null
    check (rule_key = lower(rule_key) and rule_key ~ '^[a-z][a-z0-9_]{0,49}$'),
  rule_kind public.season_financial_rule_kind not null,
  label text not null check (length(btrim(label)) between 1 and 100),
  direction public.obligation_direction not null,
  amount_cents public.nonnegative_money_cents not null check (amount_cents > 0),
  recipient_rank smallint check (recipient_rank is null or recipient_rank > 0),
  enabled boolean not null default true,
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp()),
  foreign key (season_id, league_id)
    references public.seasons (id, league_id) on delete restrict,
  unique (season_id, rule_key),
  check (
    (rule_kind = 'placement_payout' and recipient_rank is not null)
    or (rule_kind <> 'placement_payout' and recipient_rank is null)
  ),
  check (
    (rule_kind in ('weekly_low_score_penalty', 'penalty')
      and direction = 'team_owes_league')
    or (rule_kind in ('weekly_high_score', 'placement_payout', 'season_award')
      and direction = 'league_owes_team')
  )
);

create unique index season_financial_rules_placement_rank_idx
  on public.season_financial_rules (season_id, recipient_rank)
  where rule_kind = 'placement_payout' and enabled;

create index season_financial_rules_season_enabled_idx
  on public.season_financial_rules (season_id, enabled, rule_kind);

create trigger season_financial_rules_set_updated_at
before update on public.season_financial_rules
for each row execute function private.set_updated_at();

create table public.season_financial_rule_changes (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  rules jsonb not null check (jsonb_typeof(rules) = 'array'),
  changed_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  foreign key (season_id, league_id)
    references public.seasons (id, league_id) on delete restrict
);

create or replace function private.prevent_financial_rule_change_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'season financial rule audit batches are immutable';
end;
$$;

create trigger prevent_financial_rule_change_mutation
before update or delete on public.season_financial_rule_changes
for each row execute function private.prevent_financial_rule_change_mutation();

alter table public.season_financial_rules enable row level security;
alter table public.season_financial_rule_changes enable row level security;

revoke all on table public.season_financial_rules from public, anon, authenticated;
revoke all on table public.season_financial_rule_changes from public, anon, authenticated;
grant select on table public.season_financial_rules to authenticated;
grant select on table public.season_financial_rule_changes to authenticated;
grant all on table public.season_financial_rules to service_role;
grant all on table public.season_financial_rule_changes to service_role;

create policy season_financial_rules_select_member
on public.season_financial_rules
for select to authenticated
using (private.is_active_league_member(league_id));

create policy season_financial_rule_changes_select_commissioner
on public.season_financial_rule_changes
for select to authenticated
using (private.is_league_commissioner(league_id));

insert into public.season_financial_rules (
  league_id, season_id, rule_key, rule_kind, label, direction, amount_cents,
  created_by
)
select
  season.league_id,
  settings.season_id,
  rule.rule_key,
  rule.rule_kind::public.season_financial_rule_kind,
  rule.label,
  rule.direction::public.obligation_direction,
  rule.amount_cents,
  settings.created_by
from public.season_settings as settings
join public.seasons as season on season.id = settings.season_id
cross join lateral (
  values
    (
      'weekly_high_score',
      'weekly_high_score',
      'Weekly high score',
      'league_owes_team',
      settings.weekly_high_score_payout_cents
    ),
    (
      'weekly_low_score_penalty',
      'weekly_low_score_penalty',
      'Weekly low score penalty',
      'team_owes_league',
      settings.weekly_low_score_penalty_cents
    )
) as rule(rule_key, rule_kind, label, direction, amount_cents)
where rule.amount_cents > 0;

create or replace function private.initialize_season_financial_rules()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_league_id uuid;
begin
  select league_id into target_league_id
  from public.seasons
  where id = new.season_id;

  if new.weekly_high_score_payout_cents > 0 then
    insert into public.season_financial_rules (
      league_id, season_id, rule_key, rule_kind, label, direction,
      amount_cents, created_by
    ) values (
      target_league_id, new.season_id, 'weekly_high_score',
      'weekly_high_score', 'Weekly high score', 'league_owes_team',
      new.weekly_high_score_payout_cents, new.created_by
    ) on conflict (season_id, rule_key) do nothing;
  end if;

  if new.weekly_low_score_penalty_cents > 0 then
    insert into public.season_financial_rules (
      league_id, season_id, rule_key, rule_kind, label, direction,
      amount_cents, created_by
    ) values (
      target_league_id, new.season_id, 'weekly_low_score_penalty',
      'weekly_low_score_penalty', 'Weekly low score penalty',
      'team_owes_league', new.weekly_low_score_penalty_cents, new.created_by
    ) on conflict (season_id, rule_key) do nothing;
  end if;

  return new;
end;
$$;

create trigger initialize_season_financial_rules
after insert on public.season_settings
for each row execute function private.initialize_season_financial_rules();

revoke update (
  weekly_high_score_payout_cents,
  weekly_low_score_penalty_cents
) on public.season_settings from authenticated;

create or replace function public.set_season_financial_rules(
  target_season_id uuid,
  target_rules jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_league_id uuid;
  input_count integer;
  change_id uuid;
  high_amount public.nonnegative_money_cents;
  low_amount public.nonnegative_money_cents;
begin
  if jsonb_typeof(target_rules) <> 'array'
     or jsonb_array_length(target_rules) < 2
     or jsonb_array_length(target_rules) > 100 then
    raise exception using
      errcode = '22023',
      message = 'financial rules must contain between 2 and 100 entries';
  end if;

  select league_id into target_league_id
  from public.seasons
  where id = target_season_id;

  if target_league_id is null then
    raise exception using errcode = '23503', message = 'financial rule season was not found';
  end if;

  if not private.is_league_commissioner(target_league_id) then
    raise exception using
      errcode = '42501',
      message = 'only an active commissioner may change financial rules';
  end if;

  input_count := jsonb_array_length(target_rules);

  if exists (
    select 1
    from jsonb_to_recordset(target_rules) as rule(
      rule_key text,
      rule_kind text,
      label text,
      direction text,
      amount_cents bigint,
      recipient_rank integer
    )
    where rule_key is null
      or rule_key !~ '^[a-z][a-z0-9_]{0,49}$'
      or label is null
      or length(btrim(label)) not between 1 and 100
      or amount_cents is null
      or amount_cents <= 0
      or amount_cents > 9007199254740991
      or rule_kind not in (
        'weekly_high_score', 'weekly_low_score_penalty', 'placement_payout',
        'season_award', 'penalty'
      )
      or direction not in ('league_owes_team', 'team_owes_league')
      or (rule_kind = 'placement_payout' and recipient_rank is null)
      or (rule_kind <> 'placement_payout' and recipient_rank is not null)
      or (rule_kind in ('weekly_low_score_penalty', 'penalty')
        and direction <> 'team_owes_league')
      or (rule_kind in ('weekly_high_score', 'placement_payout', 'season_award')
        and direction <> 'league_owes_team')
  ) or exists (
    select 1
    from jsonb_to_recordset(target_rules) as rule(rule_key text)
    group by rule_key having count(*) > 1
  ) or exists (
    select 1
    from jsonb_to_recordset(target_rules) as rule(
      rule_kind text,
      recipient_rank integer
    )
    where rule_kind = 'placement_payout'
    group by recipient_rank having count(*) > 1
  ) then
    raise exception using errcode = '22023', message = 'financial rules are invalid or duplicated';
  end if;

  if (
    select count(*)
    from jsonb_to_recordset(target_rules) as rule(rule_key text, rule_kind text)
    where rule_key = 'weekly_high_score' and rule_kind = 'weekly_high_score'
  ) <> 1 or (
    select count(*)
    from jsonb_to_recordset(target_rules) as rule(rule_key text, rule_kind text)
    where rule_key = 'weekly_low_score_penalty'
      and rule_kind = 'weekly_low_score_penalty'
  ) <> 1 then
    raise exception using
      errcode = '22023',
      message = 'weekly high and low financial rules are required';
  end if;

  update public.season_financial_rules
  set enabled = false
  where season_id = target_season_id and enabled;

  insert into public.season_financial_rules (
    league_id, season_id, rule_key, rule_kind, label, direction, amount_cents,
    recipient_rank, enabled, created_by
  )
  select
    target_league_id,
    target_season_id,
    rule.rule_key,
    rule.rule_kind::public.season_financial_rule_kind,
    rule.label,
    rule.direction::public.obligation_direction,
    rule.amount_cents,
    rule.recipient_rank,
    true,
    auth.uid()
  from jsonb_to_recordset(target_rules) as rule(
    rule_key text,
    rule_kind text,
    label text,
    direction text,
    amount_cents bigint,
    recipient_rank integer
  )
  on conflict (season_id, rule_key) do update
  set
    rule_kind = excluded.rule_kind,
    label = excluded.label,
    direction = excluded.direction,
    amount_cents = excluded.amount_cents,
    recipient_rank = excluded.recipient_rank,
    enabled = true;

  select amount_cents into high_amount
  from public.season_financial_rules
  where season_id = target_season_id
    and rule_key = 'weekly_high_score'
    and enabled;

  select amount_cents into low_amount
  from public.season_financial_rules
  where season_id = target_season_id
    and rule_key = 'weekly_low_score_penalty'
    and enabled;

  update public.season_settings
  set
    weekly_high_score_payout_cents = high_amount,
    weekly_low_score_penalty_cents = low_amount
  where season_id = target_season_id;

  insert into public.season_financial_rule_changes (
    league_id, season_id, rules, changed_by
  ) values (
    target_league_id, target_season_id, target_rules, auth.uid()
  ) returning id into change_id;

  return jsonb_build_object(
    'status', 'saved',
    'season_id', target_season_id,
    'rule_count', input_count,
    'change_id', change_id
  );
end;
$$;

revoke all on function private.prevent_financial_rule_change_mutation()
from public, anon, authenticated;
grant execute on function private.prevent_financial_rule_change_mutation()
to service_role;

revoke all on function private.initialize_season_financial_rules()
from public, anon, authenticated;
grant execute on function private.initialize_season_financial_rules()
to service_role;

revoke all on function public.set_season_financial_rules(uuid, jsonb)
from public, anon;
grant execute on function public.set_season_financial_rules(uuid, jsonb)
to authenticated, service_role;

comment on table public.season_financial_rules is
  'Canonical season-scoped payout and penalty configuration in integer cents.';
comment on table public.season_financial_rule_changes is
  'Immutable commissioner audit snapshots of accepted season financial rules.';
comment on function public.set_season_financial_rules(uuid, jsonb) is
  'Validates and replaces the enabled season payout/penalty configuration with an immutable audit snapshot.';
