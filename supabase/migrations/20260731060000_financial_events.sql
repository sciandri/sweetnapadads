create type public.obligation_direction as enum (
  'team_owes_league',
  'league_owes_team'
);

create type public.payment_direction as enum (
  'from_team',
  'to_team'
);

create type public.balance_adjustment_direction as enum (
  'increase_team_balance',
  'decrease_team_balance'
);

create type public.payment_allocation_kind as enum (
  'apply',
  'reverse'
);

create type public.financial_source_type as enum (
  'manual',
  'rule',
  'import',
  'system'
);

revoke all on type public.obligation_direction from public;
revoke all on type public.payment_direction from public;
revoke all on type public.balance_adjustment_direction from public;
revoke all on type public.payment_allocation_kind from public;
revoke all on type public.financial_source_type from public;

alter table public.season_teams
  add constraint season_teams_id_league_season_key
  unique (id, league_id, season_id);

create table public.financial_obligations (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  season_team_id uuid not null,
  direction public.obligation_direction not null,
  amount_cents public.nonnegative_money_cents not null
    check (amount_cents > 0),
  category text not null
    check (
      category = lower(category)
      and category ~ '^[a-z][a-z0-9_]{0,49}$'
    ),
  description text not null
    check (length(btrim(description)) between 1 and 500),
  source_type public.financial_source_type not null,
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 200
    ),
  occurred_on date not null,
  created_by uuid references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint financial_obligations_season_team_fkey
    foreign key (season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id)
    on delete restrict,
  constraint financial_obligations_source_key_key
    unique (season_id, source_key),
  constraint financial_obligations_context_key
    unique (id, league_id, season_id, season_team_id)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  season_team_id uuid not null,
  direction public.payment_direction not null,
  amount_cents public.nonnegative_money_cents not null
    check (amount_cents > 0),
  paid_on date not null,
  method text
    check (
      method is null
      or (
        method = lower(method)
        and method ~ '^[a-z][a-z0-9_]{0,49}$'
      )
    ),
  reference text
    check (
      reference is null
      or (
        reference = btrim(reference)
        and length(reference) between 1 and 200
      )
    ),
  note text
    check (
      note is null
      or length(btrim(note)) between 1 and 500
    ),
  source_type public.financial_source_type not null,
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 200
    ),
  created_by uuid references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint payments_season_team_fkey
    foreign key (season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id)
    on delete restrict,
  constraint payments_source_key_key
    unique (season_id, source_key),
  constraint payments_context_key
    unique (id, league_id, season_id, season_team_id)
);

create table public.payment_allocations (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  season_team_id uuid not null,
  payment_id uuid not null,
  obligation_id uuid not null,
  kind public.payment_allocation_kind not null default 'apply',
  amount_cents public.nonnegative_money_cents not null
    check (amount_cents > 0),
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 200
    ),
  reverses_allocation_id uuid
    references public.payment_allocations (id) on delete restrict,
  reason text
    check (
      reason is null
      or length(btrim(reason)) between 1 and 500
    ),
  created_by uuid references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint payment_allocations_payment_fkey
    foreign key (payment_id, league_id, season_id, season_team_id)
    references public.payments (id, league_id, season_id, season_team_id)
    on delete restrict,
  constraint payment_allocations_obligation_fkey
    foreign key (obligation_id, league_id, season_id, season_team_id)
    references public.financial_obligations
      (id, league_id, season_id, season_team_id)
    on delete restrict,
  constraint payment_allocations_source_key_key
    unique (season_id, source_key),
  constraint payment_allocations_reversal_shape_check
    check (
      (
        kind = 'apply'
        and reverses_allocation_id is null
        and reason is null
      )
      or
      (
        kind = 'reverse'
        and reverses_allocation_id is not null
        and reason is not null
        and created_by is not null
      )
    )
);

create table public.financial_adjustments (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  season_team_id uuid not null,
  direction public.balance_adjustment_direction not null,
  amount_cents public.nonnegative_money_cents not null
    check (amount_cents > 0),
  reason text not null
    check (length(btrim(reason)) between 1 and 500),
  source_type public.financial_source_type not null,
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 200
    ),
  occurred_on date not null,
  related_obligation_id uuid,
  related_payment_id uuid,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint financial_adjustments_season_team_fkey
    foreign key (season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id)
    on delete restrict,
  constraint financial_adjustments_obligation_fkey
    foreign key (
      related_obligation_id,
      league_id,
      season_id,
      season_team_id
    )
    references public.financial_obligations
      (id, league_id, season_id, season_team_id)
    on delete restrict,
  constraint financial_adjustments_payment_fkey
    foreign key (
      related_payment_id,
      league_id,
      season_id,
      season_team_id
    )
    references public.payments (id, league_id, season_id, season_team_id)
    on delete restrict,
  constraint financial_adjustments_single_related_event_check
    check (num_nonnulls(related_obligation_id, related_payment_id) <= 1),
  constraint financial_adjustments_source_key_key
    unique (season_id, source_key)
);

create index financial_obligations_season_team_idx
  on public.financial_obligations (season_id, season_team_id, occurred_on);

create index payments_season_team_idx
  on public.payments (season_id, season_team_id, paid_on);

create index payment_allocations_payment_idx
  on public.payment_allocations (payment_id);

create index payment_allocations_obligation_idx
  on public.payment_allocations (obligation_id);

create index payment_allocations_reversal_idx
  on public.payment_allocations (reverses_allocation_id)
  where reverses_allocation_id is not null;

create index financial_adjustments_season_team_idx
  on public.financial_adjustments (season_id, season_team_id, occurred_on);

create or replace function private.prevent_financial_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'financial events are immutable; append a correction instead';
end;
$$;

create or replace function private.validate_payment_allocation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  payment_record public.payments%rowtype;
  obligation_record public.financial_obligations%rowtype;
  original_record public.payment_allocations%rowtype;
  allocated_to_payment bigint;
  allocated_to_obligation bigint;
  reversed_from_original bigint;
begin
  select *
  into payment_record
  from public.payments
  where id = new.payment_id
  for update;

  if not found then
    raise exception 'payment % does not exist', new.payment_id;
  end if;

  select *
  into obligation_record
  from public.financial_obligations
  where id = new.obligation_id
  for update;

  if not found then
    raise exception 'obligation % does not exist', new.obligation_id;
  end if;

  if (
    payment_record.direction = 'from_team'
    and obligation_record.direction <> 'team_owes_league'
  ) or (
    payment_record.direction = 'to_team'
    and obligation_record.direction <> 'league_owes_team'
  ) then
    raise exception
      'payment direction % cannot settle obligation direction %',
      payment_record.direction,
      obligation_record.direction;
  end if;

  if new.kind = 'apply' then
    select coalesce(
      sum(
        case
          when kind = 'apply' then amount_cents
          else -amount_cents
        end
      ),
      0
    )
    into allocated_to_payment
    from public.payment_allocations
    where payment_id = new.payment_id;

    if allocated_to_payment + new.amount_cents > payment_record.amount_cents then
      raise exception
        'allocation exceeds the payment amount';
    end if;

    select coalesce(
      sum(
        case
          when kind = 'apply' then amount_cents
          else -amount_cents
        end
      ),
      0
    )
    into allocated_to_obligation
    from public.payment_allocations
    where obligation_id = new.obligation_id;

    if (
      allocated_to_obligation + new.amount_cents
      > obligation_record.amount_cents
    ) then
      raise exception
        'allocation exceeds the obligation amount';
    end if;
  else
    select *
    into original_record
    from public.payment_allocations
    where id = new.reverses_allocation_id
    for update;

    if not found or original_record.kind <> 'apply' then
      raise exception
        'allocation reversal must reference an applied allocation';
    end if;

    if (
      original_record.payment_id <> new.payment_id
      or original_record.obligation_id <> new.obligation_id
      or original_record.league_id <> new.league_id
      or original_record.season_id <> new.season_id
      or original_record.season_team_id <> new.season_team_id
    ) then
      raise exception
        'allocation reversal must use the original allocation context';
    end if;

    select coalesce(sum(amount_cents), 0)
    into reversed_from_original
    from public.payment_allocations
    where kind = 'reverse'
      and reverses_allocation_id = new.reverses_allocation_id;

    if reversed_from_original + new.amount_cents > original_record.amount_cents then
      raise exception
        'allocation reversal exceeds the original allocation amount';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.prevent_financial_event_mutation() from public;
revoke all on function private.validate_payment_allocation() from public;

create trigger financial_obligations_are_immutable
before update or delete on public.financial_obligations
for each row execute function private.prevent_financial_event_mutation();

create trigger payments_are_immutable
before update or delete on public.payments
for each row execute function private.prevent_financial_event_mutation();

create trigger payment_allocations_are_immutable
before update or delete on public.payment_allocations
for each row execute function private.prevent_financial_event_mutation();

create trigger financial_adjustments_are_immutable
before update or delete on public.financial_adjustments
for each row execute function private.prevent_financial_event_mutation();

create trigger validate_payment_allocation_before_insert
before insert on public.payment_allocations
for each row execute function private.validate_payment_allocation();

alter table public.financial_obligations enable row level security;
alter table public.payments enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.financial_adjustments enable row level security;

create policy "members can read financial obligations"
on public.financial_obligations
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "commissioners can create financial obligations"
on public.financial_obligations
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and (created_by is null or created_by = (select auth.uid()))
);

create policy "members can read payments"
on public.payments
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "commissioners can create payments"
on public.payments
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and (created_by is null or created_by = (select auth.uid()))
);

create policy "members can read payment allocations"
on public.payment_allocations
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "commissioners can create payment allocations"
on public.payment_allocations
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and (created_by is null or created_by = (select auth.uid()))
);

create policy "members can read financial adjustments"
on public.financial_adjustments
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "commissioners can create financial adjustments"
on public.financial_adjustments
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and (created_by is null or created_by = (select auth.uid()))
);

grant usage on type
  public.obligation_direction,
  public.payment_direction,
  public.balance_adjustment_direction,
  public.payment_allocation_kind,
  public.financial_source_type
to authenticated, service_role;

grant select, insert on table
  public.financial_obligations,
  public.payments,
  public.payment_allocations,
  public.financial_adjustments
to authenticated, service_role;
