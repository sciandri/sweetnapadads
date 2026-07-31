import { beforeEach, describe, expect, it, vi } from "vitest";

import { createClient } from "@/lib/supabase/server";

import { GET } from "./route";

vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn(),
}));

const exchangeCodeForSession = vi.fn();
const verifyOtp = vi.fn();

describe("auth callback", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(createClient).mockResolvedValue({
      auth: {
        exchangeCodeForSession,
        verifyOtp,
      },
    } as never);
  });

  it("exchanges a PKCE code and redirects to a safe destination", async () => {
    exchangeCodeForSession.mockResolvedValue({ error: null });

    const response = await GET(
      new Request(
        "https://sweetnapadads.test/auth/callback?code=valid&next=/dashboard?season=2026",
      ),
    );

    expect(exchangeCodeForSession).toHaveBeenCalledWith("valid");
    expect(response.headers.get("location")).toBe(
      "https://sweetnapadads.test/dashboard?season=2026",
    );
  });

  it("verifies token-hash invite callbacks", async () => {
    verifyOtp.mockResolvedValue({ error: null });

    const response = await GET(
      new Request(
        "https://sweetnapadads.test/auth/callback?token_hash=hash&type=invite",
      ),
    );

    expect(verifyOtp).toHaveBeenCalledWith({
      token_hash: "hash",
      type: "invite",
    });
    expect(response.headers.get("location")).toBe(
      "https://sweetnapadads.test/dashboard",
    );
  });

  it("returns callback failures to login without exposing provider errors", async () => {
    exchangeCodeForSession.mockResolvedValue({
      error: new Error("expired provider token"),
    });

    const response = await GET(
      new Request(
        "https://sweetnapadads.test/auth/callback?code=expired&next=/dashboard",
      ),
    );
    const location = new URL(response.headers.get("location")!);

    expect(location.pathname).toBe("/login");
    expect(location.searchParams.get("error")).toBe("auth_callback");
    expect(location.searchParams.get("next")).toBe("/dashboard");
    expect(location.toString()).not.toContain("expired provider token");
  });

  it("rejects external callback destinations", async () => {
    exchangeCodeForSession.mockResolvedValue({ error: null });

    const response = await GET(
      new Request(
        "https://sweetnapadads.test/auth/callback?code=valid&next=https://attacker.test",
      ),
    );

    expect(response.headers.get("location")).toBe(
      "https://sweetnapadads.test/dashboard",
    );
  });
});
