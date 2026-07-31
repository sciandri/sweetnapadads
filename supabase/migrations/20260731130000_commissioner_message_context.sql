create or replace function public.get_commissioner_message_context(
  target_season_id uuid,
  target_week integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  season_record record;
  standings_value jsonb;
  results_value jsonb;
  awards_value jsonb;
begin
  if actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'message context requires an authenticated actor';
  end if;

  if target_week is null or target_week < 1 or target_week > 30 then
    raise exception using
      errcode = '22023',
      message = 'message context week must be between 1 and 30';
  end if;

  select
    season.id,
    season.league_id,
    season.year,
    season.name,
    league.name as league_name
  into season_record
  from public.seasons as season
  join public.leagues as league on league.id = season.league_id
  where season.id = target_season_id;

  if not found then
    raise exception 'season % does not exist', target_season_id;
  end if;

  if not private.is_league_commissioner(season_record.league_id) then
    raise exception using
      errcode = '42501',
      message = 'only an active league commissioner can assemble message context';
  end if;

  select jsonb_build_object(
    'source', 'espn',
    'available', count(*) > 0,
    'snapshot_id', min(standing.snapshot_id::text)::uuid,
    'captured_at', min(standing.captured_at),
    'scoring_period', min(standing.scoring_period),
    'official_order', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'rank', standing.official_rank,
          'team_key', team.slug,
          'team_name', season_team.name,
          'espn_team_id', standing.espn_team_id,
          'record', standing.record_summary,
          'wins', standing.wins,
          'losses', standing.losses,
          'ties', standing.ties,
          'points_for', standing.points_for,
          'points_against', standing.points_against,
          'streak', standing.streak,
          'playoff_seed', standing.playoff_seed
        )
        order by standing.official_rank
      ) filter (where standing.snapshot_id is not null),
      '[]'::jsonb
    )
  )
  into standings_value
  from public.current_espn_standings as standing
  join public.season_teams as season_team
    on season_team.id = standing.season_team_id
  join public.teams as team on team.id = season_team.team_id
  where standing.season_id = target_season_id;

  select coalesce(
    jsonb_agg(matchup_context order by matchup_week, matchup_source_key),
    '[]'::jsonb
  )
  into results_value
  from (
    select
      matchup.week as matchup_week,
      matchup.source_key as matchup_source_key,
      jsonb_build_object(
        'week', matchup.week,
        'phase', matchup.phase,
        'source_key', matchup.source_key,
        'teams', jsonb_agg(
          jsonb_build_object(
            'team_key', team.slug,
            'team_name', season_team.name,
            'score', result_row.score,
            'result', result_row.result,
            'notes', result_row.notes
          )
          order by result_row.score desc, season_team.name
        )
      ) as matchup_context
    from public.matchups as matchup
    join public.weekly_results as result_row
      on result_row.matchup_id = matchup.id
    join public.season_teams as season_team
      on season_team.id = result_row.season_team_id
    join public.teams as team on team.id = season_team.team_id
    where matchup.season_id = target_season_id
      and matchup.week = target_week
    group by matchup.id, matchup.week, matchup.phase, matchup.source_key
  ) as selected_matchups;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'week', award.week,
        'high_team_key', high_team.slug,
        'high_team_name', high_season_team.name,
        'high_score', award.high_score,
        'low_team_key', low_team.slug,
        'low_team_name', low_season_team.name,
        'low_score', award.low_score
      )
      order by award.week
    ),
    '[]'::jsonb
  )
  into awards_value
  from public.weekly_awards as award
  join public.season_teams as high_season_team
    on high_season_team.id = award.high_score_season_team_id
  join public.teams as high_team on high_team.id = high_season_team.team_id
  join public.season_teams as low_season_team
    on low_season_team.id = award.low_score_season_team_id
  join public.teams as low_team on low_team.id = low_season_team.team_id
  where award.season_id = target_season_id
    and award.week = target_week;

  return jsonb_build_object(
    'league', jsonb_build_object(
      'id', season_record.league_id,
      'name', season_record.league_name
    ),
    'season', jsonb_build_object(
      'id', season_record.id,
      'year', season_record.year,
      'name', season_record.name
    ),
    'selected_week', target_week,
    'standings', standings_value,
    'results', results_value,
    'awards', awards_value,
    'financial_context_included', false
  );
end;
$$;

revoke all on function public.get_commissioner_message_context(uuid, integer)
from public;

comment on function public.get_commissioner_message_context(uuid, integer) is
  'Commissioner-only normalized ESPN and competition facts for message drafting.';

grant execute on function public.get_commissioner_message_context(uuid, integer)
to authenticated;
