#!/usr/bin/env bash
# SessionStart hook: runs when a Claude Code session starts, resumes, or is compacted.
#
# Anything this script prints is added to Claude's context. We print the root
# CODEMAP.md, so Claude starts every session already knowing the repo's layout,
# plus a warning if the maps look out of date.

root="${CLAUDE_PROJECT_DIR:-$PWD}"
map="$root/CODEMAP.md"
[ -f "$map" ] || exit 0

max_lines=200

cat <<'EOF'
This repo has a codemap: the root CODEMAP.md below describes the project, and
each folder has its own CODEMAP.md listing that folder's files and subfolders.
To find code, follow the maps first (root, then the folder, then the file), and
open the candidate files to confirm. Search the codebase only if the maps don't
lead anywhere. The maps are a guide, not the truth: the code wins if they disagree.

--- CODEMAP.md (root) ---
EOF

head -n "$max_lines" "$map"
total=$(wc -l < "$map")
if [ "$total" -gt "$max_lines" ]; then
  echo "... (root map truncated at $max_lines of $total lines; read CODEMAP.md for the rest)"
fi
echo "--- end of root CODEMAP.md ---"

# Staleness check: how many files changed since the commit the maps were built from?
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  sha=$(grep -oE 'codemap: indexed-at [0-9a-f]+' "$map" | head -1 | awk '{print $3}')
  if [ -n "$sha" ] && git -C "$root" cat-file -e "$sha^{commit}" 2>/dev/null; then
    changed=$(
      { git -C "$root" diff --name-only "$sha" --; git -C "$root" ls-files --others --exclude-standard; } \
        | grep -vE '(^|/)CODEMAP\.md$' | sort -u | wc -l | tr -d ' '
    )
    if [ "$changed" -gt 0 ]; then
      echo
      echo "Note: $changed file(s) changed since the codemap was last built (commit $sha)."
      echo "Some maps may be out of date. If they seem wrong, suggest running /codemap to refresh them."
    fi
  fi
fi

exit 0
