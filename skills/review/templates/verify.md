# Review Template

Copy this structure when producing a `/review` consolidation output.
This runs AFTER `@code-reviewer`, `@test-runner`, `@security-scanner`
(and optionally `@nextjs-reviewer`, `@supabase-reviewer`, `@railway-deploy`)
have returned in parallel.

---

## Review Summary: <change description>

### Mechanical checks (from @verifier step 1)
- Build: ✅ / ❌
- Typecheck: ✅ / ❌
- (If any ❌: stop here, do not dispatch reviewers, return errors)

### Code quality (from @code-reviewer)
- Critical: [N]  |  Major: [N]  |  Minor: [N]
- Top issues:
  - [file:line] — [issue]
  - [file:line] — [issue]

### Test quality (from @test-runner)
- Suite result: [N passed / N failed]
- Coverage on changed files: [X%]
- Missing tests: [list or "none"]
- Flaky patterns detected: [list or "none"]

### Security (from @security-scanner)
- Critical: [N]  |  High: [N]  |  Medium: [N]
- Findings (if any):
  - [file:line] — [category] — [issue]
- npm audit: [Critical N, High N, Moderate N]

### Domain reviews (conditional)
- **@nextjs-reviewer** (if Next.js files touched): [summary]
- **@supabase-reviewer** (if DB/Supabase touched): [summary]
- **@railway-deploy** (if shipping): [summary]

### Merge decision
- **APPROVE** / **REQUEST_CHANGES** / **BLOCK**
- Reason: [one sentence]

### Blocking issues (if REQUEST_CHANGES or BLOCK)
1. [file:line] — [what must change] — [why blocking]
2. [...]

### Non-blocking suggestions
- [file:line] — [improvement, to address later]

### Suggested next step
- On APPROVE → `/ship`
- On REQUEST_CHANGES → call `@implementer` with blocking list, then re-run `/test` → `/review`
- On BLOCK → describe specific resolution path, no implicit next step

---

## Hand-off

Return this summary to the user. Do not auto-advance to `/ship` without
explicit approval, even on APPROVE.
