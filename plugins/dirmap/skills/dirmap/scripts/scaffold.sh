#!/usr/bin/env bash
# Writes a draft DIRMAP.md for every folder worth mapping, deepest first.
# Everything that can be computed is filled in from the code: file links, line
# counts, key symbols (via symbols.sh), subfolder links. Only descriptions are
# left as "TODO" for the AI to write after reading the files. Because the
# structure comes from the code, the maps can't link to files that don't exist
# or list symbols that aren't there.
#
#   scaffold.sh              create maps for folders that don't have one yet
#   scaffold.sh --force      overwrite existing maps too (full rebuild)
#   scaffold.sh --only <dir> only <dir> and the folders below it (used by the
#                            hooks when a new folder appears)
#
# Run from the repo root. Prints the maps it wrote, deepest first. That list is
# the order to fill in the TODOs.

here="$(cd "$(dirname "$0")" && pwd)"
force=0
only=""
case "${1:-}" in
  --force) force=1 ;;
  --only)  only="${2:?usage: scaffold.sh --only <dir>}"; only="${only%/}" ;;
esac
max_syms=6

# A folder is worth a map if it holds code or docs (not just images, fonts, lockfiles).
worth_mapping() {
  local d="$1"
  # Hidden folders (.github, .claude, ...) get one line in the parent instead. The root "." is never hidden.
  [ "$d" = "." ] || case "/$d" in */.*) return 1 ;; esac
  git ls-files --cached --others --exclude-standard -- "$d" \
    | grep -vE '(^|/)DIRMAP\.md$' \
    | grep -qiE '\.(py|pyi|ts|tsx|js|jsx|mjs|cjs|go|rb|java|kt|rs|php|cs|swift|c|h|cpp|hpp|sh|sql|md|html|vue|svelte|ya?ml|toml)$'
}

folders=$(bash "$here/folders.sh" all) || exit 1
if [ -n "$only" ]; then
  folders=$(printf '%s\n' "$folders" | awk -v o="$only" '$0 == o || index($0, o "/") == 1')
fi
mapped=""
for d in $folders; do
  worth_mapping "$d" && mapped="$mapped $d "
done

sha=$(git rev-parse --short HEAD 2>/dev/null || echo "none")
name=$(basename "$(git rev-parse --show-toplevel)")

for d in $folders; do
  case "$mapped" in *" $d "*) ;; *) continue ;; esac
  out="$d/DIRMAP.md"
  [ "$d" = "." ] && out="DIRMAP.md"
  if [ -f "$out" ] && [ "$force" -eq 0 ]; then
    continue
  fi

  facts=$(bash "$here/symbols.sh" "$d")

  {
    if [ "$d" = "." ]; then
      echo "# $name: Dirmap"
      echo "<!-- dirmap: indexed-at $sha -->"
      echo "TODO: 3-5 sentences: what the project does, main language/framework, how to run it, main entry points."
      echo
      echo "## Feature map"
      echo "TODO: 3-12 features (auth, database, ...). Under each, link the folders or files that implement it, each with a few words."
    else
      echo "# $d"
      echo "<!-- dirmap -->"
      echo "TODO: 1-3 sentences on what this folder is responsible for."
    fi

    # Files: one row per file, with symbols taken from symbols.sh output.
    if printf '%s\n' "$facts" | grep -q '^== '; then
      echo
      echo "## Files"
      echo "| File | Purpose | Key symbols |"
      echo "|---|---|---|"
      printf '%s\n' "$facts" | awk -v max="$max_syms" '
        function flush() {
          if (file == "") return
          s = ""
          n = split(defs, parts, /, /)
          c = 0
          for (i = 1; i <= n && c < max; i++) {
            if (parts[i] ~ /^\.\.\./ || parts[i] == "") continue
            s = s (c ? ", " : "") "`" parts[i] "`"; c++
          }
          if (routes != "") s = s (s != "" ? "; " : "") routes
          if (s == "") s = "—"
          printf "| [%s](%s) | TODO | %s |\n", file, file, s
        }
        /^== / { flush(); file = $2; defs = ""; routes = ""; next }
        /^  defines: / { defs = substr($0, 12); sub(/, \.\.\. \([0-9]+ total\)$/, "", defs); next }
        /^  routes: / { routes = substr($0, 11); next }
        END { flush() }'
    fi

    # Folders: direct subfolders, linked if they get their own map.
    subs=$(printf '%s\n' $folders | awk -v d="$d" '
      d == "." { if ($0 != "." && $0 !~ /\//) print; next }
      index($0, d "/") == 1 && substr($0, length(d) + 2) !~ /\// { print }')
    if [ -n "$subs" ]; then
      echo
      echo "## Folders"
      echo "| Folder | Purpose |"
      echo "|---|---|"
      for s in $subs; do
        base="${s##*/}"
        case "$mapped" in
          *" $s "*) echo "| [$base/]($base/DIRMAP.md) | TODO |" ;;
          *)        echo "| $base/ | TODO (no map: assets or generated files) |" ;;
        esac
      done
    fi
  } > "$out"
  echo "$out"
done
