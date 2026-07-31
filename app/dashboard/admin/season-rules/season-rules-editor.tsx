"use client";

import { useState } from "react";

import type { FinancialRuleKind } from "@/lib/finance/rules";
import { formatCurrency } from "@/lib/format/currency";

type Rule = {
  rule_key: string;
  rule_kind: FinancialRuleKind;
  label: string;
  direction: "league_owes_team" | "team_owes_league";
  amount_cents: number;
  recipient_rank: number | null;
};

type EditableRule = Omit<Rule, "amount_cents"> & { dollars: string };
type Props = { seasonId: string; initialRules: Rule[] };

const labels: Record<FinancialRuleKind, string> = {
  weekly_high_score: "Weekly high score",
  weekly_low_score_penalty: "Weekly low score penalty",
  placement_payout: "Placement payout",
  season_award: "Season award",
  penalty: "Penalty",
};
const requiredKeys = new Set(["weekly_high_score", "weekly_low_score_penalty"]);

function dollars(cents: number) {
  return (cents / 100).toFixed(2);
}

function cents(value: string) {
  if (!/^\d+(?:\.\d{1,2})?$/.test(value)) return null;
  const parsed = Math.round(Number(value) * 100);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function direction(kind: FinancialRuleKind) {
  return kind === "weekly_low_score_penalty" || kind === "penalty"
    ? "team_owes_league"
    : "league_owes_team";
}

export function SeasonRulesEditor({ seasonId, initialRules }: Props) {
  const [rules, setRules] = useState<EditableRule[]>(() =>
    initialRules.map((rule) => ({ ...rule, dollars: dollars(rule.amount_cents) })),
  );
  const [state, setState] = useState({ kind: "idle", message: "" });

  function add(kind: "placement_payout" | "season_award" | "penalty") {
    const sequence = rules.filter((rule) => rule.rule_kind === kind).length + 1;
    setRules((current) => [
      ...current,
      {
        rule_key: `new_${kind}_${sequence}`,
        rule_kind: kind,
        label: labels[kind],
        direction: direction(kind),
        dollars: "0.00",
        recipient_rank: kind === "placement_payout" ? sequence : null,
      },
    ]);
  }

  function update(index: number, values: Partial<EditableRule>) {
    setRules((current) => current.map((rule, item) => item === index ? { ...rule, ...values } : rule));
  }

  const parsed = rules.map((rule) => ({
    rule_key: rule.rule_key,
    rule_kind: rule.rule_kind,
    label: rule.label,
    direction: rule.direction,
    amount_cents: cents(rule.dollars),
    recipient_rank: rule.recipient_rank,
  }));
  const placementRanks = parsed.filter((rule) => rule.rule_kind === "placement_payout").map((rule) => rule.recipient_rank);
  const valid = parsed.length >= 2 && parsed.every((rule) =>
    /^[a-z][a-z0-9_]{0,49}$/.test(rule.rule_key) &&
    rule.label.trim() === rule.label && rule.label.length > 0 &&
    rule.amount_cents !== null &&
    (rule.rule_kind !== "placement_payout" || (rule.recipient_rank ?? 0) > 0)
  ) && new Set(parsed.map((rule) => rule.rule_key)).size === parsed.length &&
    new Set(placementRanks).size === placementRanks.length;

  async function save() {
    if (!valid || state.kind === "working") return;
    setState({ kind: "working", message: "Saving audited season rules…" });
    try {
      const response = await fetch("/api/admin/financial-rules", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ season_id: seasonId, rules: parsed }),
      });
      const result = await response.json() as { error?: string; rule_count?: number };
      if (!response.ok) {
        setState({ kind: "error", message: result.error === "rules_rejected" ? "The season rules conflict or failed database validation." : "The rule schedule could not be saved." });
        return;
      }
      setState({ kind: "success", message: `${result.rule_count ?? rules.length} configured rules saved with an immutable audit snapshot.` });
    } catch {
      setState({ kind: "error", message: "The configuration request could not reach the server." });
    }
  }

  return (
    <div className="mt-7 grid gap-7">
      <div className="grid gap-4">
        {rules.map((rule, index) => (
          <article className="grid gap-4 border border-forest/20 bg-surface/85 p-4 sm:grid-cols-2 sm:p-6 lg:grid-cols-[1fr_1fr_10rem_8rem_auto] lg:items-end" key={`${rule.rule_key}-${index}`}>
            <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.13em] text-ink-muted">Label
              <input className="min-h-12 border border-forest/25 bg-background px-3 font-sans text-base normal-case tracking-normal text-foreground" onChange={(event) => update(index, { label: event.target.value })} value={rule.label} />
            </label>
            <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.13em] text-ink-muted">Stable rule key
              <input className="min-h-12 border border-forest/25 bg-background px-3 font-mono text-sm normal-case tracking-normal text-foreground disabled:opacity-60" disabled={requiredKeys.has(rule.rule_key)} onChange={(event) => update(index, { rule_key: event.target.value })} value={rule.rule_key} />
            </label>
            <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.13em] text-ink-muted">Amount (USD)
              <input className="min-h-12 border border-forest/25 bg-background px-3 font-sans text-base normal-case tracking-normal text-foreground" inputMode="decimal" onChange={(event) => update(index, { dollars: event.target.value })} value={rule.dollars} />
            </label>
            {rule.rule_kind === "placement_payout" ? (
              <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.13em] text-ink-muted">Place
                <input className="min-h-12 border border-forest/25 bg-background px-3 font-sans text-base normal-case tracking-normal text-foreground" min="1" onChange={(event) => update(index, { recipient_rank: Number(event.target.value) })} type="number" value={rule.recipient_rank ?? ""} />
              </label>
            ) : <p className="pb-3 font-mono text-[9px] uppercase tracking-[0.12em] text-ink-muted">{labels[rule.rule_kind]}<br />{rule.direction === "league_owes_team" ? "Payout" : "Penalty"}</p>}
            <button className="min-h-11 border border-forest/25 px-3 font-mono text-[9px] font-bold uppercase tracking-[0.12em] disabled:cursor-not-allowed disabled:opacity-30" disabled={requiredKeys.has(rule.rule_key)} onClick={() => setRules((current) => current.filter((_, item) => item !== index))} type="button">Remove</button>
          </article>
        ))}
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        {(["placement_payout", "season_award", "penalty"] as const).map((kind) => (
          <button className="min-h-12 border border-forest/25 px-4 font-mono text-[9px] font-bold uppercase tracking-[0.14em] hover:border-wine hover:text-wine" key={kind} onClick={() => add(kind)} type="button">Add {labels[kind]}</button>
        ))}
      </div>

      <div className="border-t border-forest/20 pt-6">
        <p className="text-sm leading-6 text-ink-muted">Configured rule amounts sum to {formatCurrency(parsed.reduce((total, rule) => total + (rule.amount_cents ?? 0), 0))} before weekly cadence is applied. This is configuration—not money movement. Obligations are created separately when their conditions are satisfied.</p>
        {!valid ? <p className="mt-3 text-sm text-wine">Every rule needs a unique key, positive amount, label, and—when applicable—unique placement rank.</p> : null}
        <button className="mt-5 min-h-12 border border-wine bg-wine px-6 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.18em] text-white disabled:cursor-not-allowed disabled:opacity-40" disabled={!valid || state.kind === "working"} onClick={save} type="button">Save complete schedule</button>
        {state.message ? <p className={`mt-3 text-sm ${state.kind === "error" ? "text-wine" : "text-forest"}`}>{state.message}</p> : null}
      </div>
    </div>
  );
}
