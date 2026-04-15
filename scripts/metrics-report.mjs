#!/usr/bin/env node
// ADK metrics report — aggregate JSONL events into a markdown summary.
//
// Usage:
//   node scripts/metrics-report.mjs                    # default path
//   node scripts/metrics-report.mjs <path>             # custom JSONL
//   node scripts/metrics-report.mjs <path> --days=7    # filter window
//   node scripts/metrics-report.mjs <path> --json      # JSON output
//
// Default path resolves to ~/.claude/adk-metrics.jsonl (or %USERPROFILE%).

import { readFileSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';

const args = process.argv.slice(2);
const jsonOut = args.includes('--json');
const daysArg = args.find(a => a.startsWith('--days='));
const days = daysArg ? parseInt(daysArg.split('=')[1], 10) : null;

const positional = args.filter(a => !a.startsWith('--'));
const defaultPath = join(homedir(), '.claude', 'adk-metrics.jsonl');
const filePath = resolve(positional[0] || defaultPath);

if (!existsSync(filePath)) {
  console.error(`No metrics file at ${filePath}`);
  console.error('Hint: run the plugin once to generate events, or pass a different path.');
  process.exit(0);
}

const raw = readFileSync(filePath, 'utf8');
const lines = raw.split('\n').filter(Boolean);

const events = [];
let parseErrors = 0;
for (const line of lines) {
  try {
    events.push(JSON.parse(line));
  } catch {
    parseErrors++;
  }
}

// Day filter
const cutoff = days ? Date.now() - days * 24 * 60 * 60 * 1000 : 0;
const filtered = days
  ? events.filter(e => new Date(e.ts).getTime() >= cutoff)
  : events;

// Aggregate
const counts = {};
const byDay = {};
const sessions = new Set();
const riskFilesHit = {};
const retryHits = {};   // file_path → count of post_tool_failed events
const oversizeHits = {}; // file_path → count of oversize_blocked events

for (const e of filtered) {
  counts[e.event] = (counts[e.event] || 0) + 1;
  const day = (e.ts || '').slice(0, 10);
  byDay[day] = (byDay[day] || 0) + 1;
  if (e.session_id) sessions.add(e.session_id);
  if (e.event === 'risk_file_blocked' && e.file_path) {
    riskFilesHit[e.file_path] = (riskFilesHit[e.file_path] || 0) + 1;
  }
  if (e.event === 'post_tool_failed' && e.file_path) {
    retryHits[e.file_path] = (retryHits[e.file_path] || 0) + 1;
  }
  if (e.event === 'oversize_blocked' && e.file_path) {
    oversizeHits[e.file_path] = (oversizeHits[e.file_path] || 0) + 1;
  }
}

// Session durations (pair session_start with session_stop by session_id)
const sessionStarts = new Map();
const durations = [];
for (const e of filtered) {
  if (!e.session_id) continue;
  if (e.event === 'session_start') {
    sessionStarts.set(e.session_id, new Date(e.ts).getTime());
  } else if (e.event === 'session_stop' && sessionStarts.has(e.session_id)) {
    const start = sessionStarts.get(e.session_id);
    durations.push(new Date(e.ts).getTime() - start);
    sessionStarts.delete(e.session_id);
  }
}

const totalDurationMs = durations.reduce((a, b) => a + b, 0);
const avgDurationMs = durations.length ? totalDurationMs / durations.length : 0;

function fmtDuration(ms) {
  const s = Math.floor(ms / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${s % 60}s`;
  return `${s}s`;
}

const report = {
  file: filePath,
  windowDays: days,
  totalEvents: filtered.length,
  parseErrors,
  sessions: sessions.size,
  totalDuration: fmtDuration(totalDurationMs),
  avgDuration: fmtDuration(avgDurationMs),
  counts,
  topRiskFiles: Object.entries(riskFilesHit).sort((a, b) => b[1] - a[1]).slice(0, 5),
  topRepeatFailures: Object.entries(retryHits)
    .filter(([, n]) => n >= 2)  // ≥2 = actual repeat, not one-off
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10),
  topOversizeFiles: Object.entries(oversizeHits).sort((a, b) => b[1] - a[1]).slice(0, 5),
  byDay,
};

if (jsonOut) {
  console.log(JSON.stringify(report, null, 2));
  process.exit(0);
}

// Markdown output
const headerWindow = days ? ` (last ${days} days)` : '';
console.log(`# ADK Metrics${headerWindow}\n`);
console.log(`- **Source**: ${filePath}`);
console.log(`- **Total events**: ${report.totalEvents}`);
console.log(`- **Sessions**: ${report.sessions}`);
console.log(`- **Total duration**: ${report.totalDuration}`);
console.log(`- **Avg session**: ${report.avgDuration}`);
if (parseErrors) console.log(`- ⚠️  **Parse errors**: ${parseErrors}`);

const BLOCK_EVENTS = ['batch_blocked', 'risk_file_blocked', 'oversize_blocked', 'danger_blocked'];
const WARN_EVENTS = ['oversize_warned', 'post_tool_failed'];

console.log('\n## Blocks');
for (const ev of BLOCK_EVENTS) {
  console.log(`- ${ev.padEnd(22)}: ${counts[ev] || 0}`);
}

console.log('\n## Warnings');
for (const ev of WARN_EVENTS) {
  console.log(`- ${ev.padEnd(22)}: ${counts[ev] || 0}`);
}

if (report.topRiskFiles.length > 0) {
  console.log('\n## Top 🔴 risk files attempted');
  for (const [file, count] of report.topRiskFiles) {
    console.log(`- ${file}: ${count}`);
  }
}

if (report.topRepeatFailures.length > 0) {
  console.log('\n## Top repeat failures (post_tool_failed ≥2)');
  console.log('Files where typecheck/lint kept failing after Write/Edit.');
  console.log('Watch for stuck implementer loops here.');
  for (const [file, count] of report.topRepeatFailures) {
    const marker = count >= 5 ? '🔴' : count >= 3 ? '🟡' : '⚠️';
    console.log(`- ${marker} ${file}: ${count}회`);
  }
}

if (report.topOversizeFiles.length > 0) {
  console.log('\n## Top oversize block files (page.tsx >200 lines)');
  for (const [file, count] of report.topOversizeFiles) {
    console.log(`- ${file}: ${count}회 차단`);
  }
}

console.log('\n## All event counts');
const sortedCounts = Object.entries(counts).sort((a, b) => b[1] - a[1]);
for (const [ev, count] of sortedCounts) {
  console.log(`- ${ev}: ${count}`);
}
