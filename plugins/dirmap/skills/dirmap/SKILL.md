---
name: dirmap
description: Builds or refreshes DIRMAP.md files, one per folder, each listing that folder's files and subfolders with one-line descriptions, so the codebase can be navigated without grepping. Use when the user runs /dirmap, or asks to map, index, or document the structure of a codebase, or when a project has no DIRMAP.md and the user is about to explore it or ask where things are. Also use it in any project that has DIRMAP.md files, to read the maps first before you grep, glob or find to locate code, and as the last step after you add, remove or edit files, to run `bash .dirmap/sync.sh` and follow what it prints.
argument-hint: "[rebuild]"
---

# Dirmap

Create or update `DIRMAP.md` files. Each folder's map describes **only its direct contents**: its own files, and its immediate subfolders with a one-line summary and a link to their map. The root map adds a project overview and a **feature map** that groups related files by feature (auth, database, ...), even when they're spread across different folders.

**Never move, rename, or edit code files.** This skill only writes `DIRMAP.md` files.

## If you are here to use the maps, not build them

When the project already has `DIRMAP.md` files and a `.dirmap/` folder, you were probably invoked for one of two jobs. Do it and stop; don't rebuild anything.
- **To find code:** read the root `DIRMAP.md`, then the folder's `DIRMAP.md`, then open the candidate files. Search (grep, glob, find) only if the maps don't lead to the file, or you need every use of a symbol. If a map and the code disagree, trust the code.
- **After you changed files:** run `bash .dirmap/sync.sh` once, as the last step before your final reply, and do what it lists (Step 3). Edit a row's Purpose only if the file now does something it didn't, or no longer does its main job. Not for bug fixes, refactors, or additions that fit what the row says.

## Confirm once, before writing anything

A first run writes into the user's project: a `DIRMAP.md` in every folder, a `.dirmap/` folder, and a short Dirmap section in `AGENTS.md` and `CLAUDE.md`. Ask **one** question that covers all of it, before you write anything:

> "I'll map N folders (it reads many files, so this costs some tokens), copy a few scripts into `.dirmap/`, and add a short **Dirmap** section to `AGENTS.md` and `CLAUDE.md` so any agent checks the maps before searching and keeps them current. Go ahead?"

(Get N from `bash <this skill's directory>/scripts/folders.sh | wc -l`.) Skip the question only if the user's own message already says yes to all of it. If they type `/dirmap` without more, still ask: the command approves the maps, not the extra files. Wait for the answer, and never ask again later in the same run.
- **Yes** → do everything, including Step 2.6.
- **Yes to the maps but not the `AGENTS.md`/`CLAUDE.md` section** → skip Step 2.6, and tell the user that agents will then not know to use the maps unless they add the section themselves (`references/instructions.md`).
- **No** → stop, and don't offer again in this conversation.

When the project already has a root `DIRMAP.md`, this is an update, not a first run: skip the question and go to Step 3.

## Step 0: Set up (always first)

Run `bash <this skill's directory>/scripts/install.sh` from the project root. It copies the scripts into **`.dirmap/`** in the project. Nothing else: no git, no background process.

From here on, use the copies in `.dirmap/` (`bash .dirmap/<name>`), always from the project root. **Use the scripts. Don't replace them with your own `ls` or `find`.** They are what keep the maps accurate.
- `scaffold.sh`: writes a draft `DIRMAP.md` for every folder worth mapping, with real file links and real symbols filled in, and `TODO` where a description is needed.
- `symbols.sh <folder>`: a fact sheet for a folder's files, with each file's line count, first comment, and the names it **actually defines** (functions, classes, exports, HTTP routes).
- `check.sh`: reports leftover `TODO`s, broken links, and key symbols that don't exist in their file.
- `sync.sh <files or folders>`: checks those files against their maps and fixes rows and symbol lists (Step 3). With no arguments it checks the whole project. It is also what any agent runs after editing files.
- `folders.sh`: lists the folders to map, deepest first.

## Step 1: Choose the mode

- **No `DIRMAP.md` at the project root, or the argument is `rebuild`** → **Init** (Step 2).
- **A root `DIRMAP.md` exists** → **Update** (Step 3).

## Step 2: Init (build everything)

1. Run `bash .dirmap/folders.sh | wc -l`. If there are more than ~150 folders, tell the user how many and suggest starting with the main source folders. Wait for their answer.
2. **Run `bash .dirmap/scaffold.sh`** (`bash .dirmap/scaffold.sh --force` for `rebuild`). It writes the draft maps and prints them deepest first. That's your work list, in order.
3. For each map on the list, **replace every `TODO`**. Change nothing else, except as allowed below:
   - **Before describing a file, read it.** For a large file, reading its top part and its main functions is enough. Always read entry points, route or controller files, config, and anything that handles auth, errors, permissions, or app-wide behavior (middleware, interceptors, error handlers).
   - In **Purpose**, name the behavior someone would search for, not just the file's role. For example: "App entry; sets the API base URL; **logs the user out on any 401/403**", rather than "Application entry point". Mention anything surprising, such as dev-only code, security measures, or side effects.
   - A **folder's purpose** comes from its own map, which is already done, because you go deepest first.
   - **You write only the Purpose text.** The Key symbols column and the rows are the script's: **never edit a symbol, add a link, delete a row or merge rows by hand.** Every symbol comes from the scaffold or from `bash .dirmap/symbols.sh`.
   - If you can run tasks in parallel (for example with subagents), give each top-level folder its own task. The root map must still be done last.
4. Fill in the root `DIRMAP.md` last: the overview, and a **feature map** that links the files and folders for each feature, taken from the maps you just wrote.
5. Run `bash .dirmap/check.sh`. Fix every problem it reports, and run it again until it reports none.
6. **Install the instruction block** (unless the user said no to it above; don't ask again). Maps only help if agents use them and keep them current, and the block is what tells them to, in any tool and with or without this skill:
   - Append the contents of `references/instructions.md` (in this skill's directory) to `AGENTS.md`. **Create `AGENTS.md` if it doesn't exist.** Never overwrite existing content, and don't add it again if a `## Dirmap` section is already there.
   - If there is no `CLAUDE.md`, create one containing just `@AGENTS.md`, so Claude Code reads the same rules. If a `CLAUDE.md` already exists and doesn't mention `AGENTS.md`, append the same block to it.
7. Report how many maps you wrote, and tell the user the maps, the instruction files and the `.dirmap/` folder are ready to commit so teammates get them too. **Do not run any git command that changes the user's repo (`add`, `commit`, `push`). The user does that.**

## Step 3: Update (only what changed)

1. Run `bash .dirmap/sync.sh <the files and folders that changed>`. If you don't know what changed (a `git pull`, the user's own edits), run it with no arguments to check the whole project. If `.dirmap/` is missing (a fresh copy of the project), run Step 0 first.
2. It fixes rows, symbol lists, deleted files and new files itself, then prints what is left for you. Do exactly what it lists, and nothing else:
   - **UNFINISHED** (a `TODO`): read the file or folder and write one line in its place, like the neighbouring rows.
   - **A question about a Purpose** (its symbols changed): decide whether the Purpose still describes everything the file does. Rewrite it only if not.
   - **BROKEN LINK**: fix or remove that entry. In the root map's feature map this usually means a file was moved or deleted.
   - **Folders with no map**: offer `/dirmap`, or pass one of their files to `sync.sh` to map that folder.
3. The script can't see a change that keeps the same function names but changes what the code does. If you made one, rewrite that Purpose yourself.
4. Report which maps changed, in one or two lines. If none needed changes, say so.

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
<!-- dirmap -->
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
- Keep the root map under ~150 lines. It's the first thing a model reads when it needs to find code.


## Rules
- All links are relative to the map's own folder.
- Describe what the code does now, not its history.
- If code and a map disagree, the code is right. Fix the map.
