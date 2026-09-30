#!/usr/bin/env bash
# SessionStart hook: runs when a Claude Code session starts, resumes, or is compacted.
#
# Anything this script prints is added to Claude's context. We print the root
# DIRMAP.md, so Claude starts every session already knowing the repo's layout,
# plus a warning if the maps look out of date.

root="${CLAUDE_PROJECT_DIR:-$PWD}"
map="$root/DIRMAP.md"
[ -f "$map" ] || exit 0

max_lines=200

cat <<EOF
This repo has a dirmap. Repo root: $root
The root DIRMAP.md is below. Each folder also has its own DIRMAP.md listing
that folder's files and subfolders. Links in a map are relative to that map's
folder, so src/auth/DIRMAP.md's link to login.ts means $root/src/auth/login.ts.

How to use it:
- Pick candidate files from the maps (root, then the folder's DIRMAP.md), then
  Read those files directly by their full path. You usually don't need a search
  sub-agent for this.
- Search the codebase only if the maps don't lead anywhere, or to find every
  use of a symbol.
- The maps are a guide, not the truth: confirm by reading the code, and trust
  the code if they disagree.

--- DIRMAP.md (root) ---
EOF

head -n "$max_lines" "$map"
total=$(wc -l < "$map")
if [ "$total" -gt "$max_lines" ]; then
  echo "... (root map truncated at $max_lines of $total lines; read DIRMAP.md for the rest)"
fi
echo "--- end of root DIRMAP.md ---"

# Staleness check: how many files changed since the commit the maps were built from?
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  sha=$(grep -oE 'dirmap: indexed-at [0-9a-f]+' "$map" | head -1 | awk '{print $3}')
  if [ -n "$sha" ] && git -C "$root" cat-file -e "$sha^{commit}" 2>/dev/null; then
    changed=$(
      { git -C "$root" diff --name-only "$sha" --; git -C "$root" ls-files --others --exclude-standard; } \
        | grep -vE '(^|/)DIRMAP\.md$' | sort -u | wc -l | tr -d ' '
    )
    if [ "$changed" -gt 0 ]; then
      echo
      echo "Note: $changed file(s) changed since the dirmap was last built (commit $sha)."
      echo "Some maps may be out of date. If they seem wrong, suggest running /dirmap to refresh them."
    fi
  fi
fi

exit 0
