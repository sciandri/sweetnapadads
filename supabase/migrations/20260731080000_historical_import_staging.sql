create type public.historical_import_status as enum (
  'staged',
  'reviewing',
  'approved',
  'committed',
  'rejected'
);

create type public.historical_mapping_status as enum (
  'pending',
  'mapped',
  'ignored'
);

create type public.historical_team_identifier_kind as enum (
  'email',
  'team_name',
  'abbreviation'
);

create type public.historical_event_target_kind as enum (
  'obligation',
  'payment',
  'adjustment',
  'ignore'
);

create type public.historical_issue_severity as enum (
  'info',
  'warning',
  'blocking'
);

create type public.historical_issue_status as enum (
  'open',
  'accepted',
  'resolved'
);

revoke all on type public.historical_import_status from public;
revoke all on type public.historical_mapping_status from public;
revoke all on type public.historical_team_identifier_kind from public;
revoke all on type public.historical_event_target_kind from public;
revoke all on type public.historical_issue_severity from public;
revoke all on type public.historical_issue_status from public;

create table public.historical_import_batches (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null,
  season_id uuid not null,
  source_filename text not null
    check (
      source_filename = btrim(source_filename)
      and length(source_filename) between 1 and 255
    ),
  source_sha256 text not null
    check (source_sha256 ~ '^[0-9a-f]{64}$'),
  source_manifest jsonb not null
    check (jsonb_typeof(source_manifest) = 'object'),
  status public.historical_import_status not null default 'staged',
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_by uuid references auth.users (id) on delete restrict,
  approved_at timestamptz,
  committed_by uuid references auth.users (id) on delete restrict,
  committed_at timestamptz,
  rejection_reason text
    check (
      rejection_reason is null
      or length(btrim(rejection_reason)) between 1 and 500
    ),
  constraint historical_import_batches_season_fkey
    foreign key (season_id, league_id)
    references public.seasons (id, league_id)
    on delete restrict,
  constraint historical_import_batches_source_key
    unique (league_id, season_id, source_sha256),
  constraint historical_import_batches_context_key
    unique (id, league_id, season_id),
  constraint historical_import_batches_state_shape_check
    check (
      (
        status in ('staged', 'reviewing')
        and approved_by is null
        and approved_at is null
        and committed_by is null
        and committed_at is null
        and rejection_reason is null
      )
      or
      (
        status = 'approved'
        and approved_by is not null
        and approved_at is not null
        and committed_by is null
        and committed_at is null
        and rejection_reason is null
      )
      or
      (
        status = 'committed'
        and approved_by is not null
        and approved_at is not null
        and committed_by is not null
        and committed_at is not null
        and rejection_reason is null
      )
      or
      (
        status = 'rejected'
        and committed_by is null
        and committed_at is null
        and rejection_reason is not null
      )
    )
);

create table public.historical_import_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  league_id uuid not null,
  season_id uuid not null,
  source_sheet text not null
    check (
      source_sheet = btrim(source_sheet)
      and length(source_sheet) between 1 and 100
    ),
  source_row_number integer not null
    check (source_row_number > 0),
  source_range text
    check (
      source_range is null
      or (
        source_range = btrim(source_range)
        and length(source_range) between 1 and 100
      )
    ),
  raw_values jsonb not null
    check (jsonb_typeof(raw_values) = 'array'),
  raw_formulas jsonb
    check (
      raw_formulas is null
      or jsonb_typeof(raw_formulas) = 'array'
    ),
  row_sha256 text not null
    check (row_sha256 ~ '^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint historical_import_rows_batch_fkey
    foreign key (batch_id, league_id, season_id)
    references public.historical_import_batches (id, league_id, season_id)
    on delete restrict,
  constraint historical_import_rows_source_key
    unique (batch_id, source_sheet, source_row_number)
);

create table public.historical_team_mappings (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  league_id uuid not null,
  season_id uuid not null,
  identifier_kind public.historical_team_identifier_kind not null,
  source_value text not null
    check (
      source_value = btrim(source_value)
      and length(source_value) between 1 and 320
    ),
  normalized_source_value text generated always as
    (lower(btrim(source_value))) stored,
  status public.historical_mapping_status not null default 'pending',
  season_team_id uuid,
  decision_note text
    check (
      decision_note is null
      or length(btrim(decision_note)) between 1 and 500
    ),
  decided_by uuid references auth.users (id) on delete restrict,
  decided_at timestamptz,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint historical_team_mappings_batch_fkey
    foreign key (batch_id, league_id, season_id)
    references public.historical_import_batches (id, league_id, season_id)
    on delete restrict,
  constraint historical_team_mappings_season_team_fkey
    foreign key (season_team_id, league_id, season_id)
    references public.season_teams (id, league_id, season_id)
    on delete restrict,
  constraint historical_team_mappings_source_key
    unique (batch_id, identifier_kind, normalized_source_value),
  constraint historical_team_mappings_state_shape_check
    check (
      (
        status = 'pending'
        and season_team_id is null
        and decision_note is null
        and decided_by is null
        and decided_at is null
      )
      or
      (
        status = 'mapped'
        and season_team_id is not null
        and decision_note is not null
        and decided_by is not null
        and decided_at is not null
      )
      or
      (
        status = 'ignored'
        and season_team_id is null
        and decision_note is not null
        and decided_by is not null
        and decided_at is not null
      )
    )
);

create table public.historical_event_mappings (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  league_id uuid not null,
  season_id uuid not null,
  source_type text not null
    check (
      source_type = btrim(source_type)
      and length(source_type) between 1 and 100
    ),
  normalized_source_type text generated always as
    (lower(btrim(source_type))) stored,
  source_subtype text
    check (
      source_subtype is null
      or (
        source_subtype = btrim(source_subtype)
        and length(source_subtype) between 1 and 100
      )
    ),
  normalized_source_subtype text generated always as
    (lower(btrim(source_subtype))) stored,
  status public.historical_mapping_status not null default 'pending',
  target_kind public.historical_event_target_kind,
  obligation_direction public.obligation_direction,
  payment_direction public.payment_direction,
  adjustment_direction public.balance_adjustment_direction,
  target_category text
    check (
      target_category is null
      or (
        target_category = lower(target_category)
        and target_category ~ '^[a-z][a-z0-9_]{0,49}$'
      )
    ),
  target_method text
    check (
      target_method is null
      or (
        target_method = lower(target_method)
        and target_method ~ '^[a-z][a-z0-9_]{0,49}$'
      )
    ),
  decision_note text
    check (
      decision_note is null
      or length(btrim(decision_note)) between 1 and 500
    ),
  decided_by uuid references auth.users (id) on delete restrict,
  decided_at timestamptz,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint historical_event_mappings_batch_fkey
    foreign key (batch_id, league_id, season_id)
    references public.historical_import_batches (id, league_id, season_id)
    on delete restrict,
  constraint historical_event_mappings_source_key
    unique nulls not distinct (
      batch_id,
      normalized_source_type,
      normalized_source_subtype
    ),
  constraint historical_event_mappings_state_shape_check
    check (
      (
        status = 'pending'
        and target_kind is null
        and obligation_direction is null
        and payment_direction is null
        and adjustment_direction is null
        and target_category is null
        and target_method is null
        and decision_note is null
        and decided_by is null
        and decided_at is null
      )
      or
      (
        status = 'mapped'
        and target_kind = 'obligation'
        and obligation_direction is not null
        and payment_direction is null
        and adjustment_direction is null
        and target_category is not null
        and target_method is null
        and decision_note is not null
        and decided_by is not null
        and decided_at is not null
      )
      or
      (
        status = 'mapped'
        and target_kind = 'payment'
        and obligation_direction is null
        and payment_direction is not null
        and adjustment_direction is null
        and target_category is null
        and decision_note is not null
        and decided_by is not null
        and decided_at is not null
      )
      or
      (
        status = 'mapped'
        and target_kind = 'adjustment'
        and obligation_direction is null
        and payment_direction is null
        and adjustment_direction is not null
        and target_category is null
        and target_method is null
        and decision_note is not null
        and decided_by is not null
        and decided_at is not null
      )
      or
      (
        status = 'ignored'
        and target_kind = 'ignore'
        and obligation_direction is null
        and payment_direction is null
        and adjustment_direction is null
        and target_category is null
        and target_method is null
        and decision_note is not null
        and decided_by is not null
        and decided_at is not null
      )
    )
);

create table public.historical_import_issues (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  league_id uuid not null,
  season_id uuid not null,
  source_sheet text
    check (
      source_sheet is null
      or (
        source_sheet = btrim(source_sheet)
        and length(source_sheet) between 1 and 100
      )
    ),
  source_row_number integer
    check (source_row_number is null or source_row_number > 0),
  issue_code text not null
    check (
      issue_code = lower(issue_code)
      and issue_code ~ '^[a-z][a-z0-9_]{0,79}$'
    ),
  severity public.historical_issue_severity not null,
  status public.historical_issue_status not null default 'open',
  summary text not null
    check (length(btrim(summary)) between 1 and 500),
  evidence jsonb not null default '{}'::jsonb
    check (jsonb_typeof(evidence) = 'object'),
  decision_note text
    check (
      decision_note is null
      or length(btrim(decision_note)) between 1 and 1000
    ),
  decided_by uuid references auth.users (id) on delete restrict,
  decided_at timestamptz,
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint historical_import_issues_batch_fkey
    foreign key (batch_id, league_id, season_id)
    references public.historical_import_batches (id, league_id, season_id)
    on delete restrict,
  constraint historical_import_issues_source_key
    unique nulls not distinct (
      batch_id,
      issue_code,
      source_sheet,
      source_row_number
    ),
  constraint historical_import_issues_state_shape_check
    check (
      (
        status = 'open'
        and decision_note is null
        and decided_by is null
        and decided_at is null
      )
      or
      (
        status in ('accepted', 'resolved')
        and decision_note is not null
        and decided_by is not null
        and decided_at is not null
      )
    )
);

create index historical_import_rows_batch_idx
  on public.historical_import_rows (batch_id, source_sheet);

create index historical_import_rows_hash_idx
  on public.historical_import_rows (batch_id, row_sha256);

create index historical_team_mappings_batch_status_idx
  on public.historical_team_mappings (batch_id, status);

create index historical_event_mappings_batch_status_idx
  on public.historical_event_mappings (batch_id, status);

create index historical_import_issues_batch_status_idx
  on public.historical_import_issues (batch_id, status, severity);

create or replace function private.prevent_historical_import_row_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'historical source rows are immutable';
end;
$$;

create or replace function private.validate_historical_review_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  batch_status public.historical_import_status;
begin
  if (
    (select auth.uid()) is not null
    and not private.is_league_commissioner(new.league_id)
  ) then
    return new;
  end if;

  select status
  into batch_status
  from public.historical_import_batches
  where id = new.batch_id
  for update;

  if not found then
    raise exception 'historical import batch % does not exist', new.batch_id;
  end if;

  if batch_status not in ('staged', 'reviewing') then
    raise exception using
      errcode = '55000',
      message = 'approved, committed, and rejected imports cannot be changed';
  end if;

  return new;
end;
$$;

create or replace function private.validate_historical_import_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  raw_row_count bigint;
  pending_team_count bigint;
  pending_event_count bigint;
  open_blocker_count bigint;
begin
  if old.status in ('committed', 'rejected') then
    raise exception using
      errcode = '55000',
      message = 'committed and rejected imports are terminal';
  end if;

  if new.status = old.status then
    return new;
  end if;

  if not (
    (old.status = 'staged' and new.status in ('reviewing', 'rejected'))
    or
    (old.status = 'reviewing' and new.status in ('approved', 'rejected'))
    or
    (old.status = 'approved' and new.status in ('reviewing', 'committed'))
  ) then
    raise exception using
      errcode = '55000',
      message = 'invalid historical import status transition';
  end if;

  if new.status in ('approved', 'committed') then
    select count(*)
    into raw_row_count
    from public.historical_import_rows
    where batch_id = new.id;

    select count(*)
    into pending_team_count
    from public.historical_team_mappings
    where batch_id = new.id
      and status = 'pending';

    select count(*)
    into pending_event_count
    from public.historical_event_mappings
    where batch_id = new.id
      and status = 'pending';

    select count(*)
    into open_blocker_count
    from public.historical_import_issues
    where batch_id = new.id
      and severity = 'blocking'
      and status = 'open';

    if raw_row_count = 0 then
      raise exception using
        errcode = '55000',
        message = 'historical import cannot be approved without source rows';
    end if;

    if pending_team_count > 0 or pending_event_count > 0 then
      raise exception using
        errcode = '55000',
        message = 'historical import has unresolved mappings';
    end if;

    if open_blocker_count > 0 then
      raise exception using
        errcode = '55000',
        message = 'historical import has open blocking issues';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.prevent_historical_import_row_mutation()
  from public;
revoke all on function private.validate_historical_review_mutation()
  from public;
revoke all on function private.validate_historical_import_transition()
  from public;

create trigger historical_import_batches_set_updated_at
before update on public.historical_import_batches
for each row execute function private.set_updated_at();

create trigger historical_import_batches_validate_transition
before update on public.historical_import_batches
for each row execute function private.validate_historical_import_transition();

create trigger historical_import_rows_are_immutable
before update or delete on public.historical_import_rows
for each row execute function private.prevent_historical_import_row_mutation();

create trigger historical_import_rows_validate_batch
before insert on public.historical_import_rows
for each row execute function private.validate_historical_review_mutation();

create trigger historical_team_mappings_set_updated_at
before update on public.historical_team_mappings
for each row execute function private.set_updated_at();

create trigger historical_team_mappings_validate_batch
before insert or update on public.historical_team_mappings
for each row execute function private.validate_historical_review_mutation();

create trigger historical_event_mappings_set_updated_at
before update on public.historical_event_mappings
for each row execute function private.set_updated_at();

create trigger historical_event_mappings_validate_batch
before insert or update on public.historical_event_mappings
for each row execute function private.validate_historical_review_mutation();

create trigger historical_import_issues_set_updated_at
before update on public.historical_import_issues
for each row execute function private.set_updated_at();

create trigger historical_import_issues_validate_batch
before insert or update on public.historical_import_issues
for each row execute function private.validate_historical_review_mutation();

create view public.historical_import_batch_review
with (security_invoker = true)
as
select
  batch.id as batch_id,
  batch.league_id,
  batch.season_id,
  batch.source_filename,
  batch.source_sha256,
  batch.status,
  coalesce(source_rows.row_count, 0)::bigint as source_row_count,
  coalesce(team_mapping.pending_count, 0)::bigint
    as pending_team_mapping_count,
  coalesce(event_mapping.pending_count, 0)::bigint
    as pending_event_mapping_count,
  coalesce(issue.open_blocker_count, 0)::bigint
    as open_blocking_issue_count,
  (
    coalesce(source_rows.row_count, 0) > 0
    and coalesce(team_mapping.pending_count, 0) = 0
    and coalesce(event_mapping.pending_count, 0) = 0
    and coalesce(issue.open_blocker_count, 0) = 0
  ) as ready_for_approval
from public.historical_import_batches as batch
left join (
  select
    batch_id,
    count(*) as row_count
  from public.historical_import_rows
  group by batch_id
) as source_rows
  on source_rows.batch_id = batch.id
left join (
  select
    batch_id,
    count(*) filter (where status = 'pending') as pending_count
  from public.historical_team_mappings
  group by batch_id
) as team_mapping
  on team_mapping.batch_id = batch.id
left join (
  select
    batch_id,
    count(*) filter (where status = 'pending') as pending_count
  from public.historical_event_mappings
  group by batch_id
) as event_mapping
  on event_mapping.batch_id = batch.id
left join (
  select
    batch_id,
    count(*) filter (
      where severity = 'blocking'
        and status = 'open'
    ) as open_blocker_count
  from public.historical_import_issues
  group by batch_id
) as issue
  on issue.batch_id = batch.id;

comment on table public.historical_import_batches is
  'Auditable import review lifecycle keyed to an immutable source hash.';

comment on table public.historical_import_rows is
  'Lossless row-level workbook evidence; never normalized in place.';

comment on table public.historical_team_mappings is
  'Explicit workbook identifier aliases mapped to season teams.';

comment on table public.historical_event_mappings is
  'Explicit workbook event labels mapped to financial event semantics.';

comment on table public.historical_import_issues is
  'Review findings that require an accepted or resolved commissioner decision.';

alter table public.historical_import_batches enable row level security;
alter table public.historical_import_rows enable row level security;
alter table public.historical_team_mappings enable row level security;
alter table public.historical_event_mappings enable row level security;
alter table public.historical_import_issues enable row level security;

create policy "commissioners can read historical import batches"
on public.historical_import_batches
for select
to authenticated
using (private.is_league_commissioner(league_id));

create policy "commissioners can create historical import batches"
on public.historical_import_batches
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and created_by = (select auth.uid())
);

create policy "commissioners can update historical import batches"
on public.historical_import_batches
for update
to authenticated
using (private.is_league_commissioner(league_id))
with check (
  private.is_league_commissioner(league_id)
  and (
    approved_by is null
    or approved_by = (select auth.uid())
  )
  and (
    committed_by is null
    or committed_by = (select auth.uid())
  )
);

create policy "commissioners can read historical import rows"
on public.historical_import_rows
for select
to authenticated
using (private.is_league_commissioner(league_id));

create policy "commissioners can create historical import rows"
on public.historical_import_rows
for insert
to authenticated
with check (
  private.is_league_commissioner(league_id)
  and created_by = (select auth.uid())
);

create policy "commissioners can manage historical team mappings"
on public.historical_team_mappings
for all
to authenticated
using (private.is_league_commissioner(league_id))
with check (
  private.is_league_commissioner(league_id)
  and created_by = (select auth.uid())
  and (
    decided_by is null
    or decided_by = (select auth.uid())
  )
);

create policy "commissioners can manage historical event mappings"
on public.historical_event_mappings
for all
to authenticated
using (private.is_league_commissioner(league_id))
with check (
  private.is_league_commissioner(league_id)
  and created_by = (select auth.uid())
  and (
    decided_by is null
    or decided_by = (select auth.uid())
  )
);

create policy "commissioners can manage historical import issues"
on public.historical_import_issues
for all
to authenticated
using (private.is_league_commissioner(league_id))
with check (
  private.is_league_commissioner(league_id)
  and created_by = (select auth.uid())
  and (
    decided_by is null
    or decided_by = (select auth.uid())
  )
);

grant usage on type
  public.historical_import_status,
  public.historical_mapping_status,
  public.historical_team_identifier_kind,
  public.historical_event_target_kind,
  public.historical_issue_severity,
  public.historical_issue_status
to authenticated, service_role;

grant select, insert, update on table
  public.historical_import_batches,
  public.historical_team_mappings,
  public.historical_event_mappings,
  public.historical_import_issues
to authenticated, service_role;

grant select, insert on table public.historical_import_rows
to authenticated, service_role;

grant select on table public.historical_import_batch_review
to authenticated, service_role;
