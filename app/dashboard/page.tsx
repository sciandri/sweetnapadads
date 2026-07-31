import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { signOut } from "@/app/auth/actions";
import { BrandLogo } from "@/components/brand-logo";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Dashboard",
};

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;

  if (!userId) {
    redirect("/login?next=/dashboard");
  }

  const { data: membership, error: membershipError } = await supabase
    .from("league_memberships")
    .select("league_id, role")
    .eq("user_id", userId)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();

  if (membershipError || !membership) {
    redirect("/access-denied");
  }

  const { data: league } = await supabase
    .from("leagues")
    .select("name")
    .eq("id", membership.league_id)
    .maybeSingle();

  return (
    <main className="paper-noise min-h-[100svh] px-5 py-6 sm:px-10 lg:px-16">
      <div className="mx-auto max-w-6xl">
        <header className="flex flex-wrap items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <div className="flex min-w-0 items-center gap-3 sm:gap-4">
            <BrandLogo
              alt=""
              className="h-14 w-14 shrink-0 object-contain sm:h-16 sm:w-16"
              priority
              sizes="64px"
            />
            <div className="min-w-0">
              <p className="font-mono text-[8px] font-bold uppercase tracking-[0.16em] text-wine sm:text-[9px] sm:tracking-[0.18em]">
                Authenticated league access
              </p>
              <p className="mt-1 truncate font-display text-xl sm:text-2xl">
                {league?.name ?? "Sweet Looking Napa Dads"}
              </p>
            </div>
          </div>
          <form action={signOut}>
            <button
              className="min-h-11 border border-forest/25 px-4 py-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] hover:border-wine hover:text-wine"
              type="submit"
            >
              Sign out
            </button>
          </form>
        </header>

        <section className="grid min-h-[70svh] place-items-center py-16 text-center">
          <div className="max-w-2xl">
            <span className="font-mono text-[10px] uppercase tracking-[0.2em] text-ink-muted">
              Role · {membership.role}
            </span>
            <h1 className="mt-5 font-display text-6xl leading-[0.85] tracking-[-0.045em] sm:text-8xl">
              You’re in.
            </h1>
            <p className="mx-auto mt-7 max-w-lg text-pretty text-base leading-7 text-ink-muted sm:text-lg">
              Authentication and league authorization are working. The full
              member dashboard arrives in the application phase.
            </p>
            {membership.role === "commissioner" ? (
              <Link
                className="mx-auto mt-8 grid min-h-12 w-fit place-items-center border border-wine bg-wine px-6 py-3 font-mono text-[10px] font-bold uppercase tracking-[0.18em] text-white"
                href="/dashboard/message-composer"
              >
                Open message composer
              </Link>
            ) : null}
          </div>
        </section>
      </div>
    </main>
  );
}
