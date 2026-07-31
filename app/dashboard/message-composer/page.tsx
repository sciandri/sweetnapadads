import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import type { CommissionerMessageContext } from "@/lib/messages/context";
import { createClient } from "@/lib/supabase/server";

import { MessageComposer } from "./message-composer";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Message composer",
};

type ComposerPageProps = {
  searchParams: Promise<{
    season?: string | string[];
    week?: string | string[];
  }>;
};

export default async function MessageComposerPage({
  searchParams,
}: ComposerPageProps) {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;

  if (!userId) {
    redirect("/login?next=/dashboard/message-composer");
  }

  const { data: membership, error: membershipError } = await supabase
    .from("league_memberships")
    .select("league_id, role")
    .eq("user_id", userId)
    .eq("status", "active")
    .eq("role", "commissioner")
    .limit(1)
    .maybeSingle();

  if (membershipError || !membership || membership.role !== "commissioner") {
    redirect("/access-denied");
  }

  const { data: league } = await supabase
    .from("leagues")
    .select("name")
    .eq("id", membership.league_id)
    .maybeSingle();

  const { data: seasons } = await supabase
    .from("seasons")
    .select("id, year, name")
    .eq("league_id", membership.league_id)
    .order("year", { ascending: false });

  if (!seasons?.length) {
    redirect("/dashboard");
  }

  const params = await searchParams;
  const requestedSeason = Array.isArray(params.season)
    ? params.season[0]
    : params.season;
  const selectedSeason =
    seasons.find((season) => season.id === requestedSeason) ?? seasons[0];
  const requestedWeek = Number(
    Array.isArray(params.week) ? params.week[0] : params.week,
  );
  const selectedWeek =
    Number.isInteger(requestedWeek) && requestedWeek >= 1 && requestedWeek <= 30
      ? requestedWeek
      : 1;

  const { data: contextData, error: contextError } = await supabase.rpc(
    "get_commissioner_message_context",
    {
      target_season_id: selectedSeason.id,
      target_week: selectedWeek,
    },
  );

  const context = contextError
    ? null
    : (contextData as CommissionerMessageContext | null);

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
              <p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine sm:text-[9px] sm:tracking-[0.18em]">
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
                AI-assisted · Human approved
              </p>
              <h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">
                Message composer
              </h1>
              <p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">
                Turn official ESPN standings, selected results, and your own
                notes into editable copy for the league’s standing group-text
                thread.
              </p>
            </div>

            <form className="grid gap-3 sm:grid-cols-[minmax(12rem,1fr)_7rem_auto]" method="get">
              <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">
                Season
                <select
                  className="min-h-11 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground"
                  defaultValue={selectedSeason.id}
                  name="season"
                >
                  {seasons.map((season) => (
                    <option key={season.id} value={season.id}>
                      {season.name}
                    </option>
                  ))}
                </select>
              </label>
              <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">
                Week
                <input
                  className="min-h-11 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground"
                  defaultValue={selectedWeek}
                  max={30}
                  min={1}
                  name="week"
                  type="number"
                />
              </label>
              <button
                className="min-h-11 self-end border border-forest bg-forest px-4 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-background"
                type="submit"
              >
                Load facts
              </button>
            </form>
          </div>

          <div className="mt-7">
            {context ? (
              <MessageComposer context={context} />
            ) : (
              <div className="border border-wine/30 bg-wine/5 p-6">
                <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">
                  Context unavailable
                </p>
                <p className="mt-3 max-w-xl leading-7 text-ink-muted">
                  The selected league facts could not be assembled. Try another
                  season or week, then inspect the database context error.
                </p>
              </div>
            )}
          </div>
        </section>
      </div>
    </main>
  );
}
