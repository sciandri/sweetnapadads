import { describe, expect, it } from "vitest";

import {
  validatePublicSupabaseEnv,
  validateServerSupabaseEnv,
} from "./env";

describe("Supabase environment validation", () => {
  it("accepts a valid hosted project URL and publishable key", () => {
    expect(
      validatePublicSupabaseEnv(
        "https://example.supabase.co",
        "sb_publishable_example",
      ),
    ).toEqual({
      url: "https://example.supabase.co",
      publishableKey: "sb_publishable_example",
    });
  });

  it("rejects missing or malformed public configuration", () => {
    expect(() => validatePublicSupabaseEnv(undefined, "key")).toThrow(
      "NEXT_PUBLIC_SUPABASE_URL",
    );
    expect(() => validatePublicSupabaseEnv("not-a-url", "key")).toThrow(
      "valid URL",
    );
    expect(() =>
      validatePublicSupabaseEnv("https://example.supabase.co", undefined),
    ).toThrow("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY");
  });

  it("keeps the service-role key in server-only configuration", () => {
    expect(
      validateServerSupabaseEnv(
        "https://example.supabase.co",
        "service-role-key",
      ),
    ).toEqual({
      url: "https://example.supabase.co",
      serviceRoleKey: "service-role-key",
    });

    expect(() =>
      validateServerSupabaseEnv("https://example.supabase.co", undefined),
    ).toThrow("SUPABASE_SERVICE_ROLE_KEY");
  });
});
