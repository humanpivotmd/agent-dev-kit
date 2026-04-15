#!/bin/bash
# ADK doctor — post-install self-check.
# Run after `claude plugin install adk-pipeline@adk-marketplace` to verify
# all prerequisites, dependencies, permissions, and templates are in place.
#
# Usage:
#   bash scripts/doctor.sh            # run all checks
#   bash scripts/doctor.sh --fix      # attempt auto-fix for executable bits
#
# Exit codes:
#   0  = all checks passed (or only warnings)
#   1  = at least one critical check failed

set -uo pipefail

# Use Windows-form path on Git Bash so Node.js can resolve it correctly
# (Git Bash's /f/... confuses Node which reads it as C:\f\...).
if command -v cygpath >/dev/null 2>&1; then
  PLUGIN_ROOT="$(cygpath -w "$(cd "$(dirname "$0")/.." && pwd)")"
elif (cd "$(dirname "$0")/.." && pwd -W >/dev/null 2>&1); then
  PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd -W)"
else
  PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
FIX_MODE="${1:-}"
CRITICAL_FAILS=0
WARNINGS=0
PASSED=0

# Color helpers (POSIX-safe fallback)
if [ -t 1 ]; then
  RED=$'\033[0;31m'
  YELLOW=$'\033[0;33m'
  GREEN=$'\033[0;32m'
  BLUE=$'\033[0;34m'
  RESET=$'\033[0m'
else
  RED="" YELLOW="" GREEN="" BLUE="" RESET=""
fi

ok()   { echo "${GREEN}✓${RESET} $1"; PASSED=$((PASSED + 1)); }
warn() { echo "${YELLOW}⚠${RESET} $1"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo "${RED}✗${RESET} $1"; CRITICAL_FAILS=$((CRITICAL_FAILS + 1)); }
info() { echo "${BLUE}ℹ${RESET} $1"; }
section() { echo ""; echo "${BLUE}== $1 ==${RESET}"; }

echo "ADK Doctor — self-check for agent-dev-kit"
echo "Plugin root: $PLUGIN_ROOT"

# ---------------------------------------------------------------
section "1. Core structure"
# ---------------------------------------------------------------
for f in \
  ".claude-plugin/marketplace.json" \
  ".claude-plugin/plugin.json" \
  "README.md" \
  "hooks/hooks.json" \
  "scripts/impact-analyzer.mjs" \
  "scripts/case-logger.mjs" \
  "scripts/pattern-extractor.mjs" \
  "co-update/patterns-library.md" \
  "co-update/category-taxonomy.md" \
  "co-update/setup-guide.md" \
  "scripts/package.json"
do
  if [ -f "$PLUGIN_ROOT/$f" ]; then
    ok "$f exists"
  else
    fail "$f MISSING"
  fi
done

# ---------------------------------------------------------------
section "2. JSON validity"
# ---------------------------------------------------------------
for f in \
  ".claude-plugin/marketplace.json" \
  ".claude-plugin/plugin.json" \
  "hooks/hooks.json" \
  "scripts/package.json"
do
  if [ ! -f "$PLUGIN_ROOT/$f" ]; then
    continue
  fi
  # Pass path via argv to avoid backslash escaping issues on Windows paths
  if node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$PLUGIN_ROOT/$f" 2>/dev/null; then
    ok "$f is valid JSON"
  else
    fail "$f has JSON syntax errors"
  fi
done

# ---------------------------------------------------------------
section "3. Hook scripts executable"
# ---------------------------------------------------------------
for sh in "$PLUGIN_ROOT/hooks"/*.sh; do
  [ -f "$sh" ] || continue
  name=$(basename "$sh")
  if [ -x "$sh" ]; then
    ok "hooks/$name is executable"
  else
    if [ "$FIX_MODE" = "--fix" ]; then
      chmod +x "$sh" 2>/dev/null && ok "hooks/$name fixed (chmod +x)" || warn "hooks/$name chmod failed"
    else
      warn "hooks/$name not executable (run with --fix)"
    fi
  fi
done

# ---------------------------------------------------------------
section "4. Hook bash syntax"
# ---------------------------------------------------------------
for sh in "$PLUGIN_ROOT/hooks"/*.sh "$PLUGIN_ROOT/hooks/lib"/*.sh; do
  [ -f "$sh" ] || continue
  name="${sh#$PLUGIN_ROOT/}"
  if bash -n "$sh" 2>/dev/null; then
    ok "$name syntax OK"
  else
    fail "$name has bash syntax errors"
  fi
done

# ---------------------------------------------------------------
section "5. Skills & agents frontmatter"
# ---------------------------------------------------------------
for md in "$PLUGIN_ROOT/skills"/*/SKILL.md "$PLUGIN_ROOT/agents"/*.md; do
  [ -f "$md" ] || continue
  name="${md#$PLUGIN_ROOT/}"
  # Frontmatter must start and end with ---
  if head -1 "$md" | grep -q "^---$"; then
    ok "$name has frontmatter"
  else
    warn "$name missing YAML frontmatter"
  fi
done

# ---------------------------------------------------------------
section "6. Templates present"
# ---------------------------------------------------------------
for t in \
  "skills/spec/templates/spec-report.md" \
  "skills/plan/templates/plan.md" \
  "skills/review/templates/verify.md"
do
  if [ -f "$PLUGIN_ROOT/$t" ]; then
    ok "$t present"
  else
    warn "$t missing (templates feature)"
  fi
done

# ---------------------------------------------------------------
section "7. Scripts dependencies (ts-morph, madge)"
# ---------------------------------------------------------------
if [ -d "$PLUGIN_ROOT/scripts/node_modules/ts-morph" ]; then
  ok "ts-morph installed"
else
  fail "ts-morph NOT installed — run: cd scripts && npm install"
fi
if [ -d "$PLUGIN_ROOT/scripts/node_modules/madge" ]; then
  ok "madge installed"
else
  fail "madge NOT installed — run: cd scripts && npm install"
fi

# ---------------------------------------------------------------
section "8. impact-analyzer smoke test"
# ---------------------------------------------------------------
if [ -d "$PLUGIN_ROOT/scripts/node_modules/ts-morph" ]; then
  if node "$PLUGIN_ROOT/scripts/impact-analyzer.mjs" "$PLUGIN_ROOT/scripts/impact-analyzer.mjs" --json >/dev/null 2>&1; then
    ok "impact-analyzer runs cleanly"
  else
    warn "impact-analyzer exited non-zero (may be 🟡 or 🔴 — not a critical failure)"
  fi
else
  warn "impact-analyzer smoke test skipped (deps missing)"
fi

# ---------------------------------------------------------------
section "9. impact-analyzer unit tests"
# ---------------------------------------------------------------
if [ -f "$PLUGIN_ROOT/scripts/test/impact-analyzer.test.mjs" ]; then
  if [ -d "$PLUGIN_ROOT/scripts/node_modules/ts-morph" ]; then
    if (cd "$PLUGIN_ROOT/scripts" && node --test test/impact-analyzer.test.mjs >/dev/null 2>&1); then
      ok "unit tests passing"
    else
      warn "unit tests failing — run: cd scripts && npm test"
    fi
  else
    warn "unit tests skipped (deps missing)"
  fi
else
  warn "test suite not present"
fi

# ---------------------------------------------------------------
section "10. MCP environment (optional)"
# ---------------------------------------------------------------
for var in GITHUB_TOKEN DATABASE_URL_READONLY; do
  if [ -n "${!var:-}" ]; then
    ok "$var set (MCP will connect)"
  else
    warn "$var not set (related MCP server disabled, non-critical)"
  fi
done
for var in OPENAI_API_KEY MILVUS_ADDRESS; do
  if [ -n "${!var:-}" ]; then
    ok "$var set"
  else
    info "$var not set (optional — claude-context MCP)"
  fi
done

# ---------------------------------------------------------------
section "11. Co-update Map (target project, optional)"
# ---------------------------------------------------------------
# Check the CWD (not plugin root) for a project that consumes the library.
TARGET_ROOT="${ADK_TARGET_PROJECT:-$PWD}"
if [ -d "$TARGET_ROOT/.md/co-update" ]; then
  if [ -f "$TARGET_ROOT/.md/co-update/patterns.md" ]; then
    ok ".md/co-update/patterns.md exists in target project"
  else
    warn "target project missing .md/co-update/patterns.md (see co-update/setup-guide.md)"
  fi
  if [ -f "$TARGET_ROOT/.md/co-update/cases.md" ]; then
    ok ".md/co-update/cases.md exists in target project"
  else
    warn "target project missing .md/co-update/cases.md"
  fi
  # Unresolved placeholders?
  if [ -f "$TARGET_ROOT/.md/co-update/patterns.md" ] && grep -qE '<[a-z]+_[a-z_]+>' "$TARGET_ROOT/.md/co-update/patterns.md" 2>/dev/null; then
    warn "patterns.md still has unresolved <placeholder> tokens — run sed replacement (setup-guide Step 2)"
  fi
else
  info "no .md/co-update/ in CWD — run setup-guide.md if this should be a co-update project"
fi

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo ""
echo "${BLUE}═══════════════════════════════════${RESET}"
echo "Doctor report"
echo "${BLUE}═══════════════════════════════════${RESET}"
echo "Passed:    $PASSED"
echo "Warnings:  $WARNINGS"
echo "Critical:  $CRITICAL_FAILS"
echo ""

if [ $CRITICAL_FAILS -gt 0 ]; then
  echo "${RED}🔴 Plugin is NOT ready. Fix critical issues above.${RESET}"
  echo ""
  echo "Common fixes:"
  echo "  cd \"$PLUGIN_ROOT/scripts\" && npm install"
  echo "  bash \"$0\" --fix    # for executable bit issues"
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  echo "${YELLOW}🟡 Plugin works but some optional features are disabled.${RESET}"
  echo "   Review warnings above. Not a blocker."
  exit 0
else
  echo "${GREEN}🟢 All checks passed. Plugin is ready.${RESET}"
  exit 0
fi
