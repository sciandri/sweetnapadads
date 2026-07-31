import type { Metadata, Route } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { BrandLogo } from "@/components/brand-logo";
import { getSafeNextPath } from "@/lib/auth/flow";
import { createClient } from "@/lib/supabase/server";

import { LoginForm } from "./login-form";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Member sign in",
  description: "Invitation-only member access.",
};

type LoginPageProps = {
  searchParams: Promise<{
    error?: string | string[];
    next?: string | string[];
  }>;
};

const callbackErrors: Record<string, string> = {
  auth_callback:
    "That sign-in link is invalid or expired. Request a fresh link below.",
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const next = getSafeNextPath(
    typeof params.next === "string" ? params.next : null,
  );
  const error =
    typeof params.error === "string" ? callbackErrors[params.error] : undefined;
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();

  if (data?.claims?.sub) {
    redirect(next as Route);
  }

  return (
    <main className="paper-noise grid min-h-[100svh] place-items-center px-5 py-10 sm:px-8">
      <section className="w-full max-w-lg border border-forest/20 bg-background/90 p-6 shadow-[0_24px_80px_rgb(23_63_50_/_12%)] sm:p-10">
        <div className="flex items-center justify-between gap-4 border-b border-forest/20 pb-5">
          <Link
            className="font-mono text-[10px] font-bold uppercase tracking-[0.18em] text-forest hover:text-wine"
            href="/"
          >
            ← League home
          </Link>
          <span className="rounded-full border border-wine/25 px-3 py-1 font-mono text-[9px] uppercase tracking-[0.16em] text-wine">
            Members only
          </span>
        </div>

        <div className="mt-7 grid grid-cols-[5.5rem_1fr] items-center gap-5 sm:grid-cols-[7rem_1fr] sm:gap-7">
          <BrandLogo
            className="h-auto w-full drop-shadow-[0_12px_24px_rgb(23_63_50_/_12%)]"
            priority
            sizes="112px"
          />
          <div>
            <p className="font-mono text-[9px] font-bold uppercase tracking-[0.18em] text-wine sm:text-[10px] sm:tracking-[0.2em]">
              Invitation required
            </p>
            <h1 className="mt-2 font-display text-[2.55rem] leading-[0.9] tracking-[-0.035em] sm:text-5xl">
              Enter the clubhouse
            </h1>
          </div>
        </div>
        <p className="mt-6 max-w-md text-pretty text-base leading-7 text-ink-muted">
          Use the email address the commissioner invited. We’ll send a secure,
          one-time sign-in link—no password to remember.
        </p>

        {error ? (
          <p
            className="mt-6 border-l-2 border-wine bg-wine/6 px-4 py-3 text-sm leading-6 text-wine"
            role="alert"
          >
            {error}
          </p>
        ) : null}

        <LoginForm next={next} />

        <p className="mt-5 border-t border-forest/15 pt-5 text-xs leading-5 text-ink-muted">
          Not on the roster? Ask the commissioner for an invitation. This form
          never creates new accounts.
        </p>
      </section>
    </main>
  );
}
