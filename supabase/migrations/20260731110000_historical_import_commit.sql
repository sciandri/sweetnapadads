create type public.historical_committed_record_kind as enum (
  'matchup',
  'weekly_result',
  'weekly_award',
  'financial_obligation',
  'payment',
  'payment_allocation',
  'external_cash_event'
);

revoke all on type public.historical_committed_record_kind from public;

create table public.historical_import_commits (
  batch_id uuid primary key,
  league_id uuid not null,
  season_id uuid not null,
  preview_sha256 text not null check (preview_sha256 ~ '^[0-9a-f]{64}$'),
  normalized_preview jsonb not null
    check (jsonb_typeof(normalized_preview) = 'object'),
  record_counts jsonb not null
    check (jsonb_typeof(record_counts) = 'object'),
  reconciliation jsonb not null
    check (jsonb_typeof(reconciliation) = 'object'),
  committed_by uuid not null references auth.users (id) on delete restrict,
  committed_at timestamptz not null default now(),
  constraint historical_import_commits_batch_fkey
    foreign key (batch_id, league_id, season_id)
    references public.historical_import_batches (id, league_id, season_id)
    on delete restrict
);

create table public.historical_import_committed_records (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null,
  league_id uuid not null,
  season_id uuid not null,
  record_kind public.historical_committed_record_kind not null,
  target_id uuid not null,
  source_key text not null
    check (
      source_key = btrim(source_key)
      and length(source_key) between 1 and 240
    ),
  source_refs jsonb not null default '[]'::jsonb
    check (jsonb_typeof(source_refs) = 'array'),
  created_at timestamptz not null default now(),
  constraint historical_import_committed_records_commit_fkey
    foreign key (batch_id)
    references public.historical_import_commits (batch_id)
    on delete restrict
    deferrable initially deferred,
  constraint historical_import_committed_records_batch_fkey
    foreign key (batch_id, league_id, season_id)
    references public.historical_import_batches (id, league_id, season_id)
    on delete restrict,
  constraint historical_import_committed_records_target_key
    unique (batch_id, record_kind, target_id),
  constraint historical_import_committed_records_source_key
    unique (batch_id, source_key)
);

create index historical_import_committed_records_target_idx
  on public.historical_import_committed_records (record_kind, target_id);

create or replace function private.resolve_historical_season_team(
  target_batch_id uuid,
  target_season_id uuid,
  target_team_key text
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  resolved_id uuid;
begin
  select distinct candidate.id
  into strict resolved_id
  from (
    select mapping.season_team_id as id
    from public.historical_team_mappings as mapping
    where mapping.batch_id = target_batch_id
      and mapping.season_id = target_season_id
      and mapping.status = 'mapped'
      and regexp_replace(
        lower(btrim(mapping.source_value)),
        '[^a-z0-9]+',
        '_',
        'g'
      ) = regexp_replace(
        lower(btrim(target_team_key)),
        '[^a-z0-9]+',
        '_',
        'g'
      )

    union

    select season_team.id
    from public.season_teams as season_team
    join public.teams as team
      on team.id = season_team.team_id
     and team.league_id = season_team.league_id
    where season_team.season_id = target_season_id
      and replace(team.slug, '-', '_') = regexp_replace(
        lower(btrim(target_team_key)),
        '[^a-z0-9]+',
        '_',
        'g'
      )
  ) as candidate;

  return resolved_id;
exception
  when no_data_found then
    raise exception 'preview team key % is not mapped to the batch season',
      target_team_key;
  when too_many_rows then
    raise exception 'preview team key % is ambiguous in the batch season',
      target_team_key;
end;
$$;

create or replace function private.add_historical_commit_record(
  target_batch_id uuid,
  target_league_id uuid,
  target_season_id uuid,
  target_record_kind public.historical_committed_record_kind,
  target_id uuid,
  target_source_key text,
  target_source_refs jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.historical_import_committed_records (
    batch_id,
    league_id,
    season_id,
    record_kind,
    target_id,
    source_key,
    source_refs
  )
  values (
    target_batch_id,
    target_league_id,
    target_season_id,
    target_record_kind,
    target_id,
    target_source_key,
    coalesce(target_source_refs, '[]'::jsonb)
  );
$$;

create or replace function public.commit_historical_import(
  target_batch_id uuid,
  normalized_preview jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  batch_record public.historical_import_batches%rowtype;
  preview_hash text;
  committed_hash text;
  item jsonb;
  counterpart jsonb;
  team_id uuid;
  opponent_id uuid;
  target_id uuid;
  resolved_payment_id uuid;
  resolved_obligation_id uuid;
  high_award_obligation_id uuid;
  low_award_obligation_id uuid;
  resolved_matchup_id uuid;
  source_key_value text;
  payment_source_key text;
  obligation_source_key text;
  source_refs_value jsonb;
  preview_year integer;
  week_number integer;
  matchups_count integer := 0;
  results_count integer := 0;
  awards_count integer := 0;
  obligations_count integer := 0;
  payments_count integer := 0;
  allocations_count integer := 0;
  external_cash_count integer := 0;
  record_counts_value jsonb;
  team_obligations_cents bigint;
  payments_from_team_cents bigint;
  league_obligations_cents bigint;
  payments_to_team_cents bigint;
  payment_cents bigint;
  allocated_payment_cents bigint;
  external_cash_in_cents bigint;
  external_cash_out_cents bigint;
  cash_balance_cents bigint;
  net_team_balance_cents bigint;
begin
  if actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'historical import commit requires an authenticated actor';
  end if;

  if normalized_preview is null
    or jsonb_typeof(normalized_preview) <> 'object'
  then
    raise exception using
      errcode = '22023',
      message = 'normalized preview must be a JSON object';
  end if;

  select *
  into batch_record
  from public.historical_import_batches
  where id = target_batch_id
  for update;

  if not found then
    raise exception 'historical import batch % does not exist', target_batch_id;
  end if;

  if not private.is_league_commissioner(batch_record.league_id) then
    raise exception using
      errcode = '42501',
      message = 'only an active league commissioner can commit history';
  end if;

  preview_hash := encode(
    extensions.digest(
      convert_to(normalized_preview::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  if batch_record.status = 'committed' then
    select commit.preview_sha256
    into committed_hash
    from public.historical_import_commits as commit
    where commit.batch_id = target_batch_id;

    if committed_hash is null or committed_hash <> preview_hash then
      raise exception using
        errcode = '55000',
        message = 'normalized preview does not match committed preview';
    end if;

    return jsonb_build_object(
      'status', 'already_committed',
      'batch_id', target_batch_id,
      'preview_sha256', committed_hash,
      'record_counts', (
        select commit.record_counts
        from public.historical_import_commits as commit
        where commit.batch_id = target_batch_id
      )
    );
  end if;

  if batch_record.status <> 'approved' then
    raise exception using
      errcode = '55000',
      message = 'historical import batch must be approved before commit';
  end if;

  if normalized_preview #>> '{source,sha256}' <> batch_record.source_sha256
    or normalized_preview ->> 'status' <> 'review_only'
    or coalesce((normalized_preview ->> 'committed')::boolean, true)
    or normalized_preview #>> '{approval,decision_queue_status}' <> 'approved'
    or not coalesce(
      (normalized_preview #>> '{commit_gate,ready_for_domain_commit}')::boolean,
      false
    )
    or jsonb_array_length(
      coalesce(normalized_preview #> '{commit_gate,blocking_issues}', '[]'::jsonb)
    ) <> 0
  then
    raise exception using
      errcode = '55000',
      message = 'normalized preview has not passed its commit gate';
  end if;

  preview_year := (normalized_preview #>> '{season,year}')::integer;

  if not exists (
    select 1
    from public.seasons as season
    where season.id = batch_record.season_id
      and season.league_id = batch_record.league_id
      and season.year = preview_year
  ) then
    raise exception using
      errcode = '55000',
      message = 'normalized preview season does not match the batch season';
  end if;

  for item in
    select value from jsonb_array_elements(normalized_preview -> 'teams')
  loop
    perform private.resolve_historical_season_team(
      target_batch_id,
      batch_record.season_id,
      item ->> 'team_key'
    );
  end loop;

  for item in
    select value from jsonb_array_elements(
      normalized_preview -> 'financial_obligations'
    )
  loop
    team_id := private.resolve_historical_season_team(
      target_batch_id,
      batch_record.season_id,
      item ->> 'team_key'
    );
    source_key_value := item ->> 'source_key';

    insert into public.financial_obligations (
      league_id,
      season_id,
      season_team_id,
      direction,
      amount_cents,
      category,
      description,
      source_type,
      source_key,
      occurred_on,
      created_by
    )
    values (
      batch_record.league_id,
      batch_record.season_id,
      team_id,
      (item ->> 'direction')::public.obligation_direction,
      (item ->> 'amount_cents')::bigint,
      item ->> 'category',
      item ->> 'description',
      'import',
      source_key_value,
      (item ->> 'occurred_on')::date,
      actor_id
    )
    on conflict (season_id, source_key) do nothing;

    select obligation.id
    into target_id
    from public.financial_obligations as obligation
    where obligation.season_id = batch_record.season_id
      and obligation.source_key = source_key_value
      and obligation.league_id = batch_record.league_id
      and obligation.season_team_id = team_id
      and obligation.direction =
        (item ->> 'direction')::public.obligation_direction
      and obligation.amount_cents = (item ->> 'amount_cents')::bigint
      and obligation.category = item ->> 'category'
      and obligation.description = item ->> 'description'
      and obligation.source_type = 'import'
      and obligation.occurred_on = (item ->> 'occurred_on')::date;

    if target_id is null then
      raise exception 'financial obligation source-key collision: %',
        source_key_value;
    end if;

    perform private.add_historical_commit_record(
      target_batch_id,
      batch_record.league_id,
      batch_record.season_id,
      'financial_obligation',
      target_id,
      source_key_value,
      item -> 'source_refs'
    );
    obligations_count := obligations_count + 1;
  end loop;

  for item in
    select value from jsonb_array_elements(normalized_preview -> 'payments')
  loop
    team_id := private.resolve_historical_season_team(
      target_batch_id,
      batch_record.season_id,
      item ->> 'team_key'
    );
    source_key_value := item ->> 'source_key';

    insert into public.payments (
      league_id,
      season_id,
      season_team_id,
      direction,
      amount_cents,
      paid_on,
      method,
      reference,
      note,
      source_type,
      source_key,
      created_by
    )
    values (
      batch_record.league_id,
      batch_record.season_id,
      team_id,
      (item ->> 'direction')::public.payment_direction,
      (item ->> 'amount_cents')::bigint,
      (item ->> 'paid_on')::date,
      item ->> 'method',
      item ->> 'reference',
      item ->> 'note',
      'import',
      source_key_value,
      actor_id
    )
    on conflict (season_id, source_key) do nothing;

    select payment.id
    into target_id
    from public.payments as payment
    where payment.season_id = batch_record.season_id
      and payment.source_key = source_key_value
      and payment.league_id = batch_record.league_id
      and payment.season_team_id = team_id
      and payment.direction = (item ->> 'direction')::public.payment_direction
      and payment.amount_cents = (item ->> 'amount_cents')::bigint
      and payment.paid_on = (item ->> 'paid_on')::date
      and payment.method is not distinct from item ->> 'method'
      and payment.reference is not distinct from item ->> 'reference'
      and payment.note is not distinct from item ->> 'note'
      and payment.source_type = 'import';

    if target_id is null then
      raise exception 'payment source-key collision: %', source_key_value;
    end if;

    perform private.add_historical_commit_record(
      target_batch_id,
      batch_record.league_id,
      batch_record.season_id,
      'payment',
      target_id,
      source_key_value,
      item -> 'source_refs'
    );
    payments_count := payments_count + 1;
  end loop;

  for item in
    select value from jsonb_array_elements(
      normalized_preview -> 'payment_allocations'
    )
  loop
    select value ->> 'source_key'
    into payment_source_key
    from jsonb_array_elements(normalized_preview -> 'payments')
    where value ->> 'preview_id' = item ->> 'payment_preview_id';

    select value ->> 'source_key'
    into obligation_source_key
    from jsonb_array_elements(
      normalized_preview -> 'financial_obligations'
    )
    where value ->> 'preview_id' = item ->> 'obligation_preview_id';

    select payment.id, payment.season_team_id
    into resolved_payment_id, team_id
    from public.payments as payment
    where payment.season_id = batch_record.season_id
      and payment.source_key = payment_source_key;

    select obligation.id
    into resolved_obligation_id
    from public.financial_obligations as obligation
    where obligation.season_id = batch_record.season_id
      and obligation.source_key = obligation_source_key
      and obligation.season_team_id = team_id;

    if resolved_payment_id is null or resolved_obligation_id is null then
      raise exception 'allocation preview references an unknown payment or obligation';
    end if;

    source_key_value := item ->> 'source_key';
    insert into public.payment_allocations (
      league_id,
      season_id,
      season_team_id,
      payment_id,
      obligation_id,
      kind,
      amount_cents,
      source_key,
      created_by
    )
    values (
      batch_record.league_id,
      batch_record.season_id,
      team_id,
      resolved_payment_id,
      resolved_obligation_id,
      'apply',
      (item ->> 'amount_cents')::bigint,
      source_key_value,
      actor_id
    )
    on conflict (season_id, source_key) do nothing;

    select allocation.id
    into target_id
    from public.payment_allocations as allocation
    where allocation.season_id = batch_record.season_id
      and allocation.source_key = source_key_value
      and allocation.payment_id = resolved_payment_id
      and allocation.obligation_id = resolved_obligation_id
      and allocation.kind = 'apply'
      and allocation.amount_cents = (item ->> 'amount_cents')::bigint;

    if target_id is null then
      raise exception 'payment allocation source-key collision: %',
        source_key_value;
    end if;

    perform private.add_historical_commit_record(
      target_batch_id,
      batch_record.league_id,
      batch_record.season_id,
      'payment_allocation',
      target_id,
      source_key_value,
      '[]'::jsonb
    );
    allocations_count := allocations_count + 1;
  end loop;

  for item in
    select value from jsonb_array_elements(
      normalized_preview -> 'external_cash_events'
    )
  loop
    source_key_value := item ->> 'source_key';

    insert into public.external_cash_events (
      league_id,
      season_id,
      direction,
      amount_cents,
      category,
      counterparty,
      description,
      source_type,
      source_key,
      occurred_on,
      created_by
    )
    values (
      batch_record.league_id,
      batch_record.season_id,
      (item ->> 'direction')::public.external_cash_direction,
      (item ->> 'amount_cents')::bigint,
      item ->> 'category',
      item ->> 'counterparty',
      item ->> 'description',
      'import',
      source_key_value,
      nullif(item ->> 'occurred_on', '')::date,
      actor_id
    )
    on conflict (season_id, source_key) do nothing;

    select event.id
    into target_id
    from public.external_cash_events as event
    where event.season_id = batch_record.season_id
      and event.source_key = source_key_value
      and event.league_id = batch_record.league_id
      and event.direction =
        (item ->> 'direction')::public.external_cash_direction
      and event.amount_cents = (item ->> 'amount_cents')::bigint
      and event.category = item ->> 'category'
      and event.counterparty is not distinct from item ->> 'counterparty'
      and event.description = item ->> 'description'
      and event.source_type = 'import'
      and event.occurred_on is not distinct from
        nullif(item ->> 'occurred_on', '')::date;

    if target_id is null then
      raise exception 'external cash source-key collision: %', source_key_value;
    end if;

    perform private.add_historical_commit_record(
      target_batch_id,
      batch_record.league_id,
      batch_record.season_id,
      'external_cash_event',
      target_id,
      source_key_value,
      item -> 'source_refs'
    );
    external_cash_count := external_cash_count + 1;
  end loop;

  for item in
    select value from jsonb_array_elements(
      normalized_preview -> 'weekly_results'
    )
  loop
    if item ->> 'team_key' < item ->> 'opponent_team_key' then
      week_number := (item ->> 'week')::integer;
      source_key_value := format(
        'import:%s:matchup:%s:%s:%s',
        preview_year,
        week_number,
        item ->> 'team_key',
        item ->> 'opponent_team_key'
      );

      select value
      into counterpart
      from jsonb_array_elements(normalized_preview -> 'weekly_results')
      where (value ->> 'week')::integer = week_number
        and value ->> 'team_key' = item ->> 'opponent_team_key'
        and value ->> 'opponent_team_key' = item ->> 'team_key';

      if counterpart is null
        or counterpart ->> 'phase' <> item ->> 'phase'
        or not (
          (item ->> 'result' = 'win'
            and counterpart ->> 'result' = 'loss'
            and (item ->> 'score')::numeric >
              (counterpart ->> 'score')::numeric)
          or (item ->> 'result' = 'loss'
            and counterpart ->> 'result' = 'win'
            and (item ->> 'score')::numeric <
              (counterpart ->> 'score')::numeric)
          or (item ->> 'result' = 'tie'
            and counterpart ->> 'result' = 'tie'
            and (item ->> 'score')::numeric =
              (counterpart ->> 'score')::numeric)
        )
      then
        raise exception
          'weekly result has an invalid reciprocal matchup row';
      end if;

      insert into public.matchups (
        league_id,
        season_id,
        week,
        phase,
        source_type,
        source_key,
        created_by
      )
      values (
        batch_record.league_id,
        batch_record.season_id,
        week_number,
        (item ->> 'phase')::public.competition_phase,
        'import',
        source_key_value,
        actor_id
      )
      on conflict (season_id, source_key) do nothing;

      select matchup.id
      into target_id
      from public.matchups as matchup
      where matchup.season_id = batch_record.season_id
        and matchup.source_key = source_key_value
        and matchup.league_id = batch_record.league_id
        and matchup.week = week_number
        and matchup.phase = (item ->> 'phase')::public.competition_phase
        and matchup.source_type = 'import';

      if target_id is null then
        raise exception 'matchup source-key collision: %', source_key_value;
      end if;

      source_refs_value := jsonb_build_array(
        item ->> 'source_ref',
        counterpart ->> 'source_ref'
      );
      perform private.add_historical_commit_record(
        target_batch_id,
        batch_record.league_id,
        batch_record.season_id,
        'matchup',
        target_id,
        source_key_value,
        source_refs_value
      );
      matchups_count := matchups_count + 1;
    end if;
  end loop;

  for item in
    select value from jsonb_array_elements(
      normalized_preview -> 'weekly_results'
    )
  loop
    team_id := private.resolve_historical_season_team(
      target_batch_id,
      batch_record.season_id,
      item ->> 'team_key'
    );
    opponent_id := private.resolve_historical_season_team(
      target_batch_id,
      batch_record.season_id,
      item ->> 'opponent_team_key'
    );
    week_number := (item ->> 'week')::integer;

    if item ->> 'team_key' < item ->> 'opponent_team_key' then
      source_key_value := format(
        'import:%s:matchup:%s:%s:%s',
        preview_year,
        week_number,
        item ->> 'team_key',
        item ->> 'opponent_team_key'
      );
    else
      source_key_value := format(
        'import:%s:matchup:%s:%s:%s',
        preview_year,
        week_number,
        item ->> 'opponent_team_key',
        item ->> 'team_key'
      );
    end if;

    select matchup.id
    into resolved_matchup_id
    from public.matchups as matchup
    where matchup.season_id = batch_record.season_id
      and matchup.source_key = source_key_value;

    source_key_value := format(
      'import:%s:weekly_result:%s:%s',
      preview_year,
      week_number,
      item ->> 'team_key'
    );

    insert into public.weekly_results (
      league_id,
      season_id,
      matchup_id,
      season_team_id,
      opponent_season_team_id,
      score,
      result,
      notes,
      source_type,
      source_key,
      created_by
    )
    values (
      batch_record.league_id,
      batch_record.season_id,
      resolved_matchup_id,
      team_id,
      opponent_id,
      (item ->> 'score')::numeric,
      (item ->> 'result')::public.competition_result,
      item ->> 'notes',
      'import',
      source_key_value,
      actor_id
    )
    on conflict (season_id, source_key) do nothing;

    select result_row.id
    into target_id
    from public.weekly_results as result_row
    where result_row.season_id = batch_record.season_id
      and result_row.source_key = source_key_value
      and result_row.matchup_id = resolved_matchup_id
      and result_row.season_team_id = team_id
      and result_row.opponent_season_team_id = opponent_id
      and result_row.score = (item ->> 'score')::numeric
      and result_row.result = (item ->> 'result')::public.competition_result
      and result_row.notes is not distinct from item ->> 'notes'
      and result_row.source_type = 'import';

    if target_id is null then
      raise exception 'weekly result source-key collision: %', source_key_value;
    end if;

    perform private.add_historical_commit_record(
      target_batch_id,
      batch_record.league_id,
      batch_record.season_id,
      'weekly_result',
      target_id,
      source_key_value,
      jsonb_build_array(item ->> 'source_ref')
    );
    results_count := results_count + 1;
  end loop;

  for item in
    select value from jsonb_array_elements(
      normalized_preview -> 'weekly_awards'
    )
  loop
    week_number := (item ->> 'week')::integer;
    team_id := private.resolve_historical_season_team(
      target_batch_id,
      batch_record.season_id,
      item ->> 'high_team_key'
    );
    opponent_id := private.resolve_historical_season_team(
      target_batch_id,
      batch_record.season_id,
      item ->> 'low_team_key'
    );

    select obligation.id
    into high_award_obligation_id
    from public.financial_obligations as obligation
    where obligation.season_id = batch_record.season_id
      and obligation.source_key = format(
        'import:%s:obligation:weekly_high:%s',
        preview_year,
        week_number
      )
      and obligation.season_team_id = team_id
      and obligation.amount_cents = (item ->> 'payout_cents')::bigint;

    select obligation.id
    into low_award_obligation_id
    from public.financial_obligations as obligation
    where obligation.season_id = batch_record.season_id
      and obligation.source_key = format(
        'import:%s:obligation:weekly_low:%s',
        preview_year,
        week_number
      )
      and obligation.season_team_id = opponent_id
      and obligation.amount_cents = (item ->> 'penalty_cents')::bigint;

    if high_award_obligation_id is null
      or low_award_obligation_id is null
    then
      raise exception 'weekly award is missing its financial obligations';
    end if;

    source_key_value := format(
      'import:%s:weekly_award:%s',
      preview_year,
      week_number
    );
    insert into public.weekly_awards (
      league_id,
      season_id,
      week,
      high_score_season_team_id,
      high_score,
      high_score_obligation_id,
      low_score_season_team_id,
      low_score,
      low_score_obligation_id,
      source_type,
      source_key,
      source_refs,
      created_by
    )
    values (
      batch_record.league_id,
      batch_record.season_id,
      week_number,
      team_id,
      (item ->> 'high_score')::numeric,
      high_award_obligation_id,
      opponent_id,
      (item ->> 'low_score')::numeric,
      low_award_obligation_id,
      'import',
      source_key_value,
      item -> 'source_refs',
      actor_id
    )
    on conflict (season_id, source_key) do nothing;

    select award.id
    into target_id
    from public.weekly_awards as award
    where award.season_id = batch_record.season_id
      and award.source_key = source_key_value
      and award.week = week_number
      and award.high_score_season_team_id = team_id
      and award.high_score = (item ->> 'high_score')::numeric
      and award.high_score_obligation_id = high_award_obligation_id
      and award.low_score_season_team_id = opponent_id
      and award.low_score = (item ->> 'low_score')::numeric
      and award.low_score_obligation_id = low_award_obligation_id
      and award.source_type = 'import';

    if target_id is null then
      raise exception 'weekly award source-key collision: %', source_key_value;
    end if;

    perform private.add_historical_commit_record(
      target_batch_id,
      batch_record.league_id,
      batch_record.season_id,
      'weekly_award',
      target_id,
      source_key_value,
      item -> 'source_refs'
    );
    awards_count := awards_count + 1;
  end loop;

  select
    coalesce(sum((value ->> 'amount_cents')::bigint)
      filter (where value ->> 'direction' = 'team_owes_league'), 0),
    coalesce(sum((value ->> 'amount_cents')::bigint)
      filter (where value ->> 'direction' = 'league_owes_team'), 0)
  into team_obligations_cents, league_obligations_cents
  from jsonb_array_elements(
    normalized_preview -> 'financial_obligations'
  );

  select
    coalesce(sum((value ->> 'amount_cents')::bigint)
      filter (where value ->> 'direction' = 'from_team'), 0),
    coalesce(sum((value ->> 'amount_cents')::bigint)
      filter (where value ->> 'direction' = 'to_team'), 0),
    coalesce(sum((value ->> 'amount_cents')::bigint), 0)
  into payments_from_team_cents, payments_to_team_cents, payment_cents
  from jsonb_array_elements(normalized_preview -> 'payments');

  select coalesce(sum((value ->> 'amount_cents')::bigint), 0)
  into allocated_payment_cents
  from jsonb_array_elements(normalized_preview -> 'payment_allocations');

  select
    coalesce(sum((value ->> 'amount_cents')::bigint)
      filter (where value ->> 'direction' = 'cash_in'), 0),
    coalesce(sum((value ->> 'amount_cents')::bigint)
      filter (where value ->> 'direction' = 'cash_out'), 0)
  into external_cash_in_cents, external_cash_out_cents
  from jsonb_array_elements(normalized_preview -> 'external_cash_events');

  cash_balance_cents := payments_from_team_cents - payments_to_team_cents
    + external_cash_in_cents - external_cash_out_cents;
  net_team_balance_cents := team_obligations_cents
    - payments_from_team_cents
    - league_obligations_cents
    + payments_to_team_cents;

  if team_obligations_cents <>
      (normalized_preview #>>
        '{reconciliation,totals,team_obligations_cents}')::bigint
    or payments_from_team_cents <>
      (normalized_preview #>>
        '{reconciliation,totals,payments_from_team_cents}')::bigint
    or league_obligations_cents <>
      (normalized_preview #>>
        '{reconciliation,totals,league_obligations_cents}')::bigint
    or payments_to_team_cents <>
      (normalized_preview #>>
        '{reconciliation,totals,payments_to_team_cents}')::bigint
    or net_team_balance_cents <>
      (normalized_preview #>>
        '{reconciliation,totals,net_team_balance_cents}')::bigint
    or payment_cents <>
      (normalized_preview #>> '{reconciliation,totals,payment_cents}')::bigint
    or allocated_payment_cents <> payment_cents
    or allocated_payment_cents <>
      (normalized_preview #>>
        '{reconciliation,totals,allocated_payment_cents}')::bigint
    or coalesce(
      (normalized_preview #>>
        '{reconciliation,totals,unallocated_payment_cents}')::bigint,
      -1
    ) <> 0
    or payments_from_team_cents <>
      (normalized_preview #>>
        '{reconciliation,cash,team_cash_in_cents}')::bigint
    or payments_to_team_cents <>
      (normalized_preview #>>
        '{reconciliation,cash,team_cash_out_cents}')::bigint
    or external_cash_in_cents <>
      (normalized_preview #>>
        '{reconciliation,cash,external_cash_in_cents}')::bigint
    or external_cash_out_cents <>
      (normalized_preview #>>
        '{reconciliation,cash,external_cash_out_cents}')::bigint
    or cash_balance_cents <>
      (normalized_preview #>>
        '{reconciliation,cash,cash_balance_cents}')::bigint
  then
    raise exception using
      errcode = '55000',
      message = 'normalized preview reconciliation failed';
  end if;

  record_counts_value := jsonb_build_object(
    'matchups', matchups_count,
    'weekly_results', results_count,
    'weekly_awards', awards_count,
    'financial_obligations', obligations_count,
    'payments', payments_count,
    'payment_allocations', allocations_count,
    'external_cash_events', external_cash_count
  );

  insert into public.historical_import_commits (
    batch_id,
    league_id,
    season_id,
    preview_sha256,
    normalized_preview,
    record_counts,
    reconciliation,
    committed_by
  )
  values (
    target_batch_id,
    batch_record.league_id,
    batch_record.season_id,
    preview_hash,
    normalized_preview,
    record_counts_value,
    normalized_preview -> 'reconciliation',
    actor_id
  );

  update public.historical_import_batches
  set
    status = 'committed',
    committed_by = actor_id,
    committed_at = now()
  where id = target_batch_id;

  return jsonb_build_object(
    'status', 'committed',
    'batch_id', target_batch_id,
    'preview_sha256', preview_hash,
    'record_counts', record_counts_value
  );
end;
$$;

revoke all on function private.resolve_historical_season_team(uuid, uuid, text)
from public;
revoke all on function private.add_historical_commit_record(
  uuid,
  uuid,
  uuid,
  public.historical_committed_record_kind,
  uuid,
  text,
  jsonb
) from public;
revoke all on function public.commit_historical_import(uuid, jsonb)
from public;

alter table public.historical_import_commits enable row level security;
alter table public.historical_import_committed_records enable row level security;

create policy "commissioners can read historical import commits"
on public.historical_import_commits
for select
to authenticated
using (private.is_league_commissioner(league_id));

create policy "commissioners can read historical committed records"
on public.historical_import_committed_records
for select
to authenticated
using (private.is_league_commissioner(league_id));

comment on table public.historical_import_commits is
  'Canonical normalized preview and reconciliation for one committed batch.';

comment on table public.historical_import_committed_records is
  'Source-reference provenance links from an import batch to domain records.';

comment on function public.commit_historical_import(uuid, jsonb) is
  'Atomically commits one approved normalized preview and is idempotent by batch and preview hash.';

grant usage on type public.historical_committed_record_kind
to authenticated, service_role;

grant select on table
  public.historical_import_commits,
  public.historical_import_committed_records
to authenticated;

grant all on table
  public.historical_import_commits,
  public.historical_import_committed_records
to service_role;

grant execute on function public.commit_historical_import(uuid, jsonb)
to authenticated, service_role;
