import { describe, expect, it } from "vitest";

import { formatCurrency } from "./currency";

describe("formatCurrency", () => {
  it("formats integer cents without losing precision", () => {
    expect(formatCurrency(20_000)).toBe("$200");
    expect(formatCurrency(-5_050)).toBe("-$50.50");
  });

  it("rejects fractional cents", () => {
    expect(() => formatCurrency(10.5)).toThrow(
      "Currency values must be safe integer cents.",
    );
  });
});
