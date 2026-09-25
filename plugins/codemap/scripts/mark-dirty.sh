#!/usr/bin/env bash
# PostToolUse hook: runs every time Claude edits or writes a file.
#
# It only takes notes. It records which folder the changed file is in, so the
# Stop hook (stop-check.sh) can ask Claude to update that folder's CODEMAP.md
# at the end of the turn. It never writes to the repo.
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

# Opt-in: only act in repos where /codemap has been run.
[ -f "$root/CODEMAP.md" ] || exit 0

file=$(json_str file_path)
[ -n "$file" ] || file=$(json_str notebook_path)   # NotebookEdit uses a different field
[ -n "$file" ] || exit 0

# Editing a map itself shouldn't mark the folder as needing a map update.
[ "$(basename "$file")" = "CODEMAP.md" ] && exit 0

# Only files inside this project count. Convert to a path relative to the root.
case "$file" in
  "$root"/*) rel="${file#"$root"/}" ;;
  /*)        exit 0 ;;
  *)         rel="$file" ;;
esac

# Skip files git ignores (build output, .env, ...). They never appear in maps.
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$root" check-ignore -q -- "$rel" && exit 0
fi

dir=$(dirname "$rel")   # "." means the repo root

# One notes file per session, kept in the temp folder so it never ends up in the repo.
session=$(json_str session_id)
state="${TMPDIR:-/tmp}/codemap-dirty-${session:-default}"
printf '%s\n' "$dir" >> "$state"

exit 0
