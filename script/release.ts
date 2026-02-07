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
 *   bun run release --beta       # beta release (1.5.3 → 1.5.4-beta.0)
 *   bun run release:beta         # alias for --beta
 */

import * as p from "@clack/prompts";
import pc from "picocolors";
import { execSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const ROOT = resolve(import.meta.dirname, "..");
const PACKAGE_JSONS = [
	resolve(ROOT, "package.json"),
	resolve(ROOT, "packages/lacy/package.json"),
];
const HOMEBREW_TAP = resolve(ROOT, "../homebrew-tap");
const HOMEBREW_FORMULA = resolve(HOMEBREW_TAP, "Formula/lacy.rb");

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
	const base = current.replace(/-.*$/, ""); // strip any prerelease suffix
	const [major, minor, patch] = base.split(".").map(Number);
	switch (type) {
		case "major":
			return `${major + 1}.0.0`;
		case "minor":
			return `${major}.${minor + 1}.0`;
		case "patch":
			return `${major}.${minor}.${patch + 1}`;
	}
}

function bumpBeta(current: string, bumpType: "patch" | "minor" | "major"): string {
	const betaMatch = current.match(/^(.+)-beta\.(\d+)$/);
	if (betaMatch) {
		// Already a beta — increment the beta number
		return `${betaMatch[1]}-beta.${Number(betaMatch[2]) + 1}`;
	}
	// Not a beta — bump the base version and start at beta.0
	const base = bumpVersion(current, bumpType);
	return `${base}-beta.0`;
}

function cancelled(): never {
	p.cancel("Release cancelled.");
	process.exit(0);
}

/** Check if an execSync error is an npm OTP error */
function isOtpError(err: unknown): boolean {
	const check = (s: string) =>
		s.includes("EOTP") || s.includes("one-time pass");
	if (err instanceof Error) {
		if (check(err.message)) return true;
		if ("stderr" in err && typeof err.stderr === "string" && check(err.stderr))
			return true;
		if ("stdout" in err && typeof err.stdout === "string" && check(err.stdout))
			return true;
	}
	return check(String(err));
}

/** Get a human-readable error message from an execSync error */
function errorText(err: unknown): string {
	if (err instanceof Error) {
		if ("stderr" in err && typeof err.stderr === "string" && err.stderr.trim())
			return err.stderr.trim();
		return err.message;
	}
	return String(err);
}

// ── npm publish ──────────────────────────────────────────────────────────────

async function publishNpm(cwd: string, beta = false): Promise<boolean> {
	const tagFlag = beta ? " --tag beta" : "";
	// First attempt: without OTP (works if token is valid and 2FA isn't required)
	const spinner = p.spinner();
	spinner.start(`Publishing to npm${beta ? " (beta)" : ""}`);
	try {
		run(`npm publish --access public${tagFlag}`, { cwd });
		spinner.stop(pc.green(`Published to npm${beta ? " (beta)" : ""}`));
		return true;
	} catch (err: unknown) {
		spinner.stop(pc.yellow("npm publish failed"));
		p.log.message(pc.dim(errorText(err)));
	}

	// Retry loop — let the user login, provide OTP, or skip
	while (true) {
		const action = await p.select({
			message: "How would you like to proceed?",
			options: [
				{
					value: "otp" as const,
					label: "Enter OTP",
					hint: "publish with one-time password",
				},
				{
					value: "login" as const,
					label: "Log in to npm",
					hint: "run npm login, then retry",
				},
				{
					value: "retry" as const,
					label: "Retry publish",
					hint: "try again without OTP",
				},
				{
					value: "skip" as const,
					label: "Skip npm publish",
					hint: "continue to Homebrew",
				},
			],
		});

		if (p.isCancel(action)) {
			p.log.warn("Skipping npm publish");
			return false;
		}

		if (action === "skip") {
			p.log.info("Skipping npm publish");
			return false;
		}

		if (action === "login") {
			p.log.info("Running npm login...");
			try {
				run("npm login", { cwd, stdio: "inherit" });
				p.log.success("Logged in to npm");
			} catch {
				p.log.error("npm login failed");
			}
			continue;
		}

		// "otp" or "retry"
		let otpFlag = "";
		if (action === "otp") {
			const otp = await p.text({
				message: "npm OTP",
				placeholder: "123456",
				validate: (v) => {
					if (!v || !/^\d{6}$/.test(v.trim())) return "OTP must be 6 digits";
				},
			});

			if (p.isCancel(otp)) continue; // back to menu
			otpFlag = ` --otp ${otp}`;
		}

		const retrySpinner = p.spinner();
		retrySpinner.start("Publishing to npm");
		try {
			run(`npm publish --access public${tagFlag}${otpFlag}`, { cwd });
			retrySpinner.stop(pc.green("Published to npm"));
			return true;
		} catch (err: unknown) {
			retrySpinner.stop(pc.red("npm publish failed"));
			p.log.message(pc.dim(errorText(err)));
		}
	}
}

// ── Homebrew ─────────────────────────────────────────────────────────────────

async function publishHomebrew(tag: string, version: string) {
	if (!existsSync(HOMEBREW_FORMULA)) {
		p.log.warn(
			`Homebrew tap not found at ${pc.dim(HOMEBREW_FORMULA)}. Skipping.`,
		);
		return;
	}

	const doHomebrew = await p.confirm({
		message: "Update Homebrew formula?",
		initialValue: true,
	});
	if (p.isCancel(doHomebrew) || !doHomebrew) {
		p.log.info("Skipping Homebrew");
		return;
	}

	const brewSpinner = p.spinner();
	brewSpinner.start("Updating Homebrew formula");

	try {
		// Download the release tarball and compute SHA256
		const tarballUrl = `https://github.com/lacymorrow/lacy/archive/refs/tags/${tag}.tar.gz`;
		const sha256 = run(
			`curl -sL "${tarballUrl}" | shasum -a 256 | cut -d' ' -f1`,
		).trim();

		if (!sha256 || sha256.length !== 64) {
			brewSpinner.stop(pc.red("Failed to compute SHA256"));
			p.log.error(`Got: ${sha256}`);
			return;
		}

		// Update the formula
		let formula = readFileSync(HOMEBREW_FORMULA, "utf-8");
		formula = formula.replace(
			/url "https:\/\/github\.com\/lacymorrow\/lacy\/archive\/refs\/tags\/v[^"]+\.tar\.gz"/,
			`url "${tarballUrl}"`,
		);
		formula = formula.replace(
			/sha256 "[a-f0-9]+"/,
			`sha256 "${sha256}"`,
		);
		writeFileSync(HOMEBREW_FORMULA, formula);

		// Commit and push
		run("git add Formula/lacy.rb", { cwd: HOMEBREW_TAP });
		run(`git commit -m "lacy: update to ${tag}"`, { cwd: HOMEBREW_TAP });
		run("git push", { cwd: HOMEBREW_TAP });

		brewSpinner.stop(`Homebrew formula updated to ${pc.green(tag)}`);
	} catch (err: unknown) {
		brewSpinner.stop(pc.red("Homebrew update failed"));
		p.log.error(errorText(err));
		p.log.info(
			`Update manually: ${pc.cyan(`edit ${HOMEBREW_FORMULA}`)}`,
		);
	}
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
	const isBeta = process.argv.includes("--beta");
	const args = process.argv.slice(2).filter((a) => a !== "--beta");

	console.clear();
	p.intro(
		pc.magenta(
			pc.bold(isBeta ? "  Lacy Shell — Beta Release  " : "  Lacy Shell — Release  "),
		),
	);

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
	if (!isBeta && branch !== "main") {
		preflight.stop(pc.red(`On branch '${branch}', not 'main'`));
		process.exit(1);
	}

	preflight.stop("Preflight OK");

	// Current version
	const rootPkg = readJson(PACKAGE_JSONS[0]);
	const currentVersion: string = rootPkg.version;

	// Determine new version
	const arg = args[0];
	let newVersion: string;

	if (isBeta) {
		// Beta: pick a bump type then apply beta suffix
		const isAlreadyBeta = /-beta\.\d+$/.test(currentVersion);

		if (isAlreadyBeta) {
			// Already on a beta — offer to bump beta number or start fresh
			const selected = await p.select({
				message: `Current version: ${pc.cyan(currentVersion)}. Beta bump?`,
				options: [
					{
						value: "next" as const,
						label: "next beta",
						hint: `${currentVersion} → ${bumpBeta(currentVersion, "patch")}`,
					},
					{
						value: "patch" as const,
						label: "new patch beta",
						hint: `${currentVersion} → ${bumpVersion(currentVersion, "patch")}-beta.0`,
					},
					{
						value: "minor" as const,
						label: "new minor beta",
						hint: `${currentVersion} → ${bumpVersion(currentVersion, "minor")}-beta.0`,
					},
					{
						value: "major" as const,
						label: "new major beta",
						hint: `${currentVersion} → ${bumpVersion(currentVersion, "major")}-beta.0`,
					},
				],
			});

			if (p.isCancel(selected)) cancelled();
			newVersion =
				selected === "next"
					? bumpBeta(currentVersion, "patch")
					: `${bumpVersion(currentVersion, selected)}-beta.0`;
		} else {
			// Not a beta yet — bump type then add -beta.0
			if (arg === "patch" || arg === "minor" || arg === "major") {
				newVersion = bumpBeta(currentVersion, arg);
			} else {
				const selected = await p.select({
					message: `Current version: ${pc.cyan(currentVersion)}. Bump type for beta?`,
					options: [
						{
							value: "patch" as const,
							label: "patch",
							hint: `${currentVersion} → ${bumpBeta(currentVersion, "patch")}`,
						},
						{
							value: "minor" as const,
							label: "minor",
							hint: `${currentVersion} → ${bumpBeta(currentVersion, "minor")}`,
						},
						{
							value: "major" as const,
							label: "major",
							hint: `${currentVersion} → ${bumpBeta(currentVersion, "major")}`,
						},
					],
				});

				if (p.isCancel(selected)) cancelled();
				newVersion = bumpBeta(currentVersion, selected);
			}
		}
	} else if (arg === "patch" || arg === "minor" || arg === "major") {
		newVersion = bumpVersion(currentVersion, arg);
	} else if (arg && /^\d+\.\d+\.\d+/.test(arg)) {
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
	run(`git push origin ${branch} --no-verify`);
	run(`git push origin ${tag}`);
	pushSpinner.stop("Pushed to GitHub");

	// 5. GitHub release
	const releaseSpinner = p.spinner();
	releaseSpinner.start("Creating GitHub release");
	const releaseNotes = `## Changes\n\n${changelog}`;
	run(
		`gh release create ${tag} --title "${tag}" --notes "${releaseNotes.replace(/"/g, '\\"')}"${isBeta ? " --prerelease" : ""}`,
	);
	releaseSpinner.stop("GitHub release created");

	// 6. npm publish
	await publishNpm(resolve(ROOT, "packages/lacy"), isBeta);

	// 7. Homebrew (skip for beta releases)
	if (!isBeta) {
		await publishHomebrew(tag, newVersion);
	} else {
		p.log.info("Skipping Homebrew for beta release");
	}

	// Done
	p.outro(
		`${pc.green("✓")} Released ${pc.green(tag)} — ${pc.cyan(`https://github.com/lacymorrow/lacy/releases/tag/${tag}`)}`,
	);
}

main().catch((err) => {
	p.log.error(err.message ?? err);
	process.exit(1);
});
