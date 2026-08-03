"use client";

import { useRef, useState } from "react";

type Team = { id: string; name: string };
type Pair = { homeId: string; awayId: string; homeScore: string; awayScore: string };

export function ManualResultsForm({
  seasonId,
  teams,
  operation = "missing",
}: {
  seasonId: string;
  teams: Team[];
  operation?: "missing" | "correction";
}) {
  const [week, setWeek] = useState("1");
  const [reason, setReason] = useState("");
  const [pairs, setPairs] = useState<Pair[]>(() => {
    const rows: Pair[] = [];
    for (let index = 0; index < teams.length; index += 2) {
      rows.push({
        homeId: teams[index]?.id ?? "",
        awayId: teams[index + 1]?.id ?? "",
        homeScore: "",
        awayScore: "",
      });
    }
    return rows;
  });
  const [state, setState] = useState<{ kind: "idle" | "saving" | "success" | "error"; message: string }>({ kind: "idle", message: "" });
  const retryKey = useRef<string | null>(null);

  function updatePair(index: number, field: keyof Pair, value: string) {
    retryKey.current = null;
    setPairs((current) => current.map((pair, pairIndex) => pairIndex === index ? { ...pair, [field]: value } : pair));
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState({ kind: "saving", message: operation === "correction" ? "Recording correction…" : "Recording complete week…" });
    retryKey.current ??= `${operation}:${seasonId}:${week}:${crypto.randomUUID()}`;
    try {
      const response = await fetch(
        operation === "correction"
          ? "/api/admin/results/corrections"
          : "/api/admin/results",
        {
        method: "POST",
        headers: { "content-type": "application/json", "idempotency-key": retryKey.current },
        body: JSON.stringify({
          season_id: seasonId,
          week: Number(week),
          reason,
          matchups: pairs.map((pair) => ({
            home_season_team_id: pair.homeId,
            away_season_team_id: pair.awayId,
            home_score: Number(pair.homeScore),
            away_score: Number(pair.awayScore),
          })),
        }),
        },
      );
      const result = await response.json() as { error?: string; pending_tie?: boolean; status?: string };
      if (!response.ok) {
        retryKey.current = null;
        const messages: Record<string, string> = {
          results_already_exist: "This week already has accepted results. Nothing was overwritten.",
          correction_missing_source: "A correction requires a complete accepted week. Use missing-week entry instead.",
          results_rejected: "The database rejected this batch. Confirm every active team appears exactly once and scores use at most two decimals.",
          forbidden: "Only an active commissioner can record results.",
        };
        setState({ kind: "error", message: messages[result.error ?? ""] ?? "The week could not be recorded." });
        return;
      }
      retryKey.current = null;
      setState({
        kind: "success",
        message: result.pending_tie
          ? "Week recorded. A tied high or low score requires commissioner review before awards are created."
          : result.status === "already_recorded"
            ? "This exact week was already recorded; no duplicates were created."
            : operation === "correction"
              ? "Correction recorded. Accepted results and financial effects were reconciled."
              : "Week recorded and configured weekly awards processed.",
      });
    } catch {
      setState({ kind: "error", message: "The network response was interrupted. Submit again to retry the same evidence safely." });
    }
  }

  if (teams.length < 2 || teams.length % 2 !== 0) {
    return <div className="border border-dashed border-wine/40 p-5 text-sm leading-6 text-ink-muted">Manual entry requires an even active-team count of at least two. Update season participation before recording a complete week.</div>;
  }

  return (
    <form className="grid gap-7" onSubmit={submit}>
      <div className="grid gap-4 sm:grid-cols-[8rem_minmax(0,1fr)]">
        <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">Week
          <input className="min-h-12 border border-forest/25 bg-surface px-3 font-sans text-base text-foreground" max={30} min={1} onChange={(event) => { retryKey.current = null; setWeek(event.target.value); }} required type="number" value={week} />
        </label>
        <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">Reason and source evidence
          <input className="min-h-12 border border-forest/25 bg-surface px-3 font-sans text-sm normal-case tracking-normal text-foreground" maxLength={500} minLength={10} onChange={(event) => { retryKey.current = null; setReason(event.target.value); }} placeholder={operation === "correction" ? "What was wrong and which evidence confirms the correction" : "Why ESPN cannot supply this completed week"} required value={reason} />
        </label>
      </div>

      <div className="grid gap-4">
        {pairs.map((pair, index) => (
          <fieldset className="grid gap-4 border border-forest/20 bg-surface/70 p-4 sm:grid-cols-[minmax(0,1fr)_7rem_auto_minmax(0,1fr)_7rem] sm:items-end" key={index}>
            <legend className="px-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-wine">Matchup {index + 1}</legend>
            <label className="grid gap-2 text-sm font-semibold">Team one<select className="min-h-12 min-w-0 border border-forest/25 bg-background px-3" onChange={(event) => updatePair(index, "homeId", event.target.value)} value={pair.homeId}>{teams.map((team) => <option key={team.id} value={team.id}>{team.name}</option>)}</select></label>
            <label className="grid gap-2 text-sm font-semibold">Score<input className="min-h-12 min-w-0 border border-forest/25 bg-background px-3 tabular-nums" min={0} onChange={(event) => updatePair(index, "homeScore", event.target.value)} required step="0.01" type="number" value={pair.homeScore} /></label>
            <span className="hidden pb-3 text-center font-display text-2xl text-ink-muted sm:block">vs.</span>
            <label className="grid gap-2 text-sm font-semibold">Team two<select className="min-h-12 min-w-0 border border-forest/25 bg-background px-3" onChange={(event) => updatePair(index, "awayId", event.target.value)} value={pair.awayId}>{teams.map((team) => <option key={team.id} value={team.id}>{team.name}</option>)}</select></label>
            <label className="grid gap-2 text-sm font-semibold">Score<input className="min-h-12 min-w-0 border border-forest/25 bg-background px-3 tabular-nums" min={0} onChange={(event) => updatePair(index, "awayScore", event.target.value)} required step="0.01" type="number" value={pair.awayScore} /></label>
          </fieldset>
        ))}
      </div>

      <div className="grid gap-3 border-t border-forest/20 pt-5 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center">
        <p aria-live="polite" className={`text-sm leading-6 ${state.kind === "error" ? "text-wine" : state.kind === "success" ? "text-forest" : "text-ink-muted"}`}>{state.message || (operation === "correction" ? "Submission appends a new accepted version and explicitly reconciles any displaced weekly obligations." : "Submission is atomic: either the complete week and its rule-backed awards are accepted, or nothing changes.")}</p>
        <button className="min-h-12 border border-wine bg-wine px-6 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.16em] text-white disabled:opacity-50" disabled={state.kind === "saving"} type="submit">{state.kind === "saving" ? "Recording…" : operation === "correction" ? "Record correction" : "Record complete week"}</button>
      </div>
    </form>
  );
}
