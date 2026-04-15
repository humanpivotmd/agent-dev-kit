#!/usr/bin/env node
// pattern-extractor.mjs — cases.md 분석해서 patterns.md 보강 제안
//
// 사용법:
//   node scripts/pattern-extractor.mjs                              # 기본 경로
//   node scripts/pattern-extractor.mjs --cases=path/to/cases.md
//   node scripts/pattern-extractor.mjs --threshold=3                # 기본 3건
//   node scripts/pattern-extractor.mjs --json                       # JSON 출력
//
// 동작:
//   1. cases.md 파싱 (각 사례를 구조화 객체로)
//   2. 카테고리별 그룹화
//   3. 임계값(기본 3건) 도달 카테고리 추출
//   4. 각 그룹에 대해 패턴 보강 제안 생성:
//      - 공통 트리거 후보
//      - 공통 누락 항목 후보
//      - 새 패턴 vs 기존 패턴 보강 권장
//   5. 마크다운 리포트 또는 JSON 출력
//
// 사용자가 검토 후 수동으로 patterns.md 업데이트.

import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

// ── Arg parsing ─────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const jsonOut = args.includes('--json');
const verbose = args.includes('--verbose') || args.includes('-v');

function getArg(name, fallback) {
  const arg = args.find(a => a.startsWith(`--${name}=`));
  return arg ? arg.slice(name.length + 3) : fallback;
}

const casesPath = resolve(getArg('cases', './.md/co-update/cases.md'));
const threshold = parseInt(getArg('threshold', '3'), 10);

if (args.includes('--help')) {
  console.error(`
pattern-extractor.mjs — Co-update cases → 패턴 보강 제안

Usage:
  node scripts/pattern-extractor.mjs [options]

Options:
  --cases=PATH       cases.md 경로 (기본: ./.md/co-update/cases.md)
  --threshold=N      카테고리 빈도 임계값 (기본: 3)
  --json             JSON 출력
  --verbose          상세 로그
`);
  process.exit(0);
}

if (!existsSync(casesPath)) {
  console.error(`❌ cases.md not found: ${casesPath}`);
  process.exit(1);
}

// ── Parse cases ─────────────────────────────────────────────────────────
const content = readFileSync(casesPath, 'utf8');

// Match each case block: "## Case NNN — date — title" + bullet fields
const caseBlocks = content.split(/^## Case /gm).slice(1);
const cases = [];

for (const block of caseBlocks) {
  const headerMatch = block.match(/^(\d+)\s+—\s+(\S+)\s+—\s+(.+?)$/m);
  if (!headerMatch) continue;

  const c = {
    id: headerMatch[1],
    date: headerMatch[2],
    title: headerMatch[3].trim(),
    trigger: extractField(block, '트리거'),
    missing: extractField(block, '누락'),
    foundVia: extractField(block, '발견 경로'),
    matched: extractField(block, '매칭된 패턴'),
    shouldHave: extractField(block, '추가됐어야 할 패턴'),
    commit: extractField(block, '해결 커밋'),
    prevention: extractField(block, '재발 방지'),
    categoryRaw: extractField(block, '카테고리'),
  };

  // Parse categories (may be multiple)
  c.categories = (c.categoryRaw || '')
    .split(/[,，、]/)
    .map(t => t.replace(/[`'"]/g, '').trim())
    .filter(Boolean);

  cases.push(c);
}

function extractField(block, name) {
  const re = new RegExp(`-\\s+\\*\\*${name}\\*\\*:\\s*(.+?)(?=\\n-\\s+\\*\\*|\\n\\n|$)`, 's');
  const m = block.match(re);
  if (!m) return null;
  return m[1].trim().replace(/^`|`$/g, '');
}

// ── Group by category ──────────────────────────────────────────────────
const byCategory = {};
for (const c of cases) {
  for (const cat of c.categories) {
    if (!byCategory[cat]) byCategory[cat] = [];
    byCategory[cat].push(c);
  }
}

// ── Find categories above threshold ────────────────────────────────────
const candidates = Object.entries(byCategory)
  .filter(([, cs]) => cs.length >= threshold)
  .sort((a, b) => b[1].length - a[1].length);

// ── Build suggestions ───────────────────────────────────────────────────
const suggestions = candidates.map(([category, casesList]) => {
  // Find common matched pattern (if any)
  const patterns = casesList.map(c => c.matched).filter(Boolean);
  const patternFreq = {};
  for (const p of patterns) patternFreq[p] = (patternFreq[p] || 0) + 1;
  const dominantPattern = Object.entries(patternFreq).sort((a, b) => b[1] - a[1])[0];

  // Common keywords in titles
  const titleWords = casesList.flatMap(c => c.title.toLowerCase().split(/\s+/));
  const wordFreq = {};
  for (const w of titleWords) {
    if (w.length < 2) continue;
    wordFreq[w] = (wordFreq[w] || 0) + 1;
  }
  const commonWords = Object.entries(wordFreq)
    .filter(([, n]) => n >= 2)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([w]) => w);

  return {
    category,
    count: casesList.length,
    dominantPattern: dominantPattern ? dominantPattern[0] : null,
    dominantPatternMatches: dominantPattern ? dominantPattern[1] : 0,
    commonKeywords: commonWords,
    cases: casesList.map(c => ({
      id: c.id,
      title: c.title,
      matched: c.matched,
      commit: c.commit,
    })),
    suggestion: buildSuggestion(category, casesList, dominantPattern),
  };
});

function buildSuggestion(category, casesList, dominantPattern) {
  const ids = casesList.map(c => `#${c.id}`).join(', ');
  if (dominantPattern && dominantPattern[1] >= casesList.length / 2) {
    return {
      type: 'extend_existing',
      action: `기존 패턴 ${dominantPattern[0]}을(를) 보강`,
      detail: `사례 ${ids}는 모두 패턴 ${dominantPattern[0]}에 매칭됐지만 같은 빈도로 누락이 발생. ` +
              `패턴 ${dominantPattern[0]}에 해당 카테고리의 누락 항목을 추가하거나, 트리거 표현을 확장하세요.`,
    };
  }
  return {
    type: 'create_new',
    action: `새 패턴 후보`,
    detail: `사례 ${ids}는 카테고리 '${category}'로 ${casesList.length}건 누적되지만 ` +
            `매칭된 패턴이 일관성 없거나 부족합니다. 새 패턴 추가를 고려하세요. ` +
            `공통 키워드: ${casesList.flatMap(c => c.title.toLowerCase().split(/\s+/)).filter(w => w.length > 2).slice(0, 5).join(', ')}`,
  };
}

// ── Output ──────────────────────────────────────────────────────────────
const report = {
  casesPath,
  threshold,
  totalCases: cases.length,
  totalCategories: Object.keys(byCategory).length,
  candidatesAboveThreshold: candidates.length,
  suggestions,
  allCategoryFreq: Object.fromEntries(
    Object.entries(byCategory).sort((a, b) => b[1].length - a[1].length).map(([k, v]) => [k, v.length])
  ),
};

if (jsonOut) {
  console.log(JSON.stringify(report, null, 2));
  process.exit(0);
}

// ── Markdown output ─────────────────────────────────────────────────────
console.log(`# Pattern Extractor Report\n`);
console.log(`- **Source**: ${casesPath}`);
console.log(`- **Total cases**: ${cases.length}`);
console.log(`- **Total categories**: ${Object.keys(byCategory).length}`);
console.log(`- **Threshold**: ${threshold} cases`);
console.log(`- **Candidates above threshold**: ${candidates.length}`);

if (candidates.length === 0) {
  console.log(`\n✅ 임계값(${threshold}건)을 넘은 카테고리 없음. 추가 패턴 불필요.`);
  console.log(`\n## 카테고리별 현황`);
  for (const [cat, n] of Object.entries(report.allCategoryFreq)) {
    console.log(`- ${cat.padEnd(20)}: ${n}건`);
  }
  process.exit(0);
}

console.log(`\n## 🔴 패턴 보강 후보 (${candidates.length}개)\n`);

for (const sug of suggestions) {
  console.log(`### 카테고리: \`${sug.category}\` (${sug.count}건)`);
  console.log(``);
  console.log(`**제안**: ${sug.suggestion.action}`);
  console.log(`**상세**: ${sug.suggestion.detail}`);
  console.log(``);
  console.log(`**관련 사례**:`);
  for (const c of sug.cases) {
    console.log(`- Case #${c.id}: ${c.title} (commit \`${c.commit || 'n/a'}\`, 매칭: ${c.matched || 'none'})`);
  }
  if (sug.commonKeywords.length > 0) {
    console.log(``);
    console.log(`**공통 키워드**: ${sug.commonKeywords.join(', ')}`);
  }
  console.log(`\n---\n`);
}

console.log(`## 다음 단계`);
console.log(``);
console.log(`1. 위 제안 중 채택할 것 결정`);
console.log(`2. \`patterns.md\` 직접 편집:`);
console.log(`   - 기존 패턴 보강 → 해당 패턴의 트리거/항목 표 확장`);
console.log(`   - 새 패턴 추가 → 패턴 N+1 추가`);
console.log(`3. cases.md의 채택된 사례에 \`### 적용됨\` 마킹 (선택)`);
console.log(`4. designer.md가 다음 세션부터 자동 활용`);

process.exit(0);
