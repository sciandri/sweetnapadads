create type public.competition_phase as enum (
  'regular_season',
  'postseason'
);

create type public.competition_result as enum (
  'win',
  'loss',
  'tie'
);

create type public.competition_source_type as enum (
  'manual',
  'espn',
  'import',
  'system'
);

revoke all on type
  public.competition_phase,
  public.competition_result,
  public.competition_source_type
from public;

create table public.matchups (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  week smallint not null check (week between 1 and 30),
  phase public.competition_phase not null,
  source_type public.competition_source_type not null,
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 200
    ),
  source_updated_at timestamptz,
  created_by uuid references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint matchups_season_fkey
    foreign key (season_id, league_id)
    references public.seasons (id, league_id)
    on delete restrict,
  constraint matchups_source_key_key unique (season_id, source_key),
  constraint matchups_context_key unique (id, league_id, season_id)
);

create table public.weekly_results (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  matchup_id uuid not null,
  season_team_id uuid not null,
  opponent_season_team_id uuid not null,
  score numeric(8, 2) not null check (score >= 0),
  result public.competition_result not null,
  notes text
    check (
      notes is null
      or length(btrim(notes)) between 1 and 500
    ),
  source_type public.competition_source_type not null,
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 200
    ),
  source_updated_at timestamptz,
  created_by uuid references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint weekly_results_matchup_fkey
    foreign key (matchup_id, league_id, season_id)
    references public.matchups (id, league_id, season_id)
    on delete restrict,
  constraint weekly_results_team_fkey
    foreign key (season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id)
    on delete restrict,
  constraint weekly_results_opponent_fkey
    foreign key (opponent_season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id)
    on delete restrict,
  constraint weekly_results_distinct_teams_check
    check (season_team_id <> opponent_season_team_id),
  constraint weekly_results_matchup_team_key
    unique (matchup_id, season_team_id),
  constraint weekly_results_source_key_key
    unique (season_id, source_key)
);

create table public.weekly_awards (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  week smallint not null check (week between 1 and 30),
  high_score_season_team_id uuid not null,
  high_score numeric(8, 2) not null check (high_score >= 0),
  high_score_obligation_id uuid not null,
  low_score_season_team_id uuid not null,
  low_score numeric(8, 2) not null check (low_score >= 0),
  low_score_obligation_id uuid not null,
  source_type public.competition_source_type not null,
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 200
    ),
  source_refs jsonb not null default '[]'::jsonb
    check (jsonb_typeof(source_refs) = 'array'),
  created_by uuid references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint weekly_awards_high_team_fkey
    foreign key (high_score_season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id)
    on delete restrict,
  constraint weekly_awards_low_team_fkey
    foreign key (low_score_season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id)
    on delete restrict,
  constraint weekly_awards_high_obligation_fkey
    foreign key (
      high_score_obligation_id,
      league_id,
      season_id,
      high_score_season_team_id
    )
    references public.financial_obligations
      (id, league_id, season_id, season_team_id)
    on delete restrict,
  constraint weekly_awards_low_obligation_fkey
    foreign key (
      low_score_obligation_id,
      league_id,
      season_id,
      low_score_season_team_id
    )
    references public.financial_obligations
      (id, league_id, season_id, season_team_id)
    on delete restrict,
  constraint weekly_awards_score_order_check
    check (high_score >= low_score),
  constraint weekly_awards_week_key unique (season_id, week),
  constraint weekly_awards_source_key_key unique (season_id, source_key)
);

create index matchups_season_week_idx
  on public.matchups (season_id, week);

create index weekly_results_matchup_idx
  on public.weekly_results (matchup_id);

create index weekly_results_season_team_idx
  on public.weekly_results (season_id, season_team_id);

create index weekly_awards_season_team_idx
  on public.weekly_awards (
    season_id,
    high_score_season_team_id,
    low_score_season_team_id
  );

create or replace function private.prevent_imported_competition_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.source_type = 'import' then
    raise exception using
      errcode = '55000',
      message = 'imported competition history is immutable';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

revoke all on function private.prevent_imported_competition_mutation()
from public;

create trigger matchups_protect_imported_history
before update or delete on public.matchups
for each row execute function private.prevent_imported_competition_mutation();

create trigger weekly_results_protect_imported_history
before update or delete on public.weekly_results
for each row execute function private.prevent_imported_competition_mutation();

create trigger weekly_awards_protect_imported_history
before update or delete on public.weekly_awards
for each row execute function private.prevent_imported_competition_mutation();

alter table public.matchups enable row level security;
alter table public.weekly_results enable row level security;
alter table public.weekly_awards enable row level security;

create policy "members can read matchups"
on public.matchups
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "commissioners can create matchups"
on public.matchups
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and (created_by is null or created_by = (select auth.uid()))
);

create policy "members can read weekly results"
on public.weekly_results
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "commissioners can create weekly results"
on public.weekly_results
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and (created_by is null or created_by = (select auth.uid()))
);

create policy "members can read weekly awards"
on public.weekly_awards
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "commissioners can create weekly awards"
on public.weekly_awards
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and (created_by is null or created_by = (select auth.uid()))
);

comment on table public.matchups is
  'One league matchup in a season week with stable source provenance.';

comment on table public.weekly_results is
  'Per-team score and outcome rows linked to a season matchup.';

comment on table public.weekly_awards is
  'Rule-derived weekly high and low awards linked to their obligations.';

grant usage on type
  public.competition_phase,
  public.competition_result,
  public.competition_source_type
to authenticated, service_role;

grant select, insert on table
  public.matchups,
  public.weekly_results,
  public.weekly_awards
to authenticated;

grant all on table
  public.matchups,
  public.weekly_results,
  public.weekly_awards
to service_role;
