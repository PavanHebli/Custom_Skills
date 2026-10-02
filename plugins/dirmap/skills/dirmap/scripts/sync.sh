#!/usr/bin/env bash
# Brings the DIRMAP.md files up to date with the code. Run from the project root:
#
#   bash .dirmap/sync.sh <file or folder>...   check just those (what you changed)
#   bash .dirmap/sync.sh                        check every file in the project
#
# It needs no git and no record of the past. It compares each map with the files
# as they are now:
#   - a row whose file is gone                -> the row is removed
#   - a file that has no row                  -> a row is added, with real symbols
#   - a folder that has files but no map      -> its map is drafted and linked
#     from its parent (only for files you name; see below)
#   - the Key symbols cell of a row           -> regenerated from the file. If it
#     differs from what the map says, the cell is rewritten, and you get a
#     question about the Purpose.
# The Purpose of a row belongs to the model. This script never rewrites it.
#
# What a script cannot see: a change that keeps the same function names but
# changes what the code does. For that, the model's own judgement has to act.

here="$(cd "$(dirname "$0")" && pwd)"
sk="$here"
. "$here/lib.sh"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dirmap-sync.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

if [ ! -f DIRMAP.md ]; then
  echo "dirmap: there is no DIRMAP.md here yet. Run /dirmap to build the maps first."
  exit 0
fi

touched=""    # maps this script changed, one per line
hints=""      # rows whose symbols changed: is the Purpose still right?
nhints=0
nchecked=0
unmapped=""   # folders with files but no map (whole-project mode only)

map_for() { if [ "$1" = "." ]; then echo "DIRMAP.md"; else echo "$1/DIRMAP.md"; fi; }
note_touched() { printf '%s' "$touched" | grep -qxF -- "$1" || touched="$touched$1"$'\n'; }

# Rows look like:  | [name](target) | purpose | `symbols` |
# Everything below finds a row by its target, as a fixed string.
has_row() { awk -v key="](${2}) |" 'substr($0,1,3) == "| [" && index($0, key) > 0 { f = 1 } END { exit !f }' "$1"; }

remove_row() {
  awk -v key="](${2}) |" 'substr($0,1,3) == "| [" && index($0, key) > 0 { next } { print }' "$1" > "$tmp/out" \
    && cat "$tmp/out" > "$1"
}

# The Purpose text of a row.
row_purpose() {
  awk -v key="](${2}) |" 'substr($0,1,3) == "| [" && (i = index($0, key)) > 0 {
    r = substr($0, i + length(key)); sub(/^ +/, "", r); sub(/ \|[^|]*\| *$/, "", r); print r; exit }' "$1"
}

# The last cell (Key symbols) of a row.
get_cell() {
  awk -v key="](${2}) |" 'substr($0,1,3) == "| [" && index($0, key) > 0 {
    line = $0; sub(/[ \t]*\|[ \t]*$/, "", line)
    p = 0; for (i = 1; i <= length(line); i++) if (substr(line, i, 1) == "|") p = i
    c = substr(line, p + 1); gsub(/^[ \t]+|[ \t]+$/, "", c); print c; exit }' "$1"
}

# Replaces the last cell (Key symbols) of a row.
set_cell() {
  awk -v key="](${2}) |" -v cell="$3" '
    substr($0,1,3) == "| [" && index($0, key) > 0 && !done {
      line = $0; sub(/[ \t]*\|[ \t]*$/, "", line)
      cnt = 0; p = 0
      for (i = 1; i <= length(line); i++) if (substr(line, i, 1) == "|") { cnt++; p = i }
      if (cnt < 3) { print $0; next }
      print substr(line, 1, p) " " cell " |"; done = 1; next
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

# Removes rows whose file or folder no longer exists, in one map.
drop_missing_rows() {
  local map="$1" dir t
  dir=$(dirname "$map")
  sed -nE 's/^\| \[[^]]+\]\(([^)/]+)\) \|.*/\1/p' "$map" > "$tmp/targets"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if [ ! -e "$dir/$t" ]; then remove_row "$map" "$t"; note_touched "$map"; fi
  done < "$tmp/targets"
  sed -nE 's/^\| \[[^]]+\]\(([^)/]+)\/DIRMAP\.md\) \|.*/\1/p' "$map" > "$tmp/targets"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if [ ! -d "$dir/$t" ]; then remove_row "$map" "$t/DIRMAP.md"; note_touched "$map"; fi
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

# Checks one file against its map. $2 = create (may draft a map for a new folder)
# or skip (leave folders without a map alone).
reconcile_file() {
  local rel="$1" mode="$2" dir base map newcell oldcell
  rel="${rel#./}"
  dir=$(dirname "$rel"); base=$(basename "$rel"); map=$(map_for "$dir")
  nchecked=$((nchecked + 1))

  if [ ! -f "$rel" ]; then                       # the file is gone
    if [ -f "$map" ] && has_row "$map" "$base"; then remove_row "$map" "$base"; note_touched "$map"; fi
    return
  fi
  is_row_file "$rel" || return                   # not a type that gets a row
  if [ "$dir" != "." ]; then case "/$dir" in */.*) return ;; esac; fi   # hidden folders get no maps

  if [ ! -f "$map" ]; then                       # a folder with no map
    if [ "$mode" = create ]; then
      ensure_maps "$dir" || return
    else
      case " $unmapped " in *" $dir "*) ;; *) unmapped="$unmapped $dir" ;; esac
      return
    fi
  fi

  newcell=$(bash "$sk/symbols.sh" --list "$rel" | fmt_cell)
  if ! has_row "$map" "$base"; then              # a file with no row: it is new
    add_row "$map" "## Files" "$base" "| [$base]($base) | TODO | $newcell |" "| File | Purpose | Key symbols |" "|---|---|---|"
    note_touched "$map"
    return
  fi
  oldcell=$(get_cell "$map" "$base")
  if [ "$oldcell" != "$newcell" ]; then          # its symbols changed
    set_cell "$map" "$base" "$newcell"
    note_touched "$map"
    if [ "$nhints" -lt 5 ]; then
      hints="$hints- $base (row in $map): its symbols changed, now $newcell. Its Purpose says: \"$(row_purpose "$map" "$base")\". Does that still describe everything the file does? If not, rewrite it."$'\n'
      nhints=$((nhints + 1))
    fi
  fi
}

# ---- what to check -----------------------------------------------------------

: > "$tmp/files"
if [ "$#" -gt 0 ]; then
  mode=create
  for a in "$@"; do
    a="${a#./}"; a="${a%/}"
    if [ -d "$a" ]; then list_files | awk -v d="$a" 'index($0, d "/") == 1' >> "$tmp/files"
    else printf '%s\n' "$a" >> "$tmp/files"; fi
  done
else
  mode=skip
  list_files >> "$tmp/files"
  # Rows for files that vanished, in every map.
  list_maps > "$tmp/allmaps0"
  while IFS= read -r m; do [ -n "$m" ] && drop_missing_rows "$m"; done < "$tmp/allmaps0"
fi
sort -u "$tmp/files" -o "$tmp/files"

# Rows for vanished files, in the maps of the folders we were pointed at.
if [ "$#" -gt 0 ]; then
  awk '{ i = match($0, /\/[^\/]*$/); print (i ? substr($0, 1, i - 1) : ".") }' "$tmp/files" | sort -u > "$tmp/dirs"
  while IFS= read -r d; do
    m=$(map_for "$d")
    [ -f "$m" ] && drop_missing_rows "$m"
  done < "$tmp/dirs"
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue
  reconcile_file "$f" "$mode"
done < "$tmp/files"

# ---- what is still wrong in the maps we touched, the root map, and any map with a TODO

list_maps > "$tmp/allmaps"
todo_maps=$(tr '\n' '\0' < "$tmp/allmaps" | xargs -0 grep -l 'TODO' 2>/dev/null)
{ printf '%s\n' "DIRMAP.md"; printf '%s' "$touched"; printf '%s\n' "$todo_maps"; } | grep . | sort -u > "$tmp/tocheck"
problems=$(tr '\n' '\0' < "$tmp/tocheck" | xargs -0 bash "$sk/check.sh" 2>/dev/null | grep -v '^Checked ')

updated=$(printf '%s' "$touched" | grep . | sort -u | paste -sd ',' - | sed 's/,/, /g')
note=""
if [ -n "$unmapped" ]; then
  note="Note: these folders have files but no map (new, or never mapped): $(printf '%s' "$unmapped" | xargs | sed 's/ /, /g'). Run /dirmap, or pass one of their files to this script, to map them."
fi

if [ -z "$hints" ] && [ -z "$problems" ]; then
  if [ -z "$updated" ]; then
    echo "dirmap: checked $nchecked file(s). The maps already match. Nothing to do."
  else
    echo "dirmap: checked $nchecked file(s). Maps updated by the script: $updated. Nothing is left for you to do."
  fi
  [ -n "$note" ] && echo "$note"
  exit 0
fi

echo "dirmap: checked $nchecked file(s). Maps updated by the script: ${updated:-none}. What is left needs a quick decision from you. Paths are relative to $PWD."
[ -n "$hints" ] && printf '%s' "$hints"
if [ -n "$problems" ]; then
  printf '%s\n' "$problems" | sed 's/^/- /'
  echo
  echo "How to fix: for UNFINISHED, read the file (or folder) and write one line like the neighbouring rows in place of each TODO. For BROKEN LINK, correct or remove the entry (in the root map's feature map this usually means a file was moved or deleted)."
fi
[ -n "$note" ] && echo "$note"
echo "Edit only the Purpose text, and the TODOs, in the DIRMAP.md files named above. Never edit the Key symbols column: the script owns it."
exit 0
