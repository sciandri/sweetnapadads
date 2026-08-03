import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import { createClient } from "@/lib/supabase/server";

import { ManualResultsForm } from "./manual-results-form";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Manual results" };

type PageProps = { searchParams: Promise<{ season?: string | string[]; operation?: string | string[] }> };

export default async function ManualResultsPage({ searchParams }: PageProps) {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/login?next=/dashboard/admin/results");

  const { data: membership } = await supabase.from("league_memberships").select("league_id, role").eq("user_id", userId).eq("status", "active").eq("role", "commissioner").limit(1).maybeSingle();
  if (!membership) redirect("/access-denied");
  const [{ data: league }, { data: seasons }] = await Promise.all([
    supabase.from("leagues").select("name").eq("id", membership.league_id).maybeSingle(),
    supabase.from("seasons").select("id, name, status, year").eq("league_id", membership.league_id).order("year", { ascending: false }),
  ]);
  if (!seasons?.length) redirect("/dashboard");
  const params = await searchParams;
  const requested = Array.isArray(params.season) ? params.season[0] : params.season;
  const requestedOperation = Array.isArray(params.operation) ? params.operation[0] : params.operation;
  const operation = requestedOperation === "correction" ? "correction" : "missing";
  const season = seasons.find((item) => item.id === requested) ?? seasons.find((item) => item.status === "active") ?? seasons[0];
  const [{ data: teams }, { data: manualBatches }, { data: correctionBatches }] = await Promise.all([
    supabase.from("season_teams").select("id, name").eq("season_id", season.id).eq("status", "active").order("name"),
    supabase.from("manual_result_batches").select("id, week, phase, reason, created_at").eq("season_id", season.id).order("created_at", { ascending: false }).limit(10),
    supabase.from("result_correction_batches").select("id, week, phase, reason, created_at").eq("season_id", season.id).order("created_at", { ascending: false }).limit(10),
  ]);
  const batches = [
    ...(manualBatches ?? []).map((batch) => ({ ...batch, kind: "Missing week" })),
    ...(correctionBatches ?? []).map((batch) => ({ ...batch, kind: "Correction" })),
  ].sort((left, right) => String(right.created_at).localeCompare(String(left.created_at))).slice(0, 10);

  return <main className="paper-noise min-h-[100svh] px-4 py-5 sm:px-8 sm:py-7 lg:px-12"><div className="mx-auto max-w-7xl">
    <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5"><div className="flex min-w-0 items-center gap-3"><BrandLogo alt="" className="h-14 w-14 object-contain" priority sizes="56px" /><div><p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine">Commissioner control</p><p className="mt-1 font-display text-xl sm:text-2xl">{league?.name ?? "Sweet Looking Napa Dads"}</p></div></div><Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine" href="/dashboard">Standings</Link></header>
    <section className="py-8 sm:py-11"><div className="grid gap-6 border-b border-forest/20 pb-7 lg:grid-cols-[1fr_auto] lg:items-end"><div className="max-w-3xl"><p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">{season.name} · Audited result administration</p><h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">Result control</h1><p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">Fill a complete week ESPN did not supply, or append a correction to an accepted week. Source evidence remains immutable and financial effects are reconciled explicitly.</p></div><form className="grid gap-2" method="get"><input name="operation" type="hidden" value={operation} /><label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">Season<select className="min-h-12 min-w-56 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground" defaultValue={season.id} name="season">{seasons.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label><button className="min-h-11 border border-forest bg-forest px-4 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-background" type="submit">Load season</button></form></div>
      <nav aria-label="Result operation" className="mt-6 grid gap-3 sm:grid-cols-2"><Link className={`grid min-h-12 place-items-center border px-5 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.16em] ${operation === "missing" ? "border-wine bg-wine text-white" : "border-forest/25 hover:border-wine hover:text-wine"}`} href={`/dashboard/admin/results?season=${season.id}&operation=missing`}>Missing week</Link><Link className={`grid min-h-12 place-items-center border px-5 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.16em] ${operation === "correction" ? "border-wine bg-wine text-white" : "border-forest/25 hover:border-wine hover:text-wine"}`} href={`/dashboard/admin/results?season=${season.id}&operation=correction`}>Correct accepted week</Link></nav>
      <section aria-labelledby="entry-heading" className="mt-8"><p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">{operation === "correction" ? "Accepted-week correction" : "Complete-week fallback"}</p><h2 className="mt-2 font-display text-4xl sm:text-5xl" id="entry-heading">{teams?.length ?? 0} active teams</h2><p className="mt-3 max-w-3xl text-sm leading-6 text-ink-muted">{operation === "correction" ? "Enter the entire corrected week, not only the changed matchup. The latest accepted projection switches atomically, and displaced high/low obligations receive linked financial adjustments before replacements are created." : "Pair every active team exactly once. This mode accepts only a week with no existing matchup; use the correction mode for previously accepted results."}</p><div className="mt-6"><ManualResultsForm key={`${season.id}:${operation}`} operation={operation} seasonId={season.id} teams={teams ?? []} /></div></section>
      <section aria-labelledby="manual-history-heading" className="mt-12 border-t border-forest/20 pt-8"><p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">Audit trail</p><h2 className="mt-2 font-display text-4xl" id="manual-history-heading">Recent result actions</h2>{batches.length ? <ol className="mt-5 divide-y divide-forest/15 border-y border-forest/20">{batches.map((batch) => <li className="grid gap-2 py-4 sm:grid-cols-[6rem_8rem_8rem_minmax(0,1fr)]" key={batch.id}><p className="font-display text-2xl">Week {batch.week}</p><p className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-wine">{batch.kind}</p><p className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-ink-muted">{String(batch.phase).replace("_", " ")}</p><p className="text-sm leading-6 text-ink-muted">{batch.reason}</p></li>)}</ol> : <div className="mt-5 border border-dashed border-forest/30 p-6"><p className="font-display text-2xl">No manual result actions.</p><p className="mt-2 text-sm text-ink-muted">That is the preferred state while ESPN supplies accepted results.</p></div>}</section>
    </section>
  </div></main>;
}
