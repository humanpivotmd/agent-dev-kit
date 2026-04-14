---
name: review
description: Use after /test passes. Dispatches @code-reviewer, @test-runner, and @security-scanner in parallel for comprehensive quality review before ship. Consolidates findings and produces merge decision.
when_to_use: Tests pass and user wants quality review before shipping.
allowed-tools: Read Grep
---

# /review — Parallel Quality Review

You orchestrate **three parallel subagents** and consolidate findings.

## Process

1. Confirm `/test` verdict is READY_FOR_REVIEW
2. Dispatch in **a single message** (parallel, not sequential):
   - `@code-reviewer` — style, naming, duplication, readability
   - `@test-runner` — coverage gaps, test-quality, flaky patterns
   - `@security-scanner` — OWASP top 10, secrets, auth flaws
3. Wait for all three to return
4. Consolidate

## Output

```markdown
## Review summary

### Code quality (from @code-reviewer)
- Severity-ranked findings

### Test quality (from @test-runner)
- Coverage: X%
- Gaps: ...

### Security (from @security-scanner)
- Critical: N
- High: N
- Medium: N

### Merge decision
- APPROVE / REQUEST_CHANGES / BLOCK
- Reason: ...

### Required fixes before ship
1. [file:line] — action
```

## Hand-off

- If APPROVE → *"Run `/ship` to deploy."*
- If REQUEST_CHANGES → *"Call `@implementer` to address the fix list, then re-run `/test`."*
- If BLOCK → explain blocking issue, no implicit next step.
