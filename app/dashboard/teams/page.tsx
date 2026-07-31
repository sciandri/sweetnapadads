import type { Metadata, Route } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Teams & history" };

type TeamsPageProps = {
  searchParams: Promise<{ season?: string | string[] }>;
};

export default async function TeamsPage({ searchParams }: TeamsPageProps) {
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

  const [{ data: league }, { data: seasons }] = await Promise.all([
    supabase.from("leagues").select("name").eq("id", membership.league_id).maybeSingle(),
    supabase.from("seasons").select("id, name, status, year").eq("league_id", membership.league_id).order("year", { ascending: false }),
  ]);
  if (!seasons?.length) redirect("/dashboard");

  const params = await searchParams;
  const requestedSeason = Array.isArray(params.season) ? params.season[0] : params.season;
  const season = seasons.find((item) => item.id === requestedSeason)
    ?? seasons.find((item) => item.status === "active")
    ?? seasons[0];

  const [entriesResult, ownersResult, ownershipResult] = await Promise.all([
    supabase.from("season_teams").select("id, team_id, name, abbreviation, status").eq("season_id", season.id).order("name"),
    supabase.from("owners").select("id, display_name").eq("league_id", membership.league_id),
    supabase.from("team_owners").select("team_id, owner_id, started_on, ended_on, is_primary").eq("league_id", membership.league_id).order("started_on", { ascending: false }),
  ]);
  const ownerNames = new Map((ownersResult.data ?? []).map((owner) => [owner.id, owner.display_name]));
  const currentOwnerByTeam = new Map<string, string>();
  for (const ownership of ownershipResult.data ?? []) {
    if (ownership.ended_on === null && ownership.is_primary && !currentOwnerByTeam.has(ownership.team_id)) {
      currentOwnerByTeam.set(ownership.team_id, ownerNames.get(ownership.owner_id) ?? "League owner");
    }
  }

  return (
    <main className="paper-noise min-h-[100svh] px-4 py-5 sm:px-8 sm:py-7 lg:px-12">
      <div className="mx-auto max-w-7xl">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <div className="flex min-w-0 items-center gap-3 sm:gap-4">
            <BrandLogo alt="" className="h-14 w-14 shrink-0 object-contain sm:h-16 sm:w-16" priority sizes="64px" />
            <div className="min-w-0"><p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine">League record book</p><p className="mt-1 truncate font-display text-xl sm:text-2xl">{league?.name ?? "Sweet Looking Napa Dads"}</p></div>
          </div>
          <Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine" href="/dashboard">Standings</Link>
        </header>

        <section className="py-8 sm:py-11">
          <div className="grid gap-6 border-b border-forest/20 pb-7 lg:grid-cols-[1fr_auto] lg:items-end">
            <div className="max-w-3xl"><p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">{season.name} · {season.status}</p><h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">Teams & history</h1><p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">Each season entry belongs to a durable franchise. Open a team to follow its names, owners, accepted results, weekly honors, and financial balances across seasons.</p></div>
            <form className="grid gap-2" method="get"><label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">Season<select className="min-h-12 min-w-56 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground" defaultValue={season.id} name="season">{seasons.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label><button className="min-h-11 border border-forest bg-forest px-4 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-background" type="submit">Load season</button></form>
          </div>

          {entriesResult.data?.length ? <section aria-labelledby="team-directory-heading" className="mt-8"><div className="flex flex-wrap items-end justify-between gap-3"><div><p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">Season directory</p><h2 className="mt-2 font-display text-4xl sm:text-5xl" id="team-directory-heading">{entriesResult.data.length} league teams</h2></div><p className="max-w-md text-sm leading-6 text-ink-muted">Team count comes from the selected season and supports ten, twelve, or any configured league size.</p></div><div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{entriesResult.data.map((entry, index) => {
            const href = `/dashboard/teams/${entry.team_id}` as Route;
            return <Link className="group grid min-h-56 border border-forest/20 bg-surface/75 p-5 hover:border-wine sm:p-6" href={href} key={entry.id}><div className="flex items-start justify-between gap-4"><span className="font-display text-4xl text-wine">{String(index + 1).padStart(2, "0")}</span><span className="font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted">{entry.status}</span></div><div className="mt-auto"><h3 className="font-display text-3xl leading-none group-hover:text-wine">{entry.name}</h3>{entry.abbreviation ? <p className="mt-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">{entry.abbreviation}</p> : null}<p className="mt-5 border-t border-forest/15 pt-3 text-sm text-ink-muted">Current primary owner<br /><span className="font-semibold text-foreground">{currentOwnerByTeam.get(entry.team_id) ?? "Not linked"}</span></p></div></Link>;
          })}</div></section> : <div className="mt-7 border border-dashed border-forest/30 px-5 py-12 text-center"><p className="font-display text-3xl">No teams are configured for this season.</p><p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-ink-muted">Season entries will appear here after commissioner setup.</p></div>}
        </section>
      </div>
    </main>
  );
}
