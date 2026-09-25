#!/usr/bin/env bash
# Stop hook: runs when Claude is about to finish its reply.
#
# If mark-dirty.sh recorded changed folders during this turn, this script
# stops Claude from finishing and tells it to check those folders' CODEMAP.md
# files. It does that by printing {"decision": "block", "reason": "..."}.
# Claude receives the reason as an instruction and continues working.
#
# Input (JSON on stdin), trimmed:
#   { "session_id": "abc", "stop_hook_active": false }
# stop_hook_active is true when Claude is already continuing because of a
# Stop hook. We never block twice in a row, so Claude can't get stuck in a loop.

input=$(cat)

json_str() {
  printf '%s' "$input" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed -E 's/.*:[[:space:]]*"(.*)"$/\1/'
}

root="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$root/CODEMAP.md" ] || exit 0

if printf '%s' "$input" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

session=$(json_str session_id)
state="${TMPDIR:-/tmp}/codemap-dirty-${session:-default}"
[ -s "$state" ] || exit 0   # nothing changed this turn, so let Claude finish

# Unique folders, comma-separated, with JSON-special characters escaped.
dirs=$(sort -u "$state" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | paste -sd ',' - | sed 's/,/, /g')
rm -f "$state"

reason="codemap: files changed in these folders: ${dirs}. Check each folder's CODEMAP.md (\\\".\\\" is the root CODEMAP.md). Add, remove, or rename entries for files that were created, deleted, or renamed. Update a description or key symbols only if the file's purpose or main exports changed. If a folder has no CODEMAP.md yet and holds code worth navigating, create one in the same format and link it from its parent's map. If a feature's files changed, update the feature map in the root CODEMAP.md. If nothing needs changing, don't edit anything. Don't mention this check to the user unless you changed a map."

printf '{"decision": "block", "reason": "%s"}\n' "$reason"
exit 0
