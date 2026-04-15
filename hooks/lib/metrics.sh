#!/usr/bin/env bash
# ADK metrics logger — common JSONL logging helper.
#
# Sourced by other hook scripts via:
#   source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/metrics.sh"
#   adk_log EVENT_NAME key1=val1 key2=val2 ...
#
# Design:
#   - Writes JSONL (one JSON object per line) to $ADK_METRICS_FILE
#   - Default path: ~/.claude/adk-metrics.jsonl
#   - Silent failure — never breaks the hook that called it
#   - Append-only — atomic on POSIX for small writes
#   - Values are shell-escaped then JSON-escaped via node

# Default location (overridable)
: "${ADK_METRICS_FILE:=${HOME:-$USERPROFILE}/.claude/adk-metrics.jsonl}"

# Ensure parent dir exists (best effort, ignore failures)
adk_log_init() {
  local dir
  dir=$(dirname "$ADK_METRICS_FILE") || return 0
  [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null || return 0
}

# Emit one JSONL line. First arg is the event name, rest are key=value pairs.
# Usage: adk_log oversize_blocked file_path="$FILE_PATH" lines=234
adk_log() {
  adk_log_init || return 0
  local event="$1"
  shift

  # Build a JSON object via node — safe escaping regardless of shell quoting.
  node -e '
    const event = process.argv[1];
    const kvs = process.argv.slice(2);
    const obj = {
      ts: new Date().toISOString(),
      event,
      session_id: process.env.CLAUDE_SESSION_ID || null,
      cwd: process.env.CLAUDE_PROJECT_DIR || process.cwd(),
    };
    for (const kv of kvs) {
      const eq = kv.indexOf("=");
      if (eq < 0) continue;
      const k = kv.slice(0, eq);
      let v = kv.slice(eq + 1);
      // Coerce numeric values
      if (/^-?\d+$/.test(v)) v = parseInt(v, 10);
      else if (/^-?\d+\.\d+$/.test(v)) v = parseFloat(v);
      else if (v === "true") v = true;
      else if (v === "false") v = false;
      obj[k] = v;
    }
    console.log(JSON.stringify(obj));
  ' "$event" "$@" >> "$ADK_METRICS_FILE" 2>/dev/null || return 0
}
