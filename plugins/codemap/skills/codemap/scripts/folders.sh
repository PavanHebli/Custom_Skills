#!/usr/bin/env bash
# Lists the folders codemap should map, deepest first, so child maps are
# written before the parent maps that summarize them.
#
#   folders.sh all             every folder with tracked or untracked (not ignored)
#                              files, plus all their parent folders
#   folders.sh changed <sha>   only folders with files changed since commit <sha>,
#                              including uncommitted and new files
#
# Folders that were deleted still appear in "changed" output. Check whether each
# one still exists. Output: one path per line, relative to the repo root ("." = root).

set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

mode="${1:-all}"
case "$mode" in
  all)
    files=$(git ls-files --cached --others --exclude-standard)
    all=1
    ;;
  changed)
    sha="${2:?usage: folders.sh changed <sha>}"
    files=$( { git diff --name-only "$sha" --; git ls-files --others --exclude-standard; } )
    all=0
    ;;
  *)
    echo "usage: folders.sh all | folders.sh changed <sha>" >&2
    exit 1
    ;;
esac

printf '%s\n' "$files" \
  | grep -vE '(^|/)CODEMAP\.md$' \
  | grep -v '^$' \
  | awk -v all="$all" '
      function emit(d,   depth, q) {
        if (d in seen) return
        seen[d] = 1
        depth = (d == ".") ? 0 : split(d, q, "/")
        print depth "\t" d
      }
      {
        n = split($0, p, "/")
        if (all || n == 1) emit(".")
        d = ""
        for (i = 1; i < n; i++) {
          d = (i == 1) ? p[1] : d "/" p[i]
          if (all || i == n - 1) emit(d)
        }
      }' \
  | sort -t "$(printf '\t')" -k1,1nr -k2,2 \
  | cut -f2
