-- Phase 1 platform primitives.
-- Domain tables and their RLS policies are added in subsequent migrations.

revoke create on schema public from public;
grant usage on schema public to anon, authenticated, service_role;

create schema if not exists private;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated, service_role;

create type public.league_member_role as enum (
  'member',
  'commissioner'
);

comment on type public.league_member_role is
  'A member''s authorization role within a league.';

create type public.membership_status as enum (
  'invited',
  'active',
  'inactive'
);

comment on type public.membership_status is
  'The lifecycle state of a league membership.';

create type public.season_status as enum (
  'setup',
  'active',
  'complete'
);

comment on type public.season_status is
  'The lifecycle state of a fantasy-football season.';

create domain public.nonnegative_money_cents as bigint
check (value between 0 and 9007199254740991);

comment on domain public.nonnegative_money_cents is
  'A nonnegative monetary amount in integer cents within JavaScript safe-integer range.';

revoke all on type public.league_member_role from public;
revoke all on type public.membership_status from public;
revoke all on type public.season_status from public;
revoke all on domain public.nonnegative_money_cents from public;

grant usage on type public.league_member_role to authenticated, service_role;
grant usage on type public.membership_status to authenticated, service_role;
grant usage on type public.season_status to authenticated, service_role;
grant usage on domain public.nonnegative_money_cents to authenticated, service_role;

create function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = timezone('utc', statement_timestamp());
  return new;
end;
$$;

comment on function private.set_updated_at() is
  'Sets a row''s updated_at value immediately before an update.';

revoke all on function private.set_updated_at() from public, anon, authenticated;
grant execute on function private.set_updated_at() to service_role;
