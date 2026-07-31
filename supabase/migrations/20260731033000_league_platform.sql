-- Phase 1 league platform.
-- Every public table enables RLS before privileges are granted.

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null
    check (char_length(trim(display_name)) between 1 and 80),
  avatar_url text,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp())
);

comment on table public.profiles is
  'Application-facing identity data for a Supabase Auth user.';

create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 100),
  slug text not null unique
    check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp())
);

comment on table public.leagues is
  'Durable league identities shared by every season.';

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete restrict,
  year smallint not null check (year between 2000 and 2100),
  name text not null check (char_length(trim(name)) between 1 and 100),
  status public.season_status not null default 'setup',
  starts_on date,
  ends_on date,
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp()),
  unique (league_id, year),
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);

comment on table public.seasons is
  'A league season and its lifecycle; rules live in season_settings.';

create table public.season_settings (
  season_id uuid primary key references public.seasons (id) on delete restrict,
  currency_code text not null default 'USD'
    check (currency_code ~ '^[A-Z]{3}$'),
  buy_in_cents public.nonnegative_money_cents not null,
  draft_fee_cents public.nonnegative_money_cents not null default 0,
  weekly_high_score_payout_cents public.nonnegative_money_cents not null default 0,
  weekly_low_score_penalty_cents public.nonnegative_money_cents not null default 0,
  regular_season_weeks smallint not null
    check (regular_season_weeks between 1 and 30),
  playoff_team_count smallint not null
    check (playoff_team_count between 2 and 32),
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp())
);

comment on table public.season_settings is
  'Season-scoped competition and financial configuration stored as data.';

create table public.league_memberships (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete restrict,
  user_id uuid not null references auth.users (id) on delete restrict,
  role public.league_member_role not null default 'member',
  status public.membership_status not null default 'invited',
  joined_at timestamptz,
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  updated_at timestamptz not null default timezone('utc', statement_timestamp()),
  unique (league_id, user_id),
  check (
    (status = 'active' and joined_at is not null)
    or (status <> 'active')
  )
);

comment on table public.league_memberships is
  'A user''s access and authorization role within a league.';

create index league_memberships_user_active_idx
  on public.league_memberships (user_id, league_id)
  where status = 'active';

create index seasons_league_status_idx
  on public.seasons (league_id, status);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create trigger leagues_set_updated_at
before update on public.leagues
for each row execute function private.set_updated_at();

create trigger seasons_set_updated_at
before update on public.seasons
for each row execute function private.set_updated_at();

create trigger season_settings_set_updated_at
before update on public.season_settings
for each row execute function private.set_updated_at();

create trigger league_memberships_set_updated_at
before update on public.league_memberships
for each row execute function private.set_updated_at();

create function private.is_active_league_member(target_league_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.league_memberships membership
      where membership.league_id = target_league_id
        and membership.user_id = (select auth.uid())
        and membership.status = 'active'::public.membership_status
    );
$$;

create function private.is_league_commissioner(target_league_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.league_memberships membership
      where membership.league_id = target_league_id
        and membership.user_id = (select auth.uid())
        and membership.status = 'active'::public.membership_status
        and membership.role = 'commissioner'::public.league_member_role
    );
$$;

create function private.shares_active_league_with(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.league_memberships viewer_membership
      join public.league_memberships target_membership
        on target_membership.league_id = viewer_membership.league_id
      where viewer_membership.user_id = (select auth.uid())
        and viewer_membership.status = 'active'::public.membership_status
        and target_membership.user_id = target_user_id
        and target_membership.status = 'active'::public.membership_status
    );
$$;

create function private.create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(split_part(new.email, '@', 1), ''),
      'Member'
    )
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function private.is_active_league_member(uuid)
  from public, anon, authenticated;
revoke all on function private.is_league_commissioner(uuid)
  from public, anon, authenticated;
revoke all on function private.shares_active_league_with(uuid)
  from public, anon, authenticated;
revoke all on function private.create_profile_for_auth_user()
  from public, anon, authenticated;

grant execute on function private.is_active_league_member(uuid)
  to authenticated, service_role;
grant execute on function private.is_league_commissioner(uuid)
  to authenticated, service_role;
grant execute on function private.shares_active_league_with(uuid)
  to authenticated, service_role;
grant execute on function private.create_profile_for_auth_user()
  to service_role;

drop trigger if exists create_profile_after_auth_user_insert on auth.users;

create trigger create_profile_after_auth_user_insert
after insert on auth.users
for each row execute function private.create_profile_for_auth_user();

alter table public.profiles enable row level security;
alter table public.leagues enable row level security;
alter table public.seasons enable row level security;
alter table public.season_settings enable row level security;
alter table public.league_memberships enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.leagues from anon, authenticated;
revoke all on table public.seasons from anon, authenticated;
revoke all on table public.season_settings from anon, authenticated;
revoke all on table public.league_memberships from anon, authenticated;

grant select on table public.profiles to authenticated;
grant update (display_name, avatar_url) on table public.profiles to authenticated;

grant select on table public.leagues to authenticated;
grant update (name, slug) on table public.leagues to authenticated;

grant select on table public.seasons to authenticated;
grant insert (
  league_id,
  year,
  name,
  status,
  starts_on,
  ends_on
) on table public.seasons to authenticated;
grant update (
  name,
  status,
  starts_on,
  ends_on
) on table public.seasons to authenticated;

grant select on table public.season_settings to authenticated;
grant insert (
  season_id,
  currency_code,
  buy_in_cents,
  draft_fee_cents,
  weekly_high_score_payout_cents,
  weekly_low_score_penalty_cents,
  regular_season_weeks,
  playoff_team_count
) on table public.season_settings to authenticated;
grant update (
  currency_code,
  buy_in_cents,
  draft_fee_cents,
  weekly_high_score_payout_cents,
  weekly_low_score_penalty_cents,
  regular_season_weeks,
  playoff_team_count
) on table public.season_settings to authenticated;

grant select on table public.league_memberships to authenticated;
grant insert (
  league_id,
  user_id,
  role,
  status,
  joined_at
) on table public.league_memberships to authenticated;
grant update (
  role,
  status,
  joined_at
) on table public.league_memberships to authenticated;

grant all on table public.profiles to service_role;
grant all on table public.leagues to service_role;
grant all on table public.seasons to service_role;
grant all on table public.season_settings to service_role;
grant all on table public.league_memberships to service_role;

create policy profiles_select_shared_league
on public.profiles
for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.shares_active_league_with(user_id)
);

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy leagues_select_member
on public.leagues
for select
to authenticated
using (private.is_active_league_member(id));

create policy leagues_update_commissioner
on public.leagues
for update
to authenticated
using (private.is_league_commissioner(id))
with check (private.is_league_commissioner(id));

create policy seasons_select_member
on public.seasons
for select
to authenticated
using (private.is_active_league_member(league_id));

create policy seasons_insert_commissioner
on public.seasons
for insert
to authenticated
with check (private.is_league_commissioner(league_id));

create policy seasons_update_commissioner
on public.seasons
for update
to authenticated
using (private.is_league_commissioner(league_id))
with check (private.is_league_commissioner(league_id));

create policy season_settings_select_member
on public.season_settings
for select
to authenticated
using (
  exists (
    select 1
    from public.seasons season
    where season.id = season_id
      and private.is_active_league_member(season.league_id)
  )
);

create policy season_settings_insert_commissioner
on public.season_settings
for insert
to authenticated
with check (
  exists (
    select 1
    from public.seasons season
    where season.id = season_id
      and private.is_league_commissioner(season.league_id)
  )
);

create policy season_settings_update_commissioner
on public.season_settings
for update
to authenticated
using (
  exists (
    select 1
    from public.seasons season
    where season.id = season_id
      and private.is_league_commissioner(season.league_id)
  )
)
with check (
  exists (
    select 1
    from public.seasons season
    where season.id = season_id
      and private.is_league_commissioner(season.league_id)
  )
);

create policy league_memberships_select_member
on public.league_memberships
for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.is_active_league_member(league_id)
);

create policy league_memberships_insert_commissioner
on public.league_memberships
for insert
to authenticated
with check (private.is_league_commissioner(league_id));

create policy league_memberships_update_commissioner
on public.league_memberships
for update
to authenticated
using (private.is_league_commissioner(league_id))
with check (private.is_league_commissioner(league_id));
