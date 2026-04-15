---
name: spec
description: Use when defining new feature requirements or starting a new task. Performs impact analysis across files, UI, processes, functions, DB, and APIs, then outputs a risk-graded spec with 🔴🟡🟢 markers. Trigger before /plan or /build.
when_to_use: User asks for new feature, bug fix scope, or "what would it take to...". Always before implementation.
argument-hint: [feature description]
allowed-tools: Read Grep Glob Bash(node *)
---

# /spec — Requirements & Impact Analysis

You are performing requirements definition with mandatory impact analysis. **Do not write code.**

## Pre-work (mandatory)

1. Read `CLAUDE.md` for project rules and forbidden zones
2. Read `.md/설계문서/수정위험도.md` if present
3. Read `.md/설계문서/의존성맵.md` if present

## Process

1. **Parse the request**: Extract functional + non-functional requirements from: `$ARGUMENTS`
2. **Run impact analyzer** on files likely to change:
   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/scripts/impact-analyzer.mjs" <file>
   ```
3. **Gather context via MCP** (if available): related GitHub issues, DB schema for affected tables
4. **Produce the spec report** using the format below

## Output format

Use the structure in [`templates/spec-report.md`](./templates/spec-report.md).
Copy the template, fill each section, and delete the bracketed instructions
before presenting to the user. The template is the source of truth — this
section below is a summary for reference.

```markdown
## Spec Report: <feature>

### Functional requirements
- [list]

### Non-functional requirements (perf / security / a11y)
- [list]

### Files to modify
| File | Risk | Reason |
|------|------|--------|
| path | 🔴/🟡/🟢 | why |

### Files to create
- path — reason

### Indirect impact (read-only check)
- path — how it's affected

### DB impact
- Schema changes: yes/no
- Migration required: yes/no
- Order: migration → types → API → frontend

### API impact
- Endpoints changed: [list]
- Breaking change: yes/no

### Dependency impact (from impact-analyzer)
- Direct callers: N
- Transitive callers: N
- Circular deps introduced: yes/no

### 🔴 High-risk files present
- Yes/No — if yes, STOP and ask user for explicit approval

### Risk score
- 🔴 score ≥ 8 / 🟡 4-7 / 🟢 < 4

### Estimated scope
- Files: N  |  Est. time: X

### Recommended model
- Detected keywords: [list or "none"]
- Recommendation: [Opus / Sonnet / Haiku] — [reason]
  (Rules: security keywords → Opus, 10+ files → Sonnet, simple change → Haiku)

### Proposed modification order
1. [file] — reason
2. ...
```

## Hand-off

After the report, **stop and wait for user approval.** Do not proceed to /plan.
When approved, tell the user: *"Run `/plan` to break this into atomic tasks, or call `@checker` for dependency-conflict analysis."*

## Absolutely forbidden

- Writing or editing code
- Creating non-documentation files
- Proceeding to implementation without user approval
