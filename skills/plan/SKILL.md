---
name: plan
description: Use after /spec has been approved. Breaks the approved spec into atomic work units (max 2h each, max 3 files per unit), defines dependency order, and produces a rollback plan. Trigger before /build.
when_to_use: After user approves a spec report and asks for a work breakdown.
allowed-tools: Read Grep Glob
---

# /plan — Work Breakdown

You are breaking an approved spec into atomic, executable units. **Do not write code.**

## Pre-work

1. Re-read the `/spec` output (must exist in conversation)
2. Re-read `CLAUDE.md`
3. Confirm user has approved the spec

## Rules

- Each unit: **≤ 2 hours, ≤ 3 files**
- Units must form a DAG — no circular dependencies
- Every unit has a concrete acceptance check (not "looks good")
- Include a rollback step for every unit touching the DB or shared modules

## Output format

Use the structure in [`templates/plan.md`](./templates/plan.md). Copy the
template, fill each row, and delete the bracketed instructions before
presenting to the user.

```markdown
## Plan: <feature>

### Units
| # | Unit | Files | Depends on | Acceptance check | Rollback |
|---|------|-------|-----------|------------------|----------|
| 1 | ... | ≤3 | — | ... | ... |

### Critical path
1 → 3 → 5 → ...

### Parallel opportunities
- Units [2, 4] can run in parallel (no shared files)

### Review checkpoints
- After unit N: user review required before proceeding

### Rollback strategy
- Per-unit: listed above
- Full rollback: git revert range <sha1>..<sha2>
```

## Hand-off

Stop and wait for plan approval. When approved:
*"Call `@checker` to verify dependency safety, then `/build` to start unit 1."*

## Forbidden

- Creating units > 3 files
- Omitting acceptance checks
- Starting implementation
