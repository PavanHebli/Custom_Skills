# Shared helpers for the dirmap scripts. Sourced, not run.
# Every script expects to run from the project root. Nothing here needs git.

# File types that get a row in a map: code, config, docs, styles, data files.
DIRMAP_EXTS="py pyi ts tsx js jsx mjs cjs go rb java kt rs php cs swift c h cpp hpp sh sql md html vue svelte yml yaml toml json jsonc css scss sass less txt xml ini cfg conf graphql gql proto tf"
# Files with no extension that also get a row.
DIRMAP_NAMES="Dockerfile Makefile"
# A folder is worth its own map if it holds code or docs, not just data files.
DIRMAP_CODE_RE='\.(py|pyi|ts|tsx|js|jsx|mjs|cjs|go|rb|java|kt|rs|php|cs|swift|c|h|cpp|hpp|sh|sql|md|html|vue|svelte|ya?ml|toml)$'

# Folders that are never mapped: dependencies, build output, caches, tool folders.
DIRMAP_SKIP_DIRS="node_modules .venv venv env __pycache__ dist build target .next .nuxt .svelte-kit .cache vendor coverage .idea .vscode .git .dirmap .tox .mypy_cache .pytest_cache .gradle .terraform .turbo"
# Generated files that would only add noise.
DIRMAP_SKIP_FILES_RE='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lock|uv\.lock|poetry\.lock|Cargo\.lock|go\.sum|composer\.lock|Gemfile\.lock)$|\.min\.(js|css)$'

_dirmap_row_re() {
  printf '(\\.(%s)$|(^|/)(%s)$)' "$(printf '%s' "$DIRMAP_EXTS" | tr ' ' '|')" "$(printf '%s' "$DIRMAP_NAMES" | tr ' ' '|')"
}

# Every file under the current folder, one per line, relative to it, skipping
# the folders above.
_dirmap_scan() {
  local prune="" d
  for d in $DIRMAP_SKIP_DIRS; do prune="$prune -o -name $d"; done
  # shellcheck disable=SC2086
  find . \( -false $prune \) -prune -o -type f -print | sed 's#^\./##' | sort
}

# The files that get a row in a map (maps themselves excluded).
list_files() {
  _dirmap_scan | grep -E "$(_dirmap_row_re)" | grep -vE '(^|/)DIRMAP\.md$' | grep -vE "$DIRMAP_SKIP_FILES_RE"
}

# True if the path is a file type that gets a row.
is_row_file() {
  printf '%s\n' "$1" | grep -E "$(_dirmap_row_re)" | grep -vE '(^|/)DIRMAP\.md$' | grep -vqE "$DIRMAP_SKIP_FILES_RE"
}

# Every DIRMAP.md in the project.
list_maps() {
  _dirmap_scan | grep -E '(^|/)DIRMAP\.md$'
}

# Turns "S name" / "R route" lines (stdin) into the text of a Key symbols cell:
# the first six names, then up to eight routes. If there are more, the cell says
# how many, so a new function past the limit still changes the cell. Used by both
# scaffold.sh and sync.sh, so a freshly drafted map always matches what sync.sh
# would generate.
fmt_cell() {
  awk -v maxn=6 -v maxr=8 '
    substr($0,1,2) == "S " { ns++; if (ns <= maxn) names = names (ns > 1 ? ", " : "") "`" substr($0,3) "`"; next }
    substr($0,1,2) == "R " { nr++; if (nr <= maxr) routes = routes (nr > 1 ? ", " : "") substr($0,3); next }
    END {
      if (ns > maxn) names = names " (+" (ns - maxn) " more)"
      if (nr > maxr) routes = routes " (+" (nr - maxr) " more)"
      if (names != "" && routes != "") print names "; " routes
      else if (names != "") print names
      else if (routes != "") print routes
      else print "—"
    }'
}
