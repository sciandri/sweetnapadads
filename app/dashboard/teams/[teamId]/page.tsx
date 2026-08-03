import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import { formatCurrency } from "@/lib/format/currency";
import { formatCompetitionScore } from "@/lib/competition/view";
import {
  buildOwnershipHistory,
  buildTeamSeasonHistory,
  type HistoricalAward,
  type HistoricalBalance,
  type HistoricalResult,
} from "@/lib/teams/history";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Team history" };

type TeamHistoryPageProps = { params: Promise<{ teamId: string }> };

function formatDate(value: string | null) {
  if (!value) return "Present";
  const date = new Date(`${value}T12:00:00Z`);
  if (Number.isNaN(date.valueOf())) return value;
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
}

export default async function TeamHistoryPage({ params }: TeamHistoryPageProps) {
  const { teamId } = await params;
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/login?next=/dashboard/teams");

  const { data: membership } = await supabase
    .from("league_memberships")
    .select("league_id")
    .eq("user_id", userId)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();
  if (!membership) redirect("/access-denied");

  const [{ data: league }, { data: team }] = await Promise.all([
    supabase.from("leagues").select("name").eq("id", membership.league_id).maybeSingle(),
    supabase.from("teams").select("id, name, slug, is_active").eq("id", teamId).eq("league_id", membership.league_id).maybeSingle(),
  ]);
  if (!team) redirect("/dashboard/teams");

  const [seasonsResult, entriesResult, ownershipResult, ownersResult] = await Promise.all([
    supabase.from("seasons").select("id, year, name, status").eq("league_id", membership.league_id).order("year", { ascending: false }),
    supabase.from("season_teams").select("id, team_id, season_id, name, abbreviation").eq("team_id", team.id),
    supabase.from("team_owners").select("id, owner_id, started_on, ended_on, is_primary").eq("team_id", team.id),
    supabase.from("owners").select("id, display_name").eq("league_id", membership.league_id),
  ]);
  const seasonIds = (seasonsResult.data ?? []).map((season) => season.id);

  const [resultsResult, awardsResult, balancesResult] = seasonIds.length ? await Promise.all([
    supabase.from("accepted_weekly_results").select("matchup_id, season_id, season_team_id, opponent_season_team_id, score, result").in("season_id", seasonIds),
    supabase.from("accepted_weekly_awards").select("season_id, high_score_season_team_id, low_score_season_team_id").in("season_id", seasonIds),
    supabase.from("team_financial_balances").select("season_id, season_team_id, balance_cents").in("season_id", seasonIds),
  ]) : [{ data: [] }, { data: [] }, { data: [] }];

  const history = buildTeamSeasonHistory(
    team.id,
    seasonsResult.data ?? [],
    entriesResult.data ?? [],
    (resultsResult.data ?? []).map((result) => ({ ...result, score: Number(result.score) })) as HistoricalResult[],
    (awardsResult.data ?? []) as HistoricalAward[],
    (balancesResult.data ?? []).map((balance) => ({ ...balance, balance_cents: Number(balance.balance_cents) })) as HistoricalBalance[],
  );
  const ownership = buildOwnershipHistory(ownershipResult.data ?? [], ownersResult.data ?? []);
  const currentOwner = ownership.find((item) => item.ended_on === null && item.is_primary);

  return (
    <main className="paper-noise min-h-[100svh] px-4 py-5 sm:px-8 sm:py-7 lg:px-12">
      <div className="mx-auto max-w-7xl">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <div className="flex min-w-0 items-center gap-3 sm:gap-4"><BrandLogo alt="" className="h-14 w-14 shrink-0 object-contain sm:h-16 sm:w-16" priority sizes="64px" /><div className="min-w-0"><p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine">Durable franchise record</p><p className="mt-1 truncate font-display text-xl sm:text-2xl">{league?.name ?? "Sweet Looking Napa Dads"}</p></div></div>
          <Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine" href="/dashboard/teams">All teams</Link>
        </header>

        <section className="py-8 sm:py-11">
          <div className="grid gap-6 border-b border-forest/20 pb-8 lg:grid-cols-[1fr_auto] lg:items-end"><div className="max-w-4xl"><p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">Franchise · {team.is_active ? "Active" : "Inactive"}</p><h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">{team.name}</h1><p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">One durable franchise across changing season names, ownership eras, accepted competition records, weekly honors, and canonical financial balances.</p></div><div className="border-l-2 border-wine pl-4"><p className="font-mono text-[8px] font-bold uppercase tracking-[0.14em] text-ink-muted">Current primary owner</p><p className="mt-2 font-display text-2xl">{currentOwner?.owner_name ?? "Not linked"}</p><p className="mt-1 text-sm text-ink-muted">Franchise key: {team.slug}</p></div></div>

          <section aria-labelledby="ownership-heading" className="mt-8"><div><p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">Stewardship</p><h2 className="mt-2 font-display text-4xl sm:text-5xl" id="ownership-heading">Ownership history</h2></div>{ownership.length ? <ol className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">{ownership.map((item) => <li className="border border-forest/20 bg-surface/75 p-5" key={item.id}><div className="flex items-center justify-between gap-3"><p className="font-display text-2xl">{item.owner_name}</p>{item.is_primary ? <span className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-wine">Primary</span> : null}</div><p className="mt-4 font-mono text-[9px] uppercase tracking-[0.12em] text-ink-muted"><time dateTime={item.started_on}>{formatDate(item.started_on)}</time> — {item.ended_on ? <time dateTime={item.ended_on}>{formatDate(item.ended_on)}</time> : "Present"}</p></li>)}</ol> : <div className="mt-5 border border-dashed border-forest/30 px-5 py-8"><p className="font-display text-2xl">No ownership history is linked yet.</p></div>}</section>

          <section aria-labelledby="season-history-heading" className="mt-10 border-t border-forest/20 pt-8"><div className="flex flex-wrap items-end justify-between gap-3"><div><p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">Accepted record</p><h2 className="mt-2 font-display text-4xl sm:text-5xl" id="season-history-heading">Season history</h2></div><p className="max-w-lg text-sm leading-6 text-ink-muted">Records and points below summarize accepted reciprocal results. They are not ESPN’s official standings rank.</p></div>{history.length ? <div className="mt-6 grid gap-5">{history.map((season) => {
            const balanceLabel = season.balance_cents > 0 ? "Owes league" : season.balance_cents < 0 ? "League owes team" : "Settled";
            return <article className="border border-forest/20 bg-surface/70 p-5 sm:p-6" key={season.season_team_id}><div className="flex flex-wrap items-start justify-between gap-4 border-b border-forest/15 pb-5"><div><p className="font-mono text-[9px] font-bold uppercase tracking-[0.15em] text-wine">{season.year} · {season.season_status}</p><h3 className="mt-2 font-display text-3xl sm:text-4xl">{season.team_name}</h3>{season.abbreviation ? <p className="mt-1 font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted">{season.abbreviation}</p> : null}</div><div className="text-right"><p className="font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted">Season balance</p><p className={`mt-2 font-display text-3xl ${season.balance_cents > 0 ? "text-wine" : season.balance_cents < 0 ? "text-forest" : ""}`}>{formatCurrency(season.balance_cents)}</p><p className="mt-1 text-xs text-ink-muted">{balanceLabel}</p></div></div><dl className="mt-5 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-6"><div><dt className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">Record</dt><dd className="mt-1 font-display text-2xl">{season.games ? `${season.wins}-${season.losses}${season.ties ? `-${season.ties}` : ""}` : "—"}</dd></div><div><dt className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">Games</dt><dd className="mt-1 font-display text-2xl">{season.games}</dd></div><div><dt className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">Points for</dt><dd className="mt-1 font-display text-2xl">{formatCompetitionScore(season.points_for)}</dd></div><div><dt className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">Points against</dt><dd className="mt-1 font-display text-2xl">{formatCompetitionScore(season.points_against)}</dd></div><div><dt className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">High honors</dt><dd className="mt-1 font-display text-2xl">{season.high_score_honors}</dd></div><div><dt className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">Low penalties</dt><dd className="mt-1 font-display text-2xl">{season.low_score_penalties}</dd></div></dl><div className="mt-6 flex flex-wrap gap-2"><Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] hover:border-wine hover:text-wine" href={{ pathname: "/dashboard/results", query: { season: season.season_id } }}>Season results</Link><Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] hover:border-wine hover:text-wine" href={{ pathname: "/dashboard/finances", query: { season: season.season_id, team: season.season_team_id } }}>Financial detail</Link></div></article>;
          })}</div> : <div className="mt-5 border border-dashed border-forest/30 px-5 py-8"><p className="font-display text-2xl">No season entries exist for this franchise.</p></div>}</section>
        </section>
      </div>
    </main>
  );
}
