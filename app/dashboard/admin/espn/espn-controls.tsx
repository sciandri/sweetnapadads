"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";

type TeamMapping = {
  id: string;
  name: string;
  abbreviation: string | null;
  espnTeamId: number | null;
};

type SyncRun = {
  id: string;
  status: string;
  scoringPeriod: number | null;
  startedAt: string;
  finishedAt: string | null;
};

type EspnControlsProps = {
  seasonId: string;
  teams: TeamMapping[];
  recentRuns: SyncRun[];
};

type ActionState = {
  kind: "idle" | "working" | "success" | "error";
  message: string;
};

const initialAction: ActionState = { kind: "idle", message: "" };

const errorMessages: Record<string, string> = {
  forbidden: "Your commissioner access could not be verified.",
  ingestion_failed: "The standings could not be saved. Try again or inspect the latest run.",
  integration_not_configured: "Server-only ESPN synchronization credentials are not configured yet.",
  invalid_request: "The submitted data is incomplete or invalid.",
  mapping_rejected: "Every active team needs one unique positive ESPN team ID.",
  season_not_found: "That season is no longer available.",
  standings_unavailable: "ESPN has not published an official standings order yet.",
  team_mapping_incomplete: "Save one unique ESPN ID for every active team before syncing.",
  unauthorized: "Your session expired. Sign in again and retry.",
  upstream_failed: "ESPN could not be reached safely. Existing standings remain unchanged.",
};

function messageFor(error: unknown) {
  return typeof error === "string" && errorMessages[error]
    ? errorMessages[error]
    : "The request could not be completed. Existing data remains unchanged.";
}

export function EspnControls({ seasonId, teams, recentRuns }: EspnControlsProps) {
  const router = useRouter();
  const [values, setValues] = useState<Record<string, string>>(() =>
    Object.fromEntries(
      teams.map((team) => [team.id, team.espnTeamId?.toString() ?? ""]),
    ),
  );
  const [saveState, setSaveState] = useState(initialAction);
  const [syncState, setSyncState] = useState(initialAction);

  const parsedMappings = useMemo(
    () =>
      teams.map((team) => ({
        season_team_id: team.id,
        espn_team_id: Number(values[team.id]),
      })),
    [teams, values],
  );
  const uniqueIds = new Set(parsedMappings.map((mapping) => mapping.espn_team_id));
  const mappingsValid =
    parsedMappings.length > 0 &&
    parsedMappings.every(
      (mapping) =>
        Number.isInteger(mapping.espn_team_id) && mapping.espn_team_id > 0,
    ) &&
    uniqueIds.size === parsedMappings.length;
  const busy = saveState.kind === "working" || syncState.kind === "working";

  async function saveMappings() {
    if (!mappingsValid || busy) return;
    setSaveState({ kind: "working", message: "Saving every mapping…" });
    try {
      const response = await fetch("/api/admin/espn-mappings", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ season_id: seasonId, mappings: parsedMappings }),
      });
      const result = (await response.json()) as {
        error?: string;
        mapped_count?: number;
      };
      if (!response.ok) {
        setSaveState({ kind: "error", message: messageFor(result.error) });
        return;
      }
      setSaveState({
        kind: "success",
        message: `${result.mapped_count ?? parsedMappings.length} team mappings saved and audited.`,
      });
      router.refresh();
    } catch {
      setSaveState({
        kind: "error",
        message: "The mapping request could not reach the server.",
      });
    }
  }

  async function synchronize() {
    if (!mappingsValid || busy) return;
    setSyncState({ kind: "working", message: "Fetching official ESPN order…" });
    try {
      const response = await fetch("/api/sync/espn", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ season_id: seasonId }),
      });
      const result = (await response.json()) as {
        error?: string;
        status?: string;
        team_count?: number;
        matchup_count?: number;
        award_week_count?: number;
        pending_tie_weeks?: number[];
      };
      if (!response.ok) {
        setSyncState({ kind: "error", message: messageFor(result.error) });
        return;
      }
      setSyncState({
        kind: "success",
        message: [
          `${result.team_count ?? teams.length} teams`,
          `${result.matchup_count ?? 0} completed matchups`,
          `${result.award_week_count ?? 0} award weeks`,
          result.pending_tie_weeks?.length
            ? `tie review needed for week${result.pending_tie_weeks.length === 1 ? "" : "s"} ${result.pending_tie_weeks.join(", ")}`
            : null,
          result.status ?? "recorded",
        ]
          .filter(Boolean)
          .join(" · "),
      });
      router.refresh();
    } catch {
      setSyncState({
        kind: "error",
        message: "The synchronization request could not reach the server.",
      });
    }
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[minmax(0,1.15fr)_minmax(18rem,0.85fr)]">
      <section className="border border-forest/20 bg-surface/85 p-4 shadow-[5px_5px_0_rgb(23_63_50_/_0.08)] sm:p-7">
        <div className="flex flex-wrap items-end justify-between gap-4 border-b border-forest/15 pb-5">
          <div>
            <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">
              Required before sync
            </p>
            <h2 className="mt-2 font-display text-3xl tracking-[-0.025em]">
              Team mappings
            </h2>
          </div>
          <span className="font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-ink-muted">
            {teams.length} active teams
          </span>
        </div>

        {teams.length ? (
          <div className="mt-5 grid gap-3">
            {teams.map((team) => (
              <label
                className="grid gap-3 border border-forest/20 bg-background p-4 sm:grid-cols-[minmax(0,1fr)_9rem] sm:items-center"
                key={team.id}
              >
                <span className="min-w-0">
                  <span className="block truncate font-semibold">{team.name}</span>
                  <span className="mt-1 block font-mono text-[9px] uppercase tracking-[0.13em] text-ink-muted">
                    {team.abbreviation ?? "No abbreviation"}
                  </span>
                </span>
                <span className="grid gap-1.5 font-mono text-[9px] font-bold uppercase tracking-[0.12em] text-ink-muted">
                  ESPN team ID
                  <input
                    className="min-h-12 w-full border border-forest/25 bg-surface px-3 font-sans text-base font-semibold normal-case tracking-normal text-foreground outline-none focus:border-wine"
                    inputMode="numeric"
                    min="1"
                    onChange={(event) =>
                      setValues((current) => ({
                        ...current,
                        [team.id]: event.target.value,
                      }))
                    }
                    pattern="[0-9]*"
                    required
                    type="number"
                    value={values[team.id] ?? ""}
                  />
                </span>
              </label>
            ))}
          </div>
        ) : (
          <p className="mt-5 border border-gold/50 bg-gold/10 p-4 text-sm leading-6">
            This season has no active teams. Add season teams before mapping ESPN.
          </p>
        )}

        {!mappingsValid && teams.length ? (
          <p className="mt-4 text-sm leading-6 text-wine">
            Every team needs one unique positive ESPN team ID.
          </p>
        ) : null}

        <button
          className="mt-5 min-h-12 w-full border border-wine bg-wine px-5 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.18em] text-white transition disabled:cursor-not-allowed disabled:opacity-40"
          disabled={!mappingsValid || busy}
          onClick={saveMappings}
          type="button"
        >
          {saveState.kind === "working" ? "Saving all mappings…" : "Save all mappings"}
        </button>
        <ActionMessage state={saveState} />
      </section>

      <div className="grid content-start gap-6">
        <section className="border border-forest/20 bg-forest p-5 text-background sm:p-6">
          <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-gold">
            Official order
          </p>
          <h2 className="mt-2 font-display text-3xl">Run standings sync</h2>
          <p className="mt-4 text-sm leading-6 text-background/75">
            ESPN determines the order. Existing standings remain current unless a
            complete new snapshot passes every validation and commits atomically.
          </p>
          <button
            className="mt-5 min-h-12 w-full border border-gold bg-gold px-5 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.18em] text-forest transition disabled:cursor-not-allowed disabled:opacity-40"
            disabled={!mappingsValid || busy}
            onClick={synchronize}
            type="button"
          >
            {syncState.kind === "working" ? "Synchronizing…" : "Synchronize standings"}
          </button>
          <ActionMessage inverted state={syncState} />
          <p className="mt-4 border-t border-background/20 pt-4 font-mono text-[9px] uppercase leading-5 tracking-[0.12em] text-background/60">
            Production remains disabled until server-only ESPN credentials are configured.
          </p>
        </section>

        <section className="border border-forest/20 bg-surface/85 p-5 sm:p-6">
          <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">
            Recent evidence
          </p>
          <h2 className="mt-2 font-display text-3xl">Sync runs</h2>
          {recentRuns.length ? (
            <ol className="mt-5 grid gap-3">
              {recentRuns.map((run) => (
                <li className="border border-forest/15 bg-background p-4" key={run.id}>
                  <div className="flex items-center justify-between gap-3">
                    <span className="font-mono text-[9px] font-bold uppercase tracking-[0.13em] text-wine">
                      {run.status}
                    </span>
                    <span className="font-mono text-[9px] text-ink-muted">
                      {run.scoringPeriod ? `Period ${run.scoringPeriod}` : "Preseason"}
                    </span>
                  </div>
                  <p className="mt-2 text-sm text-ink-muted">
                    {formatTimestamp(run.finishedAt ?? run.startedAt)}
                  </p>
                </li>
              ))}
            </ol>
          ) : (
            <p className="mt-5 text-sm leading-6 text-ink-muted">
              No standings synchronization has been recorded for this season.
            </p>
          )}
        </section>
      </div>
    </div>
  );
}

function ActionMessage({
  inverted = false,
  state,
}: {
  inverted?: boolean;
  state: ActionState;
}) {
  if (state.kind === "idle") return null;
  return (
    <p
      aria-live="polite"
      className={`mt-3 text-sm leading-6 ${
        inverted
          ? state.kind === "error"
            ? "text-gold"
            : "text-background/80"
          : state.kind === "error"
            ? "text-wine"
            : "text-forest"
      }`}
    >
      {state.message}
    </p>
  );
}

function formatTimestamp(value: string) {
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}
