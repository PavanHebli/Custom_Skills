#!/usr/bin/env bash
# Lists the folders dirmap should map, deepest first, so child maps are
# written before the parent maps that summarize them. Every folder that holds
# files (and all its parents) is listed.
#
#   folders.sh        (run from the project root)
#
# Output: one path per line, relative to the root ("." = the root itself).

here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"

list_files \
  | grep -vE '(^|/)DIRMAP\.md$' \
  | grep -v '^$' \
  | awk '
      function emit(d,   depth, q) {
        if (d in seen) return
        seen[d] = 1
        depth = (d == ".") ? 0 : split(d, q, "/")
        print depth "\t" d
      }
      {
        n = split($0, p, "/")
        emit(".")
        d = ""
        for (i = 1; i < n; i++) {
          d = (i == 1) ? p[1] : d "/" p[i]
          emit(d)
        }
      }' \
  | sort -t "$(printf '\t')" -k1,1nr -k2,2 \
  | cut -f2
