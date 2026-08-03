"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";

export function NotificationForm({
  leagueId,
  seasonId,
}: {
  leagueId: string;
  seasonId: string | null;
}) {
  const router = useRouter();
  const [kind, setKind] = useState("announcement");
  const [audience, setAudience] = useState("all_members");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [state, setState] = useState({ status: "idle", message: "" });
  const retryKey = useRef<string | null>(null);

  function changed() {
    retryKey.current = null;
    setState({ status: "idle", message: "" });
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState({ status: "saving", message: "Publishing…" });
    retryKey.current ??= `notification:${leagueId}:${crypto.randomUUID()}`;
    try {
      const response = await fetch("/api/admin/notifications", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "idempotency-key": retryKey.current,
        },
        body: JSON.stringify({
          league_id: leagueId,
          season_id: seasonId,
          kind,
          audience,
          title,
          body,
        }),
      });
      const result = await response.json() as { error?: string; status?: string };
      if (!response.ok) {
        retryKey.current = null;
        setState({ status: "error", message: result.error === "forbidden" ? "Only an active commissioner can publish." : "The notification could not be published." });
        return;
      }
      retryKey.current = null;
      setState({ status: "success", message: result.status === "already_published" ? "This exact notification was already published." : "Notification published to the in-app league feed." });
      setTitle("");
      setBody("");
      router.refresh();
    } catch {
      setState({ status: "error", message: "The network response was interrupted. Submit again to retry safely." });
    }
  }

  return <form className="grid gap-5" onSubmit={submit}>
    <div className="grid gap-4 sm:grid-cols-2">
      <label className="grid gap-2 text-sm font-semibold">Kind<select className="min-h-12 border border-forest/25 bg-background px-3" onChange={(event) => { changed(); setKind(event.target.value); }} value={kind}><option value="announcement">Announcement</option><option value="reminder">Reminder</option><option value="result">Result</option><option value="finance">Finance</option><option value="system">System</option></select></label>
      <label className="grid gap-2 text-sm font-semibold">Audience<select className="min-h-12 border border-forest/25 bg-background px-3" onChange={(event) => { changed(); setAudience(event.target.value); }} value={audience}><option value="all_members">All active members</option><option value="commissioners">Commissioners only</option></select></label>
    </div>
    <label className="grid gap-2 text-sm font-semibold">Title<input className="min-h-12 border border-forest/25 bg-background px-3" maxLength={120} onChange={(event) => { changed(); setTitle(event.target.value); }} required value={title} /></label>
    <label className="grid gap-2 text-sm font-semibold">Message<textarea className="min-h-40 border border-forest/25 bg-background p-3 leading-6" maxLength={2000} onChange={(event) => { changed(); setBody(event.target.value); }} required value={body} /></label>
    <div className="grid gap-3 border-t border-forest/20 pt-5 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center"><p aria-live="polite" className={`text-sm ${state.status === "error" ? "text-wine" : state.status === "success" ? "text-forest" : "text-ink-muted"}`}>{state.message || "Publishing creates immutable content and recipient delivery evidence. Email delivery remains disabled until production SMTP is configured."}</p><button className="min-h-12 border border-wine bg-wine px-6 font-mono text-[10px] font-bold uppercase tracking-[0.16em] text-white disabled:opacity-50" disabled={state.status === "saving"} type="submit">{state.status === "saving" ? "Publishing…" : "Publish notification"}</button></div>
  </form>;
}
