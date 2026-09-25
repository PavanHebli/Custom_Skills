---
name: codemap-load
description: Loads the repo's CODEMAP.md files into the conversation as navigation context. By default loads the root map, or the maps for a given folder and everything under it, or all maps. Use when the user runs /codemap-load, or asks to load the code map or give you context about the repo's structure.
argument-hint: "[folder | all]"
---

# Load Codemap

Read `CODEMAP.md` files so you can find code by following the maps instead of searching.

Argument: `$ARGUMENTS`

1. **Pick the maps to read:**
   - **No argument** → the root `CODEMAP.md` only.
   - **A folder path** (for example `src/auth`) → that folder's `CODEMAP.md` and every `CODEMAP.md` below it, plus the root map.
   - **`all`** → every `CODEMAP.md` in the repo. List them with `git ls-files --cached --others --exclude-standard '*CODEMAP.md'`, or search for files with that name if it isn't a git repo. If there are more than ~40, say how many there are and suggest loading a folder instead. Continue only if the user confirms.
2. **If there's no root `CODEMAP.md`,** say that the repo has no codemap yet and suggest running `/codemap`. Stop there.
3. **Read the maps.** Don't repeat their contents back to the user. Reply briefly, for example: "Loaded 6 maps (root + src/auth/...). Ready." Then continue with whatever the user asked, if anything.
4. **From then on, find code by following the maps:** root → folder → file. Open the candidate files to confirm, and search only if the maps don't lead anywhere. If you find a map that's wrong, fix that entry.
