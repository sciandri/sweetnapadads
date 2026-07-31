import "server-only";

import { createClient as createSupabaseClient } from "@supabase/supabase-js";

import { getServerSupabaseEnv } from "./env";

export function createAdminClient() {
  const { serviceRoleKey, url } = getServerSupabaseEnv();

  return createSupabaseClient(url, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
