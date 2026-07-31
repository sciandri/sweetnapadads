create type public.external_cash_direction as enum (
  'cash_in',
  'cash_out'
);

revoke all on type public.external_cash_direction from public;

create table public.external_cash_events (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  direction public.external_cash_direction not null,
  amount_cents public.nonnegative_money_cents not null
    check (amount_cents > 0),
  category text not null
    check (
      category = lower(category)
      and category ~ '^[a-z][a-z0-9_]{0,49}$'
    ),
  counterparty text
    check (
      counterparty is null
      or length(btrim(counterparty)) between 1 and 200
    ),
  description text not null
    check (length(btrim(description)) between 1 and 500),
  source_type public.financial_source_type not null,
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 200
    ),
  occurred_on date,
  created_by uuid references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint external_cash_events_season_fkey
    foreign key (season_id, league_id)
    references public.seasons (id, league_id)
    on delete restrict,
  constraint external_cash_events_source_key_key
    unique (season_id, source_key),
  constraint external_cash_events_import_date_check
    check (occurred_on is not null or source_type = 'import')
);

create index external_cash_events_season_date_idx
  on public.external_cash_events (season_id, occurred_on, created_at);

create trigger external_cash_events_are_immutable
before update or delete on public.external_cash_events
for each row execute function private.prevent_financial_event_mutation();

alter table public.external_cash_events enable row level security;

create policy "members can read external cash events"
on public.external_cash_events
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "commissioners can create external cash events"
on public.external_cash_events
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and (created_by is null or created_by = (select auth.uid()))
);

create view public.season_cash_balances
with (security_invoker = true)
as
select
  season.league_id,
  season.id as season_id,
  coalesce(team_payment.cash_in_cents, 0)::bigint
    as team_cash_in_cents,
  coalesce(team_payment.cash_out_cents, 0)::bigint
    as team_cash_out_cents,
  coalesce(external_cash.cash_in_cents, 0)::bigint
    as external_cash_in_cents,
  coalesce(external_cash.cash_out_cents, 0)::bigint
    as external_cash_out_cents,
  (
    coalesce(team_payment.cash_in_cents, 0)
    - coalesce(team_payment.cash_out_cents, 0)
    + coalesce(external_cash.cash_in_cents, 0)
    - coalesce(external_cash.cash_out_cents, 0)
  )::bigint as cash_balance_cents
from public.seasons as season
left join (
  select
    season_id,
    sum(amount_cents::bigint)
      filter (where direction = 'from_team') as cash_in_cents,
    sum(amount_cents::bigint)
      filter (where direction = 'to_team') as cash_out_cents
  from public.payments
  group by season_id
) as team_payment
  on team_payment.season_id = season.id
left join (
  select
    season_id,
    sum(amount_cents::bigint)
      filter (where direction = 'cash_in') as cash_in_cents,
    sum(amount_cents::bigint)
      filter (where direction = 'cash_out') as cash_out_cents
  from public.external_cash_events
  group by season_id
) as external_cash
  on external_cash.season_id = season.id;

comment on table public.external_cash_events is
  'Immutable cash movements between a league and a non-team counterparty.';

comment on view public.season_cash_balances is
  'Season cash derived from team payments and external league cash events.';

grant usage on type public.external_cash_direction
to authenticated, service_role;

grant select, insert on table public.external_cash_events
to authenticated, service_role;

grant select on table public.season_cash_balances
to authenticated, service_role;
