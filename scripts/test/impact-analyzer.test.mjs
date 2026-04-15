// Unit tests for scripts/impact-analyzer.mjs
//
// Run:  cd scripts && npm test
//
// Tests the AST analysis (ts-morph + madge) end-to-end via spawnSync,
// so we exercise the real CLI path and exit codes.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const analyzer = join(__dirname, '..', 'impact-analyzer.mjs');
const fixtures = join(__dirname, 'fixtures');

function runAnalyzer(file, ...args) {
  return spawnSync('node', [analyzer, file, ...args], {
    cwd: fixtures,
    encoding: 'utf8',
  });
}

test('1. non-existent file exits with code 3', () => {
  const r = runAnalyzer('src/does-not-exist.ts', '--json');
  assert.equal(r.status, 3, `expected exit 3, got ${r.status}. stderr: ${r.stderr}`);
});

test('2. shared.ts has exactly 2 unique callers (consumer-a, consumer-b)', () => {
  const r = runAnalyzer('src/shared.ts', '--json');
  assert.equal(r.status, 0, `expected exit 0, got ${r.status}. stderr: ${r.stderr}`);
  const json = JSON.parse(r.stdout);
  assert.equal(
    json.ast.uniqueCallerCount,
    2,
    `expected 2 callers, got ${json.ast.uniqueCallerCount}: ${JSON.stringify(json.ast.uniqueCallers)}`
  );
});

test('3. shared.ts risk level is 🟢 (low fan-in)', () => {
  const r = runAnalyzer('src/shared.ts', '--json');
  const json = JSON.parse(r.stdout);
  assert.equal(json.risk.level, '🟢', `risk reasons: ${JSON.stringify(json.risk.reasons)}`);
});

test('4. --json flag produces valid parseable JSON on stdout', () => {
  const r = runAnalyzer('src/shared.ts', '--json');
  assert.doesNotThrow(
    () => JSON.parse(r.stdout),
    `stdout was not valid JSON: ${r.stdout.slice(0, 200)}`
  );
});

test('5. self-reference is filtered out (shared.ts not its own caller)', () => {
  const r = runAnalyzer('src/shared.ts', '--json');
  const json = JSON.parse(r.stdout);
  const selfReference = json.ast.uniqueCallers.find((c) => c.includes('shared.ts'));
  assert.equal(
    selfReference,
    undefined,
    `shared.ts found in its own caller list: ${selfReference}`
  );
});

test('6. security-critical keyword (auth) triggers risk boost', () => {
  const r = runAnalyzer('src/auth.ts', '--json');
  assert.ok(
    r.status === 0 || r.status === 1 || r.status === 2,
    `expected 0/1/2 exit, got ${r.status}. stderr: ${r.stderr}`
  );
  const json = JSON.parse(r.stdout);
  // auth.ts has 0 callers but the SECURITY_KEYWORDS check must still fire
  assert.equal(
    json.ast.uniqueCallerCount,
    0,
    `fixture auth.ts should have 0 callers, got ${json.ast.uniqueCallerCount}`
  );
  // Risk score must include the security reason
  const securityReason = json.risk.reasons.find((r) => r.includes('Security-critical keyword'));
  assert.ok(
    securityReason,
    `expected security-critical reason, got: ${JSON.stringify(json.risk.reasons)}`
  );
  // Score must be at least 3 (from SECURITY_KEYWORDS alone)
  assert.ok(
    json.risk.score >= 3,
    `expected score >= 3 from security heuristic, got ${json.risk.score}`
  );
});

test('7. generate API route missing parseClaudeJson + preventDuplicateStep is flagged', () => {
  const r = runAnalyzer('src/api/generate/pipeline/route.ts', '--json');
  // Exit code may be 0/1/2 depending on accumulated risk
  assert.ok(
    r.status === 0 || r.status === 1 || r.status === 2,
    `expected 0/1/2 exit, got ${r.status}. stderr: ${r.stderr}`
  );
  const json = JSON.parse(r.stdout);

  // Must flag missing parseClaudeJson (file calls anthropic.messages.create)
  const missingParser = json.risk.reasons.find((r) => r.includes('parseClaudeJson'));
  assert.ok(
    missingParser,
    `expected parseClaudeJson warning, got: ${JSON.stringify(json.risk.reasons)}`
  );

  // Must flag missing preventDuplicateStep (path matches /pipeline/route.ts)
  const missingGuard = json.risk.reasons.find((r) => r.includes('preventDuplicateStep'));
  assert.ok(
    missingGuard,
    `expected preventDuplicateStep warning, got: ${JSON.stringify(json.risk.reasons)}`
  );

  // Combined score must be at least 4 (2 + 2 from ADK pattern checks)
  assert.ok(
    json.risk.score >= 4,
    `expected score >= 4 from missing ADK patterns, got ${json.risk.score}`
  );
});
