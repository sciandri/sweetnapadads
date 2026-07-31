import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import { createClient } from "@/lib/supabase/server";

import { SeasonRulesEditor } from "./season-rules-editor";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Season financial rules" };

type PageProps = { searchParams: Promise<{ season?: string | string[] }> };

export default async function SeasonRulesPage({ searchParams }: PageProps) {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/login?next=/dashboard/admin/season-rules");

  const { data: membership } = await supabase
    .from("league_memberships")
    .select("league_id, role")
    .eq("user_id", userId)
    .eq("status", "active")
    .eq("role", "commissioner")
    .limit(1)
    .maybeSingle();
  if (membership?.role !== "commissioner") redirect("/access-denied");

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
  const requested = Array.isArray(params.season) ? params.season[0] : params.season;
  const season = seasons.find((item) => item.id === requested) ?? seasons[0];
  const { data: rules } = await supabase
    .from("season_financial_rules")
    .select(
      "rule_key, rule_kind, label, direction, amount_cents, recipient_rank",
    )
    .eq("season_id", season.id)
    .eq("enabled", true)
    .order("rule_kind")
    .order("recipient_rank");

  return (
    <main className="paper-noise min-h-[100svh] px-4 py-5 sm:px-8 sm:py-7 lg:px-12">
      <div className="mx-auto max-w-7xl">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <div className="flex min-w-0 items-center gap-3 sm:gap-4">
            <BrandLogo alt="" className="h-14 w-14 shrink-0 object-contain sm:h-16 sm:w-16" priority sizes="64px" />
            <div className="min-w-0">
              <p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine">Commissioner tools</p>
              <p className="mt-1 truncate font-display text-xl sm:text-2xl">{league?.name}</p>
            </div>
          </div>
          <Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine" href="/dashboard">
            Dashboard
          </Link>
        </header>

        <section className="py-8 sm:py-11">
          <div className="grid gap-6 border-b border-forest/20 pb-7 lg:grid-cols-[1fr_auto] lg:items-end">
            <div className="max-w-3xl">
              <p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">Season configuration · Audited</p>
              <h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">Payouts & penalties</h1>
              <p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">
                Configure every monetary league rule in integer cents. Saving replaces the enabled season schedule and records one immutable commissioner snapshot.
              </p>
            </div>
            <form className="grid gap-2" method="get">
              <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">
                Season
                <select className="min-h-12 min-w-56 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground" defaultValue={season.id} name="season">
                  {seasons.map((item) => <option key={item.id} value={item.id}>{item.name} · {item.status}</option>)}
                </select>
              </label>
              <button className="min-h-11 border border-forest/25 px-4 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] hover:border-wine hover:text-wine" type="submit">Load season</button>
            </form>
          </div>

          <SeasonRulesEditor
            key={season.id}
            seasonId={season.id}
            initialRules={(rules ?? []).map((rule) => ({
              ...rule,
              amount_cents: Number(rule.amount_cents),
            }))}
          />
        </section>
      </div>
    </main>
  );
}
