import type { EmailOtpType } from "@supabase/supabase-js";

export const DEFAULT_AUTH_DESTINATION = "/dashboard";
export const GENERIC_MAGIC_LINK_MESSAGE =
  "If that address has an invitation, a sign-in link is on its way.";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const EMAIL_OTP_TYPES = new Set<EmailOtpType>([
  "email",
  "email_change",
  "invite",
  "magiclink",
  "recovery",
  "signup",
]);

export type LoginState =
  | {
      status: "idle";
      message: "";
    }
  | {
      status: "error" | "success";
      message: string;
    };

export const initialLoginState: LoginState = {
  status: "idle",
  message: "",
};

export function parseInviteOnlyEmail(value: FormDataEntryValue | null) {
  if (typeof value !== "string") {
    return null;
  }

  const email = value.trim().toLowerCase();

  if (
    email.length === 0 ||
    email.length > 254 ||
    !EMAIL_PATTERN.test(email)
  ) {
    return null;
  }

  return email;
}

export function getSafeNextPath(
  value: string | null | undefined,
  fallback = DEFAULT_AUTH_DESTINATION,
) {
  if (!value || !value.startsWith("/") || value.startsWith("//")) {
    return fallback;
  }

  try {
    const base = new URL("https://sweetnapadads.invalid");
    const destination = new URL(value, base);

    if (destination.origin !== base.origin) {
      return fallback;
    }

    return `${destination.pathname}${destination.search}${destination.hash}`;
  } catch {
    return fallback;
  }
}

export function getEmailOtpType(
  value: string | null | undefined,
): EmailOtpType | null {
  if (!value || !EMAIL_OTP_TYPES.has(value as EmailOtpType)) {
    return null;
  }

  return value as EmailOtpType;
}
