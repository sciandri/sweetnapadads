import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import { createClient } from "@/lib/supabase/server";

import { NotificationForm } from "./notification-form";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "League notifications" };

export default async function NotificationsPage() {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/login?next=/dashboard/admin/notifications");

  const { data: membership } = await supabase.from("league_memberships").select("league_id, role").eq("user_id", userId).eq("status", "active").eq("role", "commissioner").limit(1).maybeSingle();
  if (!membership) redirect("/access-denied");

  const [{ data: league }, { data: season }, { data: notifications }] = await Promise.all([
    supabase.from("leagues").select("name").eq("id", membership.league_id).maybeSingle(),
    supabase.from("seasons").select("id, name").eq("league_id", membership.league_id).in("status", ["active", "setup"]).order("year", { ascending: false }).limit(1).maybeSingle(),
    supabase.from("league_notifications").select("id, title, body, kind, audience, published_at").eq("league_id", membership.league_id).order("published_at", { ascending: false }).limit(12),
  ]);

  return <main className="paper-noise min-h-[100svh] px-4 py-5 sm:px-8 sm:py-7 lg:px-12"><div className="mx-auto max-w-6xl"><header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5"><div className="flex min-w-0 items-center gap-3"><BrandLogo alt="" className="h-14 w-14 object-contain" priority sizes="56px" /><div><p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine">Commissioner control</p><p className="mt-1 font-display text-xl sm:text-2xl">{league?.name ?? "Sweet Looking Napa Dads"}</p></div></div><Link className="grid min-h-11 place-items-center border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em]" href="/dashboard">Standings</Link></header><section className="py-8 sm:py-11"><p className="font-mono text-[9px] font-bold uppercase tracking-[0.2em] text-wine">In-app communication</p><h1 className="mt-3 text-balance font-display text-5xl leading-[0.9] tracking-[-0.04em] sm:text-7xl">League notifications</h1><p className="mt-5 max-w-3xl text-base leading-7 text-ink-muted sm:text-lg">Publish durable announcements and reminders to the member dashboard. Every recipient receives immutable delivery evidence; no email or SMS is sent from this screen.</p><section aria-labelledby="publish-heading" className="mt-8 border border-forest/20 bg-surface/70 p-5 sm:p-7"><h2 className="font-display text-4xl" id="publish-heading">Publish</h2><p className="mb-6 mt-2 text-sm text-ink-muted">{season?.name ?? "League-wide, no active season"}</p><NotificationForm leagueId={membership.league_id} seasonId={season?.id ?? null} /></section><section aria-labelledby="notification-history-heading" className="mt-10 border-t border-forest/20 pt-8"><h2 className="font-display text-4xl" id="notification-history-heading">Published feed</h2>{notifications?.length ? <ol className="mt-5 grid gap-4">{notifications.map((notification) => <li className="border border-forest/20 bg-surface/70 p-5" key={notification.id}><div className="flex flex-wrap justify-between gap-3"><p className="font-display text-2xl">{notification.title}</p><p className="font-mono text-[8px] font-bold uppercase tracking-[0.12em] text-wine">{String(notification.kind)} · {String(notification.audience).replace("_", " ")}</p></div><p className="mt-3 whitespace-pre-wrap text-sm leading-6 text-ink-muted">{notification.body}</p></li>)}</ol> : <p className="mt-5 border border-dashed border-forest/30 p-6 text-sm text-ink-muted">No notifications have been published.</p>}</section></section></div></main>;
}
