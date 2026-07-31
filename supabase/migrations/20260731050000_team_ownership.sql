-- Phase 2 durable teams, owners, ownership history, and season entries.

create type public.season_team_status as enum (
  'active',
  'inactive'
);

comment on type public.season_team_status is
  'A team entry''s participation state for one season.';

revoke all on type public.season_team_status from public;
grant usage on type public.season_team_status to authenticated, service_role;

alter table public.seasons
  add constraint seasons_id_league_id_key unique (id, league_id);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete restrict,
  name text not null check (char_length(trim(name)) between 1 and 100),
  slug text not null
    check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  is_active boolean not null default true,
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp()),
  unique (league_id, slug),
  unique (id, league_id)
);

comment on table public.teams is
  'Durable franchise identities that persist across seasons and owners.';

create table public.owners (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete restrict,
  user_id uuid references auth.users (id) on delete set null,
  display_name text not null
    check (char_length(trim(display_name)) between 1 and 80),
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp()),
  unique (league_id, user_id),
  unique (id, league_id)
);

comment on table public.owners is
  'Historical owner identities, optionally linked to a current Auth user.';

create table public.team_owners (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete restrict,
  team_id uuid not null,
  owner_id uuid not null,
  started_on date not null,
  ended_on date,
  is_primary boolean not null default true,
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp()),
  foreign key (team_id, league_id)
    references public.teams (id, league_id) on delete restrict,
  foreign key (owner_id, league_id)
    references public.owners (id, league_id) on delete restrict,
  unique (team_id, owner_id, started_on),
  check (ended_on is null or ended_on >= started_on)
);

comment on table public.team_owners is
  'Dated franchise ownership history; closed rows remain historical facts.';

create unique index team_owners_one_current_primary_idx
  on public.team_owners (team_id)
  where ended_on is null and is_primary;

create table public.season_teams (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete restrict,
  season_id uuid not null,
  team_id uuid not null,
  name text not null check (char_length(trim(name)) between 1 and 100),
  abbreviation text
    check (
      abbreviation is null
      or char_length(trim(abbreviation)) between 2 and 10
    ),
  espn_team_id integer check (espn_team_id is null or espn_team_id > 0),
  status public.season_team_status not null default 'active',
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp()),
  foreign key (season_id, league_id)
    references public.seasons (id, league_id) on delete restrict,
  foreign key (team_id, league_id)
    references public.teams (id, league_id) on delete restrict,
  unique (season_id, team_id),
  unique (season_id, espn_team_id)
);

comment on table public.season_teams is
  'A durable franchise''s name, source mapping, and status for one season.';

create index teams_league_active_idx
  on public.teams (league_id, is_active);

create index owners_league_idx
  on public.owners (league_id);

create index team_owners_owner_history_idx
  on public.team_owners (owner_id, started_on, ended_on);

create index season_teams_season_status_idx
  on public.season_teams (season_id, status);

create trigger teams_set_updated_at
before update on public.teams
for each row execute function private.set_updated_at();

create trigger owners_set_updated_at
before update on public.owners
for each row execute function private.set_updated_at();

create trigger team_owners_set_updated_at
before update on public.team_owners
for each row execute function private.set_updated_at();

create trigger season_teams_set_updated_at
before update on public.season_teams
for each row execute function private.set_updated_at();

alter table public.teams enable row level security;
alter table public.owners enable row level security;
alter table public.team_owners enable row level security;
alter table public.season_teams enable row level security;

revoke all on table public.teams from anon, authenticated;
revoke all on table public.owners from anon, authenticated;
revoke all on table public.team_owners from anon, authenticated;
revoke all on table public.season_teams from anon, authenticated;

grant select on table public.teams to authenticated;
grant insert (league_id, name, slug, is_active)
  on table public.teams to authenticated;
grant update (name, slug, is_active)
  on table public.teams to authenticated;

grant select on table public.owners to authenticated;
grant insert (league_id, user_id, display_name)
  on table public.owners to authenticated;
grant update (user_id, display_name)
  on table public.owners to authenticated;

grant select on table public.team_owners to authenticated;
grant insert (
  league_id,
  team_id,
  owner_id,
  started_on,
  ended_on,
  is_primary
) on table public.team_owners to authenticated;
grant update (started_on, ended_on, is_primary)
  on table public.team_owners to authenticated;

grant select on table public.season_teams to authenticated;
grant insert (
  league_id,
  season_id,
  team_id,
  name,
  abbreviation,
  espn_team_id,
  status
) on table public.season_teams to authenticated;
grant update (name, abbreviation, espn_team_id, status)
  on table public.season_teams to authenticated;

grant all on table public.teams to service_role;
grant all on table public.owners to service_role;
grant all on table public.team_owners to service_role;
grant all on table public.season_teams to service_role;

create policy teams_select_member
on public.teams
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy teams_insert_commissioner
on public.teams
for insert
to authenticated
with check (private.is_league_commissioner(league_id));

create policy teams_update_commissioner
on public.teams
for update
to authenticated
using (private.is_league_commissioner(league_id))
with check (private.is_league_commissioner(league_id));

create policy owners_select_member
on public.owners
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy owners_insert_commissioner
on public.owners
for insert
to authenticated
with check (private.is_league_commissioner(league_id));

create policy owners_update_commissioner
on public.owners
for update
to authenticated
using (private.is_league_commissioner(league_id))
with check (private.is_league_commissioner(league_id));

create policy team_owners_select_member
on public.team_owners
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy team_owners_insert_commissioner
on public.team_owners
for insert
to authenticated
with check (private.is_league_commissioner(league_id));

create policy team_owners_update_commissioner
on public.team_owners
for update
to authenticated
using (private.is_league_commissioner(league_id))
with check (private.is_league_commissioner(league_id));

create policy season_teams_select_member
on public.season_teams
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy season_teams_insert_commissioner
on public.season_teams
for insert
to authenticated
with check (private.is_league_commissioner(league_id));

create policy season_teams_update_commissioner
on public.season_teams
for update
to authenticated
using (private.is_league_commissioner(league_id))
with check (private.is_league_commissioner(league_id));
