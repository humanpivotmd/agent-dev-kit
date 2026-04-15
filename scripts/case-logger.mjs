#!/usr/bin/env node
// case-logger.mjs — Co-update Map 사례 자동 로깅
//
// 사용법:
//   node scripts/case-logger.mjs "<사례 설명>" \
//     --pattern=8 \
//     --commit=390fa6f \
//     --category=진입점추가 \
//     [--cases=<path>] \
//     [--trigger="<트리거>"] \
//     [--found-via="<발견 경로>"] \
//     [--prevention="<재발 방지>"]
//
// 동작:
//   1. 지정된 cases.md 파일 (기본: ./.md/co-update/cases.md) 읽기
//   2. 다음 사례 번호 자동 할당
//   3. 새 사례를 형식대로 append
//   4. 카테고리별 빈도 자동 재계산
//
// 학습 임계값:
//   같은 카테고리에 3건 이상 누적되면 출력에 경고 표시.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

// ── Arg parsing ─────────────────────────────────────────────────────────
const args = process.argv.slice(2);
if (args.length === 0 || args.includes('--help')) {
  console.error(`
case-logger.mjs — Co-update Map 사례 로거

Usage:
  node scripts/case-logger.mjs "<설명>" --pattern=N --category=<태그> [options]

Required:
  "<설명>"         사례 한 줄 제목
  --pattern=N      매칭된 패턴 번호 (또는 'none' if not matched)
  --category=TAG   분류 태그 (진입점추가, 파이프라인단계 등)

Optional:
  --commit=SHA     해결 커밋 SHA
  --trigger="..."  무엇이 트리거였나
  --found-via="..." 발견 경로 (사용자/playwright/build 등)
  --prevention="..." 재발 방지 방안
  --cases=PATH     cases.md 경로 (기본: ./.md/co-update/cases.md)

Examples:
  node scripts/case-logger.mjs "draft-info에 영상 누락" \\
    --pattern=8 --commit=390fa6f --category=진입점추가
`);
  process.exit(args.length === 0 ? 1 : 0);
}

const description = args.find(a => !a.startsWith('--'));
if (!description) {
  console.error('❌ 사례 설명이 필요합니다. --help 참조.');
  process.exit(1);
}

function getArg(name, fallback = null) {
  const arg = args.find(a => a.startsWith(`--${name}=`));
  return arg ? arg.slice(name.length + 3) : fallback;
}

const pattern = getArg('pattern');
const category = getArg('category');
const commit = getArg('commit', '미해결');
const trigger = getArg('trigger', '(unspecified)');
const foundVia = getArg('found-via', '(unspecified)');
const prevention = getArg('prevention', '(TBD)');
const casesPath = resolve(getArg('cases', './.md/co-update/cases.md'));

if (!pattern) {
  console.error('❌ --pattern 필수');
  process.exit(1);
}
if (!category) {
  console.error('❌ --category 필수');
  process.exit(1);
}

// ── Load existing cases ─────────────────────────────────────────────────
if (!existsSync(casesPath)) {
  console.error(`❌ cases.md not found: ${casesPath}`);
  console.error('   Hint: cd into the project root, or pass --cases=<path>');
  process.exit(1);
}

const content = readFileSync(casesPath, 'utf8');

// ── Find next case number ───────────────────────────────────────────────
const caseNumbers = [...content.matchAll(/^## Case (\d{3,})/gm)].map(m => parseInt(m[1], 10));
const nextNumber = caseNumbers.length > 0 ? Math.max(...caseNumbers) + 1 : 1;
const nextNumberPadded = String(nextNumber).padStart(3, '0');

// ── Build new case block ────────────────────────────────────────────────
const today = new Date().toISOString().slice(0, 10);
const newCase = `
## Case ${nextNumberPadded} — ${today} — ${description}
- **트리거**: ${trigger}
- **누락**: (자동 로깅 — 상세는 commit 참조)
- **발견 경로**: ${foundVia}
- **매칭된 패턴**: ${pattern}
- **추가됐어야 할 패턴**: (분석 필요)
- **해결 커밋**: \`${commit}\`
- **재발 방지**: ${prevention}
- **카테고리**: \`${category}\`
`;

// ── Find insertion point (before "## 📊 카테고리별 빈도" or end) ────────
const insertMarker = '## 📊 카테고리별 빈도';
const markerIdx = content.indexOf(insertMarker);
let updatedContent;
if (markerIdx === -1) {
  // Append to end
  updatedContent = content.trimEnd() + '\n' + newCase + '\n';
} else {
  // Insert before marker, with --- separator
  updatedContent =
    content.slice(0, markerIdx).trimEnd() +
    '\n\n---\n' +
    newCase +
    '\n---\n\n' +
    content.slice(markerIdx);
}

// ── Recompute category frequencies ──────────────────────────────────────
const allCategories = [...updatedContent.matchAll(/^- \*\*카테고리\*\*: `([^`]+)`/gm)].map(m => m[1]);
const freqMap = {};
for (const cat of allCategories) {
  // Categories may have multiple tags separated by , or `, `
  const tags = cat.split(/[,，、]\s*/).map(t => t.replace(/[`'"]/g, '').trim()).filter(Boolean);
  for (const tag of tags) {
    freqMap[tag] = (freqMap[tag] || 0) + 1;
  }
}

// Sort by frequency desc
const sortedFreq = Object.entries(freqMap).sort((a, b) => b[1] - a[1]);
const freqBlock = sortedFreq.map(([tag, count]) => {
  const marker = count >= 3 ? '🔴 ⚠️ 패턴 보강 후보' : '';
  return `${tag.padEnd(20)}: ${count}건  ${marker}`.trim();
}).join('\n');

// Replace existing frequency block
const freqBlockRegex = /(## 📊 카테고리별 빈도[^\n]*\n\n```\n)([\s\S]*?)(\n```)/;
if (freqBlockRegex.test(updatedContent)) {
  updatedContent = updatedContent.replace(freqBlockRegex, `$1${freqBlock}$3`);
}

// ── Write back ──────────────────────────────────────────────────────────
writeFileSync(casesPath, updatedContent);

// ── Report ──────────────────────────────────────────────────────────────
console.log(`✅ Case #${nextNumberPadded} logged to ${casesPath}`);
console.log(`   Description: ${description}`);
console.log(`   Pattern: ${pattern}  Category: ${category}`);
console.log(`   Commit: ${commit}`);

// Threshold warning
const categoryCount = freqMap[category] || 0;
if (categoryCount >= 3) {
  console.log('');
  console.log(`🔴 ⚠️  카테고리 '${category}'에 ${categoryCount}건 누적됨 (임계값 3건 도달)`);
  console.log(`   패턴 보강 후보입니다. 다음 명령으로 추출 후보 확인:`);
  console.log(`   $ node ${process.argv[1].replace('case-logger', 'pattern-extractor')}`);
}

process.exit(0);
