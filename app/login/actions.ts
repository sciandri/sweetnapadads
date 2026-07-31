"use server";

import {
  GENERIC_MAGIC_LINK_MESSAGE,
  getSafeNextPath,
  parseInviteOnlyEmail,
  type LoginState,
} from "@/lib/auth/flow";
import { getSiteEnv } from "@/lib/supabase/env";
import { createClient } from "@/lib/supabase/server";

export async function requestMagicLink(
  _previousState: LoginState,
  formData: FormData,
): Promise<LoginState> {
  const email = parseInviteOnlyEmail(formData.get("email"));

  if (!email) {
    return {
      status: "error",
      message: "Enter a valid email address.",
    };
  }

  const next = getSafeNextPath(
    typeof formData.get("next") === "string"
      ? (formData.get("next") as string)
      : null,
  );
  const { siteUrl } = getSiteEnv();
  const callbackUrl = new URL("/auth/callback", siteUrl);
  callbackUrl.searchParams.set("next", next);

  const supabase = await createClient();

  try {
    await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: callbackUrl.toString(),
        shouldCreateUser: false,
      },
    });
  } catch {
    // Keep the response indistinguishable for invited and unknown addresses.
  }

  return {
    status: "success",
    message: GENERIC_MAGIC_LINK_MESSAGE,
  };
}
