#!/usr/bin/env node
// Version branches, changelogs and pull requests for package.json projects
// (convrtrjs and friends). Called by the wrappers in ../release.sh.
//
//   release.mjs version              print the package.json version
//   release.mjs set <x.y.z>          set the version (asks first)
//   release.mjs bump <part>          bump major|minor|patch (asks first)
//   release.mjs branch [part]        bump, create branch v-x.y.z and its changelog
//   release.mjs check-branch         check the branch matches the version before a push
//                                    (--report: just say whether it matches)
//   release.mjs pr [--dry-run]       open a PR to main from the changelog
//
// No dependencies, so it runs under whichever node the project's .nvmrc picks.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createInterface } from 'node:readline';
import { dirname } from 'node:path';

const PARTS = ['major', 'minor', 'patch'];
const TEMPLATE = '_templates/0.0.0.md';
const PR_BASE = 'main';

class Exit extends Error {
	constructor(message, code = 1) {
		super(message);
		this.code = code;
	}
}

// Prompts
// -----------------------------------------------------------------------------

// One reader for the whole run, so piped answers aren't dropped between questions
let reader;
let bufferedLines = [];
let waiting = [];

function ask(question) {
	if (!reader) {
		reader = createInterface({ input: process.stdin });
		reader.on('line', (line) => {
			if (waiting.length) {
				waiting.shift()(line);
			} else {
				bufferedLines.push(line);
			}
		});
		reader.on('close', () => {
			while (waiting.length) {
				waiting.shift()('');
			}
		});
	}
	process.stdout.write(question);
	if (bufferedLines.length) {
		return Promise.resolve(bufferedLines.shift().trim());
	}
	return new Promise((resolve) => {
		waiting.push((line) => resolve(line.trim()));
	});
}

async function confirm(question) {
	return (await ask(`${question} (y/n) `)).toLowerCase() === 'y';
}

// Git
// -----------------------------------------------------------------------------

function git(...args) {
	const result = spawnSync('git', args, { encoding: 'utf8' });
	if (result.error) {
		throw new Exit(`Couldn't run git: ${result.error.message}`);
	}
	return { ok: result.status === 0, out: result.stdout.trim(), err: result.stderr.trim() };
}

function currentBranch() {
	const result = git('symbolic-ref', '--short', 'HEAD');
	if (!result.ok) {
		throw new Exit('Not on a branch (detached HEAD?)');
	}
	return result.out;
}

// package.json and package-lock.json
// -----------------------------------------------------------------------------

function readJson(file) {
	if (!existsSync(file)) {
		throw new Exit(`${file} not found. Are you in the project folder?`);
	}
	const text = readFileSync(file, 'utf8');
	try {
		return { text, data: JSON.parse(text) };
	} catch (error) {
		throw new Exit(`${file} isn't valid JSON: ${error.message}`);
	}
}

function getVersion() {
	const { data } = readJson('package.json');
	if (typeof data.version !== 'string') {
		throw new Exit('package.json has no version field');
	}
	return data.version;
}

function parseVersion(version) {
	const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(version);
	if (!match) {
		throw new Exit(`"${version}" isn't a x.y.z version`);
	}
	return match.slice(1).map(Number);
}

function bumpVersion(version, part) {
	const [major, minor, patch] = parseVersion(version);
	if (part === 'major') {
		return `${major + 1}.0.0`;
	}
	if (part === 'minor') {
		return `${major}.${minor + 1}.0`;
	}
	return `${major}.${minor}.${patch + 1}`;
}

// Replaces the top-level version in package.json without touching the rest of
// the file's formatting, then checks nothing else changed.
function writePackageVersion(from, to) {
	const { text, data } = readJson('package.json');
	const pattern = new RegExp(`("version"\\s*:\\s*")${from.replace(/\./g, '\\.')}(")`);
	const updated = text.replace(pattern, `$1${to}$2`);
	const check = JSON.parse(updated);
	if (check.version !== to || JSON.stringify({ ...check, version: from }) !== JSON.stringify(data)) {
		throw new Exit("Couldn't safely update the version in package.json. Nothing was changed.");
	}
	writeFileSync('package.json', updated);
}

// Updates the project's own version entries in package-lock.json, keeping
// npm's 2-space format and the file's line endings.
function writeLockVersion(to) {
	if (!existsSync('package-lock.json')) {
		return false;
	}
	const { text, data } = readJson('package-lock.json');
	data.version = to;
	if (data.packages && data.packages['']) {
		data.packages[''].version = to;
	}
	const eol = text.includes('\r\n') ? '\r\n' : '\n';
	writeFileSync('package-lock.json', JSON.stringify(data, null, 2).replace(/\n/g, eol) + eol);
	return true;
}

async function changeVersion(to) {
	const from = getVersion();
	parseVersion(to);
	console.log(`Current version: ${from}`);
	console.log(`New version: ${to}`);
	if (!(await confirm('Are you sure you want to change the version?'))) {
		throw new Exit('Version change canceled');
	}
	writePackageVersion(from, to);
	const lock = writeLockVersion(to);
	console.log(`Version changed to ${to}${lock ? ' (package.json and package-lock.json)' : ''}`);
	return to;
}

// Changelog
// -----------------------------------------------------------------------------

function today() {
	// en-CA formats as YYYY-MM-DD
	return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/London' }).format(new Date());
}

function changelogPath(version) {
	const [major, minor] = parseVersion(version);
	return `changelog/${major}/${major}.${minor}/${version}.md`;
}

function createChangelog(version, tag) {
	const file = changelogPath(version);
	if (existsSync(file)) {
		console.log(`Changelog already exists, left as it is: ${file}`);
		return;
	}
	const text = readFileSync(TEMPLATE, 'utf8')
		.replace('title: "0.0.0"', `title: "${version}"`)
		.replace('date: "2025-01-01"', `date: "${today()}"`)
		.replace(/^(tags:[^\r\n]*)(\r?\n)/m, `$1$2 - ${tag}$2`);
	mkdirSync(dirname(file), { recursive: true });
	writeFileSync(file, text);
	console.log(`Changelog file created: ${file}`);
}

// Splits a changelog into its front matter fields and the body after it.
// Only handles what the template uses: key: value lines and "tags:" lists.
function readChangelog(file) {
	const text = readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
	const match = /^---\n([\s\S]*?)\n---\n?([\s\S]*)$/.exec(text);
	if (!match) {
		throw new Exit(`${file} has no front matter`);
	}
	const fields = {};
	const tags = [];
	let inTags = false;
	for (const line of match[1].split('\n')) {
		const item = /^\s+-\s+(.+?)\s*$/.exec(line);
		if (inTags && item) {
			tags.push(item[1].replace(/^"(.*)"$/, '$1'));
			continue;
		}
		inTags = false;
		const field = /^([\w-]+):\s*(.*?)\s*$/.exec(line);
		if (field) {
			fields[field[1]] = field[2].replace(/^"(.*)"$/, '$1');
			inTags = field[1] === 'tags';
		}
	}
	return { fields, tags, body: match[2].trim() };
}

// Commands
// -----------------------------------------------------------------------------

async function branch(part) {
	if (!part) {
		console.log('No version type provided. Please choose one of the following:');
		PARTS.forEach((name, i) => console.log(`${i + 1}) ${name}`));
		part = PARTS[Number(await ask('Enter your choice (1/2/3): ')) - 1];
		if (!part) {
			throw new Exit('Invalid choice. Aborting.');
		}
	}
	if (!PARTS.includes(part)) {
		throw new Exit("Invalid version type. Use 'major', 'minor', or 'patch'.");
	}

	// Check everything before changing anything
	const next = bumpVersion(getVersion(), part);
	const name = `v-${next}`;
	if (git('rev-parse', '--verify', '--quiet', `refs/heads/${name}`).ok) {
		throw new Exit(`Branch ${name} already exists`);
	}
	if (!existsSync(TEMPLATE)) {
		throw new Exit(`Template file ${TEMPLATE} not found`);
	}

	await changeVersion(next);
	const checkout = git('checkout', '-b', name);
	if (!checkout.ok) {
		throw new Exit(`Failed to create branch ${name}: ${checkout.err}\nThe version change is still in package.json.`);
	}
	console.log(`New branch created and checked out: ${name}`);
	createChangelog(next, part);
}

// With report set, only says whether they match (exit 1 if not), for vcheck
async function checkBranch(report) {
	const version = getVersion();
	const branch = currentBranch();
	if (branch === `v-${version}`) {
		console.log(report ? `✔ Branch ${branch} matches version ${version}` : `Pushing changes to ${version}`);
		return;
	}
	if (report) {
		throw new Exit(`✘ Branch ${branch} doesn't match version ${version} (expected v-${version})`);
	}
	console.log('Branch name does not match the version in package.json.');
	if (!(await confirm('Do you still want to push the changes?'))) {
		throw new Exit('Push was aborted');
	}
}

function pullRequest(dryRun) {
	const version = getVersion();
	const file = changelogPath(version);
	if (!existsSync(file)) {
		throw new Exit(`❌ Changelog not found at ${file}`);
	}
	const { fields, tags, body } = readChangelog(file);
	if (fields.date !== today()) {
		throw new Exit(`❌ Date in changelog (${fields.date}) does not match today's date (${today()})`);
	}

	const args = ['pr', 'create',
		'--title', `V ${version}`,
		'--body', body,
		'--base', PR_BASE,
		'--head', currentBranch(),
		'--assignee', '@me',
		...tags.flatMap((tag) => ['--label', tag])];

	if (dryRun) {
		console.log(`gh ${args.map((arg) => (/[\s"']/.test(arg) ? JSON.stringify(arg) : arg)).join(' ')}`);
		return;
	}
	const auth = spawnSync('gh', ['auth', 'token'], { encoding: 'utf8' });
	if (auth.error || auth.status !== 0) {
		throw new Exit("❌ GitHub CLI isn't logged in (or isn't installed). Run: gh auth login");
	}
	const result = spawnSync('gh', args, { stdio: 'inherit' });
	if (result.status !== 0) {
		throw new Exit('', result.status || 1);
	}
}

async function main([command, ...args]) {
	switch (command) {
		case 'version':
			console.log(getVersion());
			break;
		case 'set':
			if (!args[0]) {
				throw new Exit('Usage: setver <new_version>');
			}
			await changeVersion(args[0]);
			break;
		case 'bump':
			if (!PARTS.includes(args[0])) {
				throw new Exit('Usage: nver <major|minor|patch>');
			}
			await changeVersion(bumpVersion(getVersion(), args[0]));
			break;
		case 'branch':
			await branch(args[0]);
			break;
		case 'check-branch':
			await checkBranch(args.includes('--report'));
			break;
		case 'pr':
			pullRequest(args.includes('--dry-run'));
			break;
		default:
			throw new Exit('Usage: release.mjs version|set|bump|branch|check-branch|pr');
	}
}

try {
	await main(process.argv.slice(2));
	process.exitCode = 0;
} catch (error) {
	if (!(error instanceof Exit)) {
		throw error;
	}
	if (error.message) {
		console.error(error.message);
	}
	process.exitCode = error.code;
} finally {
	reader?.close();
}
