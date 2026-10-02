# Custom Skills

A small collection of [Claude Code](https://docs.claude.com/en/docs/claude-code) plugins. Install only the ones you want.

| Plugin | Commands | What it does |
|---|---|---|
| [explain-code](plugins/explain-code) | `/explain-code` | Explains code in any language block by block, with snippets, clickable line links, domain-aware terms, and callouts for complex logic. |
| [dirmap](plugins/dirmap) | `/dirmap`, `/dirmap-load` | Gives every folder a short `DIRMAP.md` (its files and subfolders, one line each) plus a feature map at the root, so Claude finds code by following the maps instead of searching. The maps are kept current with one command. |

## Install

In Claude Code:

```
/plugin marketplace add PavanHebli/Custom_Skills
/plugin install explain-code@custom-skills
/plugin install dirmap@custom-skills
```

Update later with `/plugin marketplace update custom-skills`. Remove a plugin with `claude plugin uninstall <name>@custom-skills`.

**Requirements:** Claude Code and a Unix shell (macOS or Linux; on Windows use WSL). The scripts use only standard Unix tools (`bash`, `awk`, `sed`, `grep`, `find`, and similar). Nothing needs git or a network connection.

## explain-code

Open a file (or select some code) and run `/explain-code`, or just ask "explain this file". You get an overview, then one section per logical block, each with the code, its line range and a clickable link. If the code belongs to a specific domain (finance, healthcare claims, ...), tell it the domain and how familiar you are, and it explains the terms at that level. Complex logic gets a ⚠️ callout with a step-by-step breakdown.

## dirmap

**The idea:** instead of grepping through a codebase every time, the model reads a short map first (which folder holds what, which file defines what) and goes straight to the right files. It searches only when the maps don't lead anywhere.

There is nothing to host or set up: no server, no index to build, no API key, no hooks, no background processes, and no git. Install the plugin and run `/dirmap`. Everything is plain text, plain Markdown and a few shell scripts, so it works in any AI coding agent that can read `AGENTS.md` and run a command.

### Use it

1. In your project, run **`/dirmap`** (or ask Claude to map the codebase: it will offer). It first asks **one** question that lists everything it is about to write, and writes nothing until you say yes. Then it will:
   - copy a few scripts into a `.dirmap/` folder in your project;
   - draft a map for every folder, with real file links and the functions, classes and routes each file actually defines;
   - read the files and write a one-line purpose for each, then check that no link or symbol is made up;
   - add a short **Dirmap** section to `AGENTS.md` (and a `CLAUDE.md` pointing to it). That section is what tells agents to check the maps before searching, and to run one command after editing.

   | Your project has | What it does |
   |---|---|
   | No `AGENTS.md` | Creates it with the Dirmap section |
   | An `AGENTS.md` | Adds the section at the end and never overwrites your text (skips it if a `## Dirmap` section is already there) |
   | No `CLAUDE.md` | Creates one containing only `@AGENTS.md`, so Claude Code reads the same rules |
   | A `CLAUDE.md` that doesn't mention `AGENTS.md` | Adds the section to it as well |

   **Why `AGENTS.md`, and why also `CLAUDE.md`?** dirmap puts its rules in `AGENTS.md` on purpose, so they aren't tied to one coding agent: many tools read that file. Claude Code reads `CLAUDE.md`. Some versions don't read `AGENTS.md` at all (we checked 2.1.197: with only an `AGENTS.md` it never saw the rules), and newer ones may use it only when there is no `CLAUDE.md`. The one-line `CLAUDE.md` containing `@AGENTS.md` makes Claude Code load the same rules in every case.
2. Review the maps, then commit `DIRMAP.md`, `.dirmap/` and the instruction files so your teammates get them too. (dirmap never runs `git` commands that change your repo.)
3. From then on, nothing else to do:
   - **To find code**, the model reads the root `DIRMAP.md`, then the folder's, then the files, before it would grep.
   - **After the model changes files**, it decides for each one whether the change touched what the file is *for*, then runs `bash .dirmap/sync.sh` on those files. The script fixes the rows and symbol lists and asks about any purpose that may be out of date.
   - **After your own edits or a `git pull`**, run `/dirmap` again, or `bash .dirmap/sync.sh` (from the project root) with no arguments to check the whole project.
   - **`/dirmap rebuild`** starts over and redrafts every map, even if some already exist. Use it after a large restructure, or if the maps have drifted a long way. It's the same `/dirmap` skill with `rebuild` as an argument, not a separate skill.
   - **`/dirmap-load src/auth`** loads that folder's maps and everything below it. `/dirmap-load all` loads every map.

**The first time an agent runs `sync.sh`, your tool will probably ask you to approve the command.** Choose "always allow" for `bash .dirmap/sync.sh` (in Claude Code: `/permissions`, or add `Bash(bash .dirmap/sync.sh)` to the allowed commands) so it runs without asking each time. It only reads your source files and rewrites `DIRMAP.md` files.

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

A row has three parts, and each has one owner:

| Part of a row | Owner | How it stays right |
|---|---|---|
| File name | The script | A row whose file is gone is removed, and a file with no row gets one |
| Key symbols | The script | Regenerated from the file every time, so it is exact (for Python, JavaScript, TypeScript and Go; see the limits below) |
| **Purpose** | **The model** | Judged by the model at the end of a task. The script never rewrites it. |

`sync.sh` needs no git and no record of the past: it compares each map with the files as they are now.

| What changed | What happens |
|---|---|
| Formatting, or a bug fix inside a function | The symbols are the same, so nothing changes and nothing is asked |
| A function, class or route added or removed | The script rewrites the Key symbols cell, and asks whether the Purpose still fits |
| A file deleted | The script removes its row |
| A new file | The script adds its row with the real symbols. The model writes the one-line purpose. |
| A new folder (when you name one of its files) | The script drafts its map and links it from the parent. The model writes the purposes. |

The question the script prints is just text: bash can't call a model, so it appears in the output of the command the model ran, and the model decides what to do with it. dirmap can't *force* a model to refresh the maps. The instruction asks, and a model can skip it. If a map ever looks stale, run `/dirmap` or `bash .dirmap/sync.sh`.

**What dirmap writes:** `DIRMAP.md` files, the `.dirmap/` folder (scripts only), and, with your permission, the Dirmap section in `AGENTS.md` and `CLAUDE.md`. It makes no network calls. Skipped as non-source: `node_modules`, `.venv`, `venv`, `env`, `dist`, `build`, `target`, `vendor`, caches, hidden tool folders, lock files, and minified files. It doesn't read `.gitignore`.

**Known limits:**
- Nothing forces a model to read the maps or to run `sync.sh`. See above.
- A change that keeps the same function names but changes what the code does can't be seen by a script. The instruction tells the model to rewrite the Purpose itself in that case.
- The maps describe what files are *for* and what they define. They aren't an index of every usage, so "find every use of X" still needs a search.
- **Languages.** The maps themselves work for any language. Every code, config, doc, style and data file gets a row with a purpose: Python, JavaScript, TypeScript, Go, Java, Kotlin, Rust, Ruby, PHP, C#, C and C++, Swift, shell, SQL, HTML, CSS, YAML, JSON, TOML and more (see `DIRMAP_EXTS` in `.dirmap/lib.sh`). But only **Python, JavaScript, TypeScript and Go** get automatic symbol lists (functions, classes, routes). For every other language the Key symbols column shows `—`. Because the script can't see what those files define, it can't notice that a function was added or removed, so it never asks about the Purpose there: the model's own judgement is the only signal.
- A new folder is only mapped when you run `/dirmap` or name one of its files to `sync.sh`.

### Other AI tools

The skill is a standard `SKILL.md` folder (`plugins/dirmap/skills/dirmap`), and the instruction block is plain Markdown. In another agent, copy the skill folder into that tool's skills location, or just run its scripts by hand and paste the block into the tool's instructions file. I have only tested it in Claude Code.
