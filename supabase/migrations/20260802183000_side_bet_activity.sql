-- Immutable season side-bet evidence. Side bets are league activity, but they
-- are not league obligations or payments unless a later audited financial
-- event explicitly records settlement.

create table public.side_bets (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  party_one_season_team_id uuid not null,
  party_two_season_team_id uuid not null,
  description text not null
    check (description = btrim(description) and length(description) between 1 and 500),
  amount_cents public.nonnegative_money_cents not null
    check (amount_cents > 0),
  source_type public.competition_source_type not null,
  source_key text not null
    check (source_key = btrim(source_key) and length(source_key) between 1 and 200),
  source_refs jsonb not null
    check (jsonb_typeof(source_refs) = 'array' and jsonb_array_length(source_refs) > 0),
  import_batch_id uuid,
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  constraint side_bets_season_fkey
    foreign key (season_id, league_id)
    references public.seasons (id, league_id) on delete restrict,
  constraint side_bets_party_one_fkey
    foreign key (party_one_season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id) on delete restrict,
  constraint side_bets_party_two_fkey
    foreign key (party_two_season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id) on delete restrict,
  constraint side_bets_import_batch_fkey
    foreign key (import_batch_id, league_id, season_id)
    references public.historical_import_batches (id, league_id, season_id)
    on delete restrict,
  constraint side_bets_distinct_parties_check
    check (party_one_season_team_id <> party_two_season_team_id),
  constraint side_bets_source_key unique (league_id, source_key)
);

comment on table public.side_bets is
  'Immutable season side-bet evidence, separate from league financial events and with no invented outcome.';

create index side_bets_season_idx
on public.side_bets (season_id, created_at);

create or replace function private.prevent_side_bet_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'side-bet evidence is immutable';
end;
$$;

revoke all on function private.prevent_side_bet_mutation()
from public, anon, authenticated;
grant execute on function private.prevent_side_bet_mutation()
to service_role;

create trigger side_bets_are_immutable
before update or delete on public.side_bets
for each row execute function private.prevent_side_bet_mutation();

alter table public.side_bets enable row level security;

revoke all on table public.side_bets from anon, authenticated;
grant select on table public.side_bets to authenticated;
grant insert (
  league_id,
  season_id,
  party_one_season_team_id,
  party_two_season_team_id,
  description,
  amount_cents,
  source_type,
  source_key,
  source_refs,
  import_batch_id
) on table public.side_bets to authenticated;
grant all on table public.side_bets to service_role;

create policy side_bets_select_member
on public.side_bets
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy side_bets_insert_commissioner
on public.side_bets
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and created_by = (select auth.uid())
);
