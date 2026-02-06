#!/usr/bin/env bun
/**
 * Release script for lacy-shell
 *
 * Usage:
 *   bun run release              # interactive — prompts for bump type
 *   bun run release patch        # patch bump  (1.5.3 → 1.5.4)
 *   bun run release minor        # minor bump  (1.5.3 → 1.6.0)
 *   bun run release major        # major bump  (1.5.3 → 2.0.0)
 *   bun run release 1.6.0        # explicit version
 */

import * as p from "@clack/prompts";
import pc from "picocolors";
import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const ROOT = resolve(import.meta.dirname, "..");
const PACKAGE_JSONS = [
	resolve(ROOT, "package.json"),
	resolve(ROOT, "packages/lacy/package.json"),
];

// ── Helpers ──────────────────────────────────────────────────────────────────

function run(cmd: string, opts?: { cwd?: string; stdio?: "inherit" | "pipe" }) {
	return execSync(cmd, {
		cwd: opts?.cwd ?? ROOT,
		stdio: opts?.stdio ?? "pipe",
		encoding: "utf-8",
	});
}

function readJson(path: string) {
	return JSON.parse(readFileSync(path, "utf-8"));
}

function writeJson(path: string, data: Record<string, unknown>) {
	writeFileSync(path, JSON.stringify(data, null, 2) + "\n");
}

function bumpVersion(
	current: string,
	type: "patch" | "minor" | "major",
): string {
	const [major, minor, patch] = current.split(".").map(Number);
	switch (type) {
		case "major":
			return `${major + 1}.0.0`;
		case "minor":
			return `${major}.${minor + 1}.0`;
		case "patch":
			return `${major}.${minor}.${patch + 1}`;
	}
}

function cancelled(): never {
	p.cancel("Release cancelled.");
	process.exit(0);
}

// ── npm publish with OTP ─────────────────────────────────────────────────────

async function publishNpm(cwd: string) {
	const MAX_ATTEMPTS = 5;
	const spinner = p.spinner();

	// First attempt: without OTP
	spinner.start("Publishing to npm");
	try {
		run("npm publish --access public", { cwd });
		spinner.stop(pc.green("Published to npm"));
		return;
	} catch (err: unknown) {
		const msg = err instanceof Error ? err.message : String(err);
		if (!msg.includes("EOTP") && !msg.includes("one-time pass")) {
			spinner.stop(pc.red("npm publish failed"));
			p.log.error(msg);
			p.log.info(
				`Retry manually: ${pc.cyan("cd packages/lacy && npm publish --access public")}`,
			);
			return;
		}
		spinner.stop("OTP required");
	}

	// OTP required — prompt interactively
	for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
		const otp = await p.text({
			message: `Enter npm OTP${attempt > 1 ? pc.dim(` (attempt ${attempt}/${MAX_ATTEMPTS})`) : ""}`,
			placeholder: "123456",
			validate: (v) => {
				if (!v || !/^\d{6}$/.test(v.trim())) return "OTP must be 6 digits";
			},
		});

		if (p.isCancel(otp)) {
			p.log.warn("Skipping npm publish");
			return;
		}

		const spinner = p.spinner();
		spinner.start("Publishing to npm");
		try {
			run(`npm publish --access public --otp ${otp}`, { cwd });
			spinner.stop(pc.green("Published to npm"));
			return;
		} catch (err: unknown) {
			const msg = err instanceof Error ? err.message : String(err);
			if (msg.includes("EOTP") || msg.includes("one-time pass")) {
				spinner.stop(pc.yellow("OTP expired or invalid"));
				continue;
			}
			spinner.stop(pc.red("npm publish failed"));
			p.log.error(msg);
			p.log.info(
				`Retry manually: ${pc.cyan("cd packages/lacy && npm publish --access public")}`,
			);
			return;
		}
	}

	p.log.error(`Failed after ${MAX_ATTEMPTS} OTP attempts`);
	p.log.info(
		`Retry manually: ${pc.cyan("cd packages/lacy && npm publish --access public")}`,
	);
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
	console.clear();
	p.intro(pc.magenta(pc.bold("  Lacy Shell — Release  ")));

	// Preflight checks
	const preflight = p.spinner();
	preflight.start("Running preflight checks");

	const status = run("git status --porcelain").trim();
	if (status) {
		preflight.stop(pc.red("Working tree is not clean"));
		p.log.error("Commit or stash changes first:");
		console.log(pc.dim(status));
		process.exit(1);
	}

	const branch = run("git branch --show-current").trim();
	if (branch !== "main") {
		preflight.stop(pc.red(`On branch '${branch}', not 'main'`));
		process.exit(1);
	}

	preflight.stop("Preflight OK");

	// Current version
	const rootPkg = readJson(PACKAGE_JSONS[0]);
	const currentVersion: string = rootPkg.version;

	// Determine new version
	const arg = process.argv[2];
	let newVersion: string;

	if (arg === "patch" || arg === "minor" || arg === "major") {
		newVersion = bumpVersion(currentVersion, arg);
	} else if (arg && /^\d+\.\d+\.\d+$/.test(arg)) {
		newVersion = arg;
	} else {
		const selected = await p.select({
			message: `Current version: ${pc.cyan(currentVersion)}. Bump type?`,
			options: [
				{
					value: "patch" as const,
					label: "patch",
					hint: `${currentVersion} → ${bumpVersion(currentVersion, "patch")}`,
				},
				{
					value: "minor" as const,
					label: "minor",
					hint: `${currentVersion} → ${bumpVersion(currentVersion, "minor")}`,
				},
				{
					value: "major" as const,
					label: "major",
					hint: `${currentVersion} → ${bumpVersion(currentVersion, "major")}`,
				},
			],
		});

		if (p.isCancel(selected)) cancelled();
		newVersion = bumpVersion(currentVersion, selected);
	}

	const tag = `v${newVersion}`;

	const proceed = await p.confirm({
		message: `Release ${pc.cyan(currentVersion)} → ${pc.green(newVersion)} (${tag})?`,
	});
	if (p.isCancel(proceed) || !proceed) cancelled();

	// 1. Bump versions
	const bumpSpinner = p.spinner();
	bumpSpinner.start("Bumping versions");
	for (const path of PACKAGE_JSONS) {
		const pkg = readJson(path);
		pkg.version = newVersion;
		writeJson(path, pkg);
	}
	bumpSpinner.stop(
		`Updated ${pc.cyan("package.json")} → ${pc.green(newVersion)}`,
	);

	// 2. Changelog
	const lastTag = run(
		"git describe --tags --abbrev=0 2>/dev/null || echo ''",
	).trim();
	let changelog = "";
	if (lastTag) {
		changelog = run(
			`git log ${lastTag}..HEAD --pretty=format:"- %s (%h)" --no-merges`,
		).trim();
	}
	if (!changelog) changelog = `- Release ${tag}`;

	p.note(changelog, "Changelog");

	// 3. Commit + tag
	const gitSpinner = p.spinner();
	gitSpinner.start("Committing and tagging");
	run("git add package.json packages/lacy/package.json");
	run(`git commit -m "release: ${tag}" --no-verify`);
	run(`git tag ${tag}`);
	gitSpinner.stop(`Committed and tagged ${pc.green(tag)}`);

	// 4. Push
	const pushSpinner = p.spinner();
	pushSpinner.start("Pushing to GitHub");
	run("git push origin main --no-verify");
	run(`git push origin ${tag}`);
	pushSpinner.stop("Pushed to GitHub");

	// 5. GitHub release
	const releaseSpinner = p.spinner();
	releaseSpinner.start("Creating GitHub release");
	const releaseNotes = `## Changes\n\n${changelog}`;
	run(
		`gh release create ${tag} --title "${tag}" --notes "${releaseNotes.replace(/"/g, '\\"')}"`,
	);
	releaseSpinner.stop("GitHub release created");

	// 6. npm publish
	await publishNpm(resolve(ROOT, "packages/lacy"));

	// Done
	p.outro(
		`${pc.green("✓")} Released ${pc.green(tag)} — ${pc.cyan(`https://github.com/lacymorrow/lacy/releases/tag/${tag}`)}`,
	);
}

main().catch((err) => {
	p.log.error(err.message ?? err);
	process.exit(1);
});
