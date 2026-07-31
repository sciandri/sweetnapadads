import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const requiredFiles = [
  "tracking/README.md",
  "tracking/CURRENT.md",
  "tracking/CHECKLIST.md",
  "tracking/templates/SESSION.md",
];

const errors = [];

for (const relativePath of requiredFiles) {
  if (!fs.existsSync(path.join(root, relativePath))) {
    errors.push(`Missing required tracking file: ${relativePath}`);
  }
}

const currentPath = path.join(root, "tracking/CURRENT.md");
if (fs.existsSync(currentPath)) {
  const current = fs.readFileSync(currentPath, "utf8");
  const requiredSections = [
    "## Current outcome",
    "## In progress",
    "## Next actions",
    "## Decisions in force",
    "## Known risks and blockers",
    "## Verification",
    "## Latest commit intent",
    "## Pickup instruction",
  ];

  for (const section of requiredSections) {
    if (!current.includes(section)) {
      errors.push(`CURRENT.md is missing section: ${section}`);
    }
  }

  if (!/- Last updated: \d{4}-\d{2}-\d{2}/.test(current)) {
    errors.push("CURRENT.md must contain an ISO-formatted Last updated date.");
  }

  if (!/- Session: \d{4}/.test(current)) {
    errors.push("CURRENT.md must contain a four-digit session number.");
  }
}

const sessionsDirectory = path.join(root, "tracking/sessions");
const sessionFiles = fs.existsSync(sessionsDirectory)
  ? fs
      .readdirSync(sessionsDirectory)
      .filter((name) => /^\d{4}-\d{4}-\d{2}-\d{2}-.+\.md$/.test(name))
  : [];

if (sessionFiles.length === 0) {
  errors.push("At least one numbered session log is required.");
}

if (errors.length > 0) {
  console.error("Session tracking validation failed:");
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exitCode = 1;
} else {
  console.log(
    `Session tracking is valid (${sessionFiles.length} session log${
      sessionFiles.length === 1 ? "" : "s"
    }).`,
  );
}
