import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import { formatCurrency } from "@/lib/format/currency";
import {
  buildTeamBalanceRows,
  buildTeamLedger,
  summarizeTeamBalances,
  type AdjustmentEventRecord,
  type ObligationEventRecord,
  type ObligationReconciliationRecord,
  type PaymentEventRecord,
  type PaymentReconciliationRecord,
  type TeamFinancialBalanceRecord,
  type TeamLedgerEntry,
} from "@/lib/finance/view";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "League finances" };

type FinancePageProps = {
  searchParams: Promise<{
    season?: string | string[];
    team?: string | string[];
  }>;
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

function balanceStatus(status: "owes_league" | "league_owes_team" | "settled") {
  if (status === "owes_league") return "Owes league";
  if (status === "league_owes_team") return "League owes team";
  return "Settled";
}

function directionLabel(direction: TeamLedgerEntry["direction"]) {
  const labels: Record<TeamLedgerEntry["direction"], string> = {
    team_owes_league: "Team obligation",
    league_owes_team: "League obligation",
    from_team: "Paid by team",
    to_team: "Paid to team",
    increase_team_balance: "Balance increased",
    decrease_team_balance: "Balance decreased",
  };
  return labels[direction];
}

export default async function FinancePage({ searchParams }: FinancePageProps) {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/login?next=/dashboard/finances");

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
    balancesResult,
    cashResult,
    teamsResult,
    obligationsResult,
    obligationStateResult,
    paymentsResult,
    paymentStateResult,
    adjustmentsResult,
  ] = await Promise.all([
    supabase.from("team_financial_balances").select("season_team_id, team_obligations_cents, payments_from_team_cents, league_obligations_cents, payments_to_team_cents, balance_increases_cents, balance_decreases_cents, balance_cents").eq("season_id", season.id),
    supabase.from("season_cash_balances").select("team_cash_in_cents, team_cash_out_cents, external_cash_in_cents, external_cash_out_cents, cash_balance_cents").eq("season_id", season.id).maybeSingle(),
    supabase.from("season_teams").select("id, name, abbreviation").eq("season_id", season.id),
    supabase.from("financial_obligations").select("id, season_team_id, direction, amount_cents, category, description, occurred_on").eq("season_id", season.id),
    supabase.from("obligation_reconciliation").select("obligation_id, allocated_cents, outstanding_cents, reconciliation_status").eq("season_id", season.id),
    supabase.from("payments").select("id, season_team_id, direction, amount_cents, paid_on, method, note").eq("season_id", season.id),
    supabase.from("payment_reconciliation").select("payment_id, allocated_cents, unallocated_cents, reconciliation_status").eq("season_id", season.id),
    supabase.from("financial_adjustments").select("id, season_team_id, direction, amount_cents, reason, occurred_on").eq("season_id", season.id),
  ]);

  const balanceRows = buildTeamBalanceRows(
    (balancesResult.data ?? []).map((row) => ({
      ...row,
      team_obligations_cents: Number(row.team_obligations_cents),
      payments_from_team_cents: Number(row.payments_from_team_cents),
      league_obligations_cents: Number(row.league_obligations_cents),
      payments_to_team_cents: Number(row.payments_to_team_cents),
      balance_increases_cents: Number(row.balance_increases_cents),
      balance_decreases_cents: Number(row.balance_decreases_cents),
      balance_cents: Number(row.balance_cents),
    })) as TeamFinancialBalanceRecord[],
    teamsResult.data ?? [],
  );
  const summary = summarizeTeamBalances(balanceRows);
  const requestedTeam = first(params.team);
  const selectedTeam = balanceRows.find((row) => row.season_team_id === requestedTeam) ?? balanceRows[0];
  const cash = cashResult.data ? {
    team_cash_in_cents: Number(cashResult.data.team_cash_in_cents),
    team_cash_out_cents: Number(cashResult.data.team_cash_out_cents),
    external_cash_in_cents: Number(cashResult.data.external_cash_in_cents),
    external_cash_out_cents: Number(cashResult.data.external_cash_out_cents),
    cash_balance_cents: Number(cashResult.data.cash_balance_cents),
  } : null;
  const ledger = selectedTeam ? buildTeamLedger(
    selectedTeam.season_team_id,
    (obligationsResult.data ?? []).map((row) => ({ ...row, amount_cents: Number(row.amount_cents) })) as ObligationEventRecord[],
    (obligationStateResult.data ?? []).map((row) => ({ ...row, allocated_cents: Number(row.allocated_cents), outstanding_cents: Number(row.outstanding_cents) })) as ObligationReconciliationRecord[],
    (paymentsResult.data ?? []).map((row) => ({ ...row, amount_cents: Number(row.amount_cents) })) as PaymentEventRecord[],
    (paymentStateResult.data ?? []).map((row) => ({ ...row, allocated_cents: Number(row.allocated_cents), unallocated_cents: Number(row.unallocated_cents) })) as PaymentReconciliationRecord[],
    (adjustmentsResult.data ?? []).map((row) => ({ ...row, amount_cents: Number(row.amount_cents) })) as AdjustmentEventRecord[],
  ) : [];

  return (
    <main className="paper-noise min-h-[100svh] px-4 py-5 sm:px-8 sm:py-7 lg:px-12">
      <div className="mx-auto max-w-7xl">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <div className="flex min-w-0 items-center gap-3 sm:gap-4">
            <BrandLogo alt="" className="h-14 w-14 shrink-0 object-contain sm:h-16 sm:w-16" priority sizes="64px" />
            <div className="min-w-0">
              <p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine">Member ledger</p>
              <p className="mt-1 truncate font-display text-xl sm:text-2xl">{league?.name ?? "Sweet Looking Napa Dads"}</p>
            </div>
          </div>
          <Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine" href="/dashboard">Standings</Link>
        </header>

        <section className="py-8 sm:py-11">
          <div className="grid gap-6 border-b border-forest/20 pb-7 lg:grid-cols-[1fr_auto] lg:items-end">
            <div className="max-w-3xl">
              <p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">{season.name} · Immutable event ledger</p>
              <h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">League finances</h1>
              <p className="mt-5 max-w-2xl text-pretty text-base leading-7 text-ink-muted sm:text-lg">Every balance is read from the canonical PostgreSQL view and explained by its obligations, payments, and audited adjustments. Positive means a team owes the league; negative means the league owes the team.</p>
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

          <section aria-label="Season finance summary" className="mt-7 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <article className="border border-forest/20 bg-surface/80 p-5"><p className="font-mono text-[8px] font-bold uppercase tracking-[0.15em] text-ink-muted">Actual league cash</p><p className="mt-3 font-display text-4xl">{formatCurrency(cash?.cash_balance_cents ?? 0)}</p><p className="mt-2 text-xs leading-5 text-ink-muted">Payments and external cash only</p></article>
            <article className="border border-forest/20 bg-surface/80 p-5"><p className="font-mono text-[8px] font-bold uppercase tracking-[0.15em] text-ink-muted">Teams owe league</p><p className="mt-3 font-display text-4xl text-wine">{formatCurrency(summary.teams_owe_cents)}</p><p className="mt-2 text-xs leading-5 text-ink-muted">Sum of positive canonical balances</p></article>
            <article className="border border-forest/20 bg-surface/80 p-5"><p className="font-mono text-[8px] font-bold uppercase tracking-[0.15em] text-ink-muted">League owes teams</p><p className="mt-3 font-display text-4xl text-forest">{formatCurrency(summary.league_owes_cents)}</p><p className="mt-2 text-xs leading-5 text-ink-muted">Absolute value of negative balances</p></article>
            <article className="border border-forest/20 bg-surface/80 p-5"><p className="font-mono text-[8px] font-bold uppercase tracking-[0.15em] text-ink-muted">Settled teams</p><p className="mt-3 font-display text-4xl">{summary.settled_teams} / {balanceRows.length}</p><p className="mt-2 text-xs leading-5 text-ink-muted">Exactly zero in the balance view</p></article>
          </section>

          {balanceRows.length ? (
            <div className="mt-9 grid gap-10">
              <section aria-labelledby="team-balances-heading">
                <div className="flex flex-wrap items-end justify-between gap-3"><div><p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">Team perspective</p><h2 className="mt-2 font-display text-4xl sm:text-5xl" id="team-balances-heading">Team balances</h2></div><p className="max-w-md text-sm leading-6 text-ink-muted">Choose a team to inspect the exact components and source events behind its balance.</p></div>
                <div className="mt-5 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
                  {balanceRows.map((row) => {
                    const selected = row.season_team_id === selectedTeam?.season_team_id;
                    const href = {
                      pathname: "/dashboard/finances",
                      query: { season: season.id, team: row.season_team_id },
                    } as const;
                    return <Link aria-current={selected ? "page" : undefined} className={`grid min-h-36 grid-cols-[minmax(0,1fr)_auto] items-end gap-4 border p-5 transition ${selected ? "border-wine bg-wine/5" : "border-forest/20 bg-surface/70 hover:border-wine"}`} href={href} key={row.season_team_id}><div className="min-w-0"><p className="truncate font-display text-2xl">{row.team_name}</p>{row.abbreviation ? <p className="mt-1 font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted">{row.abbreviation}</p> : null}<p className={`mt-5 font-mono text-[8px] font-bold uppercase tracking-[0.14em] ${row.status === "owes_league" ? "text-wine" : row.status === "league_owes_team" ? "text-forest" : "text-ink-muted"}`}>{balanceStatus(row.status)}</p></div><data className="font-display text-3xl tabular-nums" value={row.balance_cents}>{formatCurrency(Math.abs(row.balance_cents))}</data></Link>;
                  })}
                </div>
              </section>

              {selectedTeam ? <section aria-labelledby="balance-detail-heading" className="border-t border-forest/20 pt-8">
                <div className="flex flex-wrap items-end justify-between gap-3"><div><p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">Balance explanation</p><h2 className="mt-2 font-display text-4xl sm:text-5xl" id="balance-detail-heading">{selectedTeam.team_name}</h2></div><div className="text-right"><p className="font-mono text-[8px] font-bold uppercase tracking-[0.14em] text-ink-muted">Canonical net balance</p><p className={`mt-2 font-display text-5xl ${selectedTeam.status === "owes_league" ? "text-wine" : selectedTeam.status === "league_owes_team" ? "text-forest" : ""}`}>{formatCurrency(selectedTeam.balance_cents)}</p><p className="mt-1 text-sm text-ink-muted">{balanceStatus(selectedTeam.status)}</p></div></div>
                <dl className="mt-6 grid gap-px border border-forest/20 bg-forest/20 sm:grid-cols-2 lg:grid-cols-3">
                  {[
                    ["Team obligations", selectedTeam.team_obligations_cents],
                    ["Payments from team", selectedTeam.payments_from_team_cents],
                    ["League obligations", selectedTeam.league_obligations_cents],
                    ["Payments to team", selectedTeam.payments_to_team_cents],
                    ["Balance increases", selectedTeam.balance_increases_cents],
                    ["Balance decreases", selectedTeam.balance_decreases_cents],
                  ].map(([label, amount]) => <div className="bg-background p-4" key={String(label)}><dt className="font-mono text-[8px] font-bold uppercase tracking-[0.13em] text-ink-muted">{label}</dt><dd className="mt-2 font-display text-2xl">{formatCurrency(Number(amount))}</dd></div>)}
                </dl>
              </section> : null}

              <section aria-labelledby="ledger-heading">
                <div><p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">Source events</p><h2 className="mt-2 font-display text-4xl sm:text-5xl" id="ledger-heading">Ledger activity</h2></div>
                {ledger.length ? <ol className="mt-5 divide-y divide-forest/15 border-y border-forest/20">{ledger.map((entry) => <li className="grid gap-4 py-5 sm:grid-cols-[8rem_minmax(0,1fr)_auto] sm:items-center" key={`${entry.kind}-${entry.id}`}><div><time className="font-mono text-[9px] font-bold uppercase tracking-[0.12em] text-ink-muted" dateTime={entry.occurred_on}>{formatDate(entry.occurred_on)}</time><p className="mt-1 font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-wine">{entry.kind}</p></div><div className="min-w-0"><p className="font-display text-2xl">{entry.title}</p><p className="mt-1 text-sm capitalize leading-6 text-ink-muted">{entry.detail}</p><div className="mt-2 flex flex-wrap gap-2 font-mono text-[8px] font-bold uppercase tracking-[0.11em] text-ink-muted"><span>{directionLabel(entry.direction)}</span>{entry.reconciliation_status ? <span>· {entry.reconciliation_status}</span> : null}{entry.remainder_cents !== null ? <span>· {formatCurrency(entry.remainder_cents)} remaining</span> : null}</div></div><data className="font-display text-3xl tabular-nums sm:text-right" value={entry.amount_cents}>{formatCurrency(entry.amount_cents)}</data></li>)}</ol> : <div className="mt-5 border border-dashed border-forest/30 px-5 py-8"><p className="font-display text-2xl">No financial events for this team.</p><p className="mt-2 text-sm leading-6 text-ink-muted">A zero balance with no source events is an honest empty ledger—not an inferred settlement.</p></div>}
              </section>
            </div>
          ) : <div className="mt-7 border border-dashed border-forest/30 px-5 py-12 text-center sm:px-10"><p className="font-display text-3xl">No season teams are available.</p><p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-ink-muted">Team balances will appear automatically from the canonical view after season teams are configured.</p></div>}
        </section>
      </div>
    </main>
  );
}
