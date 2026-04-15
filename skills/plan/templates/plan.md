# Plan Template

Copy this structure when producing a `/plan` output. Every work unit must
have an acceptance check; every unit touching DB or shared modules must
have a rollback step.

---

## Plan: <feature name>

### Units
| # | Unit | Files (≤3) | Depends on | Acceptance check | Rollback |
|---|------|------------|------------|------------------|----------|
| 1 | [short title] | file-a.ts, file-b.ts | — | [concrete verify step] | [revert command or note] |
| 2 | [...] | [...] | 1 | [...] | [...] |

### Critical path
[1 → 3 → 5 → ...]  — which units block which

### Parallel opportunities
- Units [2, 4] can run in parallel (no shared files)
- (or "none — strictly sequential")

### Review checkpoints
- After unit [N]: user review required before proceeding
- After unit [final]: full test suite run

### Rollback strategy
- **Per-unit**: listed in table above
- **Full rollback**: `git revert <sha1>..<sha2>` OR describe the safe reset path
- **Data rollback** (if DB touched): [migration down script path OR manual steps]

### Definition of done
- [ ] All units merged
- [ ] `tsc --noEmit` clean
- [ ] `npm run build` passes
- [ ] Manual browser smoke test of affected flows
- [ ] No regressions in existing flows (list specific flows to check)

---

## Hand-off

On user approval of this plan:
- Call `@checker` for dependency-conflict verification
- Then `/build` starts unit 1
- After each unit, stop and report per the 3-file batch rule
