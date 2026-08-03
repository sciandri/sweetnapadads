import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import {
  buildCompetitionWeeks,
  formatCompetitionScore,
  type CompetitionMatchupRecord,
  type WeeklyAwardRecord,
  type WeeklyResultRecord,
} from "@/lib/competition/view";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Results & weekly honors" };

type ResultsPageProps = {
  searchParams: Promise<{
    season?: string | string[];
    week?: string | string[];
  }>;
};

export default async function ResultsPage({ searchParams }: ResultsPageProps) {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/login?next=/dashboard/results");

  const { data: membership } = await supabase
    .from("league_memberships")
    .select("league_id")
    .eq("user_id", userId)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();
  if (!membership) redirect("/access-denied");

  const [{ data: league }, { data: seasons }] = await Promise.all([
    supabase.from("leagues").select("name").eq("id", membership.league_id).maybeSingle(),
    supabase
      .from("seasons")
      .select("id, name, status, year")
      .eq("league_id", membership.league_id)
      .order("year", { ascending: false }),
  ]);
  if (!seasons?.length) redirect("/dashboard");

  const params = await searchParams;
  const requestedSeason = Array.isArray(params.season) ? params.season[0] : params.season;
  const season = seasons.find((item) => item.id === requestedSeason)
    ?? seasons.find((item) => item.status === "active")
    ?? seasons[0];

  const [matchupsResult, resultsResult, awardsResult, teamsResult] = await Promise.all([
    supabase
      .from("accepted_matchups")
      .select("id, week, phase, source_type")
      .eq("season_id", season.id)
      .order("week", { ascending: false }),
    supabase
      .from("accepted_weekly_results")
      .select("matchup_id, season_team_id, opponent_season_team_id, score, result")
      .eq("season_id", season.id),
    supabase
      .from("accepted_weekly_awards")
      .select("week, high_score_season_team_id, high_score, low_score_season_team_id, low_score")
      .eq("season_id", season.id)
      .order("week", { ascending: false }),
    supabase
      .from("season_teams")
      .select("id, name, abbreviation")
      .eq("season_id", season.id),
  ]);

  const weeks = buildCompetitionWeeks(
    (matchupsResult.data ?? []) as CompetitionMatchupRecord[],
    (resultsResult.data ?? []).map((result) => ({
      ...result,
      score: Number(result.score),
    })) as WeeklyResultRecord[],
    (awardsResult.data ?? []).map((award) => ({
      ...award,
      high_score: Number(award.high_score),
      low_score: Number(award.low_score),
    })) as WeeklyAwardRecord[],
    teamsResult.data ?? [],
  );
  const requestedWeek = Number(Array.isArray(params.week) ? params.week[0] : params.week);
  const selectedWeek = weeks.find((week) => week.week === requestedWeek) ?? weeks[0];

  return (
    <main className="paper-noise min-h-[100svh] px-4 py-5 sm:px-8 sm:py-7 lg:px-12">
      <div className="mx-auto max-w-7xl">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <div className="flex min-w-0 items-center gap-3 sm:gap-4">
            <BrandLogo alt="" className="h-14 w-14 shrink-0 object-contain sm:h-16 sm:w-16" priority sizes="64px" />
            <div className="min-w-0">
              <p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine">League competition</p>
              <p className="mt-1 truncate font-display text-xl sm:text-2xl">{league?.name ?? "Sweet Looking Napa Dads"}</p>
            </div>
          </div>
          <Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine" href="/dashboard">
            Standings
          </Link>
        </header>

        <section className="py-8 sm:py-11">
          <div className="grid gap-6 border-b border-forest/20 pb-7 lg:grid-cols-[1fr_auto] lg:items-end">
            <div className="max-w-3xl">
              <p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">{season.name} · Accepted league record</p>
              <h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">Results & weekly honors</h1>
              <p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">
                Final scores and rule-derived weekly honors from accepted competition data. Results and awards are displayed—not recalculated—in this view.
              </p>
            </div>

            <form className="grid gap-3 sm:grid-cols-[minmax(13rem,1fr)_7rem_auto]" method="get">
              <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">
                Season
                <select className="min-h-11 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground" defaultValue={season.id} name="season">
                  {seasons.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
                </select>
              </label>
              <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">
                Week
                <select className="min-h-11 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground" defaultValue={selectedWeek?.week ?? ""} disabled={!weeks.length} name="week">
                  {weeks.map((week) => <option key={week.week} value={week.week}>Week {week.week}</option>)}
                </select>
              </label>
              <button className="min-h-11 self-end border border-forest bg-forest px-4 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-background" type="submit">Load</button>
            </form>
          </div>

          {selectedWeek ? (
            <div className="mt-7 grid gap-8">
              <div className="flex flex-wrap items-end justify-between gap-3">
                <div>
                  <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">{selectedWeek.phase === "postseason" ? "Postseason" : "Regular season"}</p>
                  <h2 className="mt-2 font-display text-4xl sm:text-5xl">Week {selectedWeek.week}</h2>
                </div>
                <p className="font-mono text-[9px] uppercase tracking-[0.14em] text-ink-muted">{selectedWeek.matchups.length} accepted matchup{selectedWeek.matchups.length === 1 ? "" : "s"}</p>
              </div>

              {selectedWeek.award ? (
                <section aria-labelledby="weekly-honors-heading" className="grid gap-3 sm:grid-cols-2">
                  <h2 className="sr-only" id="weekly-honors-heading">Weekly honors</h2>
                  <article className="border-l-4 border-forest bg-surface/85 p-5 sm:p-6">
                    <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-forest">High score · Weekly honor</p>
                    <p className="mt-3 font-display text-3xl">{selectedWeek.award.high.team_name}</p>
                    <p className="mt-2 font-display text-5xl text-forest">{formatCompetitionScore(selectedWeek.award.high.score)}</p>
                  </article>
                  <article className="border-l-4 border-wine bg-surface/85 p-5 sm:p-6">
                    <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">Low score · Weekly penalty</p>
                    <p className="mt-3 font-display text-3xl">{selectedWeek.award.low.team_name}</p>
                    <p className="mt-2 font-display text-5xl text-wine">{formatCompetitionScore(selectedWeek.award.low.score)}</p>
                  </article>
                </section>
              ) : (
                <div className="border border-dashed border-forest/30 px-5 py-6">
                  <p className="font-display text-2xl">Weekly honors are pending.</p>
                  <p className="mt-2 max-w-2xl text-sm leading-6 text-ink-muted">Honors appear only after the complete week has unique high and low scores. Incomplete or tied weeks remain under commissioner review.</p>
                </div>
              )}

              <section aria-labelledby="matchups-heading">
                <h2 className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-ink-muted" id="matchups-heading">Final matchups</h2>
                <div className="mt-3 grid gap-4 lg:grid-cols-2">
                  {selectedWeek.matchups.map((matchup) => (
                    <article className="border border-forest/20 bg-surface/80 p-4 sm:p-5" key={matchup.id}>
                      <div className="mb-4 flex items-center justify-between gap-3 border-b border-forest/15 pb-3">
                        <p className="font-mono text-[8px] font-bold uppercase tracking-[0.14em] text-ink-muted">{matchup.source_type} accepted</p>
                        {!matchup.complete ? <span className="font-mono text-[8px] font-bold uppercase tracking-[0.14em] text-wine">Result pending</span> : null}
                      </div>
                      <ol className="grid gap-2">
                        {matchup.results.map((result) => (
                          <li className={`grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4 border px-3 py-4 ${result.result === "win" ? "border-forest/25 bg-forest/5" : "border-forest/10"}`} key={result.season_team_id}>
                            <div className="min-w-0">
                              <div className="flex items-center gap-2">
                                <p className="truncate font-display text-2xl">{result.team_name}</p>
                                <span className={`shrink-0 font-mono text-[8px] font-bold uppercase tracking-[0.12em] ${result.result === "win" ? "text-forest" : "text-ink-muted"}`}>{result.result}</span>
                              </div>
                              {result.abbreviation ? <p className="mt-1 font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted">{result.abbreviation}</p> : null}
                            </div>
                            <data className="font-display text-3xl tabular-nums sm:text-4xl" value={result.score}>{formatCompetitionScore(result.score)}</data>
                          </li>
                        ))}
                      </ol>
                    </article>
                  ))}
                </div>
              </section>
            </div>
          ) : (
            <div className="mt-7 border border-dashed border-forest/30 px-5 py-12 text-center sm:px-10">
              <p className="font-display text-3xl">No accepted results yet.</p>
              <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-ink-muted">Completed matchups will appear here after competition data is synchronized or entered through the reviewed fallback workflow.</p>
            </div>
          )}
        </section>
      </div>
    </main>
  );
}
