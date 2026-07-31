import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import { createClient } from "@/lib/supabase/server";

import { EspnControls } from "./espn-controls";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "ESPN controls",
};

type EspnAdminPageProps = {
  searchParams: Promise<{ season?: string | string[] }>;
};

export default async function EspnAdminPage({ searchParams }: EspnAdminPageProps) {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/login?next=/dashboard/admin/espn");

  const { data: membership, error: membershipError } = await supabase
    .from("league_memberships")
    .select("league_id, role")
    .eq("user_id", userId)
    .eq("status", "active")
    .eq("role", "commissioner")
    .limit(1)
    .maybeSingle();
  if (membershipError || membership?.role !== "commissioner") {
    redirect("/access-denied");
  }

  const [{ data: league }, { data: seasons }] = await Promise.all([
    supabase.from("leagues").select("name").eq("id", membership.league_id).maybeSingle(),
    supabase
      .from("seasons")
      .select("id, year, name, status")
      .eq("league_id", membership.league_id)
      .order("year", { ascending: false }),
  ]);
  if (!seasons?.length) redirect("/dashboard");

  const params = await searchParams;
  const requestedSeason = Array.isArray(params.season)
    ? params.season[0]
    : params.season;
  const selectedSeason =
    seasons.find((season) => season.id === requestedSeason) ?? seasons[0];

  const [{ data: seasonTeams }, { data: runs }] = await Promise.all([
    supabase
      .from("season_teams")
      .select("id, name, abbreviation, espn_team_id")
      .eq("season_id", selectedSeason.id)
      .eq("status", "active")
      .order("name"),
    supabase
      .from("espn_sync_runs")
      .select("id, status, scoring_period, started_at, finished_at")
      .eq("season_id", selectedSeason.id)
      .eq("sync_kind", "standings")
      .order("started_at", { ascending: false })
      .limit(5),
  ]);

  return (
    <main className="paper-noise min-h-[100svh] px-4 py-5 sm:px-8 sm:py-7 lg:px-12">
      <div className="mx-auto max-w-7xl">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <div className="flex min-w-0 items-center gap-3 sm:gap-4">
            <BrandLogo
              alt=""
              className="h-14 w-14 shrink-0 object-contain sm:h-16 sm:w-16"
              priority
              sizes="64px"
            />
            <div className="min-w-0">
              <p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine sm:text-[9px]">
                Commissioner tools
              </p>
              <p className="mt-1 truncate font-display text-xl sm:text-2xl">
                {league?.name ?? "Sweet Looking Napa Dads"}
              </p>
            </div>
          </div>
          <Link
            className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine"
            href="/dashboard"
          >
            Dashboard
          </Link>
        </header>

        <section className="py-8 sm:py-11">
          <div className="grid gap-6 border-b border-forest/20 pb-7 lg:grid-cols-[1fr_auto] lg:items-end">
            <div className="max-w-3xl">
              <p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">
                ESPN · Server controlled
              </p>
              <h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">
                Standings control room
              </h1>
              <p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">
                Review every team mapping, save one audited batch, then import ESPN’s
                official order without recalculating it locally.
              </p>
            </div>

            <form className="grid gap-2" method="get">
              <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">
                Season
                <select
                  className="min-h-12 min-w-56 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground"
                  defaultValue={selectedSeason.id}
                  name="season"
                >
                  {seasons.map((season) => (
                    <option key={season.id} value={season.id}>
                      {season.name} · {season.status}
                    </option>
                  ))}
                </select>
              </label>
              <button
                className="min-h-11 border border-forest/25 px-4 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] hover:border-wine hover:text-wine"
                type="submit"
              >
                Load season
              </button>
            </form>
          </div>

          <div className="mt-7">
            <EspnControls
              key={selectedSeason.id}
              recentRuns={(runs ?? []).map((run) => ({
                id: run.id,
                status: run.status,
                scoringPeriod: run.scoring_period,
                startedAt: run.started_at,
                finishedAt: run.finished_at,
              }))}
              seasonId={selectedSeason.id}
              teams={(seasonTeams ?? []).map((team) => ({
                id: team.id,
                name: team.name,
                abbreviation: team.abbreviation,
                espnTeamId: team.espn_team_id,
              }))}
            />
          </div>
        </section>
      </div>
    </main>
  );
}
