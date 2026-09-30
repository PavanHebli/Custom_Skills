#!/usr/bin/env bash
# Brings the DIRMAP.md files up to date after a turn in which Claude edited
# files. Called by stop-check.sh with the snapshot folder that snapshot.sh
# filled in. Run from the repo root.
#
# What a script can do exactly, it does itself, with no AI and no tokens:
#   - a file was deleted            -> its row is removed from the folder's map
#   - a file's symbols changed      -> the "Key symbols" cell is edited (names
#                                      that disappeared are removed, new ones
#                                      appended; the rest of the cell is kept)
#   - a new file appeared           -> a row is added, with real symbols
#   - a new folder appeared         -> its map is drafted and linked from its parent
# What only judgement can do is left to Claude, and printed as a short list:
#   - a purpose to write for a new file or folder (marked TODO)
#   - a purpose to recheck, because the file was largely rewritten or its
#     top-of-file comment changed
#   - problems the checker finds (broken links, missing symbols)
# Small edits that change none of this print nothing: the map is still right.

here="$(cd "$(dirname "$0")" && pwd)"
sk="$here/../skills/dirmap/scripts"
snap="${1:?usage: sync-maps.sh <snapshot-dir>}"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dirmap-sync.XXXXXX") || exit 0
trap 'rm -rf "$tmp"' EXIT

touched=""   # maps this script changed, one per line
recheck=""   # purposes Claude should recheck, one per line
code_re='\.(py|pyi|ts|tsx|js|jsx|mjs|cjs|go|rb|java|kt|rs|php|cs|swift|c|h|cpp|hpp|sh|sql|md|html|vue|svelte|ya?ml|toml)$'

map_for() { if [ "$1" = "." ]; then echo "DIRMAP.md"; else echo "$1/DIRMAP.md"; fi; }

note_touched() { printf '%s' "$touched" | grep -qxF -- "$1" || touched="$touched$1"$'\n'; }

# Rows look like:  | [name](target) | purpose | `symbols` |
# Everything below finds a row by its target, as a fixed string.
has_row() { awk -v key="](${2}) |" 'substr($0,1,3) == "| [" && index($0, key) > 0 { f = 1 } END { exit !f }' "$1"; }

remove_row() {
  awk -v key="](${2}) |" 'substr($0,1,3) == "| [" && index($0, key) > 0 { next } { print }' "$1" > "$tmp/out" \
    && cat "$tmp/out" > "$1"
}

# Turns "S name" / "R route" lines (stdin) into the text of a Key symbols cell.
fmt_cell() {
  awk -v max=6 '
    substr($0,1,2) == "S " { if (n < max) { names = names (n ? ", " : "") "`" substr($0,3) "`"; n++ } next }
    substr($0,1,2) == "R " { routes = routes (r ? ", " : "") substr($0,3); r++ }
    END {
      if (names != "" && routes != "") print names "; " routes
      else if (names != "") print names
      else if (routes != "") print routes
      else print "—"
    }'
}

# Edits the Key symbols cell of one row: removes the names in $3, appends the
# names in $4 (files of "S name" / "R route" lines), and keeps everything else.
update_cell() {
  awk -v t="$2" -v remf="$3" -v addf="$4" '
    BEGIN {
      while ((getline l < remf) > 0) { if (substr(l,1,2) == "S ") remS[substr(l,3)] = 1; else if (substr(l,1,2) == "R ") remR[substr(l,3)] = 1 }
      while ((getline l < addf) > 0) { if (substr(l,1,2) == "S ") addS[++na] = substr(l,3); else if (substr(l,1,2) == "R ") addR[++nr] = substr(l,3) }
      key = "](" t ") |"
    }
    substr($0,1,3) == "| [" && index($0, key) > 0 {
      line = $0
      sub(/[ \t]*\|[ \t]*$/, "", line)
      cnt = 0; p = 0
      for (i = 1; i <= length(line); i++) if (substr(line, i, 1) == "|") { cnt++; p = i }
      if (cnt < 3) { print $0; next }
      head = substr(line, 1, p)
      cell = substr(line, p + 1)
      gsub(/^[ \t]+|[ \t]+$/, "", cell)
      gsub(/; /, ", ", cell)
      k = split(cell, T, ", ")
      split("", seenS); split("", seenR); split("", N); split("", Rt)
      nn = 0; nrt = 0
      for (i = 1; i <= k; i++) {
        tk = T[i]
        if (tk == "" || tk == "—") continue
        if (tk ~ /^`.*`$/) {
          nm = substr(tk, 2, length(tk) - 2)
          if (nm in remS) continue
          if (!(nm in seenS)) { seenS[nm] = 1; N[++nn] = tk }
        } else if (tk ~ /^(GET|POST|PUT|PATCH|DELETE|PAGE) /) {
          if (tk in remR) continue
          if (!(tk in seenR)) { seenR[tk] = 1; Rt[++nrt] = tk }
        } else {
          N[++nn] = tk
        }
      }
      for (i = 1; i <= na; i++) if (!(addS[i] in seenS) && nn < 10) { seenS[addS[i]] = 1; N[++nn] = "`" addS[i] "`" }
      for (i = 1; i <= nr; i++) if (!(addR[i] in seenR)) { seenR[addR[i]] = 1; Rt[++nrt] = addR[i] }
      names = ""; for (i = 1; i <= nn; i++) names = names (i > 1 ? ", " : "") N[i]
      routes = ""; for (i = 1; i <= nrt; i++) routes = routes (i > 1 ? ", " : "") Rt[i]
      if (names != "" && routes != "") out = names "; " routes
      else if (names != "") out = names
      else if (routes != "") out = routes
      else out = "—"
      print head " " out " |"
      next
    }
    { print }' "$1" > "$tmp/out" && cat "$tmp/out" > "$1"
}

# Adds a row to a table, in name order. $1 map, $2 section heading, $3 name (to
# sort by), $4 the row, $5/$6 the table's header lines (used if the section is missing).
add_row() {
  awk -v sec="$2" -v key="$3" -v row="$4" -v h1="$5" -v h2="$6" '
    $0 == sec { found = 1; insec = 1; seen = 0; print; next }
    insec {
      if (substr($0,1,1) == "|") {
        seen++
        if (seen > 2 && !done && match($0, /^\| \[[^]]*\]/)) {
          k = substr($0, 4, RLENGTH - 4)
          if (k > key) { print row; done = 1 }
        }
        print; next
      }
      if (!done) { print row; done = 1 }
      insec = 0
    }
    { print }
    END {
      if (insec && !done) print row
      if (!found) { print ""; print sec; print h1; print h2; print row }
    }' "$1" > "$tmp/out" && cat "$tmp/out" > "$1"
}

# Removes rows whose file no longer exists, in one folder's map.
drop_missing_rows() {
  local map="$1" dir t
  dir=$(dirname "$map")
  sed -nE 's/^\| \[[^]]+\]\(([^)/]+)\) \|.*/\1/p' "$map" > "$tmp/targets"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if [ ! -e "$dir/$t" ]; then
      remove_row "$map" "$t"
      note_touched "$map"
    fi
  done < "$tmp/targets"
}

# Makes sure the folder $1 and its parents have a map, drafting missing ones and
# linking each from its parent. Returns 1 if the folder isn't worth mapping.
ensure_maps() {
  local d="$1" chain="" c b parent pm created m
  while [ "$d" != "." ] && [ ! -f "$d/DIRMAP.md" ]; do
    chain="$d"$'\n'"$chain"
    d=$(dirname "$d")
  done
  [ -n "$chain" ] || return 0
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    created=$(bash "$sk/scaffold.sh" --only "$c" 2>/dev/null)
    [ -f "$c/DIRMAP.md" ] || return 1
    while IFS= read -r m; do [ -n "$m" ] && note_touched "$m"; done <<< "$created"
    parent=$(dirname "$c"); pm=$(map_for "$parent"); b=$(basename "$c")
    [ -f "$pm" ] || return 1
    if ! has_row "$pm" "$b/DIRMAP.md"; then
      add_row "$pm" "## Folders" "$b/" "| [$b/]($b/DIRMAP.md) | TODO |" "| Folder | Purpose |" "|---|---|"
      note_touched "$pm"
    fi
  done <<< "$chain"
  return 0
}

# ---- 1. Work out which folders were touched, and drop rows for vanished files.
: > "$tmp/dirs"
for pf in "$snap"/*.path; do
  [ -e "$pf" ] || continue
  dirname "$(cat "$pf")" >> "$tmp/dirs"
done
sort -u "$tmp/dirs" > "$tmp/dirs.sorted"
while IFS= read -r d; do
  [ -n "$d" ] || continue
  m=$(map_for "$d")
  [ -f "$m" ] && drop_missing_rows "$m"
done < "$tmp/dirs.sorted"

# ---- 2. Go through each edited file.
for pf in "$snap"/*.path; do
  [ -e "$pf" ] || continue
  key=$(basename "$pf" .path)
  rel=$(cat "$pf"); dir=$(dirname "$rel"); base=$(basename "$rel")
  [ -f "$rel" ] || continue          # deleted again: its row is already gone

  if [ -e "$snap/$key.new" ]; then
    # A new file: add a row with real symbols; its purpose is left as TODO.
    printf '%s' "$base" | grep -qiE "$code_re" || continue
    if [ "$dir" != "." ]; then
      case "/$dir" in */.*) continue ;; esac   # hidden folders get no maps
    fi
    ensure_maps "$dir" || continue
    m=$(map_for "$dir")
    [ -f "$m" ] || continue
    has_row "$m" "$base" && continue
    cell=$(bash "$sk/symbols.sh" --list "$rel" | fmt_cell)
    add_row "$m" "## Files" "$base" "| [$base]($base) | TODO | $cell |" "| File | Purpose | Key symbols |" "|---|---|---|"
    note_touched "$m"
    continue
  fi

  # An existing file: compare what it defines now with the snapshot.
  m=$(map_for "$dir")
  [ -f "$m" ] || continue
  has_row "$m" "$base" || continue
  old="$snap/$key.list"
  [ -f "$old" ] || continue
  bash "$sk/symbols.sh" --list "$rel" > "$tmp/now"
  grep -E '^[SR] ' "$old"      | LC_ALL=C sort -u > "$tmp/o"
  grep -E '^[SR] ' "$tmp/now"  | LC_ALL=C sort -u > "$tmp/n"
  comm -23 "$tmp/o" "$tmp/n" > "$tmp/rem"
  comm -13 "$tmp/o" "$tmp/n" > "$tmp/add"
  if [ -s "$tmp/rem" ] || [ -s "$tmp/add" ]; then
    update_cell "$m" "$base" "$tmp/rem" "$tmp/add"
    note_touched "$m"
  fi

  # Was it rewritten enough that its one-line purpose may be wrong?
  rewritten=0
  [ "$(grep -m1 '^D ' "$old")" != "$(grep -m1 '^D ' "$tmp/now")" ] && rewritten=1
  if [ -f "$snap/$key.orig" ]; then
    total=$(wc -l < "$snap/$key.orig" | tr -d ' ')
    diff "$snap/$key.orig" "$rel" > "$tmp/diff" 2>/dev/null
    added=$(grep -c '^>' "$tmp/diff"); removed=$(grep -c '^<' "$tmp/diff")
    changed=$added; [ "$removed" -gt "$changed" ] && changed=$removed
    if [ "$changed" -ge 20 ] && [ $((changed * 100)) -ge $((40 * ${total:-0})) ]; then rewritten=1; fi
  fi
  [ "$rewritten" -eq 1 ] && recheck="$recheck- Recheck the Purpose of $base in $m: the file was largely rewritten. Read it again, and change the Purpose only if it no longer fits."$'\n'
done

# ---- 3. What is still wrong in the maps we touched (and the root map)?
{ printf '%s\n' "DIRMAP.md"; printf '%s' "$touched"; } | grep . | sort -u > "$tmp/tocheck"
problems=$(tr '\n' '\0' < "$tmp/tocheck" | xargs -0 bash "$sk/check.sh" 2>/dev/null | grep -v '^Checked ')

[ -n "$recheck" ] || [ -n "$problems" ] || exit 0

echo "dirmap: the maps are already updated for what a script can tell (file rows and symbol lists). What is left needs you. Paths are relative to $PWD."
[ -n "$recheck" ] && printf '%s' "$recheck"
if [ -n "$problems" ]; then
  printf '%s\n' "$problems" | sed 's/^/- /'
  echo
  echo "How to fix: for UNFINISHED, read the file (or folder) and write one line like the neighbouring rows in place of each TODO. For MISSING SYMBOL, remove that name from the row. For BROKEN LINK, correct or remove the entry (in the root map's feature map this usually means a file was moved or deleted)."
fi
echo "Edit only the DIRMAP.md files named above, and don't mention this to the user unless you changed a map."
exit 0
