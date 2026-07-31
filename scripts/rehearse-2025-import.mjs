import { execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { createClient } from "@supabase/supabase-js";

const projectRoot = process.cwd();
const importRoot = path.join(projectRoot, "data", "import", "2025");
const commissionerId = "d0000000-0000-4000-8000-000000000001";
const commissionerEmail = "dev-commissioner@sweetnapadads.test";
const leagueId = "c5000000-0000-4000-8000-000000000001";
const seasonId = "c5000000-0000-4000-8000-000000000002";
const batchId = "c5000000-0000-4000-8000-000000000003";

const [manifest, decisions, preview, workbookRows] = await Promise.all(
  [
    "workbook-manifest.json",
    "decision-queue.json",
    "normalized-preview.json",
    "workbook-rows.json",
  ].map(async (filename) =>
    JSON.parse(await readFile(path.join(importRoot, filename), "utf8")),
  ),
);

if (
  manifest.source.sha256 !== preview.source.sha256 ||
  manifest.source.sha256 !== decisions.source_sha256 ||
  manifest.source.sha256 !== workbookRows.source.sha256
) {
  throw new Error("Canonical 2025 artifacts do not share one source checksum");
}

if (
  preview.status !== "review_only" ||
  preview.committed !== false ||
  preview.commit_gate?.ready_for_domain_commit !== true
) {
  throw new Error("Canonical 2025 preview has not passed its commit gate");
}

const statusOutput = execFileSync(
  path.join(projectRoot, "node_modules", ".bin", "supabase"),
  ["status", "-o", "env"],
  { cwd: projectRoot, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
);
const localEnvironment = Object.fromEntries(
  statusOutput
    .split("\n")
    .filter((line) => line.includes("="))
    .map((line) => {
      const delimiter = line.indexOf("=");
      return [
        line.slice(0, delimiter),
        line.slice(delimiter + 1).replace(/^"|"$/g, ""),
      ];
    }),
);
const supabaseUrl = localEnvironment.API_URL;
const serviceRoleKey = localEnvironment.SERVICE_ROLE_KEY;
const anonKey = localEnvironment.ANON_KEY;

if (!supabaseUrl || !serviceRoleKey || !anonKey) {
  throw new Error("Local Supabase is not running or did not report credentials");
}

const localHost = new URL(supabaseUrl).hostname;
if (localHost !== "127.0.0.1" && localHost !== "localhost") {
  throw new Error("Canonical import rehearsal refuses non-local Supabase URLs");
}

const clientOptions = {
  auth: { autoRefreshToken: false, persistSession: false },
};
const admin = createClient(supabaseUrl, serviceRoleKey, clientOptions);
const commissioner = createClient(supabaseUrl, anonKey, clientOptions);
const commissionerPassword = randomBytes(30).toString("base64url");

async function requireData(operation, label) {
  const { data, error } = await operation;
  if (error) throw new Error(`${label}: ${error.message}`);
  return data;
}

function deterministicId(namespace, index) {
  return `c5000000-0000-4000-${namespace}-${String(index).padStart(12, "0")}`;
}

function chunks(items, size) {
  const output = [];
  for (let index = 0; index < items.length; index += size) {
    output.push(items.slice(index, index + size));
  }
  return output;
}

function stableJson(value) {
  if (Array.isArray(value)) return value.map(stableJson);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, stableJson(value[key])]),
    );
  }
  return value;
}

function eventMapping(sourceType, sourceSubtype) {
  const common = {
    source_type: sourceType,
    source_subtype: sourceSubtype,
    status: "mapped",
    decision_note: "Commissioner-approved Type + How mapping from decision queue",
  };
  const manualOrVenmo = sourceSubtype.toLowerCase().startsWith("venmo")
    ? "venmo"
    : sourceSubtype.toLowerCase() === "self"
      ? "self"
      : "manual";

  if (sourceType === "Dues" || sourceType === "Draft Party") {
    return {
      ...common,
      target_kind: "payment",
      payment_direction: "from_team",
      target_method: manualOrVenmo,
    };
  }
  if (sourceType === "Penalty Paid") {
    return {
      ...common,
      target_kind: "payment",
      payment_direction: "from_team",
      target_method: manualOrVenmo,
    };
  }
  if (sourceType === "Payout Paid") {
    return {
      ...common,
      target_kind: "payment",
      payment_direction: "to_team",
      target_method: manualOrVenmo,
    };
  }
  if (sourceType === "Penalty Assessed") {
    return {
      ...common,
      target_kind: "obligation",
      obligation_direction: "team_owes_league",
      target_category: "weekly_low_score_penalty",
    };
  }
  if (sourceType === "Payout Obligation") {
    const categories = {
      "High Score": "weekly_high_score",
      "High Score YEAR": "season_high_score",
      CHAMPION: "placement_champion",
      "2nd Place": "placement_runner_up",
      "3rd Place": "placement_third",
    };
    const targetCategory = categories[sourceSubtype];
    if (!targetCategory) {
      throw new Error(`Unknown payout obligation subtype: ${sourceSubtype}`);
    }
    return {
      ...common,
      target_kind: "obligation",
      obligation_direction: "league_owes_team",
      target_category: targetCategory,
    };
  }

  throw new Error(`Unknown ledger mapping: ${sourceType} + ${sourceSubtype}`);
}

await requireData(
  admin.auth.admin.updateUserById(commissionerId, {
    password: commissionerPassword,
    email_confirm: true,
  }),
  "prepare synthetic commissioner login",
);

await requireData(
  admin.from("leagues").upsert({
    id: leagueId,
    name: "Sweet Looking Napa Dads",
    slug: "sweet-looking-napa-dads-canonical-local",
    created_by: commissionerId,
  }),
  "stage canonical league",
);

await requireData(
  admin.from("league_memberships").upsert(
    {
      id: deterministicId("b000", 1),
      league_id: leagueId,
      user_id: commissionerId,
      role: "commissioner",
      status: "active",
      joined_at: "2025-08-01T00:00:00Z",
      created_by: commissionerId,
    },
    { onConflict: "league_id,user_id" },
  ),
  "stage commissioner membership",
);

await requireData(
  admin.from("seasons").upsert({
    id: seasonId,
    league_id: leagueId,
    year: preview.season.year,
    name: `${preview.season.year} Season`,
    status: "complete",
    created_by: commissionerId,
  }),
  "stage canonical season",
);

const postseasonTeams = new Set(
  preview.weekly_results
    .filter((result) => result.phase === "postseason")
    .map((result) => result.team_key),
);
await requireData(
  admin.from("season_settings").upsert({
    season_id: seasonId,
    currency_code: preview.season.currency,
    buy_in_cents: preview.season.rules.buy_in_cents,
    draft_fee_cents: preview.season.rules.draft_party_fee_cents,
    weekly_high_score_payout_cents:
      preview.season.rules.weekly_high_score_payout_cents,
    weekly_low_score_penalty_cents:
      preview.season.rules.weekly_low_score_penalty_cents,
    regular_season_weeks: preview.season.regular_season_weeks,
    playoff_team_count: postseasonTeams.size,
    created_by: commissionerId,
  }),
  "stage season rules",
);

const teams = preview.teams.map((team, index) => ({
  id: deterministicId("c000", index + 1),
  league_id: leagueId,
  name: team.name,
  slug: team.team_key.replaceAll("_", "-"),
  created_by: commissionerId,
}));
const seasonTeams = preview.teams.map((team, index) => ({
  id: deterministicId("d000", index + 1),
  league_id: leagueId,
  season_id: seasonId,
  team_id: teams[index].id,
  name: team.name,
  status: "active",
  created_by: commissionerId,
}));

await requireData(
  admin.from("teams").upsert(teams),
  "stage canonical teams",
);
await requireData(
  admin.from("season_teams").upsert(seasonTeams),
  "stage canonical season teams",
);

let batch = await requireData(
  admin
    .from("historical_import_batches")
    .select("id,status")
    .eq("id", batchId)
    .maybeSingle(),
  "inspect canonical import batch",
);

if (!batch) {
  batch = await requireData(
    admin
      .from("historical_import_batches")
      .insert({
        id: batchId,
        league_id: leagueId,
        season_id: seasonId,
        source_filename: manifest.source.filename,
        source_sha256: manifest.source.sha256,
        source_manifest: manifest,
        created_by: commissionerId,
      })
      .select("id,status")
      .single(),
    "create canonical import batch",
  );
}

if (batch.status === "staged" || batch.status === "reviewing") {
  for (const rowChunk of chunks(workbookRows.rows, 75)) {
    await requireData(
      admin.from("historical_import_rows").upsert(
        rowChunk.map((row) => ({
          ...row,
          batch_id: batchId,
          league_id: leagueId,
          season_id: seasonId,
          created_by: commissionerId,
        })),
        {
          onConflict: "batch_id,source_sheet,source_row_number",
          ignoreDuplicates: true,
        },
      ),
      "stage lossless workbook rows",
    );
  }

  await requireData(
    admin.from("historical_team_mappings").upsert(
      preview.teams.map((team, index) => ({
        id: deterministicId("e000", index + 1),
        batch_id: batchId,
        league_id: leagueId,
        season_id: seasonId,
        identifier_kind: "team_name",
        source_value: team.name,
        status: "mapped",
        season_team_id: seasonTeams[index].id,
        decision_note: "Canonical team mapping from approved 2025 preview",
        decided_by: commissionerId,
        decided_at: "2026-07-30T00:00:00Z",
        created_by: commissionerId,
      })),
      { onConflict: "batch_id,identifier_kind,normalized_source_value" },
    ),
    "stage canonical team mappings",
  );

  const ledgerPairs = new Map();
  for (const row of workbookRows.rows) {
    if (row.source_sheet !== "League Ledger" || row.source_row_number === 1) {
      continue;
    }
    const sourceType = row.raw_values[5];
    const sourceSubtype = row.raw_values[3];
    if (typeof sourceType === "string" && typeof sourceSubtype === "string") {
      ledgerPairs.set(`${sourceType}\u0000${sourceSubtype}`, {
        sourceType,
        sourceSubtype,
      });
    }
  }
  const eventMappings = [...ledgerPairs.values()].map(
    ({ sourceType, sourceSubtype }, index) => ({
      id: deterministicId("f000", index + 1),
      batch_id: batchId,
      league_id: leagueId,
      season_id: seasonId,
      ...eventMapping(sourceType, sourceSubtype),
      decided_by: commissionerId,
      decided_at: "2026-07-30T00:00:00Z",
      created_by: commissionerId,
    }),
  );
  await requireData(
    admin.from("historical_event_mappings").upsert(eventMappings, {
      onConflict:
        "batch_id,normalized_source_type,normalized_source_subtype",
    }),
    "stage commissioner-approved financial mappings",
  );

  const decisionsByCode = new Map(
    decisions.decisions.map((decision) => [decision.issue_code, decision]),
  );
  await requireData(
    admin.from("historical_import_issues").upsert(
      manifest.known_issues.map((issue, index) => {
        const decision = decisionsByCode.get(issue.issue_code);
        return {
          id: deterministicId("a000", index + 1),
          batch_id: batchId,
          league_id: leagueId,
          season_id: seasonId,
          issue_code: issue.issue_code,
          severity: issue.severity,
          status: issue.status,
          summary: decision?.title ?? issue.issue_code,
          evidence: issue.evidence,
          decision_note: `Accepted ${decision?.recommended_option_id}`,
          decided_by: commissionerId,
          decided_at: "2026-07-30T00:00:00Z",
          created_by: commissionerId,
        };
      }),
      {
        onConflict: "batch_id,issue_code,source_sheet,source_row_number",
      },
    ),
    "stage approved issue decisions",
  );
}

await requireData(
  commissioner.auth.signInWithPassword({
    email: commissionerEmail,
    password: commissionerPassword,
  }),
  "authenticate local rehearsal commissioner",
);

if (batch.status === "staged") {
  batch = await requireData(
    commissioner
      .from("historical_import_batches")
      .update({ status: "reviewing" })
      .eq("id", batchId)
      .select("id,status")
      .single(),
    "start canonical import review",
  );
}
if (batch.status === "reviewing") {
  batch = await requireData(
    commissioner
      .from("historical_import_batches")
      .update({
        status: "approved",
        approved_by: commissionerId,
        approved_at: "2026-07-30T00:00:00Z",
      })
      .eq("id", batchId)
      .select("id,status")
      .single(),
    "approve canonical import",
  );
}

const firstCommit = await requireData(
  commissioner.rpc("commit_historical_import", {
    target_batch_id: batchId,
    normalized_preview: preview,
  }),
  "commit canonical normalized preview",
);
const exactRetry = await requireData(
  commissioner.rpc("commit_historical_import", {
    target_batch_id: batchId,
    normalized_preview: preview,
  }),
  "retry canonical normalized preview",
);

const [review, storedCommit] = await Promise.all([
  requireData(
    commissioner
      .from("historical_import_batch_review")
      .select("*")
      .eq("batch_id", batchId)
      .single(),
    "read canonical batch review",
  ),
  requireData(
    commissioner
      .from("historical_import_commits")
      .select("record_counts,reconciliation")
      .eq("batch_id", batchId)
      .single(),
    "read canonical stored commit",
  ),
]);

const expectedCounts = {
  matchups: 80,
  weekly_results: 160,
  weekly_awards: 14,
  financial_obligations: 49,
  payments: 43,
  payment_allocations: 43,
  external_cash_events: 1,
};
for (const [recordKind, expectedCount] of Object.entries(expectedCounts)) {
  if (storedCommit.record_counts[recordKind] !== expectedCount) {
    throw new Error(
      `Canonical ${recordKind} count was ${storedCommit.record_counts[recordKind]}, expected ${expectedCount}`,
    );
  }
}
if (
  JSON.stringify(stableJson(storedCommit.reconciliation)) !==
  JSON.stringify(stableJson(preview.reconciliation))
) {
  throw new Error("Stored reconciliation does not match the approved preview");
}
if (review.source_row_count !== workbookRows.extraction.row_count) {
  throw new Error("Stored source row count does not match lossless extraction");
}
if (firstCommit.status !== "committed" && firstCommit.status !== "already_committed") {
  throw new Error(`Unexpected first commit status: ${firstCommit.status}`);
}
if (exactRetry.status !== "already_committed") {
  throw new Error(`Exact retry was not idempotent: ${exactRetry.status}`);
}

process.stdout.write(
  `${JSON.stringify(
    {
      target: "local-only",
      source_sha256: manifest.source.sha256,
      source_rows: review.source_row_count,
      team_mappings: preview.teams.length,
      financial_label_mappings: 18,
      resolved_issues: manifest.known_issues.length,
      commit_status: firstCommit.status,
      retry_status: exactRetry.status,
      record_counts: storedCommit.record_counts,
      reconciliation: storedCommit.reconciliation,
    },
    null,
    2,
  )}\n`,
);
