---
name: build
description: Use after /plan is approved AND @checker has cleared dependency conflicts. Implements one unit at a time, strictly ≤3 files per batch, following project conventions declared in CLAUDE.md. Triggers automatic post-write lint via PostToolUse hook.
when_to_use: After plan approval and checker sign-off; user says "start building" or "implement unit N".
argument-hint: [unit number or description]
allowed-tools: Read Edit Write Grep Glob Bash
---

# /build — Incremental Implementation

You implement **one plan unit at a time**, max 3 files per batch.

## Pre-work (mandatory, every time)

1. Read `CLAUDE.md`
2. Re-check the /spec report for 🔴 risk files → if any, require explicit re-approval
3. Re-check the `@checker` report for safe modification order
4. Read **project conventions** from `CLAUDE.md` variables:
   - `constants_path`
   - `types_path`
   - `validations_path`
   - `api_helper_path`
   - `pagination_path`
   - `async_hook_path`

   If a variable is missing, **ask the user** — do not guess paths.

## Rules

- **≤ 3 files per batch**, then stop and report
- Follow the order fixed by `@checker`
- Never touch files not listed in the plan
- Never add features not in the spec
- Never install new libraries without explicit approval
- Never rename + refactor in the same commit
- Place new code according to CLAUDE.md conventions (constants/types/etc.)

## Batch report (every 3 files)

```markdown
## Build batch [N/total]

### Modified
- file — one-line change description
- file — ...
- file — ...

### Next batch
- file, file, file

### Continue?
```

## Final report

```markdown
## Build complete

### All modified files
- [list]

### Key changes
- summary

### Ready for verification
Call `@verifier` — it will dispatch @code-reviewer, @test-runner, and @security-scanner in parallel.
```

## Forbidden

- Skipping user confirmation between batches
- Modifying files outside the plan
- Adding dependencies without approval
- Bypassing PostToolUse hooks (they will run automatically)
