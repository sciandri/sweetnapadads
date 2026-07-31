import { NextResponse } from "next/server";

import {
  getEmailOtpType,
  getSafeNextPath,
} from "@/lib/auth/flow";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const tokenHash = requestUrl.searchParams.get("token_hash");
  const otpType = getEmailOtpType(requestUrl.searchParams.get("type"));
  const next = getSafeNextPath(requestUrl.searchParams.get("next"));
  const supabase = await createClient();

  let error: unknown = new Error("Missing authentication callback token");

  if (code) {
    ({ error } = await supabase.auth.exchangeCodeForSession(code));
  } else if (tokenHash && otpType) {
    ({ error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: otpType,
    }));
  }

  if (!error) {
    return NextResponse.redirect(new URL(next, requestUrl.origin));
  }

  const loginUrl = new URL("/login", requestUrl.origin);
  loginUrl.searchParams.set("error", "auth_callback");
  loginUrl.searchParams.set("next", next);

  return NextResponse.redirect(loginUrl);
}
