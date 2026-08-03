create type public.notification_kind as enum (
  'announcement',
  'reminder',
  'result',
  'finance',
  'system'
);

create type public.notification_audience as enum (
  'all_members',
  'commissioners'
);

create type public.notification_channel as enum ('in_app', 'email');
create type public.notification_delivery_status as enum (
  'queued',
  'delivered',
  'failed',
  'skipped'
);

revoke all on type
  public.notification_kind,
  public.notification_audience,
  public.notification_channel,
  public.notification_delivery_status
from public;

grant usage on type
  public.notification_kind,
  public.notification_audience,
  public.notification_channel,
  public.notification_delivery_status
to authenticated, service_role;

create table public.league_notifications (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues (id) on delete restrict,
  season_id uuid,
  kind public.notification_kind not null,
  audience public.notification_audience not null,
  title text not null check (length(btrim(title)) between 1 and 120),
  body text not null check (length(btrim(body)) between 1 and 2000),
  source_key text not null check (
    source_key = btrim(source_key)
    and source_key ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$'
  ),
  published_at timestamptz not null default timezone('utc', statement_timestamp()),
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', statement_timestamp()),
  foreign key (season_id, league_id)
    references public.seasons (id, league_id) on delete restrict,
  unique (league_id, source_key),
  unique (id, league_id)
);

create table public.notification_delivery_events (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null,
  league_id uuid not null,
  user_id uuid not null references auth.users (id) on delete restrict,
  channel public.notification_channel not null,
  status public.notification_delivery_status not null,
  attempt smallint not null default 1 check (attempt between 1 and 20),
  stable_error_code text check (
    stable_error_code is null
    or stable_error_code ~ '^[a-z][a-z0-9_]{0,49}$'
  ),
  occurred_at timestamptz not null default timezone('utc', statement_timestamp()),
  foreign key (notification_id, league_id)
    references public.league_notifications (id, league_id) on delete restrict,
  unique (notification_id, user_id, channel, attempt),
  check (
    (status = 'failed' and stable_error_code is not null)
    or (status <> 'failed' and stable_error_code is null)
  )
);

create index league_notifications_league_published_idx
  on public.league_notifications (league_id, published_at desc);
create index notification_delivery_events_user_occurred_idx
  on public.notification_delivery_events (user_id, occurred_at desc);
create index notification_delivery_events_notification_idx
  on public.notification_delivery_events (notification_id);

create or replace function private.prevent_notification_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'notification evidence is immutable';
end;
$$;

create trigger league_notifications_are_immutable
before update or delete on public.league_notifications
for each row execute function private.prevent_notification_event_mutation();

create trigger notification_delivery_events_are_immutable
before update or delete on public.notification_delivery_events
for each row execute function private.prevent_notification_event_mutation();

alter table public.league_notifications enable row level security;
alter table public.notification_delivery_events enable row level security;

create policy league_notifications_select_audience
on public.league_notifications
for select to authenticated
using (
  (select private.is_active_league_member(league_id))
  and (
    audience = 'all_members'
    or (select private.is_league_commissioner(league_id))
  )
);

create policy notification_delivery_events_select_recipient
on public.notification_delivery_events
for select to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_league_commissioner(league_id))
);

revoke all on table
  public.league_notifications,
  public.notification_delivery_events
from public, anon, authenticated;
grant select on table
  public.league_notifications,
  public.notification_delivery_events
to authenticated;
grant all on table
  public.league_notifications,
  public.notification_delivery_events
to service_role;

create or replace function public.publish_league_notification(
  target_league_id uuid,
  target_season_id uuid,
  target_kind public.notification_kind,
  target_audience public.notification_audience,
  target_title text,
  target_body text,
  target_source_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  notification_id uuid;
  existing_notification public.league_notifications%rowtype;
  delivery_count integer;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'notification publishing requires an authenticated actor';
  end if;

  if not private.is_league_commissioner(target_league_id) then
    raise exception using errcode = '42501', message = 'only an active commissioner may publish notifications';
  end if;

  if target_season_id is not null and not exists (
    select 1 from public.seasons
    where id = target_season_id and league_id = target_league_id
  ) then
    raise exception using errcode = '23503', message = 'notification season does not belong to the league';
  end if;

  if target_title is null
     or length(btrim(target_title)) not between 1 and 120
     or target_title <> btrim(target_title)
     or target_body is null
     or length(btrim(target_body)) not between 1 and 2000
     or target_body <> btrim(target_body)
     or target_source_key is null
     or target_source_key !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$' then
    raise exception using errcode = '22023', message = 'notification request is invalid';
  end if;

  select * into existing_notification
  from public.league_notifications
  where league_id = target_league_id and source_key = target_source_key;

  if found then
    if existing_notification.season_id is distinct from target_season_id
       or existing_notification.kind <> target_kind
       or existing_notification.audience <> target_audience
       or existing_notification.title <> target_title
       or existing_notification.body <> target_body then
      raise exception using errcode = '23505', message = 'notification source key was reused with different content';
    end if;
    return jsonb_build_object(
      'status', 'already_published',
      'notification_id', existing_notification.id
    );
  end if;

  insert into public.league_notifications (
    league_id, season_id, kind, audience, title, body, source_key, created_by
  ) values (
    target_league_id, target_season_id, target_kind, target_audience,
    target_title, target_body, target_source_key, actor_id
  ) returning id into notification_id;

  insert into public.notification_delivery_events (
    notification_id, league_id, user_id, channel, status
  )
  select
    notification_id,
    target_league_id,
    membership.user_id,
    'in_app',
    'delivered'
  from public.league_memberships as membership
  where membership.league_id = target_league_id
    and membership.status = 'active'
    and (
      target_audience = 'all_members'
      or membership.role = 'commissioner'
    );
  get diagnostics delivery_count = row_count;

  return jsonb_build_object(
    'status', 'published',
    'notification_id', notification_id,
    'in_app_delivery_count', delivery_count
  );
end;
$$;

revoke all on function private.prevent_notification_event_mutation()
from public, anon, authenticated;
grant execute on function private.prevent_notification_event_mutation()
to service_role;

revoke all on function public.publish_league_notification(
  uuid, uuid, public.notification_kind, public.notification_audience,
  text, text, text
) from public, anon;
grant execute on function public.publish_league_notification(
  uuid, uuid, public.notification_kind, public.notification_audience,
  text, text, text
) to authenticated, service_role;

comment on function public.publish_league_notification(
  uuid, uuid, public.notification_kind, public.notification_audience,
  text, text, text
) is
  'Publishes one immutable in-app league notification and recipient delivery evidence.';
