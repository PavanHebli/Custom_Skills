---
name: codemap
description: Builds or refreshes CODEMAP.md files, one per folder, each listing that folder's files and subfolders with one-line descriptions, so the codebase can be navigated without grepping. On first run it maps the whole repo; after that it updates only the folders that changed. Use when the user runs /codemap, or asks to create, rebuild, or refresh the code map or folder indexes.
argument-hint: "[rebuild]"
disable-model-invocation: true
---

# Codemap

Create or update `CODEMAP.md` files. Each folder's map describes **only its direct contents**: its own files, and its immediate subfolders with a one-line summary and a link to their map. The root map adds a project overview and a **feature map** that groups related files by feature (auth, database, ...), even when they're spread across different folders.

**Never move, rename, or edit code files.** This skill only writes `CODEMAP.md` files.

## Step 1: Choose the mode

The helper script `scripts/folders.sh` is in this skill's directory. Run it from the repo root.

- **No `CODEMAP.md` at the repo root, or the argument is `rebuild`** → **Init** (Step 2).
- **A root `CODEMAP.md` exists** → **Update** (Step 3).
- **Not a git repo:** the script won't work. For Init, list folders yourself, skipping dependency, build, and cache folders (`node_modules`, `dist`, `build`, `.venv`, `__pycache__`, `target`, ...). For Update, compare each folder's files with its map, and add or remove entries to match.

## Step 2: Init (build everything)

1. Run `scripts/folders.sh all`. It lists the folders **deepest first**, skipping anything git ignores.
2. If there are more than ~150 folders, tell the user how many and suggest starting with the main source folders. Wait for their answer.
3. Work through the list in order, so every child map exists before its parent's map is written:
   - Read the folder's files. For a large file, skimming its top part and its exported or public names is enough.
   - Write `CODEMAP.md` using the **folder format** below.
   - **Skip** folders that aren't worth navigating: only images, fixtures, generated code, or vendored copies. Instead, describe them in one line in the parent's map, with no link.
   - If you can run tasks in parallel (for example with subagents), you can give each top-level folder its own task. The root map must still be written last.
4. Write the root `CODEMAP.md` last, using the **root format** below. Set `indexed-at` to the output of `git rev-parse --short HEAD`.
5. Report how many maps you wrote, and suggest committing them so teammates get them too.
6. Offer to add the codemap rules for people and tools that don't have this plugin (other AI agents, or teammates without it). This isn't needed for the plugin's own hooks. Ask first, and never overwrite existing content:
   - Add the block below to `AGENTS.md`, the instructions file most AI coding agents read. **Create `AGENTS.md` if it doesn't exist.**
   - If there's no `CLAUDE.md`, offer to create one containing just `@AGENTS.md`, so Claude Code reads the same rules. If a `CLAUDE.md` already exists and doesn't mention `AGENTS.md`, add the block to it as well.
   - Don't add the block again if a `## Codemap` section is already there.

   ```markdown
   ## Codemap
   Every folder has a `CODEMAP.md` listing its files and subfolders. The root `CODEMAP.md` has a feature map.
   - To find code, read the root `CODEMAP.md`, follow it to the folder's `CODEMAP.md`, then open the candidate files. Search only if the maps don't lead anywhere.
   - After adding, deleting, or renaming files, or changing what a file does, update that folder's `CODEMAP.md` (and the root feature map if a feature changed).
   ```

## Step 3: Update (only what changed)

1. Read the `indexed-at` commit from the root `CODEMAP.md`. Run `scripts/folders.sh changed <sha>`.
   - If the commit no longer exists (for example after a rebase), tell the user, and fall back to comparing each folder's files with its map.
2. For each folder listed:
   - **Folder was deleted** → remove its entry from the parent's map.
   - **New folder with no map** → create its map, and add it to the parent's map.
   - **Existing folder** → run `git diff <sha> -- <folder>` and update entries for added, deleted, or renamed files. Change a description or key symbols only if the file's purpose or main exports actually changed. Don't rewrite entries that are still accurate.
3. Update the root's feature map if files were added to, or removed from, a feature. Set `indexed-at` to the current `HEAD`.
4. Report which maps changed, in one or two lines. If none needed changes, say so.

## Folder format

```markdown
# src/auth
<!-- codemap -->
Handles login, sessions, and JWT tokens. Entry point: `login.ts`.

## Files
| File | Purpose | Key symbols |
|---|---|---|
| [login.ts](login.ts) | /login and /refresh endpoints | `login`, `refresh` |
| [session.ts](session.ts) | Session store in Redis, 24h expiry | `createSession`, `getSession` |

## Folders
| Folder | Purpose |
|---|---|
| [tokens/](tokens/CODEMAP.md) | JWT signing, verification, key rotation |
| fixtures/ | Sample tokens for tests (no map) |
```

- **Heading:** the folder's path from the repo root.
- **Summary:** 1–3 sentences on what the folder is responsible for.
- **Purpose:** one line saying what the file is *for*, not a restatement of its name. Mention anything that isn't obvious (side effects, where it's called from, gotchas).
- **Key symbols:** up to ~5 names someone would search for (exported functions, classes, endpoints, tables). Use `—` if there are none.
- Leave out the Files or Folders section if it would be empty. Put obvious boilerplate together in one row (for example "`__init__.py`, `py.typed`: package markers").

## Root format

```markdown
# <project name>: Codemap
<!-- codemap: indexed-at a1b2c3d -->
3–5 sentences: what the project does, main language/framework, how to run it, main entry points.

## Feature map
### Auth
- [src/middleware/auth.ts](src/middleware/auth.ts): checks the JWT on every request
- [src/auth/](src/auth/CODEMAP.md): login, sessions, tokens
### Database
- ...

## Files
(same table as the folder format, key root files only: config, entry points, build files)

## Folders
(same table as the folder format)
```

- The **feature map** is the logical grouping. It's what lets the map work even when the folders are organized by layer (for example `controllers/` and `models/`) rather than by feature. Aim for 3–12 features. Link folders when a whole folder belongs to a feature, and individual files when only some do.
- Keep the root map under ~150 lines. It's loaded at the start of every session.
- Keep the `<!-- codemap: indexed-at ... -->` line exactly in this form. The hooks read it.

## Rules
- All links are relative to the map's own folder.
- Describe what the code does now, not its history.
- If code and a map disagree, the code is right. Fix the map.
