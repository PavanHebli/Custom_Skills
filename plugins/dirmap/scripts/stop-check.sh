#!/usr/bin/env bash
# Stop hook: runs when Claude is about to finish its reply.
#
# If Claude edited files this turn, snapshot.sh left before-edit snapshots
# behind. sync-maps.sh compares them with the files now, updates the DIRMAP.md
# files itself wherever a script can (file rows, symbol lists), and prints what
# is left for Claude, if anything. Only then do we stop Claude from finishing,
# by printing {"decision": "block", "reason": "..."}. Claude receives the reason
# as an instruction and continues. When nothing is left, Claude just finishes.
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
[ -f "$root/DIRMAP.md" ] || exit 0

if printf '%s' "$input" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

session=$(json_str session_id)
snap="${TMPDIR:-/tmp}/dirmap-${session:-default}"
[ -d "$snap" ] || exit 0   # nothing was edited this turn, so let Claude finish

msg=$(cd "$root" && bash "$(dirname "$0")/sync-maps.sh" "$snap")
rm -rf "$snap"
[ -n "$msg" ] || exit 0    # the maps are up to date

# Escape for JSON: backslashes, quotes, then newlines.
reason=$(printf '%s' "$msg" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')

printf '{"decision": "block", "reason": "%s"}\n' "$reason"
exit 0
