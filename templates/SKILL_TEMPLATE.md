---
# Lowercase with hyphens. Must match the folder name: plugins/<plugin>/skills/<name>/SKILL.md
name: my-skill-name
# The most important line in the file. Claude reads only this to decide whether
# to load the skill, so say (1) what the skill does and (2) when to use it,
# including the phrases a user would actually type.
description: Does X for Y. Use when the user asks to ..., or mentions "...", "...".
---

# Skill Title

One or two sentences on what this skill produces and for whom.

## Step 1: Gather context
- What to read or check first (files, the user's selection, earlier messages).
- What to infer, and the default to use if it can't be inferred.
- When to ask the user. Ask only if the answer changes the output, and ask at most once.

## Step 2: Do the work
Numbered steps. Be concrete. Where the output should look a certain way, give an example.

## Output format
The exact structure, headings, or file(s) to produce.

## Rules
- Hard constraints ("never ...", "always ...").
- How to handle edge cases (empty input, very large input, ambiguous request).

<!--
Checklist before committing a new skill:
[ ] Folder is plugins/<plugin>/skills/<name>/ and the file is named exactly SKILL.md
[ ] Frontmatter has name + description; description says WHEN to use it
[ ] Instructions scale: small inputs don't get a huge rigid template
[ ] Nothing depends on facts the model might guess (line numbers, paths): tell it to read/verify
[ ] Long reference material goes in separate files next to SKILL.md (e.g. reference.md),
    and SKILL.md says when to read them
[ ] Tested: ask Claude something that should trigger the skill, and check that it does
-->
