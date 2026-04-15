# Agent Development Kit (ADK) — 최종 스펙

> **Version**: 1.2.0
> **Last updated**: 2026-04-15
> **Repository**: https://github.com/humanpivotmd/agent-dev-kit
> **Plugin name**: `adk-pipeline@adk-marketplace`
> **License**: (선택, repo에 추가 필요)

---

## 목차

1. [개요](#1-개요)
2. [아키텍처](#2-아키텍처)
3. [파일 구조](#3-파일-구조)
4. [Skills — 7개 워크플로우](#4-skills--7개-워크플로우)
5. [Subagents — 10개 에이전트](#5-subagents--10개-에이전트)
6. [Hooks — 결정론적 가드레일](#6-hooks--결정론적-가드레일)
7. [Scripts — 유틸리티](#7-scripts--유틸리티)
8. [Templates — 산출물 양식](#8-templates--산출물-양식)
9. [Tests — 자동 검증](#9-tests--자동-검증)
10. [CI/CD — GitHub Actions](#10-cicd--github-actions)
11. [Plugin Manifest](#11-plugin-manifest)
12. [MCP Servers](#12-mcp-servers)
13. [설치 가이드](#13-설치-가이드)
14. [운영 지표](#14-운영-지표)
15. [CLAUDE.md 필수 설정](#15-claudemd-필수-설정)
16. [Changelog](#16-changelog)
17. [참고 문서](#17-참고-문서)

---

## 1. 개요

### 정체

ADK(Agent Development Kit)는 Claude Code용 **플러그인**입니다. 목적: **안전하고 보수적인 AI 코드 수정 파이프라인** 제공. 한국 팀의 실제 경험(3-파일 배치, 🔴 위험 파일 재확인, 사용자 승인 게이트)을 **강제 메커니즘**으로 박아 넣음.

### 핵심 가치

| 가치 | 구현 방식 |
|---|---|
| **Determinism > Prompt trust** | Hook 레벨에서 shell이 직접 deny, 프롬프트로 "하지 마"라고 쓰지 않음 |
| **소형 원자 배치** | 3-파일 배치 카운터로 폭주 방지 |
| **위험 파일 이중 보호** | 🔴 위험 파일 수정 시 각 단계(designer/checker/implementer)에서 재확인 + Hook 레벨 차단 |
| **AST 기반 정확성** | grep 대신 ts-morph로 caller 추적, false positive 제거 |
| **병렬 속도 + 순차 안전** | verifier는 병렬 리뷰어 3~5개 dispatch, designer→checker→implementer는 순차 승인 게이트 |

### 포지셔닝

```
                   규모 많음
                       │
     wshobson/agents   │   BMAD-METHOD
     (arsenal)         │   (full team)
                       │
   ──────────일반목적─┼─도메인특화──────
                       │
     Aider             │   👉 ADK (우리)
     (efficient solo)  │   (safety-first local)
                       │
                   규모 적음
```

**우리 위치**: 도메인 특화(한국어 + 특정 스택) × 소규모 깊이. wshobson/BMAD가 못 채우는 "신중한 팀의 체크리스트" 구멍.

### 지원 환경

| 환경 | 지원 |
|---|---|
| macOS (bash) | ✅ 완전 지원 |
| Linux (bash) | ✅ 완전 지원 |
| Windows + Git Bash | ✅ 완전 지원 |
| Windows + WSL2 | ✅ 완전 지원 |
| Windows Native PowerShell | ✅ v1.2+ (`hooks/ps/`) |
| Windows PowerShell Core (pwsh) | ✅ v1.2+ |

---

## 2. 아키텍처

### Pandey 5-Layer 모델 (Brij Kishore Pandey ADK)

```
┌─────────────────────────────────────────┐
│ Layer 1 — Memory (CLAUDE.md)            │  프로젝트 헌법
├─────────────────────────────────────────┤
│ Layer 2 — Skills (7 SKILL.md)           │  워크플로우 지식
├─────────────────────────────────────────┤
│ Layer 3 — Hooks (10 훅 + metrics)       │  결정론적 가드레일
├─────────────────────────────────────────┤
│ Layer 4 — Subagents (10 agents)         │  역할 분리·병렬화
├─────────────────────────────────────────┤
│ Layer 5 — Plugins (marketplace.json)    │  배포
└─────────────────────────────────────────┘
         ↔ MCP Servers (GitHub / Postgres / claude-context)
```

**5개 레이어 모두 채움**. 공개 ADK 중 5개 전부 커버하는 건 드묾.

### 파이프라인 흐름

```
사용자 요청
    │
    ▼
/spec (또는 @designer)
    │  ← 승인 게이트
    ▼
@checker
    │  ← 승인 게이트
    ▼
/plan
    │  ← 승인 게이트
    ▼
@implementer (3파일 배치, 각 배치마다 사용자 확인)
    │
    ▼  (PostToolUse hook: per-file tsc/eslint 자동 주입)
@verifier
    │
    ├── @code-reviewer     ┐
    ├── @test-runner       ├── 병렬 dispatch
    ├── @security-scanner  ┘
    ├── @nextjs-reviewer   ┐
    ├── @supabase-reviewer ├── 조건부 병렬 (해당 파일 수정 시)
    └── @railway-deploy    ┘
    │
    ▼  (결과 consolidate)
/review → APPROVE / REQUEST_CHANGES / BLOCK
    │
    ▼
/ship (수동 invoke만 가능)
```

---

## 3. 파일 구조

```
agent-dev-kit/
│
├── .claude-plugin/
│   ├── marketplace.json        # 마켓플레이스 카탈로그
│   └── plugin.json             # 플러그인 매니페스트 (hooks + MCP 인라인)
│
├── skills/                     # 7 워크플로우 스킬
│   ├── spec/
│   │   ├── SKILL.md            # /spec — impact analysis + risk grading
│   │   └── templates/
│   │       └── spec-report.md  # Spec 보고서 템플릿
│   ├── plan/
│   │   ├── SKILL.md            # /plan — atomic 3-file work units
│   │   └── templates/
│   │       └── plan.md         # Plan 템플릿
│   ├── build/SKILL.md          # /build — strict implementation rules
│   ├── test/SKILL.md           # /test — build + typecheck + tests
│   ├── review/
│   │   ├── SKILL.md            # /review — parallel reviewer orchestration
│   │   └── templates/
│   │       └── verify.md       # Verify 템플릿
│   ├── code-simplify/SKILL.md  # /code-simplify — dead code & clarity
│   └── ship/SKILL.md           # /ship — deploy (manual-invoke only)
│
├── agents/                     # 10 subagents
│   ├── designer.md             # 설계 + 위험도 분석
│   ├── checker.md              # 의존성 충돌 체크
│   ├── implementer.md          # 3-파일 배치 구현 (🔴 유일한 write 권한자)
│   ├── verifier.md             # 병렬 dispatch orchestrator
│   ├── code-reviewer.md        # 품질 리뷰 (병렬)
│   ├── test-runner.md          # 테스트 실행 + 커버리지 (병렬)
│   ├── security-scanner.md     # OWASP + secret 스캔 (병렬)
│   ├── nextjs-reviewer.md      # Next.js App Router 리뷰 (조건부)
│   ├── supabase-reviewer.md    # Supabase/RLS 리뷰 (조건부)
│   └── railway-deploy.md       # Railway 배포 리뷰 (조건부)
│
├── hooks/                      # Bash hooks (기본)
│   ├── hooks.json              # 훅 이벤트 등록 (bash 기본)
│   ├── hooks-powershell.json   # 대체 PowerShell 설정
│   ├── lib/
│   │   └── metrics.sh          # Adk-Log 공통 로거
│   ├── session-start.sh        # SessionStart 이벤트
│   ├── session-stop.sh         # Stop 이벤트
│   ├── pre-tool-use.sh         # 🔴 차단 + 3-파일 배치 카운터
│   ├── post-tool-use.sh        # tsc/eslint + 200줄 제한
│   ├── subagent-stop.sh        # implementer 종료 시 리셋
│   ├── block-dangerous.sh      # rm -rf / force push / --no-verify 차단
│   │
│   └── ps/                     # PowerShell hooks (v1.2+)
│       ├── lib/metrics.ps1
│       ├── session-start.ps1
│       ├── session-stop.ps1
│       ├── pre-tool-use.ps1
│       ├── post-tool-use.ps1
│       ├── subagent-stop.ps1
│       └── block-dangerous.ps1
│
├── co-update/                  # Forward propagation 라이브러리 (학습형)
│   ├── patterns-library.md     # 7 generic 패턴 (placeholder 기반)
│   ├── category-taxonomy.md    # 11 표준 카테고리
│   └── setup-guide.md          # 새 프로젝트 적용 5분 가이드
│
├── scripts/                    # 유틸리티 스크립트
│   ├── impact-analyzer.mjs     # AST 기반 영향 분석 (ts-morph + madge)
│   ├── case-logger.mjs         # Co-update 사례 자동 로깅 (cases.md append)
│   ├── pattern-extractor.mjs   # cases.md → 패턴 보강 제안 (3건 임계값)
│   ├── metrics-report.mjs      # JSONL 메트릭 집계 + 마크다운 리포트
│   ├── doctor.sh               # 46개 설치 self-check
│   ├── check-env.sh            # MCP env 변수 검증
│   ├── reset-password.mjs      # Supabase admin 비밀번호 재설정 유틸
│   ├── package.json            # 의존성 (ts-morph, madge)
│   └── test/
│       ├── impact-analyzer.test.mjs  # node:test 단위 테스트 5종
│       └── fixtures/
│           ├── tsconfig.json
│           └── src/
│               ├── shared.ts
│               ├── consumer-a.ts
│               └── consumer-b.ts
│
├── .github/
│   └── workflows/
│       └── validate-plugin.yml # CI: validate + test + smoke + shellcheck
│
├── .claude-plugin/             # (중복 — 맨 위 참조)
├── .gitattributes              # LF 통일
├── .gitignore                  # scripts/node_modules 제외
│
├── README.md                   # 메인 README
├── ADK-SPEC.md                 # 이 문서
├── Agent-Development-Kit.md    # 아키텍처 문서 (legacy)
├── Agent-Skills.md             # 워크플로우 문서 (legacy)
├── 분석보고서.md               # 초기 장단점 분석
├── 구현완료_분석보고서.md      # v1.0 구현 완료 분석
│
├── impact-analyzer.js          # 레거시 v0 (grep 기반)
└── install.sh                  # 레거시 설치 스크립트
```

---

## 4. Skills — 7개 워크플로우

각 Skill은 `description` 기반 **auto-invoke** (Claude Code가 사용자 요청에서 자동 매칭).

| # | 슬래시 커맨드 | 파일 | 역할 | 승인 게이트 |
|---|---|---|---|---|
| 1 | `/spec` | `skills/spec/SKILL.md` | 요구사항 + 영향 분석 + 🔴🟡🟢 등급 | ✅ |
| 2 | `/plan` | `skills/plan/SKILL.md` | 원자 배치 분해 + 롤백 계획 | ✅ |
| 3 | `/build` | `skills/build/SKILL.md` | 3-파일 배치 구현 | ✅ (매 배치마다) |
| 4 | `/test` | `skills/test/SKILL.md` | build + tsc + 테스트 | - |
| 5 | `/review` | `skills/review/SKILL.md` | 병렬 리뷰어 oprchestration | ✅ |
| 6 | `/code-simplify` | `skills/code-simplify/SKILL.md` | Dead code + clarity | ✅ |
| 7 | `/ship` | `skills/ship/SKILL.md` | 배포 (disable-model-invocation) | 🔴 수동만 |

### Frontmatter 핵심 필드

```yaml
---
name: spec
description: Use when defining new feature requirements...
when_to_use: User asks for new feature...
argument-hint: [feature description]
allowed-tools: Read Grep Glob Bash(node *)
---
```

- `description`: 자동 호출 트리거
- `disable-model-invocation: true` (ship만): Claude가 자동 호출 못함
- `allowed-tools`: 스킬 활성 시 사용자 승인 없이 호출 가능한 tool 목록

---

## 5. Subagents — 10개 에이전트

### 5.1 파이프라인 코어 (4개, 순차)

| 에이전트 | 권한 | 역할 |
|---|---|---|
| **@designer** | Read, Grep, Glob, Bash | 설계·위험도 분석, **코드 수정 금지** |
| **@checker** | Read, Grep, Glob, Bash | 의존성 충돌 탐지, **코드 수정 금지** |
| **@implementer** | Read, Edit, Write, Grep, Glob, Bash | **코드 작성 유일 권한자**, 3-파일 배치 |
| **@verifier** | Read, Bash | 병렬 dispatch orchestrator, **코드 수정 금지** |

### 5.2 병렬 리뷰어 (3개, verifier가 dispatch)

| 에이전트 | 권한 | 포커스 |
|---|---|---|
| **@code-reviewer** | Read, Grep, Glob | 스타일, 중복, 네이밍, 가독성, CLAUDE.md 규칙 |
| **@test-runner** | Read, Grep, Glob, Bash | 테스트 실행, 커버리지, flaky 패턴 |
| **@security-scanner** | Read, Grep, Glob, Bash | OWASP 10, secrets, 인증, 주입, npm audit |

### 5.3 도메인 특화 리뷰어 (3개, 조건부)

| 에이전트 | 권한 | 언제 호출 |
|---|---|---|
| **@nextjs-reviewer** | Read, Grep, Glob | Next.js App Router 코드 수정 시 |
| **@supabase-reviewer** | Read, Grep, Glob | `supabase/*` 또는 DB 클라이언트 수정 시 |
| **@railway-deploy** | Read, Grep, Glob, Bash | `/ship` 또는 배포 설정 수정 시 |

### 5.4 에이전트 원칙

1. **단일 쓰기 권한자**: `@implementer`만 Edit/Write 권한. 나머지 9개는 읽기 전용.
2. **병렬 가능 구조**: verifier가 한 메시지에 3~6개 리뷰어 dispatch → Claude Code가 병렬 실행 → 결과 수집.
3. **강제 뒤따라 가는 승인 게이트**: designer → (사용자 OK) → checker → (사용자 OK) → implementer.
4. **도메인 에이전트는 description 매칭**으로 자동 호출. verifier.md에서 명시적 언급 안 해도 OK.

---

## 6. Hooks — 결정론적 가드레일

### 6.1 이벤트별 훅 매핑

| 이벤트 | Matcher | Bash 스크립트 | PowerShell 스크립트 |
|---|---|---|---|
| `SessionStart` | - | `session-start.sh` | `ps/session-start.ps1` |
| `Stop` | - | `session-stop.sh` | `ps/session-stop.ps1` |
| `PreToolUse` | `Write\|Edit` | `pre-tool-use.sh` | `ps/pre-tool-use.ps1` |
| `PreToolUse` | `Bash` + `if: Bash(rm -rf *)` | `block-dangerous.sh` | `ps/block-dangerous.ps1` |
| `PreToolUse` | `Bash` + `if: Bash(git push --force*)` | `block-dangerous.sh` | `ps/block-dangerous.ps1` |
| `PreToolUse` | `Bash` + `if: Bash(git commit *--no-verify*)` | `block-dangerous.sh` | `ps/block-dangerous.ps1` |
| `PostToolUse` | `Write\|Edit` | `post-tool-use.sh` | `ps/post-tool-use.ps1` |
| `SubagentStop` | `implementer` | `subagent-stop.sh` | `ps/subagent-stop.ps1` |

### 6.2 차단 동작 (PreToolUse)

| 조건 | 환경변수 | 결과 |
|---|---|---|
| 🔴 위험 파일 수정 시도 | `ADK_ALLOW_HIGH_RISK` unset | `permissionDecision: ask` — 사용자 재확인 요구 |
| 🔴 위험 파일 수정 시도 | `ADK_ALLOW_HIGH_RISK=1` | 허용 |
| 4번째 파일 수정 (배치 제한) | - | `permissionDecision: ask` — 사용자 중단 + 보고 요구 |
| `rm -rf *` | - | `permissionDecision: deny` (하드 차단) |
| `git push --force*` | - | `permissionDecision: deny` |
| `git commit *--no-verify*` | - | `permissionDecision: deny` |

### 6.3 차단 동작 (PostToolUse)

| 조건 | 환경변수 | 결과 |
|---|---|---|
| `app/**/page.tsx` 새로 쓴 후 200줄 초과 | - | `decision: block` + additionalContext로 추출 지시 |
| 기존 grandfathered page.tsx (200줄 초과) | `ADK_ALLOW_OVERSIZE=1` | 경고 only (boy-scout 리마인더) |
| 기존 grandfathered page.tsx (200줄 초과) | unset | `decision: block` + grandfathered 가이드 |
| tsc 또는 eslint 실패 | - | `decision: block` + 에러 컨텍스트 주입 |

### 6.4 로깅 이벤트 (총 9종)

`hooks/lib/metrics.sh`의 `adk_log`가 JSONL로 기록:

| 이벤트 | 언제 | 필드 |
|---|---|---|
| `session_start` | SessionStart 훅 | ts, event, session_id, cwd |
| `session_stop` | Stop 훅 | ts, event, session_id, cwd |
| `subagent_stop` | @implementer 완료 시 | ts, event, session_id, cwd |
| `risk_file_blocked` | 🔴 위험 파일 차단 | + file_path |
| `batch_blocked` | 4번째 파일 차단 | + file_path, count |
| `danger_blocked` | rm -rf 등 차단 | + command (80자) |
| `oversize_blocked` | page.tsx 200줄 초과 차단 | + file_path |
| `oversize_warned` | grandfathered 경고만 | + file_path |
| `post_tool_failed` | tsc/eslint 실패 | + file_path |

**저장 위치**: `~/.claude/adk-metrics.jsonl` (env `ADK_METRICS_FILE`로 override)

### 6.5 PowerShell/Bash 전환 방법

기본은 bash. Windows PowerShell 네이티브를 원하면:

```bash
cp hooks/hooks-powershell.json hooks/hooks.json
```

→ Claude Code 재시작. 두 버전은 100% parity (동일한 JSON 출력, 동일한 로직).

---

## 7. Scripts — 유틸리티

### 7.1 `impact-analyzer.mjs`

**역할**: AST 기반 caller 추적 + 의존성 그래프 + 리스크 점수

**의존성**: `ts-morph@^24`, `madge@^8`

**사용법**:
```bash
node scripts/impact-analyzer.mjs <file-path>
node scripts/impact-analyzer.mjs <file-path> --json
```

**출력 (--json)**:
```json
{
  "target": "src/lib/constants.ts",
  "ast": {
    "exports": [...],
    "uniqueCallerCount": 14
  },
  "graph": {
    "circular": [],
    "directDependents": []
  },
  "risk": {
    "score": 6,
    "level": "🔴",
    "reasons": ["High fan-in: 14 unique callers", "..."]
  }
}
```

**Exit codes**: `0`=🟢, `1`=🟡, `2`=🔴, `3`=invalid invocation/crash

**알려진 이슈**:
- Windows 경로 정규화: ts-morph는 `/`, Node `path.resolve`는 `\` → 내부에서 `source.getFilePath()` 사용해서 정규화
- 자기 참조 필터링: 같은 파일의 export끼리 참조하는 경우 caller 집계에서 제외 (v1.0.1 수정)

### 7.1b `case-logger.mjs` + `pattern-extractor.mjs` (Co-update 학습 루프)

**역할**: Forward propagation 사례를 누적 학습해서 패턴 라이브러리를 자가 보강.

**`case-logger.mjs`** — cases.md에 새 사례 append + 카테고리 빈도 재계산
```bash
node scripts/case-logger.mjs "설명" \
  --pattern=L1 --commit=$(git rev-parse HEAD) \
  --category=entry-point --trigger="..." --prevention="..."
```
3건 이상 누적 시 경고 + `pattern-extractor.mjs` 실행 권장 메시지 출력.

**`pattern-extractor.mjs`** — cases.md 파싱 → 카테고리별 그룹화 → 임계값(기본 3) 초과 시 패턴 보강 제안
```bash
node scripts/pattern-extractor.mjs                      # 마크다운 리포트
node scripts/pattern-extractor.mjs --json               # JSON 출력
node scripts/pattern-extractor.mjs --threshold=5        # 임계값 조정
```
제안 타입:
- `extend_existing` — 특정 패턴에 다수 매칭되지만 같은 빈도로 누락 → 해당 패턴 보강
- `create_new` — 일관된 매칭 없음 → 새 패턴 추가 권장

**관련 파일**: `co-update/patterns-library.md`, `co-update/category-taxonomy.md`, `co-update/setup-guide.md`

### 7.2 `metrics-report.mjs`

**역할**: `~/.claude/adk-metrics.jsonl` 집계 → 마크다운 리포트

**사용법**:
```bash
node scripts/metrics-report.mjs                       # 기본 경로 + 마크다운
node scripts/metrics-report.mjs <path>                # 커스텀 경로
node scripts/metrics-report.mjs --days=7              # 7일 필터
node scripts/metrics-report.mjs --json                # JSON 출력 (대시보드용)
```

**출력 예시**:
```
# ADK Metrics (last 7 days)

- Total events: 147
- Sessions: 14
- Total duration: 11h 32m
- Avg session: 49m

## Blocks
- batch_blocked      : 3
- risk_file_blocked  : 1
- oversize_blocked   : 7
- danger_blocked     : 0

## Warnings
- oversize_warned    : 22
- post_tool_failed   : 4

## Top 🔴 risk files attempted
- src/lib/auth.ts: 1
```

### 7.3 `doctor.sh`

**역할**: 플러그인 설치 후 46개 체크 자동 실행

**사용법**:
```bash
bash scripts/doctor.sh              # 전체 검사
bash scripts/doctor.sh --fix        # 실행 권한 자동 복구
```

**10개 체크 카테고리**:
1. 코어 파일 존재 (marketplace.json, plugin.json, README, hooks.json, impact-analyzer.mjs, scripts/package.json)
2. JSON 유효성 (4개 JSON 파일)
3. 훅 스크립트 실행 권한
4. 훅 bash 문법 (`bash -n`)
5. Skills/Agents frontmatter
6. 템플릿 파일 존재 (spec-report, plan, verify)
7. ts-morph / madge 설치 여부
8. impact-analyzer 스모크 테스트
9. 단위 테스트 (node:test)
10. MCP 환경 변수 (optional)

**Exit codes**: `0`=pass 또는 warnings only, `1`=critical fail

**Windows 대응**: `cygpath` 또는 `pwd -W`로 Git Bash 경로를 Windows 네이티브로 변환.

### 7.4 `check-env.sh`

**역할**: MCP 환경 변수만 빠르게 체크 (doctor.sh 서브셋)

```bash
bash scripts/check-env.sh
```

필수: `GITHUB_TOKEN`, `DATABASE_URL_READONLY`
선택: `OPENAI_API_KEY`, `MILVUS_ADDRESS`

Exit 0 = 필수 전부 set, Exit 1 = 필수 누락

### 7.5 `reset-password.mjs`

**역할**: 개발/테스트용 Supabase 비밀번호 재설정 (직접 SDK 호출)

```bash
export SUPABASE_SERVICE_ROLE_KEY=eyJ...
node scripts/reset-password.mjs user@example.com "newPassword123"
```

2초 대기 후 실행 (Ctrl+C 취소 가능). 비밀번호는 로그에 안 남음.

---

## 8. Templates — 산출물 양식

각 workflow 단계가 항상 일관된 포맷으로 보고하도록 템플릿 파일로 고정.

| 템플릿 | 경로 | 사용 스킬 |
|---|---|---|
| Spec 보고서 | `skills/spec/templates/spec-report.md` | `/spec` |
| Plan 테이블 | `skills/plan/templates/plan.md` | `/plan` |
| Verify 요약 | `skills/review/templates/verify.md` | `/review` |

각 SKILL.md에서 "source of truth"로 참조. Agent가 매번 동일한 섹션 구조를 채움 → 사용자가 포맷을 반복 요구할 필요 없음.

---

## 9. Tests — 자동 검증

### 9.1 단위 테스트

**파일**: `scripts/test/impact-analyzer.test.mjs`
**프레임워크**: `node:test` (외부 의존성 없음)
**Fixture**: `scripts/test/fixtures/src/` — 3개 TS 파일 (shared, consumer-a, consumer-b)

**5개 케이스**:
1. 존재하지 않는 파일 → exit 3
2. `shared.ts` → 정확히 2 unique callers (consumer-a, consumer-b)
3. `shared.ts` → risk level `🟢` (low fan-in)
4. `--json` → 유효한 parseable JSON
5. Self-reference 필터링 (shared.ts가 자기 자신을 caller로 포함하지 않음)

**실행**:
```bash
cd scripts && npm test
```

**결과**: 5/5 passing, 약 4.5초

### 9.2 Smoke Test

`doctor.sh`가 실행 시 `impact-analyzer.mjs`를 자기 자신에 대해 분석 → 0/1/2 exit code는 정상, 3+ exit만 실패로 판정.

### 9.3 Shellcheck

CI에서 `shellcheck hooks/*.sh scripts/check-env.sh` 실행. 현재 비차단(`|| true`) — 리팩토링 후 제거 예정.

---

## 10. CI/CD — GitHub Actions

**파일**: `.github/workflows/validate-plugin.yml`

### 실행 조건
- `push` to `main`
- `pull_request` to `main`

### 단계
1. `actions/checkout@v4`
2. `actions/setup-node@v4` (Node 20)
3. `cd scripts && npm install`
4. `npm install -g @anthropic-ai/claude-code`
5. `claude plugin validate .`
6. `cd scripts && npm test` — 단위 테스트
7. `impact-analyzer self-test` (exit 3+면 실패)
8. `shellcheck hooks/*.sh scripts/check-env.sh || true`
9. `check-env.sh` (CI에서는 exit 1이 **정상** — 회귀 방지 검증)

---

## 11. Plugin Manifest

### `.claude-plugin/marketplace.json`

```json
{
  "name": "adk-marketplace",
  "owner": { "name": "marketing-saas team" },
  "metadata": {
    "description": "Agent Development Kit — spec→plan→build→test→review→ship pipeline",
    "version": "1.2.0"
  },
  "plugins": [
    {
      "name": "adk-pipeline",
      "source": "./",
      "description": "Full ADK: 7 workflow skills + 10 subagents + deterministic hooks + impact-analyzer",
      "version": "1.2.0",
      "category": "workflow",
      "keywords": ["workflow", "safety", "impact-analysis", "pipeline"],
      "strict": true
    }
  ]
}
```

### `.claude-plugin/plugin.json`

```json
{
  "name": "adk-pipeline",
  "version": "1.2.0",
  "hooks": "./hooks/hooks.json",
  "mcpServers": {
    "github": { ... },
    "postgres-readonly": { ... },
    "claude-context": { ... }
  }
}
```

---

## 12. MCP Servers

인라인으로 `plugin.json`에 정의. env 변수 있으면 자동 연결, 없으면 비활성.

| 서버 | 용도 | 필요 env |
|---|---|---|
| `github` | designer가 관련 이슈/PR 조회 | `GITHUB_TOKEN` |
| `postgres-readonly` | checker가 실제 DB 스키마 조회 (read-only role 필수) | `DATABASE_URL_READONLY` |
| `claude-context` | 의미 기반 코드 검색 (grep 대체) | `OPENAI_API_KEY`, `MILVUS_ADDRESS` |

---

## 13. 설치 가이드

### 13.1 Marketplace 추가 (Public)

```bash
claude plugin marketplace add humanpivotmd/agent-dev-kit
claude plugin install adk-pipeline@adk-marketplace
```

### 13.2 Local 개발

```bash
# 1. 저장소 클론
git clone https://github.com/humanpivotmd/agent-dev-kit.git
cd agent-dev-kit

# 2. 의존성 설치 (plugin의 scripts 디렉토리 내)
cd scripts && npm install

# 3. 로컬 마켓플레이스로 등록
claude plugin marketplace add /absolute/path/to/agent-dev-kit
claude plugin install adk-pipeline@adk-marketplace

# 4. 설치 검증
bash scripts/doctor.sh
```

### 13.3 MCP 활성화 (선택)

```bash
export GITHUB_TOKEN=ghp_xxx
export DATABASE_URL_READONLY=postgresql://readonly@host/db
export OPENAI_API_KEY=sk-...     # claude-context 선택
export MILVUS_ADDRESS=...        # claude-context 선택
claude  # Claude Code 재시작
```

### 13.4 Windows PowerShell 전환

```bash
cp hooks/hooks-powershell.json hooks/hooks.json
# Claude Code 재시작
```

### 13.5 업그레이드

```bash
claude plugin marketplace update adk-marketplace
```

---

## 14. 운영 지표

### 14.1 메트릭 조회

```bash
# 전체
node scripts/metrics-report.mjs

# 최근 7일
node scripts/metrics-report.mjs --days=7

# JSON (대시보드 연동)
node scripts/metrics-report.mjs --json > metrics.json
```

### 14.2 추적 지표

- **세션당 평균 duration**
- **배치 제한 위반 횟수** (`batch_blocked`)
- **🔴 위험 파일 수정 시도 횟수** (`risk_file_blocked`)
- **PostToolUse 실패율** (`post_tool_failed` / total edits)
- **Oversize 경고 빈도** (`oversize_warned`)
- **위험 명령 차단 횟수** (`danger_blocked`)

### 14.3 쿼리 예시 (`jq`)

```bash
# 어떤 파일이 가장 자주 🔴로 차단되는가
jq 'select(.event == "risk_file_blocked") | .file_path' \
  ~/.claude/adk-metrics.jsonl | sort | uniq -c | sort -rn

# 지난 24시간 배치 차단 횟수
jq -r 'select(.event == "batch_blocked") | .ts' ~/.claude/adk-metrics.jsonl | \
  awk -v cutoff="$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)" '$0 > cutoff' | wc -l
```

---

## 15. CLAUDE.md 필수 설정

ADK가 설치된 프로젝트의 `CLAUDE.md`에 반드시 포함:

### 15.1 경로 변수

`@implementer`가 파일 배치 위치를 결정할 때 참조:

```markdown
## Project conventions (paths)
- constants_path: src/lib/constants.ts
- types_path: src/types/index.ts
- validations_path: src/lib/validations.ts
- api_helper_path: src/lib/api-helpers.ts
- pagination_path: src/lib/pagination.ts
- async_hook_path: src/hooks/useAsyncAction.ts
```

### 15.2 🔴 위험 파일 목록

`.md/설계문서/수정위험도.md`에 저장하거나 CLAUDE.md에 직접 테이블:

```markdown
## 🔴 위험 파일
| 파일 | 위험 이유 |
|---|---|
| src/lib/auth.ts | 전체 인증 흐름 |
| src/types/index.ts | 69개 API 의존 |
| supabase/migrations/ | DB 롤백 어려움 |
```

### 15.3 Code Conventions

```markdown
## Code Conventions (ADK plugin 강제)
### 파일 크기
- 신규 파일: 200줄 이하 필수
- 기존 위반 파일: 수정 시 해당 함수/섹션만 분리 (보이스카우트 규칙)
- 기존 파일 편집 필요 시: `export ADK_ALLOW_OVERSIZE=1` 후 Claude 실행
```

---

## 16. Changelog

### v1.2.0 (2026-04-15)

**Added**:
- 3개 템플릿 파일 (spec-report, plan, verify)
- `scripts/doctor.sh` — 46개 체크 self-test
- PowerShell 네이티브 훅 7개 파일
- `hooks/hooks-powershell.json` 대체 설정
- README Windows 섹션 PowerShell 활성화 방법

### v1.1.0 (2026-04-15)

**Added**:
- `scripts/test/` — node:test 단위 테스트 5종
- `hooks/lib/metrics.sh` + 2 session hooks — JSONL 메트릭 인프라
- 기존 훅 5개에 `adk_log` 계측 삽입
- `scripts/metrics-report.mjs` — JSONL 집계
- 3 도메인 에이전트 (nextjs / supabase / railway)
- GitHub Actions에 단위 테스트 단계 추가

### v1.0.0 (2026-04-14)

**Initial public release**:
- Claude Code 표준 플러그인 구조
- 7 skills, 7 subagents
- 5 bash hooks
- `impact-analyzer.mjs` (ts-morph + madge)
- GitHub Actions CI
- Public repo 공개

---

## 17. 참고 문서

### 내부 문서
- [README.md](./README.md) — 퀵스타트 + 설치 가이드
- [분석보고서.md](./분석보고서.md) — 초기 약점 분석 + 웹 리서치 보완책
- [구현완료_분석보고서.md](./구현완료_분석보고서.md) — 외부 툴(wshobson/BMAD/Cline/Aider) 비교
- [Agent-Development-Kit.md](./Agent-Development-Kit.md) — Pandey 5-Layer 원문 (legacy)
- [Agent-Skills.md](./Agent-Skills.md) — 워크플로우 원문 (legacy)

### 외부 참조
- [Claude Code Docs — Skills](https://code.claude.com/docs/en/skills)
- [Claude Code Docs — Subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Docs — Hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code Docs — Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [Claude Code Docs — MCP](https://code.claude.com/docs/en/mcp)
- [ts-morph GitHub](https://github.com/dsherret/ts-morph)
- [madge npm](https://www.npmjs.com/package/madge)

---

## 18. 라이선스 및 기여

**현재 라이선스**: TBD (repo에 LICENSE 파일 추가 필요)

**기여 방법**:
1. Fork → feature branch
2. 변경 사항 구현
3. `cd scripts && npm test` 통과 확인
4. `bash scripts/doctor.sh` 통과 확인
5. PR 생성

**이슈 보고**: https://github.com/humanpivotmd/agent-dev-kit/issues

---

*이 문서는 ADK v1.2.0 기준입니다. 최신 상태는 [GitHub 저장소](https://github.com/humanpivotmd/agent-dev-kit)를 참조하세요.*
