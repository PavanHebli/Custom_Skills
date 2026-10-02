#!/usr/bin/env bash
# Step 0 of /dirmap. Run from the project root.
#
# Copies the dirmap scripts into .dirmap/, so any agent or teammate can run
# `bash .dirmap/sync.sh` without installing anything. That is all it does: no
# git, no background process, nothing outside .dirmap/.

here="$(cd "$(dirname "$0")" && pwd)"

mkdir -p .dirmap || exit 1
for f in lib.sh folders.sh scaffold.sh symbols.sh check.sh sync.sh; do
  cp "$here/$f" ".dirmap/$f" || exit 1
done
chmod +x .dirmap/*.sh
echo "dirmap: copied the scripts into .dirmap/."
