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

import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { createInterface } from "node:readline";

const ROOT = resolve(import.meta.dirname, "..");
const PACKAGE_JSONS = [
	resolve(ROOT, "package.json"),
	resolve(ROOT, "packages/lacy/package.json"),
];

// ── Helpers ──────────────────────────────────────────────────────────────────

function run(cmd: string, opts?: { cwd?: string; stdio?: "inherit" | "pipe" }) {
	console.log(`  $ ${cmd}`);
	return execSync(cmd, {
		cwd: opts?.cwd ?? ROOT,
		stdio: opts?.stdio ?? "inherit",
		encoding: "utf-8",
	});
}

function runQuiet(cmd: string): string {
	return execSync(cmd, { cwd: ROOT, encoding: "utf-8" }).trim();
}

function readJson(path: string) {
	return JSON.parse(readFileSync(path, "utf-8"));
}

function writeJson(path: string, data: Record<string, unknown>) {
	writeFileSync(path, JSON.stringify(data, null, 2) + "\n");
}

function ask(question: string): Promise<string> {
	const rl = createInterface({ input: process.stdin, output: process.stdout });
	return new Promise((res) =>
		rl.question(question, (answer) => {
			rl.close();
			res(answer.trim());
		}),
	);
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

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
	// Ensure clean working tree
	const status = runQuiet("git status --porcelain");
	if (status) {
		console.error("Error: working tree is not clean. Commit or stash changes first.");
		console.error(status);
		process.exit(1);
	}

	// Ensure on main
	const branch = runQuiet("git branch --show-current");
	if (branch !== "main") {
		console.error(`Error: must be on 'main' branch (currently on '${branch}')`);
		process.exit(1);
	}

	// Current version from root package.json
	const rootPkg = readJson(PACKAGE_JSONS[0]);
	const currentVersion: string = rootPkg.version;
	console.log(`\nCurrent version: ${currentVersion}`);

	// Determine new version
	let arg = process.argv[2];
	let newVersion: string;

	if (arg === "patch" || arg === "minor" || arg === "major") {
		newVersion = bumpVersion(currentVersion, arg);
	} else if (arg && /^\d+\.\d+\.\d+$/.test(arg)) {
		newVersion = arg;
	} else {
		// Interactive
		console.log(`\n  1) patch → ${bumpVersion(currentVersion, "patch")}`);
		console.log(`  2) minor → ${bumpVersion(currentVersion, "minor")}`);
		console.log(`  3) major → ${bumpVersion(currentVersion, "major")}`);
		const choice = await ask("\nBump type [1/2/3]: ");
		const map: Record<string, "patch" | "minor" | "major"> = {
			"1": "patch",
			"2": "minor",
			"3": "major",
			patch: "patch",
			minor: "minor",
			major: "major",
		};
		const type = map[choice];
		if (!type) {
			console.error("Invalid choice");
			process.exit(1);
		}
		newVersion = bumpVersion(currentVersion, type);
	}

	const tag = `v${newVersion}`;
	console.log(`\nReleasing: ${currentVersion} → ${newVersion} (${tag})\n`);

	// 1. Update all package.json files
	console.log("Updating package.json versions...");
	for (const path of PACKAGE_JSONS) {
		const pkg = readJson(path);
		pkg.version = newVersion;
		writeJson(path, pkg);
		console.log(`  ✓ ${path.replace(ROOT + "/", "")}`);
	}

	// 2. Build changelog from commits since last tag
	const lastTag = runQuiet("git describe --tags --abbrev=0 2>/dev/null || echo ''");
	let changelog = "";
	if (lastTag) {
		const log = runQuiet(
			`git log ${lastTag}..HEAD --pretty=format:"- %s (%h)" --no-merges`,
		);
		if (log) {
			changelog = log;
		}
	}
	if (!changelog) {
		changelog = "- Release " + tag;
	}

	console.log(`\nChangelog:\n${changelog}\n`);

	// 3. Commit
	console.log("Committing...");
	run(`git add package.json packages/lacy/package.json`);
	run(
		`git commit -m "release: ${tag}" --no-verify`,
	);

	// 4. Tag
	console.log("Tagging...");
	run(`git tag ${tag}`);

	// 5. Push
	console.log("Pushing...");
	run(`git push origin main --no-verify`);
	run(`git push origin ${tag}`);

	// 6. GitHub release
	console.log("Creating GitHub release...");
	const releaseNotes = `## Changes\n\n${changelog}`;
	run(
		`gh release create ${tag} --title "${tag}" --notes "${releaseNotes.replace(/"/g, '\\"')}"`,
	);

	// 7. Publish npm package
	console.log("\nPublishing to npm...");
	const npmPkgDir = resolve(ROOT, "packages/lacy");
	try {
		run("npm publish --access public", { cwd: npmPkgDir });
		console.log("  ✓ Published to npm");
	} catch {
		console.error(
			"  ✗ npm publish failed (may need `npm login` or OTP). You can retry with:",
		);
		console.error(`    cd packages/lacy && npm publish --access public`);
	}

	console.log(`\n✓ Released ${tag}`);
	console.log(
		`  https://github.com/lacymorrow/lacy/releases/tag/${tag}`,
	);
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
