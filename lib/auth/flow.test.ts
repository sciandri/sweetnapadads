import { describe, expect, it } from "vitest";

import {
  DEFAULT_AUTH_DESTINATION,
  getEmailOtpType,
  getSafeNextPath,
  parseInviteOnlyEmail,
} from "./flow";

describe("invite-only auth flow", () => {
  it("normalizes a valid invited email", () => {
    expect(parseInviteOnlyEmail("  DAD@Example.COM ")).toBe("dad@example.com");
  });

  it("rejects missing and malformed emails", () => {
    expect(parseInviteOnlyEmail(null)).toBeNull();
    expect(parseInviteOnlyEmail("not-an-email")).toBeNull();
    expect(parseInviteOnlyEmail("dad @example.com")).toBeNull();
  });

  it("keeps local destinations and their query strings", () => {
    expect(getSafeNextPath("/dashboard?season=2026")).toBe(
      "/dashboard?season=2026",
    );
  });

  it("rejects absolute, protocol-relative, and backslash redirects", () => {
    expect(getSafeNextPath("https://attacker.example")).toBe(
      DEFAULT_AUTH_DESTINATION,
    );
    expect(getSafeNextPath("//attacker.example")).toBe(
      DEFAULT_AUTH_DESTINATION,
    );
    expect(getSafeNextPath("/\\attacker.example")).toBe(
      DEFAULT_AUTH_DESTINATION,
    );
  });

  it("allows only supported email OTP callback types", () => {
    expect(getEmailOtpType("invite")).toBe("invite");
    expect(getEmailOtpType("magiclink")).toBe("magiclink");
    expect(getEmailOtpType("sms")).toBeNull();
    expect(getEmailOtpType(undefined)).toBeNull();
  });
});
