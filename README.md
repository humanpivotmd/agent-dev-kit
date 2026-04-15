# Agent Development Kit (ADK) — Claude Code Plugin

> Version 1.0.0 · 2026-04-14
> `spec → plan → build → test → review → ship` pipeline with 4-agent safety, parallel verification, AST impact analysis, and deterministic hooks.

This directory is **both** a Claude Code plugin marketplace and the plugin itself. Install it into any project and get the full ADK workflow.

> ⚠️ **모든 ADK 사용자 필독**: [AI-BEHAVIOR.md](./AI-BEHAVIOR.md) — Claude가 이 플러그인을
> 쓸 때 반드시 따라야 할 행동 규칙 (playwright 검증 의무, "못 한다" 거짓말 금지, 패턴 매칭 등).
> 새 프로젝트에 ADK 설치 시 프로젝트 CLAUDE.md 상단에 이 파일 링크 추가 권장.

---

## 🚀 Install

### Option A — Local marketplace (Windows / development)

From any project root:

```bash
claude plugin marketplace add "F:/marketing -app/agent-dev-kit"
claude plugin install adk-pipeline@adk-marketplace
```

### Option B — Git-based (once pushed to GitHub)

```bash
claude plugin marketplace add your-org/agent-dev-kit
claude plugin install adk-pipeline@adk-marketplace
```

### Required dependencies for impact-analyzer

`impact-analyzer.mjs` depends on `ts-morph` and `madge`. **Install them inside the plugin's `scripts/` directory**, not in the target project — Node resolves `node_modules` from the script's own location, not from the caller's cwd.

```bash
cd "F:/marketing -app/agent-dev-kit/scripts" && npm install
```

This only has to be done once per plugin checkout. After that, any target project can call the analyzer via its absolute path:

```bash
node "F:/marketing -app/agent-dev-kit/scripts/impact-analyzer.mjs" src/lib/constants.ts --json
```

### Required CLAUDE.md variables

Add to your project's `CLAUDE.md` so `@implementer` knows where to place code:

```markdown
## Project conventions (paths)
- constants_path: src/lib/constants.ts
- types_path: src/types/index.ts
- validations_path: src/lib/validations.ts
- api_helper_path: src/lib/api-helpers.ts
- pagination_path: src/lib/pagination.ts
- async_hook_path: src/hooks/useAsyncAction.ts

## Code Conventions

### 파일 크기
- 신규 파일: 200줄 이하 필수
- 기존 위반 파일: 수정 시 해당 함수/섹션만 분리 (보이스카우트 규칙)
- 기존 파일 편집 필요 시: `export ADK_ALLOW_OVERSIZE=1` 후 Claude 실행

### 공통화 규칙
- 동일 로직 2회 이상 → `src/lib/`에 추출
- API 호출 → `src/lib/api/` 전용
- 재사용 훅 → `src/hooks/`
- 타입 → `src/types/index.ts` 중앙 관리

### 컴포넌트 분리 기준
- 공통 UI → `src/components/`
- 페이지 전용 → `src/app/.../components/` (필요 시 생성)
- 200줄 초과 페이지 수정 시 → 건드린 섹션을 `components/`로 즉시 추출
```

If any variable is missing, `@implementer` will stop and ask. The
`Code Conventions` section is enforced by both `@implementer` (in
prompt) and `hooks/post-tool-use.sh` (at the shell level).

### Hook behavior for oversize files

The PostToolUse hook detects `app/**/page.tsx` writes and checks line count:

| Situation | `ADK_ALLOW_OVERSIZE` | Hook action |
|---|---|---|
| New file, >200 lines | any | **Block** — implementer must extract before proceeding |
| Existing grandfathered file, >200 lines | unset / `0` | **Block** — instructs user to set the flag |
| Existing grandfathered file, >200 lines | `1` | **Warn only** — emits boy-scout-rule reminder into Claude's context, allows the edit |
| Any file ≤200 lines | any | Pass |

To enable grandfathered editing for a session:

```bash
export ADK_ALLOW_OVERSIZE=1
claude
```

---

## 🪟 Windows 환경 설정

이 키트의 훅 스크립트(`hooks/*.sh`)는 bash 기반입니다.
Windows에서는 반드시 아래 중 하나가 필요합니다.

### Git Bash (권장)
1. [Git for Windows](https://git-scm.com/download/win) 설치
2. Claude Code를 Git Bash 터미널에서 실행
3. 환경 변수 설정:
   ```bash
   echo 'export GITHUB_TOKEN=ghp_xxx' >> ~/.bashrc
   echo 'export DATABASE_URL_READONLY=postgresql://...' >> ~/.bashrc
   source ~/.bashrc
   ```

### WSL2 (대안)
- Ubuntu 서브시스템에서 실행 시 네이티브 bash 동작
- 경로 주의: Windows 경로(`F:/...`)는 `/mnt/f/...`로 변환 필요

### PowerShell 네이티브 지원 (v1.2+)
`hooks/ps/*.ps1`에 PowerShell 포팅 버전이 포함되어 있습니다. 활성화:

```bash
# 기본은 bash (hooks/hooks.json). PowerShell로 전환하려면:
cp hooks/hooks-powershell.json hooks/hooks.json
```

그 후 Claude Code 재시작. 기능 parity는 bash 버전과 동일:
- metrics.ps1 → 동일한 JSONL 포맷
- pre-tool-use.ps1 → 3-파일 배치 카운터, 🔴 파일 차단
- post-tool-use.ps1 → 200줄 제한, typecheck, lint
- block-dangerous.ps1 → rm -rf / force push / --no-verify
- session-start/stop, subagent-stop 동일

**PowerShell 실행 정책**: 스크립트는 `-ExecutionPolicy Bypass`로 호출되므로 사용자가 별도 정책 변경할 필요 없음.

**Windows Native PowerShell vs pwsh (Core)**: 둘 다 동작. `hooks-powershell.json`은 `powershell` 명령을 사용 (Windows 기본 설치). `pwsh`를 선호하면 JSON에서 `powershell` → `pwsh`로 치환.

---

## 📂 Structure

```
agent-dev-kit/
├── .claude-plugin/
│   ├── marketplace.json        # marketplace catalog
│   └── plugin.json             # plugin manifest (hooks + MCP inline)
├── skills/
│   ├── spec/SKILL.md           # /spec — impact analysis + risk grading
│   ├── plan/SKILL.md           # /plan — atomic 3-file work units
│   ├── build/SKILL.md          # /build — strict implementation rules
│   ├── test/SKILL.md           # /test — build + typecheck + tests
│   ├── review/SKILL.md         # /review — parallel reviewer orchestration
│   ├── code-simplify/SKILL.md  # /code-simplify — dead code & clarity
│   └── ship/SKILL.md           # /ship — deploy (manual-invoke only)
├── agents/
│   ├── designer.md             # design + risk grading
│   ├── checker.md              # dependency-conflict check
│   ├── implementer.md          # code writing (3-file batches)
│   ├── verifier.md             # orchestrator (parallel dispatch)
│   ├── code-reviewer.md        # parallel reviewer
│   ├── test-runner.md          # parallel reviewer
│   └── security-scanner.md     # parallel reviewer
├── hooks/
│   ├── hooks.json              # PreToolUse / PostToolUse / SubagentStop
│   ├── pre-tool-use.sh         # 🔴 file block + 3-file batch counter
│   ├── post-tool-use.sh        # per-file typecheck + lint → feedback
│   ├── subagent-stop.sh        # reset batch counter + next-step hint
│   └── block-dangerous.sh      # rm -rf / force push / --no-verify
├── scripts/
│   ├── impact-analyzer.mjs     # ts-morph + madge AST analyzer
│   └── package.json
├── README.md                   # this file
├── Agent-Development-Kit.md    # architecture doc (legacy reference)
├── Agent-Skills.md             # workflow doc (legacy reference)
├── 분석보고서.md               # analysis report
└── _legacy/                    # (optional) old impact-analyzer.js + install.sh
```

---

## 🔄 Workflow

```
User: "add feature X"
  │
  ▼
/spec         ← impact-analyzer.mjs + MCP (issues, DB schema) → risk-graded report
  │           (user approves)
  ▼
@checker      ← AST dependency check → safe modification order
  │           (user approves)
  ▼
/plan         ← atomic 3-file units + rollback plan
  │           (user approves)
  ▼
@implementer  ← 3 files → user confirms → next 3 files → ...
  │           (PreToolUse: 🔴 block + batch counter)
  │           (PostToolUse: per-file typecheck → auto-feedback)
  ▼
@verifier     ← npm run build + tsc, then dispatches in parallel:
                ├─ @code-reviewer
                ├─ @test-runner
                └─ @security-scanner
  │           (consolidates → APPROVE / REQUEST_CHANGES / BLOCK)
  ▼
/ship         ← conventional commit + deploy (user must invoke)
```

---

## 🧰 Components delivered

| Weakness (from 분석보고서) | Solution shipped |
|---|---|
| 1. PLUGINS layer absent | `.claude-plugin/marketplace.json` + `plugin.json` — install via `claude plugin install` |
| 2. SKILLS auto-invocation missing | 7 `SKILL.md` files with description-based matching, `disable-model-invocation` on `/ship` |
| 3. Parallelization missing | `@verifier` dispatches 3 reviewers in parallel in a single message |
| 4. impact-analyzer stubs | `scripts/impact-analyzer.mjs` — ts-morph (AST, type-aware) + madge (graph, cycles) |
| 5. Context layer mixing | 7KB `Agent-Skills.md` split into 7 on-demand SKILL.md files |
| 6. Feedback loop absent | `PostToolUse` hook injects typecheck/lint errors back into Claude's context |
| 7. Quantitative metrics absent | `impact-analyzer.mjs` emits JSON (`--json`) for dashboards; exit codes 0/1/2 for 🟢🟡🔴 |
| 8. Project-specific paths hard-coded | `@implementer` reads `constants_path`, `types_path`, etc. from CLAUDE.md — stops if missing |
| bonus: MCP absent | `plugin.json` inlines GitHub, Postgres (read-only), and claude-context MCP servers |
| bonus: dangerous commands | `hooks/block-dangerous.sh` hard-denies `rm -rf`, `git push --force`, `--no-verify` |

---

## 🧪 Test locally

```bash
# 1. Validate the marketplace
claude plugin validate "F:/marketing -app/agent-dev-kit"

# 2. Add it
claude plugin marketplace add "F:/marketing -app/agent-dev-kit"

# 3. Install
claude plugin install adk-pipeline@adk-marketplace

# 4. In a Claude Code session inside a test project:
/spec "add a user settings page"
# → should produce a risk-graded report and stop for approval
```

---

## 🔐 MCP environment variables

Set before launching Claude Code:

```bash
export GITHUB_TOKEN=ghp_xxx
export DATABASE_URL_READONLY=postgresql://readonly:***@host/db
export OPENAI_API_KEY=sk-...       # for claude-context
export MILVUS_ADDRESS=...           # for claude-context
```

Any missing variable disables the corresponding MCP server but does not break the plugin.

---

## 🔁 Upgrade workflow

1. Edit files in this directory
2. Bump `version` in `.claude-plugin/marketplace.json` and `plugin.json`
3. Commit and push
4. Users run `/plugin marketplace update adk-marketplace`

The legacy `install.sh` and old `impact-analyzer.js` are kept for reference but should not be used for new installs.

---

## 📜 Source

Original: `F:/marketing -app/marketing-saas-v2/` (2026-04-14)
This directory is now the **single source of truth** — modify here first, then `/plugin marketplace update` in consumer projects.
