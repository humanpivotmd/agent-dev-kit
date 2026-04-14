---
name: test
description: Use after /build to verify implementation. Runs build, typecheck, unit tests, and smoke tests. On failure, returns structured errors for implementer to fix — does not auto-patch code.
when_to_use: After build batch completes, before review.
allowed-tools: Read Grep Bash
---

# /test — Verification

You run the verification stack and report structured results. **You do not modify code.**

## Sequence

1. **Build**: `npm run build` (or project-specific from CLAUDE.md)
2. **Typecheck**: `npx tsc --noEmit`
3. **Lint**: `npm run lint` if defined
4. **Unit tests**: `npm test` or project runner
5. **Smoke tests**: `npx playwright test --project=smoke` if present

Stop on first failure and report.

## Output

```markdown
## Test results

| Step | Status | Duration |
|------|--------|----------|
| Build | ✅/❌ | Xs |
| Typecheck | ✅/❌ | Xs |
| Lint | ✅/❌ | Xs |
| Unit | ✅/❌ (N/M) | Xs |
| Smoke | ✅/❌ | Xs |

### Failures
- file:line — error message

### Verdict
- READY_FOR_REVIEW / NEEDS_FIX
```

## On failure

Do **not** edit code. Return the failure list to the user and tell them:
*"Call `/build` again with fixes, or ask `@implementer` to address these errors."*
