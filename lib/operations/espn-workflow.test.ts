import { readFile } from "node:fs/promises";
import path from "node:path";

import { describe, expect, it } from "vitest";

const workflowPath = path.join(
  process.cwd(),
  ".github/workflows/espn-standings-sync.yml",
);
const runbookPath = path.join(
  process.cwd(),
  "docs/runbooks/ESPN_STANDINGS_SYNC.md",
);

async function workflow() {
  return readFile(workflowPath, "utf8");
}

describe("ESPN standings operations contract", () => {
  it("retains manual recovery and defines the reviewed in-season schedule", async () => {
    const source = await workflow();

    expect(source).toContain("workflow_dispatch:");
    expect(source).toMatch(/^\s*schedule:/m);
    expect(source).toContain('cron: "0 16 * 9-12,1 2"');
    expect(source).toContain("SEASON_ID: ${{ inputs.season_id || vars.SEASON_ID }}");
  });

  it("uses least privilege, production environment protection, and concurrency", async () => {
    const source = await workflow();

    expect(source).toContain("permissions:\n  contents: read");
    expect(source).toContain("environment: production");
    expect(source).toContain("group: espn-standings-${{ inputs.season_id || vars.SEASON_ID }}");
    expect(source).toContain("cancel-in-progress: false");
  });

  it("uses only indirect secret references and evidence-derived idempotency", async () => {
    const source = await workflow();

    expect(source).toContain("SYNC_SECRET: ${{ secrets.SYNC_SECRET }}");
    expect(source).toContain("SITE_URL: ${{ vars.SITE_URL }}");
    expect(source).not.toContain("Idempotency-Key:");
    expect(source).not.toContain("github.run_id");
    expect(source).not.toContain("ESPN_S2");
    expect(source).not.toContain("ESPN_SWID");
    expect(source).not.toContain("SUPABASE_SERVICE_ROLE_KEY");
  });

  it("validates input and redacts the response contract", async () => {
    const source = await workflow();

    expect(source).toContain("season_id must be a canonical UUID");
    expect(source).toContain("--retry 2");
    expect(source).toContain("jq -c '{status,season_id,team_count}'");
    expect(source).toContain("'{error:(.error // \"invalid_response\")}'");
  });

  it("documents activation, verification, rotation, failure, and scheduling gates", async () => {
    const runbook = await readFile(runbookPath, "utf8");

    expect(runbook).toContain("## Activation gate");
    expect(runbook).toContain("## Manual production run");
    expect(runbook).toContain("## Stable failure responses");
    expect(runbook).toContain("## Secret rotation");
    expect(runbook).toContain("## Scheduled production run");
    expect(runbook).toContain("prior successful standings snapshot authoritative");
    expect(runbook).toContain("derives its key from the immutable raw ESPN response hash");
  });
});
