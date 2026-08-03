import { execFileSync } from "node:child_process";
import { mkdir } from "node:fs/promises";

import { chromium, type FullConfig } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";

const COMMISSIONER_EMAIL = "dev-commissioner@sweetnapadads.test";

function localSupabaseEnvironment() {
  const output = execFileSync(
    "./node_modules/.bin/supabase",
    ["status", "-o", "env"],
    { encoding: "utf8" },
  );
  return Object.fromEntries(
    output.split("\n").flatMap((line) => {
      const match = line.match(/^([A-Z_]+)=(?:"(.*)"|(.*))$/);
      return match ? [[match[1], match[2] ?? match[3] ?? ""]] : [];
    }),
  );
}

export default async function globalSetup(config: FullConfig) {
  const environment = localSupabaseEnvironment();
  const apiUrl = environment.API_URL;
  const serviceRoleKey = environment.SERVICE_ROLE_KEY;
  if (!apiUrl || !serviceRoleKey) {
    throw new Error("Local Supabase API_URL and SERVICE_ROLE_KEY are required for browser tests.");
  }

  const admin = createClient(apiUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const fixtureTeamId = "e2000000-0000-4000-8000-000000000001";
  const fixtureSeasonTeamId = "e2000000-0000-4000-8000-000000000002";
  const { error: teamError } = await admin.from("teams").upsert({
    id: fixtureTeamId,
    league_id: "d0000000-0000-4000-8000-000000000002",
    name: "Browser Test Opponent",
    slug: "browser-test-opponent",
    created_by: "d0000000-0000-4000-8000-000000000001",
  });
  const { error: seasonTeamError } = await admin.from("season_teams").upsert({
    id: fixtureSeasonTeamId,
    league_id: "d0000000-0000-4000-8000-000000000002",
    season_id: "d0000000-0000-4000-8000-000000000004",
    team_id: fixtureTeamId,
    name: "Browser Test Opponent 2026",
    abbreviation: "BTO",
    status: "active",
    created_by: "d0000000-0000-4000-8000-000000000001",
  });
  if (teamError || seasonTeamError) {
    throw new Error("Could not prepare the local browser-test league fixture.");
  }

  const fixtureMatchupId = "e2000000-0000-4000-8000-000000000003";
  const fixtureResultIds = [
    "e2000000-0000-4000-8000-000000000004",
    "e2000000-0000-4000-8000-000000000005",
  ];
  const { error: matchupError } = await admin.from("matchups").upsert({
    id: fixtureMatchupId,
    league_id: "d0000000-0000-4000-8000-000000000002",
    season_id: "d0000000-0000-4000-8000-000000000004",
    week: 1,
    phase: "regular_season",
    source_type: "espn",
    source_key: "browser-test:espn:week-1:matchup-1",
  });
  const { error: resultsError } = await admin.from("weekly_results").upsert([
    {
      id: fixtureResultIds[0],
      league_id: "d0000000-0000-4000-8000-000000000002",
      season_id: "d0000000-0000-4000-8000-000000000004",
      matchup_id: fixtureMatchupId,
      season_team_id: "d0000000-0000-4000-8000-000000000008",
      opponent_season_team_id: fixtureSeasonTeamId,
      score: 128.42,
      result: "win",
      source_type: "espn",
      source_key: "browser-test:espn:week-1:result-development",
    },
    {
      id: fixtureResultIds[1],
      league_id: "d0000000-0000-4000-8000-000000000002",
      season_id: "d0000000-0000-4000-8000-000000000004",
      matchup_id: fixtureMatchupId,
      season_team_id: fixtureSeasonTeamId,
      opponent_season_team_id: "d0000000-0000-4000-8000-000000000008",
      score: 91.18,
      result: "loss",
      source_type: "espn",
      source_key: "browser-test:espn:week-1:result-opponent",
    },
  ]);
  if (matchupError || resultsError) {
    throw new Error("Could not prepare accepted weekly results for browser tests.");
  }

  const { error: awardError } = await admin.rpc("derive_weekly_award", {
    target_season_id: "d0000000-0000-4000-8000-000000000004",
    target_week: 1,
  });
  if (awardError) {
    throw new Error(`Could not derive the browser-test weekly award: ${awardError.message}`);
  }

  const { data, error } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email: COMMISSIONER_EMAIL,
    options: { redirectTo: "http://127.0.0.1:3000/auth/callback?next=/dashboard" },
  });
  if (error || !data.properties?.hashed_token) {
    throw new Error("Could not create the local commissioner browser session.");
  }

  await mkdir("playwright/.auth", { recursive: true });
  const browser = await chromium.launch({ channel: "chrome" });
  const page = await browser.newPage();
  const callback = new URL("http://127.0.0.1:3000/auth/callback");
  callback.searchParams.set("token_hash", data.properties.hashed_token);
  callback.searchParams.set("type", "magiclink");
  callback.searchParams.set("next", "/dashboard");
  await page.goto(callback.toString());
  await page.waitForURL("**/dashboard", { timeout: 30_000 });
  await page.context().storageState({ path: "playwright/.auth/commissioner.json" });
  await browser.close();

  if (!config.projects.length) {
    throw new Error("At least one Playwright project must be configured.");
  }
}
