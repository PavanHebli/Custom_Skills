#!/usr/bin/env bash
# PreToolUse hook: runs just before Claude edits or writes a file.
#
# It takes a snapshot of the file as it is now: its symbols (functions, classes,
# routes) and a copy of its contents. At the end of the turn, sync-maps.sh
# compares the file with this snapshot to see what really changed, and updates
# the DIRMAP.md files itself when it can. Only the first edit of a file in a
# turn is snapshotted, so the snapshot always shows the "before".
#
# It never writes to the repo: snapshots go to the temp folder.
#
# Input (JSON on stdin), trimmed:
#   { "session_id": "abc", "tool_name": "Edit",
#     "tool_input": { "file_path": "/repo/src/auth/login.ts", ... } }

input=$(cat)

# Pull a string field out of the JSON without needing jq installed.
json_str() {
  printf '%s' "$input" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed -E 's/.*:[[:space:]]*"(.*)"$/\1/'
}

root="${CLAUDE_PROJECT_DIR:-$PWD}"

# Opt-in: only act in repos where /dirmap has been run.
[ -f "$root/DIRMAP.md" ] || exit 0

file=$(json_str file_path)
[ -n "$file" ] || file=$(json_str notebook_path)   # NotebookEdit uses a different field
[ -n "$file" ] || exit 0

# Editing a map itself is never snapshotted.
[ "$(basename "$file")" = "DIRMAP.md" ] && exit 0

# Only files inside this project count. Convert to a path relative to the root,
# trying the resolved form too (macOS: /tmp is really /private/tmp).
root_real=$(cd "$root" 2>/dev/null && pwd -P)
case "$file" in
  "$root"/*)      rel="${file#"$root"/}" ;;
  "$root_real"/*) rel="${file#"$root_real"/}" ;;
  /*)             exit 0 ;;
  *)              rel="$file" ;;
esac

# Skip files git ignores (build output, .env, ...). They never appear in maps.
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$root" check-ignore -q -- "$rel" && exit 0
fi

session=$(json_str session_id)
snap="${TMPDIR:-/tmp}/dirmap-${session:-default}"
key=$(printf '%s' "$rel" | cksum | cut -d' ' -f1)
[ -e "$snap/$key.path" ] && exit 0   # already snapshotted this turn
mkdir -p "$snap" || exit 0

symbols="$(cd "$(dirname "$0")/../skills/dirmap/scripts" && pwd)/symbols.sh"

if [ -f "$root/$rel" ]; then
  # An existing file: remember what it defines and what it looked like.
  ( cd "$root" && bash "$symbols" --list "$rel" ) > "$snap/$key.list" 2>/dev/null
  size=$(wc -c < "$root/$rel" | tr -d ' ')
  [ "${size:-0}" -le 1048576 ] && cp "$root/$rel" "$snap/$key.orig"
else
  # The file doesn't exist yet, so Claude is about to create it.
  : > "$snap/$key.new"
fi
printf '%s\n' "$rel" > "$snap/$key.path"

exit 0
