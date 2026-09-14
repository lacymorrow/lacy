import type { ShipConfig } from "@lacymorrow/shipx";

// Release pipeline for lacy. Run with `bun run release` (or `shipx patch`).
// Preflight refuses a dirty tree or a branch other than main. Every git and
// gh call goes through an argv array, so commit subjects in the changelog
// are never interpreted by a shell.

export default {
	// Both package.json files carry the version; the root one is the source.
	packageJsonPaths: ["package.json", "packages/lacy/package.json"],
	versionSource: "package.json",

	bumpFiles: [
		// The CLI reads its version from the installed git checkout and falls
		// back to this string when that fails (Homebrew installs).
		{
			path: "bin/lacy",
			pattern: /^VERSION_FALLBACK="[^"]*"/m,
			replacement: (v) => `VERSION_FALLBACK="${v}"`,
		},
		// npm lockfile: the top-level "version" and the root package entry
		// under "packages" -> "". Both sit inside the first 10 lines and are
		// the only "version" keys followed by a "lockfileVersion" or
		// "license" line, which keeps dependency versions untouched.
		{
			path: "packages/lacy/package-lock.json",
			pattern: /"version": "[^"]+"(,\n\s+"(?:lockfileVersion|license)")/g,
			replacement: (v) => `"version": "${v}"$1`,
		},
	],

	// No Rust here; stop shipx from probing for src-tauri.
	cargoWorkspaces: [],

	steps: {
		test: true,
		githubRelease: true,
		npm: true,
		homebrew: true,
	},

	// Runs the package.json "test" script before the bump; a failure stops
	// the release.
	testScript: "test",

	git: {
		releaseBranch: "main",
		tagPrefix: "v",
		commitMessage: "release: {tag}",
	},

	npm: {
		cwd: "packages/lacy",
		access: "public",
	},

	homebrew: {
		tapPath: "../homebrew-tap",
		formulaFile: "Formula/lacy.rb",
		repoSlug: "lacymorrow/lacy",
		commitMessage: "lacy: update to {tag}",
	},
} satisfies ShipConfig;
