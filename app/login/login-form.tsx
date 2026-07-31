"use client";

import { useActionState } from "react";

import { initialLoginState } from "@/lib/auth/flow";

import { requestMagicLink } from "./actions";

type LoginFormProps = {
  next: string;
};

export function LoginForm({ next }: LoginFormProps) {
  const [state, formAction, pending] = useActionState(
    requestMagicLink,
    initialLoginState,
  );

  return (
    <form action={formAction} className="mt-8 space-y-5">
      <input name="next" type="hidden" value={next} />
      <div>
        <label
          className="mb-2 block font-mono text-[10px] font-bold uppercase tracking-[0.18em] text-ink-muted"
          htmlFor="email"
        >
          Invited email
        </label>
        <input
          autoComplete="email"
          autoFocus
          className="min-h-12 w-full rounded-sm border border-forest/25 bg-surface px-4 py-3 text-base outline-none transition focus:border-forest focus:ring-2 focus:ring-gold/45"
          id="email"
          inputMode="email"
          name="email"
          placeholder="you@example.com"
          required
          type="email"
        />
      </div>
      <button
        className="min-h-12 w-full rounded-sm bg-forest px-5 py-3 font-mono text-xs font-bold uppercase tracking-[0.16em] text-background transition hover:bg-forest-light disabled:cursor-wait disabled:opacity-65"
        disabled={pending}
        type="submit"
      >
        {pending ? "Sending link…" : "Email my sign-in link"}
      </button>
      <p
        aria-live="polite"
        className={
          state.status === "error"
            ? "min-h-6 text-sm leading-6 text-wine"
            : "min-h-6 text-sm leading-6 text-forest"
        }
        role={state.status === "error" ? "alert" : "status"}
      >
        {state.message}
      </p>
    </form>
  );
}
