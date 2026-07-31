import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { signOut } from "@/app/auth/actions";
import { BrandLogo } from "@/components/brand-logo";
import {
  buildStandingRows,
  formatCaptureTime,
  formatPoints,
  type CurrentStandingRecord,
} from "@/lib/standings/view";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Dashboard",
};

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;

  if (!userId) {
    redirect("/login?next=/dashboard");
  }

  const { data: membership, error: membershipError } = await supabase
    .from("league_memberships")
    .select("league_id, role")
    .eq("user_id", userId)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();

  if (membershipError || !membership) {
    redirect("/access-denied");
  }

  const [{ data: league }, { data: seasons }] = await Promise.all([
    supabase
      .from("leagues")
      .select("name")
      .eq("id", membership.league_id)
      .maybeSingle(),
    supabase
      .from("seasons")
      .select("id, year, name, status")
      .eq("league_id", membership.league_id)
      .order("year", { ascending: false }),
  ]);

  const season =
    seasons?.find((candidate) => candidate.status === "active") ?? seasons?.[0];

  const [standingsResult, teamsResult] = season
    ? await Promise.all([
        supabase
          .from("current_espn_standings")
          .select(
            "season_team_id, official_rank, record_summary, wins, losses, ties, points_for, points_against, streak, captured_at, scoring_period",
          )
          .eq("season_id", season.id)
          .order("official_rank"),
        supabase
          .from("season_teams")
          .select("id, name, abbreviation")
          .eq("season_id", season.id)
          .eq("status", "active"),
      ])
    : [{ data: [] }, { data: [] }];

  const standingRows = buildStandingRows(
    (standingsResult.data ?? []) as CurrentStandingRecord[],
    teamsResult.data ?? [],
  );
  const capture = standingRows[0];

  return (
    <main className="paper-noise min-h-[100svh] px-5 py-6 sm:px-10 lg:px-16">
      <div className="mx-auto max-w-6xl">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <div className="flex min-w-0 items-center gap-3 sm:gap-4">
            <BrandLogo
              alt=""
              className="h-14 w-14 shrink-0 object-contain sm:h-16 sm:w-16"
              priority
              sizes="64px"
            />
            <div className="min-w-0">
              <p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine sm:text-[9px] sm:tracking-[0.18em]">
                Authenticated league access
              </p>
              <p className="mt-1 truncate font-display text-xl sm:text-2xl">
                {league?.name ?? "Sweet Looking Napa Dads"}
              </p>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            <Link
              className="grid min-h-11 place-items-center border border-wine bg-wine px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] text-white"
              href="/dashboard/results"
            >
              Results & awards
            </Link>
            <form action={signOut}>
              <button
                className="min-h-11 border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine"
                type="submit"
              >
                Sign out
              </button>
            </form>
          </div>
        </header>

        <section className="py-10 sm:py-14">
          <div className="flex flex-col gap-6 border-b border-forest/20 pb-8 md:flex-row md:items-end md:justify-between">
            <div className="max-w-3xl">
              <p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">
                {season?.name ?? "League season"} · Official ESPN order
              </p>
              <h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">
                League standings
              </h1>
              <p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">
                The latest accepted ESPN table, shown exactly in ESPN’s reported
                rank order. Scores and records are not recalculated here.
              </p>
            </div>

            <div className="border-l-2 border-wine pl-4 text-left md:max-w-64">
              <p className="font-mono text-[9px] font-bold uppercase tracking-[0.16em] text-ink-muted">
                Latest accepted capture
              </p>
              {capture ? (
                <>
                  <time
                    className="mt-2 block font-display text-xl"
                    dateTime={capture.captured_at}
                  >
                    {formatCaptureTime(capture.captured_at)}
                  </time>
                  <p className="mt-1 text-sm text-ink-muted">
                    {capture.scoring_period
                      ? `Scoring period ${capture.scoring_period}`
                      : "Season snapshot"}
                  </p>
                </>
              ) : (
                <p className="mt-2 text-sm leading-6 text-ink-muted">
                  No successful ESPN snapshot yet.
                </p>
              )}
            </div>
          </div>

          {standingRows.length ? (
            <div className="mt-7" aria-label="Official ESPN standings">
              <div className="hidden grid-cols-[3rem_minmax(12rem,1fr)_7rem_7rem_7rem_5rem] gap-3 border-b border-forest/25 px-3 pb-3 font-mono text-[9px] font-bold uppercase tracking-[0.15em] text-ink-muted md:grid">
                <span>Rank</span>
                <span>Team</span>
                <span>Record</span>
                <span>Points for</span>
                <span>Points against</span>
                <span>Streak</span>
              </div>
              <ol className="divide-y divide-forest/15">
                {standingRows.map((row) => (
                  <li
                    className="grid grid-cols-[3rem_minmax(0,1fr)] gap-x-3 gap-y-4 px-2 py-5 md:grid-cols-[3rem_minmax(12rem,1fr)_7rem_7rem_7rem_5rem] md:items-center md:px-3"
                    key={row.season_team_id}
                  >
                    <span className="font-display text-3xl text-wine">
                      {row.official_rank}
                    </span>
                    <div className="min-w-0">
                      <p className="truncate font-display text-2xl leading-none">
                        {row.team_name}
                      </p>
                      {row.abbreviation ? (
                        <p className="mt-1 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">
                          {row.abbreviation}
                        </p>
                      ) : null}
                    </div>
                    <dl className="col-span-2 grid grid-cols-2 gap-3 sm:grid-cols-4 md:contents">
                      <div>
                        <dt className="font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted md:hidden">
                          Record
                        </dt>
                        <dd className="mt-1 text-sm font-semibold md:mt-0">
                          {row.record_summary}
                        </dd>
                      </div>
                      <div>
                        <dt className="font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted md:hidden">
                          Points for
                        </dt>
                        <dd className="mt-1 text-sm md:mt-0">
                          {formatPoints(row.points_for)}
                        </dd>
                      </div>
                      <div>
                        <dt className="font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted md:hidden">
                          Points against
                        </dt>
                        <dd className="mt-1 text-sm md:mt-0">
                          {formatPoints(row.points_against)}
                        </dd>
                      </div>
                      <div>
                        <dt className="font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted md:hidden">
                          Streak
                        </dt>
                        <dd className="mt-1 text-sm md:mt-0">{row.streak ?? "—"}</dd>
                      </div>
                    </dl>
                  </li>
                ))}
              </ol>
            </div>
          ) : (
            <div className="mt-7 border border-dashed border-forest/30 px-5 py-12 text-center sm:px-10">
              <p className="font-display text-3xl">Standings are not available yet.</p>
              <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-ink-muted">
                The prior accepted table will appear here after the first successful
                ESPN synchronization for this season.
              </p>
              {membership.role === "commissioner" ? (
                <Link
                  className="mt-6 inline-grid min-h-11 place-items-center border border-wine bg-wine px-5 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.15em] text-white"
                  href="/dashboard/admin/espn"
                >
                  Open ESPN controls
                </Link>
              ) : null}
            </div>
          )}

          {membership.role === "commissioner" ? (
            <nav
              aria-label="Commissioner tools"
              className="mt-10 grid gap-3 border-t border-forest/20 pt-7 sm:max-w-3xl sm:grid-cols-3"
            >
              <Link
                className="grid min-h-12 place-items-center border border-wine bg-wine px-5 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.16em] text-white"
                href="/dashboard/admin/espn"
              >
                ESPN controls
              </Link>
              <Link
                className="grid min-h-12 place-items-center border border-forest/25 px-5 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine"
                href="/dashboard/message-composer"
              >
                Message composer
              </Link>
              <Link
                className="grid min-h-12 place-items-center border border-forest/25 px-5 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine"
                href="/dashboard/admin/season-rules"
              >
                Season rules
              </Link>
            </nav>
          ) : null}
        </section>
      </div>
    </main>
  );
}
