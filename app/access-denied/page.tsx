import type { Metadata } from "next";
import Link from "next/link";

import { signOut } from "@/app/auth/actions";
import { BrandLogo } from "@/components/brand-logo";

export const metadata: Metadata = {
  title: "Access unavailable",
};

export default function AccessDeniedPage() {
  return (
    <main className="paper-noise grid min-h-[100svh] place-items-center px-5 py-10">
      <section className="w-full max-w-xl border border-forest/20 bg-background/90 p-7 text-center sm:p-12">
        <BrandLogo
          className="mx-auto h-auto w-28 drop-shadow-[0_12px_24px_rgb(23_63_50_/_12%)] sm:w-32"
          priority
          sizes="128px"
        />
        <p className="font-mono text-[10px] font-bold uppercase tracking-[0.2em] text-wine">
          Roster check
        </p>
        <h1 className="mt-4 font-display text-5xl tracking-[-0.04em] sm:text-6xl">
          Access unavailable
        </h1>
        <p className="mx-auto mt-5 max-w-md text-pretty leading-7 text-ink-muted">
          This account is authenticated but does not have an active league
          membership. Ask the commissioner to check your invitation.
        </p>
        <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
          <form action={signOut}>
            <button
              className="min-h-12 w-full bg-forest px-5 py-3 font-mono text-xs font-bold uppercase tracking-[0.16em] text-background sm:w-auto"
              type="submit"
            >
              Sign out
            </button>
          </form>
          <Link
            className="grid min-h-12 place-items-center border border-forest/25 px-5 py-3 font-mono text-xs font-bold uppercase tracking-[0.16em]"
            href="/"
          >
            League home
          </Link>
        </div>
      </section>
    </main>
  );
}
