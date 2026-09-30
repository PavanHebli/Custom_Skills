---
name: dirmap
description: Builds or refreshes DIRMAP.md files, one per folder, each listing that folder's files and subfolders with one-line descriptions, so the codebase can be navigated without grepping. On first run it maps the whole repo; after that it updates only the folders that changed. Use when the user runs /dirmap, or asks to create, rebuild, or refresh the code map or folder indexes.
argument-hint: "[rebuild]"
disable-model-invocation: true
---

# Dirmap

Create or update `DIRMAP.md` files. Each folder's map describes **only its direct contents**: its own files, and its immediate subfolders with a one-line summary and a link to their map. The root map adds a project overview and a **feature map** that groups related files by feature (auth, database, ...), even when they're spread across different folders.

**Never move, rename, or edit code files.** This skill only writes `DIRMAP.md` files.

## Step 1: Choose the mode

Helper scripts are in this skill's `scripts/` directory. Run them with `bash <this skill's directory>/scripts/<name>` from the repo root. **Use them. Don't replace them with your own `ls` or `find`.** They are what keep the maps accurate.
- `scaffold.sh`: writes a draft `DIRMAP.md` for every folder worth mapping, with real file links and real symbols filled in, and `TODO` where a description is needed.
- `symbols.sh <folder>`: a fact sheet for a folder's files, with each file's line count, first comment, and the names it **actually defines** (functions, classes, exports, HTTP routes).
- `folders.sh`: lists folders deepest first (`all`), or the folders changed since a commit (`changed <sha>`).
- `check.sh`: reports leftover `TODO`s, broken links, and key symbols that don't exist in their file.

- **No `DIRMAP.md` at the repo root, or the argument is `rebuild`** → **Init** (Step 2).
- **A root `DIRMAP.md` exists** → **Update** (Step 3).
- **Not a git repo:** the script won't work. For Init, list folders yourself, skipping dependency, build, and cache folders (`node_modules`, `dist`, `build`, `.venv`, `__pycache__`, `target`, ...). For Update, compare each folder's files with its map, and add or remove entries to match.

## Step 2: Init (build everything)

1. Run `scripts/folders.sh all | wc -l`. If there are more than ~150 folders, tell the user how many and suggest starting with the main source folders. Wait for their answer.
2. **Run `scripts/scaffold.sh`** (`scripts/scaffold.sh --force` for `rebuild`). It writes the draft maps and prints them deepest first. That's your work list, in order.
3. For each map on the list, **replace every `TODO`**. Change nothing else, except as allowed below:
   - **Before describing a file, read it.** For a large file, reading its top part and its main functions is enough. Always read entry points, route or controller files, config, and anything that handles auth, errors, permissions, or app-wide behavior (middleware, interceptors, error handlers).
   - In **Purpose**, name the behavior someone would search for, not just the file's role. For example: "App entry; sets the API base URL; **logs the user out on any 401/403**", rather than "Application entry point". Mention anything surprising, such as dev-only code, security measures, or side effects.
   - A **folder's purpose** comes from its own map, which is already done, because you go deepest first.
   - **Allowed edits:** you may remove a symbol that isn't important, merge rows of obvious boilerplate into one (for example "`__init__.py`: package markers"), and delete rows for noise files (lockfiles, `.gitignore`, and similar). **Never add a link or a symbol by hand.** Every symbol must come from the scaffold or from `scripts/symbols.sh`.
   - If you can run tasks in parallel (for example with subagents), give each top-level folder its own task. The root map must still be done last.
4. Fill in the root `DIRMAP.md` last: the overview, and a **feature map** that links the files and folders for each feature, taken from the maps you just wrote.
5. Run `scripts/check.sh`. Fix every problem it reports, and run it again until it reports none.
6. Report how many maps you wrote, and tell the user they're ready to commit so teammates get them too. **Do not run any git command that changes the repo (`add`, `commit`, `push`). The user does that.**
7. Offer to add the dirmap rules for people and tools that don't have this plugin (other AI agents, or teammates without it). This isn't needed for the plugin's own hooks. Ask first, and never overwrite existing content:
   - Add the block below to `AGENTS.md`, the instructions file most AI coding agents read. **Create `AGENTS.md` if it doesn't exist.**
   - If there's no `CLAUDE.md`, offer to create one containing just `@AGENTS.md`, so Claude Code reads the same rules. If a `CLAUDE.md` already exists and doesn't mention `AGENTS.md`, add the block to it as well.
   - Don't add the block again if a `## Dirmap` section is already there.

   ```markdown
   ## Dirmap
   Every folder has a `DIRMAP.md` listing its files and subfolders. The root `DIRMAP.md` has a feature map.
   - To find code, read the root `DIRMAP.md`, follow it to the folder's `DIRMAP.md`, then open the candidate files. Search only if the maps don't lead anywhere.
   - After adding, deleting, or renaming files, or changing what a file does, update that folder's `DIRMAP.md` (and the root feature map if a feature changed).
   ```

## Step 3: Update (only what changed)

1. Read the `indexed-at` commit from the root `DIRMAP.md`. Run `scripts/folders.sh changed <sha>`.
   - If the commit no longer exists (for example after a rebase), tell the user, and fall back to comparing each folder's files with its map.
2. For each folder listed:
   - **Folder was deleted** → remove its entry from the parent's map.
   - **New folder with no map** → run `scripts/scaffold.sh` (it only creates missing maps), fill in the `TODO`s, and add the folder to its parent's map.
   - **Existing folder** → run `git diff <sha> -- <folder>` and `scripts/symbols.sh <folder>`, then update entries for added, deleted, or renamed files. Change a description or key symbols only if the file's purpose or main exports actually changed. Don't rewrite entries that are still accurate.
3. Update the root's feature map if files were added to, or removed from, a feature. Set `indexed-at` to the current `HEAD`.
4. Run `scripts/check.sh` and fix anything it reports.
5. Report which maps changed, in one or two lines. If none needed changes, say so.

## Folder format

```markdown
# src/auth
<!-- dirmap -->
Handles login, sessions, and JWT tokens. Entry point: `login.ts`.

## Files
| File | Purpose | Key symbols |
|---|---|---|
| [login.ts](login.ts) | /login and /refresh endpoints | `login`, `refresh` |
| [session.ts](session.ts) | Session store in Redis, 24h expiry | `createSession`, `getSession` |

## Folders
| Folder | Purpose |
|---|---|
| [tokens/](tokens/DIRMAP.md) | JWT signing, verification, key rotation |
| fixtures/ | Sample tokens for tests (no map) |
```

- **Heading:** the folder's path from the repo root.
- **Summary:** 1–3 sentences on what the folder is responsible for.
- **Purpose:** one line saying what the file is *for*, not a restatement of its name. Mention anything that isn't obvious (side effects, where it's called from, gotchas).
- **Key symbols:** up to ~5 names someone would search for (exported functions, classes, endpoints, tables). Use `—` if there are none.
- Leave out the Files or Folders section if it would be empty. Put obvious boilerplate together in one row (for example "`__init__.py`, `py.typed`: package markers").

## Root format

```markdown
# <project name>: Dirmap
<!-- dirmap: indexed-at a1b2c3d -->
3–5 sentences: what the project does, main language/framework, how to run it, main entry points.

## Feature map
### Auth
- [src/middleware/auth.ts](src/middleware/auth.ts): checks the JWT on every request
- [src/auth/](src/auth/DIRMAP.md): login, sessions, tokens
### Database
- ...

## Files
(same table as the folder format, key root files only: config, entry points, build files)

## Folders
(same table as the folder format)
```

- The **feature map** is the logical grouping. It's what lets the map work even when the folders are organized by layer (for example `controllers/` and `models/`) rather than by feature. Aim for 3–12 features. Link folders when a whole folder belongs to a feature, and individual files when only some do.
- Keep the root map under ~150 lines. It's loaded at the start of every session.
- Keep the `<!-- dirmap: indexed-at ... -->` line exactly in this form. The hooks read it.

## Rules
- All links are relative to the map's own folder.
- Describe what the code does now, not its history.
- If code and a map disagree, the code is right. Fix the map.
