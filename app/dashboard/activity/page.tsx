import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import {
  buildCompetitionActivity,
  buildFinancialActivity,
  type ActivityAdjustment,
  type ActivityAward,
  type ActivityMatchup,
  type ActivityObligation,
  type ActivityPayment,
  type ActivityResult,
} from "@/lib/activity/view";
import { formatCurrency } from "@/lib/format/currency";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "League activity" };

type ActivityPageProps = {
  searchParams: Promise<{ season?: string | string[] }>;
};

function first(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

function formatDate(value: string) {
  const date = new Date(`${value}T12:00:00Z`);
  if (Number.isNaN(date.valueOf())) return value;
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
}

function phaseLabel(phase: "regular_season" | "postseason") {
  return phase === "postseason" ? "Postseason" : "Regular season";
}

export default async function ActivityPage({ searchParams }: ActivityPageProps) {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/login?next=/dashboard/activity");

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
  const requestedSeason = first(params.season);
  const season = seasons.find((item) => item.id === requestedSeason)
    ?? seasons.find((item) => item.status === "active")
    ?? seasons[0];

  const [
    teamsResult,
    matchupsResult,
    resultsResult,
    awardsResult,
    obligationsResult,
    paymentsResult,
    adjustmentsResult,
  ] = await Promise.all([
    supabase.from("season_teams").select("id, name").eq("season_id", season.id),
    supabase.from("matchups").select("id, week, phase, source_type").eq("season_id", season.id),
    supabase.from("weekly_results").select("matchup_id, season_team_id, score, result").eq("season_id", season.id),
    supabase.from("weekly_awards").select("id, week, high_score_season_team_id, high_score, low_score_season_team_id, low_score, source_type").eq("season_id", season.id),
    supabase.from("financial_obligations").select("id, season_team_id, direction, amount_cents, description, occurred_on").eq("season_id", season.id),
    supabase.from("payments").select("id, season_team_id, direction, amount_cents, paid_on, note").eq("season_id", season.id),
    supabase.from("financial_adjustments").select("id, season_team_id, direction, amount_cents, reason, occurred_on").eq("season_id", season.id),
  ]);

  const teams = teamsResult.data ?? [];
  const competition = buildCompetitionActivity(
    (matchupsResult.data ?? []) as ActivityMatchup[],
    (resultsResult.data ?? []).map((item) => ({ ...item, score: Number(item.score) })) as ActivityResult[],
    (awardsResult.data ?? []).map((item) => ({
      ...item,
      high_score: Number(item.high_score),
      low_score: Number(item.low_score),
    })) as ActivityAward[],
    teams,
  ).slice(0, 30);
  const finances = buildFinancialActivity(
    (obligationsResult.data ?? []).map((item) => ({ ...item, amount_cents: Number(item.amount_cents) })) as ActivityObligation[],
    (paymentsResult.data ?? []).map((item) => ({ ...item, amount_cents: Number(item.amount_cents) })) as ActivityPayment[],
    (adjustmentsResult.data ?? []).map((item) => ({ ...item, amount_cents: Number(item.amount_cents) })) as ActivityAdjustment[],
    teams,
  ).slice(0, 30);

  return (
    <main className="paper-noise min-h-[100svh] px-4 py-5 sm:px-8 sm:py-7 lg:px-12">
      <div className="mx-auto max-w-7xl">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <div className="flex min-w-0 items-center gap-3 sm:gap-4">
            <BrandLogo alt="" className="h-14 w-14 shrink-0 object-contain sm:h-16 sm:w-16" priority sizes="64px" />
            <div className="min-w-0">
              <p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine">League timeline</p>
              <p className="mt-1 truncate font-display text-xl sm:text-2xl">{league?.name ?? "Sweet Looking Napa Dads"}</p>
            </div>
          </div>
          <Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine" href="/dashboard">Standings</Link>
        </header>

        <section className="py-8 sm:py-11">
          <div className="grid gap-6 border-b border-forest/20 pb-7 lg:grid-cols-[1fr_auto] lg:items-end">
            <div className="max-w-3xl">
              <p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">{season.name} · Accepted records</p>
              <h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">League activity</h1>
              <p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">A season-at-a-glance timeline with competition organized by week and financial events organized by date. The two records stay separate so a score never masquerades as a transaction.</p>
            </div>
            <form className="grid gap-2" method="get">
              <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">Season
                <select className="min-h-12 min-w-56 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground" defaultValue={season.id} name="season">
                  {seasons.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
                </select>
              </label>
              <button className="min-h-11 border border-forest bg-forest px-4 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-background" type="submit">Load season</button>
            </form>
          </div>

          <div className="mt-8 grid gap-10 xl:grid-cols-2 xl:gap-8">
            <section aria-labelledby="competition-activity-heading">
              <div className="border-l-2 border-wine pl-4">
                <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">By scoring week</p>
                <h2 className="mt-2 font-display text-4xl sm:text-5xl" id="competition-activity-heading">Competition</h2>
                <p className="mt-2 max-w-xl text-sm leading-6 text-ink-muted">Accepted matchup results and stored weekly honors. Honors are shown as their own records, not inferred in this page.</p>
              </div>
              {competition.length ? (
                <ol className="mt-5 divide-y divide-forest/15 border-y border-forest/20">
                  {competition.map((entry) => (
                    <li className="grid grid-cols-[3.5rem_minmax(0,1fr)] gap-4 py-5 sm:grid-cols-[4.5rem_minmax(0,1fr)]" key={`${entry.kind}-${entry.id}`}>
                      <div>
                        <p className="font-display text-3xl text-wine">{entry.week}</p>
                        <p className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">Week</p>
                      </div>
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-x-2 gap-y-1 font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">
                          <span className="text-wine">{entry.kind === "award" ? "Weekly honors" : "Matchup"}</span>
                          <span>· {phaseLabel(entry.phase)}</span>
                        </div>
                        <h3 className="mt-2 font-display text-2xl leading-tight sm:text-3xl">{entry.headline}</h3>
                        <p className="mt-2 text-sm leading-6 text-ink-muted">{entry.detail}</p>
                        <p className="mt-2 font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">Source: {entry.source.replaceAll("_", " ")}</p>
                      </div>
                    </li>
                  ))}
                </ol>
              ) : (
                <div className="mt-5 border border-dashed border-forest/30 px-5 py-8">
                  <p className="font-display text-2xl">No competition activity yet.</p>
                  <p className="mt-2 text-sm leading-6 text-ink-muted">Accepted results and weekly honors will appear after import, ESPN sync, or commissioner entry.</p>
                </div>
              )}
            </section>

            <section aria-labelledby="financial-activity-heading">
              <div className="border-l-2 border-forest pl-4">
                <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-forest">By event date</p>
                <h2 className="mt-2 font-display text-4xl sm:text-5xl" id="financial-activity-heading">Financial events</h2>
                <p className="mt-2 max-w-xl text-sm leading-6 text-ink-muted">Immutable obligations and payments, plus audited adjustments. Amounts are shown without changing their recorded direction.</p>
              </div>
              {finances.length ? (
                <ol className="mt-5 divide-y divide-forest/15 border-y border-forest/20">
                  {finances.map((entry) => (
                    <li className="grid gap-3 py-5 sm:grid-cols-[7.5rem_minmax(0,1fr)_auto] sm:items-center" key={`${entry.kind}-${entry.id}`}>
                      <div>
                        <time className="font-mono text-[9px] font-bold uppercase tracking-[0.12em] text-ink-muted" dateTime={entry.occurred_on}>{formatDate(entry.occurred_on)}</time>
                        <p className="mt-1 font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-forest">{entry.kind}</p>
                      </div>
                      <div className="min-w-0">
                        <h3 className="font-display text-2xl leading-tight">{entry.headline}</h3>
                        <p className="mt-1 text-sm leading-6 text-ink-muted">{entry.team_name} · {entry.direction}</p>
                      </div>
                      <data className="font-display text-3xl tabular-nums sm:text-right" value={entry.amount_cents}>{formatCurrency(entry.amount_cents)}</data>
                    </li>
                  ))}
                </ol>
              ) : (
                <div className="mt-5 border border-dashed border-forest/30 px-5 py-8">
                  <p className="font-display text-2xl">No financial activity yet.</p>
                  <p className="mt-2 text-sm leading-6 text-ink-muted">Configured dues, awards, penalties, payments, and adjustments will appear as separate source events.</p>
                </div>
              )}
            </section>
          </div>
        </section>
      </div>
    </main>
  );
}
