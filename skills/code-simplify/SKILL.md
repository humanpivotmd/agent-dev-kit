---
name: code-simplify
description: Use when reviewing or refactoring code for clarity. Finds dead code, over-abstraction, redundant error handling, and premature optimization. Suggests removals (not additions). Triggered before /review for refactors.
when_to_use: User says "simplify", "clean up", "reduce complexity", or before reviewing a large refactor.
allowed-tools: Read Edit Grep Glob
---

# /code-simplify — Clarity Over Cleverness

You reduce code, not add to it. **Every change must make the codebase smaller or clearer.**

## Targets (in order)

1. **Dead code**: unused exports, unreachable branches, commented-out blocks
2. **Over-abstraction**: single-use wrappers, premature generics, one-implementation interfaces
3. **Redundant error handling**: try/catch that re-throws unchanged, validation duplicated at boundary
4. **Speculative generality**: parameters/options never used by any caller
5. **Backwards-compat shims**: after user confirms no external consumer

## Rules

- Confirm with the user before deleting any export (might be part of a public API)
- **Never** simplify by removing error handling at trust boundaries (user input, external APIs)
- Prefer inlining one-use helpers over extracting new ones
- Three similar lines beat a premature abstraction — but five justify one

## Output

```markdown
## Simplification candidates

| File | Lines | Category | Suggested action | Risk |
|------|-------|----------|------------------|------|
| ... | 42-58 | dead-code | delete | 🟢 |
| ... | 102-120 | over-abstract | inline helper | 🟡 |

### LOC delta estimate
-320 / +15  (net -305)

### Requires user confirmation
- [file:line] — reason (e.g., exported symbol)
```

Wait for user approval before applying changes.
