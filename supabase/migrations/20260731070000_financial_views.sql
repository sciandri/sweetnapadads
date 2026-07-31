create view public.obligation_reconciliation
with (security_invoker = true)
as
select
  obligation.id as obligation_id,
  obligation.league_id,
  obligation.season_id,
  obligation.season_team_id,
  obligation.direction,
  obligation.amount_cents::bigint as obligation_cents,
  coalesce(allocation.allocated_cents, 0)::bigint as allocated_cents,
  (
    obligation.amount_cents::bigint
    - coalesce(allocation.allocated_cents, 0)
  )::bigint as outstanding_cents,
  case
    when coalesce(allocation.allocated_cents, 0) = 0 then 'open'
    when allocation.allocated_cents = obligation.amount_cents then 'settled'
    else 'partial'
  end as reconciliation_status
from public.financial_obligations as obligation
left join (
  select
    obligation_id,
    sum(
      case
        when kind = 'apply' then amount_cents::bigint
        else -amount_cents::bigint
      end
    ) as allocated_cents
  from public.payment_allocations
  group by obligation_id
) as allocation
  on allocation.obligation_id = obligation.id;

create view public.payment_reconciliation
with (security_invoker = true)
as
select
  payment.id as payment_id,
  payment.league_id,
  payment.season_id,
  payment.season_team_id,
  payment.direction,
  payment.amount_cents::bigint as payment_cents,
  coalesce(allocation.allocated_cents, 0)::bigint as allocated_cents,
  (
    payment.amount_cents::bigint
    - coalesce(allocation.allocated_cents, 0)
  )::bigint as unallocated_cents,
  case
    when coalesce(allocation.allocated_cents, 0) = 0 then 'unallocated'
    when allocation.allocated_cents = payment.amount_cents then 'allocated'
    else 'partial'
  end as reconciliation_status
from public.payments as payment
left join (
  select
    payment_id,
    sum(
      case
        when kind = 'apply' then amount_cents::bigint
        else -amount_cents::bigint
      end
    ) as allocated_cents
  from public.payment_allocations
  group by payment_id
) as allocation
  on allocation.payment_id = payment.id;

create view public.team_financial_balances
with (security_invoker = true)
as
select
  season_team.league_id,
  season_team.season_id,
  season_team.id as season_team_id,
  coalesce(obligation.team_owes_cents, 0)::bigint
    as team_obligations_cents,
  coalesce(payment.from_team_cents, 0)::bigint
    as payments_from_team_cents,
  coalesce(obligation.league_owes_cents, 0)::bigint
    as league_obligations_cents,
  coalesce(payment.to_team_cents, 0)::bigint
    as payments_to_team_cents,
  coalesce(adjustment.increase_cents, 0)::bigint
    as balance_increases_cents,
  coalesce(adjustment.decrease_cents, 0)::bigint
    as balance_decreases_cents,
  (
    coalesce(obligation.team_owes_cents, 0)
    - coalesce(payment.from_team_cents, 0)
    - coalesce(obligation.league_owes_cents, 0)
    + coalesce(payment.to_team_cents, 0)
    + coalesce(adjustment.increase_cents, 0)
    - coalesce(adjustment.decrease_cents, 0)
  )::bigint as balance_cents
from public.season_teams as season_team
left join (
  select
    season_team_id,
    sum(amount_cents::bigint)
      filter (where direction = 'team_owes_league') as team_owes_cents,
    sum(amount_cents::bigint)
      filter (where direction = 'league_owes_team') as league_owes_cents
  from public.financial_obligations
  group by season_team_id
) as obligation
  on obligation.season_team_id = season_team.id
left join (
  select
    season_team_id,
    sum(amount_cents::bigint)
      filter (where direction = 'from_team') as from_team_cents,
    sum(amount_cents::bigint)
      filter (where direction = 'to_team') as to_team_cents
  from public.payments
  group by season_team_id
) as payment
  on payment.season_team_id = season_team.id
left join (
  select
    season_team_id,
    sum(amount_cents::bigint)
      filter (
        where direction = 'increase_team_balance'
      ) as increase_cents,
    sum(amount_cents::bigint)
      filter (
        where direction = 'decrease_team_balance'
      ) as decrease_cents
  from public.financial_adjustments
  group by season_team_id
) as adjustment
  on adjustment.season_team_id = season_team.id;

comment on view public.obligation_reconciliation is
  'Derived allocation and outstanding totals for each immutable obligation.';

comment on view public.payment_reconciliation is
  'Derived allocation and unallocated totals for each immutable payment.';

comment on view public.team_financial_balances is
  'Team-perspective balance derived from obligations, payments, and audited adjustments.';

grant select on table
  public.obligation_reconciliation,
  public.payment_reconciliation,
  public.team_financial_balances
to authenticated, service_role;
