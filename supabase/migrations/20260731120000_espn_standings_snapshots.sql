create type public.espn_sync_status as enum (
  'running',
  'succeeded',
  'failed'
);

revoke all on type public.espn_sync_status from public;

create table public.espn_sync_runs (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  sync_kind text not null
    check (
      sync_kind = btrim(sync_kind)
      and length(sync_kind) between 1 and 50
    ),
  scoring_period integer check (scoring_period is null or scoring_period > 0),
  source_revision text not null
    check (
      source_revision = btrim(source_revision)
      and length(source_revision) between 1 and 120
    ),
  idempotency_key text not null
    check (
      idempotency_key = btrim(idempotency_key)
      and length(idempotency_key) between 1 and 200
    ),
  status public.espn_sync_status not null default 'running',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  error_code text
    check (
      error_code is null
      or (
        error_code = btrim(error_code)
        and length(error_code) between 1 and 100
      )
    ),
  error_message text
    check (
      error_message is null
      or length(btrim(error_message)) between 1 and 1000
    ),
  created_by uuid references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint espn_sync_runs_season_fkey
    foreign key (season_id, league_id)
    references public.seasons (id, league_id)
    on delete restrict,
  constraint espn_sync_runs_context_key unique (id, league_id, season_id),
  constraint espn_sync_runs_idempotency_key
    unique (season_id, sync_kind, idempotency_key),
  constraint espn_sync_runs_status_shape_check
    check (
      (
        status = 'running'
        and finished_at is null
        and error_code is null
        and error_message is null
      )
      or
      (
        status = 'succeeded'
        and finished_at is not null
        and error_code is null
        and error_message is null
      )
      or
      (
        status = 'failed'
        and finished_at is not null
        and error_code is not null
        and error_message is not null
      )
    )
);

create table public.espn_raw_payloads (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null,
  league_id uuid not null,
  season_id uuid not null,
  payload_kind text not null
    check (
      payload_kind = btrim(payload_kind)
      and length(payload_kind) between 1 and 50
    ),
  endpoint_path text not null
    check (
      endpoint_path = btrim(endpoint_path)
      and endpoint_path like '/%'
      and length(endpoint_path) between 1 and 500
    ),
  http_status integer not null check (http_status between 100 and 599),
  payload jsonb not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  fetched_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint espn_raw_payloads_run_fkey
    foreign key (run_id, league_id, season_id)
    references public.espn_sync_runs (id, league_id, season_id)
    on delete restrict,
  constraint espn_raw_payloads_context_key
    unique (id, run_id, league_id, season_id),
  constraint espn_raw_payloads_source_key
    unique (run_id, payload_kind, payload_sha256)
);

create table public.espn_standings_snapshots (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null,
  raw_payload_id uuid not null,
  league_id uuid not null,
  season_id uuid not null,
  espn_league_id bigint not null check (espn_league_id > 0),
  scoring_period integer check (scoring_period is null or scoring_period > 0),
  source_revision text not null
    check (
      source_revision = btrim(source_revision)
      and length(source_revision) between 1 and 120
    ),
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 200
    ),
  captured_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint espn_standings_snapshots_run_fkey
    foreign key (run_id, league_id, season_id)
    references public.espn_sync_runs (id, league_id, season_id)
    on delete restrict,
  constraint espn_standings_snapshots_payload_fkey
    foreign key (raw_payload_id, run_id, league_id, season_id)
    references public.espn_raw_payloads (id, run_id, league_id, season_id)
    on delete restrict,
  constraint espn_standings_snapshots_context_key
    unique (id, league_id, season_id),
  constraint espn_standings_snapshots_source_key
    unique (season_id, source_key),
  constraint espn_standings_snapshots_payload_key unique (raw_payload_id)
);

create table public.espn_standing_entries (
  id uuid primary key default gen_random_uuid(),
  snapshot_id uuid not null,
  league_id uuid not null,
  season_id uuid not null,
  season_team_id uuid not null,
  espn_team_id integer not null check (espn_team_id > 0),
  official_rank integer not null check (official_rank > 0),
  playoff_seed integer check (playoff_seed is null or playoff_seed > 0),
  wins integer not null check (wins >= 0),
  losses integer not null check (losses >= 0),
  ties integer not null check (ties >= 0),
  points_for numeric(10, 2) not null check (points_for >= 0),
  points_against numeric(10, 2) not null check (points_against >= 0),
  streak text
    check (
      streak is null
      or length(btrim(streak)) between 1 and 30
    ),
  record_summary text not null
    check (length(btrim(record_summary)) between 1 and 40),
  source_record jsonb not null
    check (jsonb_typeof(source_record) = 'object'),
  created_at timestamptz not null default now(),
  constraint espn_standing_entries_snapshot_fkey
    foreign key (snapshot_id, league_id, season_id)
    references public.espn_standings_snapshots (id, league_id, season_id)
    on delete restrict,
  constraint espn_standing_entries_team_fkey
    foreign key (season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id)
    on delete restrict,
  constraint espn_standing_entries_rank_key
    unique (snapshot_id, official_rank),
  constraint espn_standing_entries_team_key
    unique (snapshot_id, season_team_id),
  constraint espn_standing_entries_espn_team_key
    unique (snapshot_id, espn_team_id)
);

create index espn_sync_runs_season_status_idx
  on public.espn_sync_runs (season_id, status, finished_at desc);

create index espn_standings_snapshots_latest_idx
  on public.espn_standings_snapshots (season_id, captured_at desc);

create or replace function private.prevent_espn_source_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'ESPN source snapshots and payloads are immutable';
end;
$$;

create trigger prevent_espn_raw_payload_mutation
before update or delete on public.espn_raw_payloads
for each row execute function private.prevent_espn_source_mutation();

create trigger prevent_espn_standings_snapshot_mutation
before update or delete on public.espn_standings_snapshots
for each row execute function private.prevent_espn_source_mutation();

create trigger prevent_espn_standing_entry_mutation
before update or delete on public.espn_standing_entries
for each row execute function private.prevent_espn_source_mutation();

create view public.current_espn_standings
with (security_invoker = true)
as
select
  snapshot.league_id,
  snapshot.season_id,
  snapshot.id as snapshot_id,
  snapshot.raw_payload_id,
  snapshot.espn_league_id,
  snapshot.scoring_period,
  snapshot.captured_at,
  entry.season_team_id,
  entry.espn_team_id,
  entry.official_rank,
  entry.playoff_seed,
  entry.wins,
  entry.losses,
  entry.ties,
  entry.points_for,
  entry.points_against,
  entry.streak,
  entry.record_summary
from public.espn_standings_snapshots as snapshot
join public.espn_sync_runs as run
  on run.id = snapshot.run_id
 and run.status = 'succeeded'
join public.espn_standing_entries as entry
  on entry.snapshot_id = snapshot.id
where snapshot.id = (
  select latest.id
  from public.espn_standings_snapshots as latest
  join public.espn_sync_runs as latest_run
    on latest_run.id = latest.run_id
   and latest_run.status = 'succeeded'
  where latest.season_id = snapshot.season_id
  order by latest.captured_at desc, latest.created_at desc, latest.id desc
  limit 1
);

alter table public.espn_sync_runs enable row level security;
alter table public.espn_raw_payloads enable row level security;
alter table public.espn_standings_snapshots enable row level security;
alter table public.espn_standing_entries enable row level security;

create policy "members can read ESPN sync runs"
on public.espn_sync_runs
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "members can read ESPN standings snapshots"
on public.espn_standings_snapshots
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "members can read ESPN standing entries"
on public.espn_standing_entries
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy "commissioners can read raw ESPN payloads"
on public.espn_raw_payloads
for select
to authenticated
using (private.is_league_commissioner(league_id));

comment on table public.espn_sync_runs is
  'Idempotent lifecycle records for server-side ESPN synchronization.';

comment on table public.espn_raw_payloads is
  'Immutable private ESPN response evidence without request credentials.';

comment on table public.espn_standings_snapshots is
  'Immutable official-order ESPN standings snapshots tied to raw evidence.';

comment on view public.current_espn_standings is
  'Latest successful ESPN standings for each season in official ESPN order.';

revoke all on function private.prevent_espn_source_mutation() from public;

grant usage on type public.espn_sync_status to authenticated, service_role;

grant select on table
  public.espn_sync_runs,
  public.espn_raw_payloads,
  public.espn_standings_snapshots,
  public.espn_standing_entries
to authenticated;

grant all on table
  public.espn_sync_runs,
  public.espn_raw_payloads,
  public.espn_standings_snapshots,
  public.espn_standing_entries
to service_role;

grant select on table public.current_espn_standings
to authenticated, service_role;
