import Link from "next/link";

import { BrandLogo } from "@/components/brand-logo";

export default function Home() {
  const modules = [
    {
      number: "01",
      title: "The competition",
      copy: "Standings, weekly results, awards, playoffs, and a record book that outlives any ESPN season.",
    },
    {
      number: "02",
      title: "Every dollar",
      copy: "Dues, penalties, payouts, and payments reconciled in one transparent, auditable ledger.",
    },
    {
      number: "03",
      title: "The lore",
      copy: "Announcements, rivalries, side bets, photos, trophies, and the evidence nobody gets to delete.",
    },
  ];

  return (
    <main className="paper-noise min-h-[100svh] overflow-hidden">
      <section className="relative mx-auto flex min-h-[92svh] max-w-[1440px] flex-col px-5 pb-8 pt-5 sm:px-10 sm:pb-10 sm:pt-6 lg:px-16">
        <div
          aria-hidden="true"
          className="absolute -right-40 top-24 h-[34rem] w-[34rem] rounded-full border-[7rem] border-wine/8"
        />

        <header className="relative z-10 flex items-start justify-between gap-4 border-b border-forest/20 pb-5 sm:items-center">
          <div className="flex items-center gap-2.5 sm:gap-3">
            <BrandLogo
              alt=""
              className="h-11 w-11 object-contain sm:h-13 sm:w-13"
              priority
              sizes="52px"
            />
            <span className="text-[10px] font-bold uppercase leading-4 tracking-[0.2em] sm:text-xs sm:tracking-[0.24em]">
              Napa · California
            </span>
          </div>
          <div className="flex flex-col items-end gap-2 sm:flex-row sm:items-center sm:gap-5">
            <span className="hidden max-w-36 text-right font-mono text-[9px] uppercase leading-4 tracking-[0.16em] text-ink-muted sm:inline sm:max-w-none sm:text-[11px] sm:tracking-[0.18em]">
              Est. long before good judgment
            </span>
            <Link
              className="min-h-10 border border-forest/25 px-3 py-2.5 font-mono text-[9px] font-bold uppercase tracking-[0.16em] transition hover:border-wine hover:text-wine sm:px-4 sm:text-[10px]"
              href="/login"
            >
              Member sign in
            </Link>
          </div>
        </header>

        <div className="relative z-10 grid flex-1 items-center gap-10 py-12 sm:gap-14 sm:py-16 lg:grid-cols-[1.25fr_0.75fr] lg:py-20">
          <div>
            <p className="mb-6 flex items-center gap-3 font-mono text-[10px] font-semibold uppercase tracking-[0.2em] text-wine sm:mb-8 sm:text-xs sm:tracking-[0.22em]">
              <span className="h-px w-10 bg-wine" />
              League headquarters
            </p>
            <h1 className="max-w-5xl font-display text-[clamp(3.75rem,12vw,6.5rem)] font-medium leading-[0.78] tracking-[-0.06em] lg:text-[clamp(6.5rem,10.5vw,9.5rem)] lg:leading-[0.76] lg:tracking-[-0.065em]">
              Sweet Looking
              <span className="ml-[0.32em] block italic text-wine">
                Napa Dads
              </span>
            </h1>
            <p className="mt-8 max-w-xl text-pretty text-base leading-7 text-ink-muted sm:mt-10 sm:text-xl sm:leading-8">
              A permanent home for a fantasy football league with expensive
              taste, questionable wagers, and impeccably documented debts.
            </p>
          </div>

          <aside className="relative border-t border-forest/20 pt-8 sm:border-l sm:border-t-0 sm:pl-8 sm:pt-0 lg:ml-auto lg:max-w-sm">
            <div className="mb-7 flex items-end justify-between gap-6 sm:mb-9">
              <BrandLogo
                className="h-auto w-40 drop-shadow-[0_16px_28px_rgb(23_63_50_/_12%)] sm:w-48 lg:w-56"
                priority
                sizes="(min-width: 1024px) 224px, (min-width: 640px) 192px, 160px"
              />
              <span className="mb-2 shrink-0 text-right font-mono text-[9px] uppercase leading-5 tracking-[0.18em] text-ink-muted sm:text-[10px] sm:tracking-[0.2em]">
                Ten teams
                <br />
                One trophy
              </span>
            </div>
            <blockquote className="text-balance border-y border-forest/20 py-6 font-display text-[1.7rem] italic leading-tight sm:py-7 sm:text-3xl">
              “The commissioner has way too much free time.”
            </blockquote>
            <div className="mt-7 flex items-center justify-between font-mono text-[10px] uppercase tracking-[0.18em] text-ink-muted">
              <span>2025 archive loaded</span>
              <span className="h-2 w-2 rounded-full bg-forest" />
            </div>
          </aside>
        </div>

        <div className="relative z-10 grid divide-y divide-forest/20 border-y border-forest/20 md:grid-cols-3 md:divide-y-0">
          {modules.map((module) => (
            <article
              key={module.number}
              className="group px-1 py-6 sm:py-7 md:border-r md:border-forest/20 md:px-7 md:last:border-r-0"
            >
              <span className="font-mono text-[10px] tracking-[0.2em] text-wine">
                {module.number}
              </span>
              <h2 className="mt-3 font-display text-3xl">{module.title}</h2>
              <p className="mt-3 max-w-sm text-pretty text-sm leading-6 text-ink-muted">
                {module.copy}
              </p>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
