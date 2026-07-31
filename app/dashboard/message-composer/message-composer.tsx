"use client";

import { useState } from "react";

import type {
  CommissionerMessageContext,
  MessageLength,
  MessageTone,
} from "@/lib/messages/context";

type MessageComposerProps = {
  context: CommissionerMessageContext;
};

export function MessageComposer({ context }: MessageComposerProps) {
  const [includeStandings, setIncludeStandings] = useState(
    context.standings.available,
  );
  const [includeResults, setIncludeResults] = useState(
    context.results.length > 0,
  );
  const [includeAwards, setIncludeAwards] = useState(
    context.awards.length > 0,
  );
  const [tone, setTone] = useState<MessageTone>("friendly");
  const [length, setLength] = useState<MessageLength>("medium");
  const [notes, setNotes] = useState("");
  const [draft, setDraft] = useState("");
  const [copyStatus, setCopyStatus] = useState<
    "idle" | "copied" | "failed"
  >("idle");

  async function copyDraft() {
    if (!draft.trim()) return;
    try {
      await navigator.clipboard.writeText(draft.trim());
      setCopyStatus("copied");
    } catch {
      setCopyStatus("failed");
    }
    window.setTimeout(() => setCopyStatus("idle"), 1800);
  }

  const capturedAt = context.standings.captured_at
    ? new Intl.DateTimeFormat("en-US", {
        dateStyle: "medium",
        timeStyle: "short",
      }).format(new Date(context.standings.captured_at))
    : null;

  return (
    <div className="grid gap-6 lg:grid-cols-[minmax(0,1.08fr)_minmax(19rem,0.92fr)]">
      <section className="border border-forest/20 bg-surface/85 p-5 shadow-[5px_5px_0_rgb(23_63_50_/_0.08)] sm:p-7">
        <div className="flex flex-wrap items-start justify-between gap-4 border-b border-forest/15 pb-5">
          <div>
            <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">
              Draft ingredients
            </p>
            <h2 className="mt-2 font-display text-3xl tracking-[-0.025em]">
              Pick the facts
            </h2>
          </div>
          <span className="border border-gold/60 bg-gold/10 px-3 py-2 font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-forest">
            Week {context.selected_week}
          </span>
        </div>

        <fieldset className="mt-5 grid gap-3">
          <legend className="sr-only">League facts to include</legend>
          <FactToggle
            checked={includeStandings}
            disabled={!context.standings.available}
            label="Official ESPN standings"
            meta={
              context.standings.available
                ? `${context.standings.official_order.length} teams · ESPN order`
                : "No successful ESPN snapshot yet"
            }
            onChange={setIncludeStandings}
          />
          <FactToggle
            checked={includeResults}
            disabled={context.results.length === 0}
            label={`Week ${context.selected_week} results`}
            meta={
              context.results.length
                ? `${context.results.length} matchups`
                : "No normalized results for this week"
            }
            onChange={setIncludeResults}
          />
          <FactToggle
            checked={includeAwards}
            disabled={context.awards.length === 0}
            label={`Week ${context.selected_week} awards`}
            meta={
              context.awards.length
                ? `${context.awards.length} verified award set`
                : "No verified awards for this week"
            }
            onChange={setIncludeAwards}
          />
        </fieldset>

        <div className="mt-6 grid gap-5 sm:grid-cols-2">
          <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.16em] text-ink-muted">
            Tone
            <select
              className="min-h-12 border border-forest/25 bg-background px-3 font-sans text-sm normal-case tracking-normal text-foreground outline-none focus:border-wine"
              onChange={(event) => setTone(event.target.value as MessageTone)}
              value={tone}
            >
              <option value="concise">Concise</option>
              <option value="friendly">Friendly</option>
              <option value="energetic">Energetic</option>
            </select>
          </label>
          <label className="grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.16em] text-ink-muted">
            Length
            <select
              className="min-h-12 border border-forest/25 bg-background px-3 font-sans text-sm normal-case tracking-normal text-foreground outline-none focus:border-wine"
              onChange={(event) =>
                setLength(event.target.value as MessageLength)
              }
              value={length}
            >
              <option value="short">Short</option>
              <option value="medium">Medium</option>
              <option value="long">Long recap</option>
            </select>
          </label>
        </div>

        <label className="mt-5 grid gap-2 font-mono text-[9px] font-bold uppercase tracking-[0.16em] text-ink-muted">
          Commissioner notes
          <textarea
            className="min-h-36 resize-y border border-forest/25 bg-background p-4 font-sans text-base font-normal normal-case leading-6 tracking-normal text-foreground outline-none placeholder:text-ink-muted/60 focus:border-wine"
            maxLength={1200}
            onChange={(event) => setNotes(event.target.value)}
            placeholder="What should the league know? Add deadlines, jokes, reminders, or facts that are not in ESPN."
            value={notes}
          />
          <span className="text-right font-mono text-[9px] tracking-normal text-ink-muted">
            {notes.length}/1200
          </span>
        </label>

        <button
          className="mt-5 min-h-12 w-full cursor-not-allowed bg-forest px-5 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.18em] text-background opacity-55"
          disabled
          type="button"
        >
          Generate three options · OpenAI setup pending
        </button>
        <p className="mt-3 text-sm leading-6 text-ink-muted">
          The verified context and interface are ready. Generation turns on
          after the server-only OpenAI key is configured.
        </p>
      </section>

      <div className="grid content-start gap-6">
        <section className="border border-forest/20 bg-forest p-5 text-background sm:p-6">
          <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-gold">
            Fact check
          </p>
          <h2 className="mt-2 font-display text-3xl">What the AI sees</h2>
          <dl className="mt-5 grid gap-4 text-sm">
            <FactRow label="League" value={context.league.name} />
            <FactRow label="Season" value={context.season.name} />
            <FactRow
              label="Standings"
              value={
                includeStandings
                  ? `${context.standings.official_order.length} teams in ESPN order`
                  : "Excluded"
              }
            />
            <FactRow
              label="Results"
              value={
                includeResults
                  ? `${context.results.length} matchups from week ${context.selected_week}`
                  : "Excluded"
              }
            />
            <FactRow
              label="Awards"
              value={
                includeAwards
                  ? `${context.awards.length} award set`
                  : "Excluded"
              }
            />
            <FactRow label="Finances" value="Always excluded" />
          </dl>
          <div className="mt-5 border-t border-background/20 pt-4 font-mono text-[9px] uppercase tracking-[0.12em] text-background/65">
            {capturedAt
              ? `ESPN standings synced ${capturedAt}`
              : "No successful ESPN standings sync"}
          </div>

          {includeStandings ? (
            <div className="mt-5 border-t border-background/20 pt-4">
              <h3 className="font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-gold">
                ESPN official order
              </h3>
              <ol className="mt-3 grid gap-2">
                {context.standings.official_order.map((team) => (
                  <li
                    className="grid grid-cols-[1.5rem_minmax(0,1fr)_auto] items-baseline gap-2 text-sm"
                    key={team.team_key}
                  >
                    <span className="font-mono text-[10px] text-background/55">
                      {team.rank}
                    </span>
                    <span className="truncate">{team.team_name}</span>
                    <span className="font-mono text-[10px] text-background/70">
                      {team.record} · {team.points_for} PF
                    </span>
                  </li>
                ))}
              </ol>
            </div>
          ) : null}

          {includeResults && context.results.length ? (
            <div className="mt-5 border-t border-background/20 pt-4">
              <h3 className="font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-gold">
                Selected results
              </h3>
              <ul className="mt-3 grid gap-3 text-sm">
                {context.results.map((matchup) => (
                  <li className="leading-5" key={matchup.source_key}>
                    {matchup.teams.map((team, index) => (
                      <span key={team.team_key}>
                        {index ? " · " : ""}
                        {team.team_name} {team.score}
                      </span>
                    ))}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {includeAwards && context.awards.length ? (
            <div className="mt-5 border-t border-background/20 pt-4">
              <h3 className="font-mono text-[9px] font-bold uppercase tracking-[0.14em] text-gold">
                Selected awards
              </h3>
              <ul className="mt-3 grid gap-2 text-sm leading-5">
                {context.awards.map((award) => (
                  <li key={`${award.week}-${award.high_team_key}`}>
                    High: {award.high_team_name} {award.high_score} · Low:{" "}
                    {award.low_team_name} {award.low_score}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </section>

        <section className="border border-forest/20 bg-surface/85 p-5 sm:p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine">
                Editable copy
              </p>
              <h2 className="mt-2 font-display text-3xl">Final message</h2>
            </div>
            <span className="font-mono text-[9px] uppercase tracking-[0.14em] text-ink-muted">
              {draft.length} characters
            </span>
          </div>
          <textarea
            className="mt-5 min-h-56 w-full resize-y border border-forest/25 bg-background p-4 text-base leading-7 outline-none placeholder:text-ink-muted/55 focus:border-wine"
            onChange={(event) => setDraft(event.target.value)}
            placeholder="A generated option will appear here. You can also paste or write a draft manually."
            value={draft}
          />
          <button
            className="mt-3 min-h-12 w-full border border-wine bg-wine px-5 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.18em] text-white transition disabled:cursor-not-allowed disabled:opacity-40"
            disabled={!draft.trim()}
            onClick={copyDraft}
            type="button"
          >
            {copyStatus === "copied"
              ? "Copied to clipboard"
              : copyStatus === "failed"
                ? "Copy failed · select the text"
                : "Copy for the group thread"}
          </button>
          <p className="mt-3 text-sm leading-6 text-ink-muted">
            There is intentionally no send button. Review the facts, edit the
            language, then paste the message into the standing SMS thread.
          </p>
        </section>
      </div>
    </div>
  );
}

function FactToggle({
  checked,
  disabled,
  label,
  meta,
  onChange,
}: {
  checked: boolean;
  disabled: boolean;
  label: string;
  meta: string;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label className="flex min-h-16 items-center gap-4 border border-forest/20 bg-background px-4 py-3 has-[:checked]:border-wine has-[:checked]:bg-wine/5 has-[:disabled]:opacity-50">
      <input
        checked={checked}
        className="h-5 w-5 accent-wine"
        disabled={disabled}
        onChange={(event) => onChange(event.target.checked)}
        type="checkbox"
      />
      <span className="min-w-0">
        <span className="block text-sm font-semibold text-foreground">
          {label}
        </span>
        <span className="mt-1 block text-xs text-ink-muted">{meta}</span>
      </span>
    </label>
  );
}

function FactRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[6rem_1fr] gap-3 border-b border-background/15 pb-3 last:border-0 last:pb-0">
      <dt className="font-mono text-[9px] font-bold uppercase tracking-[0.12em] text-background/60">
        {label}
      </dt>
      <dd className="text-right leading-5 text-background">{value}</dd>
    </div>
  );
}
