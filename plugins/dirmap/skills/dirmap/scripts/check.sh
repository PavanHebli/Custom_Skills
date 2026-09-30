#!/usr/bin/env bash
# Checks every DIRMAP.md against the code:
#   - every link points to a file or folder that exists
#   - every key symbol listed for a file actually appears in that file
# Prints one line per problem. Exit code 1 if any problems were found.
#
#   check.sh            check every map (run from the repo root)
#   check.sh <map>...   check only the given maps

if [ "$#" -gt 0 ]; then
  maps=$(printf '%s\n' "$@")
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  maps=$(git ls-files --cached --others --exclude-standard | grep -E '(^|/)DIRMAP\.md$')
else
  maps=$(find . -name DIRMAP.md -not -path '*/node_modules/*' | sed 's#^\./##')
fi

problems=0
nmaps=0
while IFS= read -r map; do
  [ -f "$map" ] || continue
  nmaps=$((nmaps + 1))
  dir=$(dirname "$map")

  # 0. Unfinished drafts from scaffold.sh
  todos=$(grep -c 'TODO' "$map")
  if [ "$todos" -gt 0 ]; then
    echo "UNFINISHED      $map has $todos TODO(s) left"
    problems=$((problems + todos))
  fi

  # 1. Links: [text](target)
  while IFS= read -r target; do
    case "$target" in http*|"") continue ;; esac
    if [ ! -e "$dir/$target" ]; then
      echo "BROKEN LINK     $map -> $target"
      problems=$((problems + 1))
    fi
  done < <(grep -oE '\]\([^)#[:space:]]+\)' "$map" | sed -E 's/^\]\((.*)\)$/\1/')

  # 2. File rows: | [file](file) | purpose | `sym`, `sym` |
  while IFS= read -r row; do
    target=$(printf '%s' "$row" | sed -nE 's/^\|[[:space:]]*\[[^]]*\]\(([^)]*)\).*/\1/p')
    [ -f "$dir/$target" ] || continue
    fields=$(printf '%s' "$row" | awk -F'|' '{print NF}')
    [ "$fields" -ge 5 ] || continue   # folder rows have no symbols column
    last=$(printf '%s' "$row" | awk -F'|' '{print $(NF-1)}')
    while IFS= read -r sym; do
      name="${sym%%(*}"
      name="${name##*.}"
      printf '%s' "$name" | grep -qE '^[A-Za-z_$][A-Za-z0-9_$]*$' || continue
      if ! grep -qwF -- "$name" "$dir/$target"; then
        echo "MISSING SYMBOL  $dir/$target: $name   (listed in $map)"
        problems=$((problems + 1))
      fi
    done < <(printf '%s' "$last" | grep -oE '`[^`]+`' | tr -d '`')
  done < <(grep -E '^\|[[:space:]]*\[[^]]+\]\([^)]+\)' "$map")
done <<< "$maps"

echo "Checked $nmaps maps: $problems problem(s)."
[ "$problems" -eq 0 ]
