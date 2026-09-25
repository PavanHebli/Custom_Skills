# Custom Skills

A growing collection of custom [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills), packaged as plugins. Install only the ones you want.

## Plugins

| Plugin | Commands | What it does |
|---|---|---|
| [explain-code](plugins/explain-code) | `/explain-code` | Explains code in any language block by block, with snippets, clickable line links, domain-aware terms, and callouts for complex logic. |
| [codemap](plugins/codemap) | `/codemap`, `/codemap-load` | Writes a `CODEMAP.md` in every folder (its files, its subfolders, one line each) plus a feature map at the root, so the AI finds code by following maps instead of grepping. Hooks keep the maps up to date automatically. |

## Install (Claude Code)

```
/plugin marketplace add PavanHebli/Custom_Skills
/plugin install explain-code@custom-skills
/plugin install codemap@custom-skills
```

To get updates, run `/plugin marketplace update custom-skills`.

## Using codemap

1. In your project, run **`/codemap`**. On the first run it maps every folder, deepest first, and writes the root `CODEMAP.md` last.
2. Commit the `CODEMAP.md` files so your teammates get them too.
3. That's it. From then on:
   - **Every new session** starts with the root map already loaded, and a warning if files have changed since the maps were built.
   - **Whenever Claude edits code**, it checks the affected folders' maps before finishing its reply, and updates them if needed.
   - **Changes made outside Claude** (your own edits, `git pull`): run `/codemap` again. It updates only the folders that changed since the last build.
   - **`/codemap-load src/auth`** loads that folder's maps, and those of everything below it. `/codemap-load all` loads every map.

### How the hooks work

| Hook | When it fires | What it does |
|---|---|---|
| `SessionStart` | A session starts, resumes, or is compacted | Adds the root `CODEMAP.md` to Claude's context |
| `PostToolUse` (Edit/Write) | After Claude edits a file | Records the file's folder in a temp file. Nothing else. |
| `Stop` | Claude is about to finish its reply | If any folders were recorded, asks Claude to check those folders' maps (at most once per reply) |

All three do nothing in repos without a root `CODEMAP.md`, so installing the plugin changes nothing until you run `/codemap`. Type `/hooks` in Claude Code to see them. The scripts are in [plugins/codemap/scripts](plugins/codemap/scripts) and are short and commented.

**Known gap:** files deleted or moved with shell commands (`rm`, `mv`) don't trigger the edit hook. Running `/codemap` catches them, because it compares against git.

## Adding a new skill

1. Pick a plugin in `plugins/`, or create a new one: copy an existing plugin folder, rename it in its `.claude-plugin/plugin.json`, and add it to [.claude-plugin/marketplace.json](.claude-plugin/marketplace.json).
2. Copy [templates/SKILL_TEMPLATE.md](templates/SKILL_TEMPLATE.md) to `plugins/<plugin>/skills/<skill-name>/SKILL.md` and fill it in.
3. Add it to the table above, and bump `version` in that plugin's `plugin.json`.
4. Check the manifests: `claude plugin validate .`
