import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";

type WorkbookManifest = {
  source: {
    filename: string;
    size_bytes: number;
    sha256: string;
  };
  inventory: Array<{
    sheet: string;
    source_range: string;
  }>;
  known_issues: Array<{
    issue_code: string;
    severity: "info" | "warning" | "blocking";
    status: "open" | "accepted" | "resolved";
  }>;
  acceptance_state: {
    ready_for_approval: boolean;
    normalized_history_committed: boolean;
    commissioner_decisions_required: boolean;
  };
};

type DecisionQueue = {
  source_sha256: string;
  status: "proposed" | "approved";
  approved_on?: string;
  approval_source?: string;
  accepted_option_ids: string[];
  decisions: Array<{
    issue_code: string;
    recommended_option_id: string;
    options: Array<{
      option_id: string;
      normalized_effect?: {
        obligation_cents: number;
        payment_cents: number;
        adjustment_cents: number;
        team_balance_cents: number;
      };
    }>;
  }>;
};

type NormalizedPreview = {
  status: "review_only";
  committed: boolean;
  source: { sha256: string };
  approval: {
    decision_queue_status: "approved";
    accepted_option_ids: string[];
  };
  teams: unknown[];
  weekly_results: unknown[];
  weekly_awards: Array<{
    payout_cents: number;
    penalty_cents: number;
  }>;
  financial_obligations: Array<{
    direction: "team_owes_league" | "league_owes_team";
    amount_cents: number;
  }>;
  payments: Array<{
    preview_id: string;
    amount_cents: number;
  }>;
  payment_allocations: Array<{
    payment_preview_id: string;
    amount_cents: number;
  }>;
  external_cash_events: Array<{
    direction: "cash_in" | "cash_out";
    amount_cents: number;
  }>;
  reconciliation: {
    totals: {
      team_obligations_cents: number;
      payments_from_team_cents: number;
      league_obligations_cents: number;
      payments_to_team_cents: number;
      net_team_balance_cents: number;
      payment_cents: number;
      allocated_payment_cents: number;
      unallocated_payment_cents: number;
    };
    cash: {
      external_cash_out_cents: number;
      cash_balance_cents: number;
    };
    checks: Record<string, number>;
  };
  commit_gate: {
    ready_for_domain_commit: boolean;
    requires_separate_commit_action: boolean;
    blocking_issues: unknown[];
  };
};

type WorkbookRows = {
  source: { sha256: string };
  extraction: {
    row_count: number;
    sheet_count: number;
    includes_headers: boolean;
    includes_blank_rows_within_manifest_ranges: boolean;
  };
  rows: Array<{
    source_sheet: string;
    source_row_number: number;
    source_range: string;
    raw_values: unknown[];
    raw_formulas: Array<string | null> | null;
    row_sha256: string;
  }>;
};

const projectPath = (...segments: string[]) =>
  path.join(process.cwd(), ...segments);

const readImportJson = async <Value>(filename: string) =>
  JSON.parse(
    await readFile(
      projectPath("data", "import", "2025", filename),
      "utf8",
    ),
  ) as Value;

describe("2025 workbook manifest", () => {
  it("matches the immutable source workbook", async () => {
    const manifest = await readImportJson<WorkbookManifest>(
      "workbook-manifest.json",
    );
    const workbook = await readFile(projectPath(manifest.source.filename));
    const sha256 = createHash("sha256").update(workbook).digest("hex");

    expect(workbook.byteLength).toBe(manifest.source.size_bytes);
    expect(sha256).toBe(manifest.source.sha256);
  });

  it("inventories each source sheet exactly once", async () => {
    const manifest = await readImportJson<WorkbookManifest>(
      "workbook-manifest.json",
    );
    const sheetNames = manifest.inventory.map(({ sheet }) => sheet);

    expect(sheetNames).toHaveLength(8);
    expect(new Set(sheetNames).size).toBe(8);
    expect(sheetNames).toEqual([
      "Teams",
      "League Ledger",
      "Team Balance",
      "Weekly Results",
      "Weekly Awards",
      "League Payouts",
      "Net Cash",
      "Bets",
    ]);
    expect(
      manifest.inventory.every(({ source_range }) =>
        /^[A-Z]+\d+:[A-Z]+\d+$/.test(source_range),
      ),
    ).toBe(true);
  });

  it("records every source discrepancy as resolved after approval", async () => {
    const manifest = await readImportJson<WorkbookManifest>(
      "workbook-manifest.json",
    );

    expect(manifest.known_issues).toHaveLength(7);
    expect(manifest.known_issues.every(({ status }) => status === "resolved"))
      .toBe(true);
    expect(manifest.acceptance_state).toEqual({
      ready_for_approval: true,
      normalized_history_committed: false,
      commissioner_decisions_required: false,
    });
  });

  it("records the recommended treatment for every manifest issue", async () => {
    const [manifest, queue] = await Promise.all([
      readImportJson<WorkbookManifest>("workbook-manifest.json"),
      readImportJson<DecisionQueue>("decision-queue.json"),
    ]);
    const manifestIssues = manifest.known_issues
      .map(({ issue_code }) => issue_code)
      .sort();
    const decisionIssues = queue.decisions
      .map(({ issue_code }) => issue_code)
      .sort();

    expect(queue.source_sha256).toBe(manifest.source.sha256);
    expect(decisionIssues).toEqual(manifestIssues);
    expect(queue.status).toBe("approved");
    expect(queue.approved_on).toBe("2026-07-30");
    expect(queue.approval_source).toContain("Commissioner instruction");
    expect(queue.accepted_option_ids.sort()).toEqual(
      queue.decisions
        .map(({ recommended_option_id }) => recommended_option_id)
        .sort(),
    );
  });

  it("references a valid recommendation for every decision", async () => {
    const queue =
      await readImportJson<DecisionQueue>("decision-queue.json");

    for (const decision of queue.decisions) {
      const optionIds = decision.options.map(({ option_id }) => option_id);

      expect(new Set(optionIds).size).toBe(optionIds.length);
      expect(optionIds).toContain(decision.recommended_option_id);
    }
  });

  it("keeps champion options arithmetically consistent", async () => {
    const queue =
      await readImportJson<DecisionQueue>("decision-queue.json");
    const champion = queue.decisions.find(
      ({ issue_code }) => issue_code === "champion_payout_conflict",
    );

    expect(champion).toBeDefined();
    for (const option of champion?.options ?? []) {
      const effect = option.normalized_effect;

      expect(effect).toBeDefined();
      expect(
        -effect!.obligation_cents +
          effect!.payment_cents +
          effect!.adjustment_cents,
      ).toBe(effect!.team_balance_cents);
    }
  });

  it("keeps the normalized preview review-only and checksum-pinned", async () => {
    const [manifest, queue, preview] = await Promise.all([
      readImportJson<WorkbookManifest>("workbook-manifest.json"),
      readImportJson<DecisionQueue>("decision-queue.json"),
      readImportJson<NormalizedPreview>("normalized-preview.json"),
    ]);

    expect(preview.status).toBe("review_only");
    expect(preview.committed).toBe(false);
    expect(preview.source.sha256).toBe(manifest.source.sha256);
    expect(preview.approval.decision_queue_status).toBe("approved");
    expect(preview.approval.accepted_option_ids.sort()).toEqual(
      queue.accepted_option_ids.sort(),
    );
    expect(preview.commit_gate).toEqual(
      expect.objectContaining({
        ready_for_domain_commit: true,
        requires_separate_commit_action: true,
        blocking_issues: [],
      }),
    );
  });

  it("preserves every manifest-range row and formula as staged source evidence", async () => {
    const [manifest, workbookRows] = await Promise.all([
      readImportJson<WorkbookManifest>("workbook-manifest.json"),
      readImportJson<WorkbookRows>("workbook-rows.json"),
    ]);

    expect(workbookRows.source.sha256).toBe(manifest.source.sha256);
    expect(workbookRows.extraction).toEqual({
      row_count: 533,
      sheet_count: 8,
      includes_headers: true,
      includes_blank_rows_within_manifest_ranges: true,
    });

    const sheetCounts = Object.fromEntries(
      manifest.inventory.map(({ sheet, source_range }) => {
        const [start, end] = source_range.split(":");
        const startRow = Number(start.match(/\d+$/)?.[0]);
        const endRow = Number(end.match(/\d+$/)?.[0]);
        return [sheet, endRow - startRow + 1];
      }),
    );
    expect(
      workbookRows.rows.reduce<Record<string, number>>((counts, row) => {
        counts[row.source_sheet] = (counts[row.source_sheet] ?? 0) + 1;
        return counts;
      }, {}),
    ).toEqual(sheetCounts);

    for (const row of workbookRows.rows) {
      const rowEvidence = {
        source_sheet: row.source_sheet,
        source_row_number: row.source_row_number,
        source_range: row.source_range,
        raw_values: row.raw_values,
        raw_formulas: row.raw_formulas,
      };
      expect(createHash("sha256").update(JSON.stringify(rowEvidence)).digest("hex"))
        .toBe(row.row_sha256);
    }

    const malformedDate = workbookRows.rows.find(
      (row) =>
        row.source_sheet === "League Ledger" && row.source_row_number === 2,
    );
    const brokenFormula = workbookRows.rows.find(
      (row) =>
        row.source_sheet === "Team Balance" && row.source_row_number === 2,
    );

    expect(malformedDate?.raw_values[2]).toBe(374603);
    expect(brokenFormula?.raw_values[19]).toBe("#NAME?");
    expect(brokenFormula?.raw_formulas?.[19]).toContain(
      "__xludf.DUMMYFUNCTION",
    );
  });

  it("normalizes the full competition and financial history", async () => {
    const preview = await readImportJson<NormalizedPreview>(
      "normalized-preview.json",
    );

    expect(preview.teams).toHaveLength(10);
    expect(preview.weekly_results).toHaveLength(160);
    expect(preview.weekly_awards).toHaveLength(14);
    expect(preview.financial_obligations).toHaveLength(49);
    expect(preview.payments).toHaveLength(43);
    expect(preview.payment_allocations).toHaveLength(43);
    expect(preview.external_cash_events).toHaveLength(1);
  });

  it("reconciles every normalized payment exactly once in total", async () => {
    const preview = await readImportJson<NormalizedPreview>(
      "normalized-preview.json",
    );
    const allocatedByPayment = new Map<string, number>();

    for (const allocation of preview.payment_allocations) {
      allocatedByPayment.set(
        allocation.payment_preview_id,
        (allocatedByPayment.get(allocation.payment_preview_id) ?? 0) +
          allocation.amount_cents,
      );
    }

    for (const payment of preview.payments) {
      expect(allocatedByPayment.get(payment.preview_id)).toBe(
        payment.amount_cents,
      );
    }
    expect(preview.reconciliation.totals.payment_cents).toBe(448000);
    expect(preview.reconciliation.totals.allocated_payment_cents).toBe(
      448000,
    );
    expect(preview.reconciliation.totals.unallocated_payment_cents).toBe(0);
  });

  it("ties normalized awards, balances, payouts, and cash to approved totals", async () => {
    const preview = await readImportJson<NormalizedPreview>(
      "normalized-preview.json",
    );
    const { totals, cash, checks } = preview.reconciliation;

    expect(totals).toEqual(
      expect.objectContaining({
        team_obligations_cents: 298000,
        payments_from_team_cents: 271000,
        league_obligations_cents: 200000,
        payments_to_team_cents: 177000,
        net_team_balance_cents: 4000,
      }),
    );
    expect(cash.external_cash_out_cents).toBe(70000);
    expect(cash.cash_balance_cents).toBe(24000);
    expect(checks.source_weekly_payout_pool_cents).toBe(
      checks.normalized_weekly_payout_pool_cents,
    );
    expect(checks.source_weekly_penalty_total_cents).toBe(
      checks.normalized_weekly_penalty_total_cents,
    );
    expect(checks.source_configured_payout_total_cents).toBe(
      checks.normalized_payout_obligation_total_cents,
    );
    expect(checks.source_realized_cash_balance_cents).toBe(
      checks.normalized_cash_balance_cents,
    );
  });
});
