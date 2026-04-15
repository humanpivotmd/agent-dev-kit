# Spec Report Template

Copy this structure when producing a `/spec` report. Fill each section;
delete bracketed instructions before handing to the user.

---

## Spec Report: <feature name>

### Feature summary
[One sentence. What does this feature do for the user?]

### Functional requirements
- [Concrete capability 1]
- [Concrete capability 2]

### Non-functional requirements
- [Performance, security, accessibility, etc. — only if relevant]

### Files to modify
| File | Risk | Reason |
|------|------|--------|
| path/to/file.ts | 🔴/🟡/🟢 | one-line reason |

### Files to create
- path/to/new-file.ts — one-line reason
- (or "none")

### Indirect impact (read-only check, no modification planned)
- path/to/related.ts — how it's affected
- (or "none")

### DB impact
- Schema changes: [yes/no]
- Migration required: [yes/no]
- Order (if yes): migration → types → API → frontend

### API impact
- Endpoints changed: [list or "none"]
- Breaking change: [yes/no — if yes, specify consumers]

### Dependency impact (from impact-analyzer)
- Direct callers: [N]
- Transitive callers: [N or "unknown"]
- Circular deps introduced: [yes/no]

### 🔴 High-risk files included
[Yes/No. If Yes, STOP and ask user for explicit approval. Name the files.]

### Risk score
- Overall: 🔴 (≥8) / 🟡 (4-7) / 🟢 (<4)
- Reasons: [bullet list]

### Estimated scope
- Files: [N total]
- Batches needed: [N, respecting 3-file limit]
- Est. time: [rough minutes/hours]

### Proposed modification order
1. [file] — [reason for going first]
2. [file] — ...
3. [file] — ...

### Anticipated risks
- [Risk 1, with mitigation]
- [Risk 2, with mitigation]

### Recommended model
[Pick one based on task complexity + risk keywords in the request.
Ported from md/router.py HIGH_RISK_KEYWORDS heuristic.]

| Condition | Recommended model | Why |
|---|---|---|
| Task mentions auth/secret/password/crypto/token/encrypt | **Opus** | Security-critical — use the strongest reasoner |
| 10+ files expected OR schema/migration work | **Sonnet** | Default workhorse, handles multi-file edits |
| Simple text/style/typo change | **Haiku** | Fast and cheap |
| Default (unsure) | **Sonnet** | Safe middle ground |

**Detected keywords in this task**: [list matched security keywords, or "none"]
**Detected scope**: [N files, DB changes yes/no]
**Recommendation**: [Opus / Sonnet / Haiku]

If user wants to switch: restart Claude Code with `claude --model <name>`.

### User confirmation required
[List any decisions the user must make before proceeding. Number them.]

---

## Hand-off

After this report: **stop and wait for user approval**.
On approval, instruct the user to call `@checker` (dependency verification)
or proceed to `/plan` if dependencies are trivial.
