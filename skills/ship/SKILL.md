---
name: ship
description: Use after /review APPROVE. Runs final pre-ship checks, creates conventional-commit message, opens PR (if configured), and monitors initial deploy health. Does not bypass pre-commit hooks.
when_to_use: Review approved and user says "ship it" or "deploy".
disable-model-invocation: true
allowed-tools: Read Bash(git *) Bash(gh *) Bash(npm *)
---

# /ship — Deploy

Side-effectful operation. **Only runs when explicitly invoked by user.**

## Pre-ship gate

1. `/review` verdict must be APPROVE
2. Working tree must match last verified commit
3. Re-run `npm run build && npx tsc --noEmit` — fail fast if regression
4. Confirm CLAUDE.md deployment policy allows current branch

## Commit

- Staging: explicit file list only, never `git add -A`
- Secrets check: reject if `.env`, `credentials.*`, `*.key` staged
- Message format: conventional commit (`feat:`, `fix:`, `refactor:`, etc.)
- **Never** use `--no-verify` — if pre-commit hook fails, stop and report

## Deploy

- Follow project deploy script from CLAUDE.md (`railway up`, `vercel --prod`, etc.)
- Tail logs for 60s post-deploy
- Report first error or success

## Output

```markdown
## Ship report

- Commit: <sha> — <message>
- Branch: <name>
- PR: <url or "direct">
- Deploy: SUCCESS / FAILED
- Health check (60s): OK / errors: ...
- Rollback command: git revert <sha> && <deploy cmd>
```

## On failure

Do NOT force-push, NOT `--amend`, NOT skip hooks. Report exact failure and ask user.
