#!/usr/bin/env bash
# Prints a fact sheet for one folder's files: line count, the first comment or
# docstring line, and the names actually defined in each file (functions,
# classes, exports, HTTP routes). Maps must take key symbols from this output,
# so no symbol is ever guessed from a file name.
#
#   symbols.sh <folder>        (run from the repo root; "." = root)
#   symbols.sh --list <file>   one item per line, no limit, for comparing before
#                              and after an edit:  "S name"  "R METHOD /route"
#                              "D first comment"
#
# Covers Python, JS/TS, and Go. For other languages it still lists the files,
# so read those files to find their symbols.

max=15

# Sets $doc, $syms and $routes for the file $1.
extract() {
  local f="$1"
  syms=""; routes=""

  doc=$(grep -m1 -E '^[[:space:]]*(#[^!]|//|/\*\*?|"""|'"'''"')' "$f" 2>/dev/null \
    | sed -E 's/^[[:space:]]*(#|\/\/|\/\*\*?|"""|'"'''"')[[:space:]]*//' | cut -c1-100)

  case "$f" in
    *.py)
      syms=$(sed -nE \
        -e 's/^(async[[:space:]]+)?def[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/p' \
        -e 's/^class[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p' \
        -e 's/^([A-Z][A-Za-z0-9_]*)[[:space:]]*(:[^=]*)?=.*/\1/p' "$f")
      # Route decorators, including ones whose path is on the next line.
      routes=$(awk '
        /^@[A-Za-z_]+\.(get|post|put|patch|delete)\(/ {
          m = $0; sub(/^@[A-Za-z_]+\./, "", m)
          method = m; sub(/\(.*/, "", method)
          rest = m; sub(/^[a-z]+\(/, "", rest)
          if (rest !~ /["\047]/) { getline rest }
          if (match(rest, /["\047][^"\047]*["\047]/)) print toupper(method) " " substr(rest, RSTART + 1, RLENGTH - 2)
        }' "$f")
      ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
      syms=$(sed -nE \
        -e 's/^export[[:space:]]+(default[[:space:]]+)?(async[[:space:]]+)?(function|class|const|let|var|interface|type|enum)[[:space:]]+([A-Za-z_$][A-Za-z0-9_$]*).*/\4/p' \
        -e 's/^export[[:space:]]+default[[:space:]]+([A-Za-z_$][A-Za-z0-9_$]*)[[:space:];]*$/\1/p' \
        -e 's/^export[[:space:]]*\{([^}]*)\}.*/\1/p' "$f" | tr ',' '\n' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/.* as //')
      routes=$(sed -nE 's/.*createFileRoute\([[:space:]]*["'"'"']([^"'"'"']*).*/PAGE \1/p' "$f")
      ;;
    *.go)
      syms=$(sed -nE \
        -e 's/^func[[:space:]]+(\([^)]*\)[[:space:]]*)?([A-Za-z_][A-Za-z0-9_]*).*/\2/p' \
        -e 's/^type[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p' "$f")
      ;;
  esac
}

if [ "${1:-}" = "--list" ]; then
  f="${2:?usage: symbols.sh --list <file>}"
  [ -f "$f" ] || exit 0
  extract "$f"
  printf '%s\n' "$syms" | grep . | awk '!seen[$0]++' | sed 's/^/S /'
  printf '%s\n' "$routes" | grep . | awk '!seen[$0]++' | sed 's/^/R /'
  [ -n "$doc" ] && echo "D $doc"
  exit 0
fi

dir="${1:?usage: symbols.sh <folder>}"
dir="${dir%/}"

here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
files=$(list_files \
  | awk -v d="$dir" 'd == "." ? $0 !~ /\// : (index($0, d "/") == 1 && substr($0, length(d) + 2) !~ /\//)')

printf '%s\n' "$files" | grep -vE '(^|/)DIRMAP\.md$' | sort | while IFS= read -r f; do
  [ -f "$f" ] || continue
  lines=$(wc -l < "$f" | tr -d ' ')
  echo "== $(basename "$f") ($lines lines)"

  extract "$f"
  [ -n "$doc" ] && echo "  first comment: $doc"

  if [ -n "$syms" ]; then
    count=$(printf '%s\n' "$syms" | grep -c .)
    list=$(printf '%s\n' "$syms" | grep . | awk '!seen[$0]++' | head -n "$max" | paste -sd ',' - | sed 's/,/, /g')
    [ "$count" -gt "$max" ] && list="$list, ... ($count total)"
    echo "  defines: $list"
  fi
  [ -n "$routes" ] && echo "  routes: $(printf '%s\n' "$routes" | paste -sd ',' - | sed 's/,/, /g')"
done
exit 0
