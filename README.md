# Custom Skills

A small collection of [Claude Code](https://docs.claude.com/en/docs/claude-code) plugins. Install only the ones you want.

| Plugin | Commands | What it does |
|---|---|---|
| [explain-code](plugins/explain-code) | `/explain-code` | Explains code in any language block by block, with snippets, clickable line links, domain-aware terms, and callouts for complex logic. |
| [dirmap](plugins/dirmap) | `/dirmap`, `/dirmap-load` | Gives every folder a short `DIRMAP.md` (its files and subfolders, one line each) plus a feature map at the root, so Claude finds code by following the maps instead of searching. The maps keep themselves up to date. |

## Install

In Claude Code:

```
/plugin marketplace add PavanHebli/Custom_Skills
/plugin install explain-code@custom-skills
/plugin install dirmap@custom-skills
```

Update later with `/plugin marketplace update custom-skills`. Remove a plugin with `claude plugin uninstall <name>@custom-skills`.

**Requirements:** Claude Code, `git`, and a Unix shell (macOS or Linux; on Windows use WSL). The scripts use only `bash`, `git`, `awk`, `sed` and `grep`. Nothing needs a network connection.

## explain-code

Open a file (or select some code) and run `/explain-code`, or just ask "explain this file". You get an overview, then one section per logical block, each with the code, its line range and a clickable link. If the code belongs to a specific domain (finance, healthcare claims, ...), tell it the domain and how familiar you are, and it explains the terms at that level. Complex logic gets a ⚠️ callout with a step-by-step breakdown.

## dirmap

**The idea:** instead of grepping through a codebase every time, Claude reads a short map first (which folder holds what, which file defines what) and goes straight to the right files. It searches only when the maps don't lead anywhere.

### Use it

1. In your project, run **`/dirmap`**. A script drafts a map for every folder, filling in real file links and the functions, classes and routes each file actually defines. Claude then reads the files and writes a one-line purpose for each, and a checker confirms no link or symbol is made up.
2. The maps are ordinary files. Review them, then commit the `DIRMAP.md` files so your teammates get them too. (dirmap never runs `git` commands that change your repo.)
3. From then on:
   - **Each new session** starts with the root map loaded, plus a warning if files changed since the maps were built.
   - **When Claude edits code**, the maps are updated for you (details below). Most edits change nothing in a map, so most edits cost nothing extra.
   - **After changes made outside Claude** (your own edits, `git pull`), run `/dirmap` again. It updates only the folders that changed.
   - **`/dirmap-load src/auth`** loads that folder's maps and everything below it. `/dirmap-load all` loads every map.

### What a map looks like

```markdown
# backend/app/api/routes
<!-- dirmap -->
API endpoint handlers, one module per resource.

## Files
| File | Purpose | Key symbols |
|---|---|---|
| [items.py](items.py) | Item CRUD; non-superusers see only their own items | `read_items`, `create_item`; GET /, POST /, PUT /{id} |
| [login.py](login.py) | Login and password reset endpoints | `login_access_token`, `reset_password`; POST /login/access-token |
```

The root `DIRMAP.md` also has a **feature map** that groups files by feature (auth, database, email, ...), even when they live in different folders.

### How the maps stay up to date

Three small hooks do the work. All of them do nothing in a repo without a root `DIRMAP.md`, so installing the plugin changes nothing until you run `/dirmap`. Type `/hooks` in Claude Code to see them.

| Hook | When it fires | What it does |
|---|---|---|
| `SessionStart` | A session starts, resumes, or is compacted | Adds the root `DIRMAP.md` to Claude's context |
| `PreToolUse` (Edit/Write) | Just before Claude edits a file | Saves a snapshot of the file (its symbols and a copy) to your temp folder, once per turn |
| `Stop` | Claude is about to finish its reply | Compares each edited file with its snapshot and updates the maps itself where a script can. Asks Claude for help only when judgement is needed, at most once per reply. |

| What changed | Who updates the map |
|---|---|
| An edit inside a function (same functions, classes and routes) | Nobody: the map is still right |
| A function, class or route added or removed | The script edits that row's *Key symbols* cell and keeps the rest |
| A file deleted | The script removes its row |
| A new file | The script adds its row with the real symbols. Claude writes the one-line purpose. |
| A new folder | The script drafts its map and links it from the parent. Claude writes the purposes. |
| A file largely rewritten, or its top comment changed | Claude rechecks that one row's purpose |

**What the plugin touches:** the only files it writes in your repo are `DIRMAP.md` files. Snapshots go to your system temp folder and are deleted at the end of each turn. It makes no network calls. The scripts are short and commented: [plugins/dirmap/scripts](plugins/dirmap/scripts) and [plugins/dirmap/skills/dirmap/scripts](plugins/dirmap/skills/dirmap/scripts).

**Known gaps:**
- Files deleted or moved with shell commands (`rm`, `mv`) don't trigger the edit hook, unless another file in the same folder is edited in that turn. Run `/dirmap` to catch the rest: it compares against git.
- The maps describe what files are *for* and what they define. They aren't an index of every usage, so "find every use of X" still needs a search.
- Symbol extraction is built in for Python, JavaScript/TypeScript and Go. Other languages still get a map with links and descriptions, but no symbol lists.

### Other AI tools

The hooks are specific to Claude Code. The maps are plain Markdown, so any tool can read them. `/dirmap` offers to add a short "Dirmap" section to your `AGENTS.md` (and a `CLAUDE.md` that points to it), which tells other agents to read the maps first and keep them updated.
