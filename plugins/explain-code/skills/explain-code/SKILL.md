---
name: explain-code
description: Explains a file, function, query, or snippet in any programming language, block by block, with code excerpts, clickable line links, domain-aware terminology (e.g. finance, pharmacy claims), and step-by-step breakdowns of complex logic. Use when the user asks to explain, walk through, understand, or document what some code does, or says things like "what does this do" or "help me understand this script".
---

# Explain Code

Explain the code the user has provided, referenced, or has open/selected. Follow the process below, then produce output in the format described.

## Step 1: Gather context

1. **Find the code.** If the user named or attached a file, read it with line numbers so every line range you cite is accurate. Never guess line numbers. If the code was pasted into chat with no file, skip line ranges and file links.
2. **Work out the domain and the reader's familiarity with it:**
   - **Domain**, e.g. finance, healthcare/pharmacy claims, e-commerce, or general.
   - **Familiarity**: beginner in the domain, or already knows it.
3. Use what the user has already said in the conversation. If the domain is obvious from the code (table names like `claims` or `ndc_code`, or terms like `ledger` or `accrual`), use that domain and say which one you assumed.
4. Ask **one short question** only if the domain or familiarity is still unclear and it would noticeably change the explanation. For example: "Is this for a particular domain (finance, pharmacy claims, …), and are you new to it or already familiar?" Don't ask again if the user has already answered.

## Step 2: Scale to the size of the code

- **Small snippets (under ~30 lines)**: give a short overview, then one explanation. You don't need a heading for each block.
- **Normal files**: use the full structure below.
- **Very large files or several files**: give the overview and a map of the main sections first, then explain in depth only the parts the user cares about. Offer to go deeper into the rest.

## Output format

Use Markdown headings in this order. Keep it easy to scan: bullet points and short paragraphs, no long walls of prose.

### 1. Overview
A 3–6 sentence summary of what the file or script does overall and where its inputs and outputs come from and go.

### 2. One section per logical block
Go through the code in the order it appears. Give each helper function, class, method, or other independent unit its own heading.

For each block:

1. **Location link** on its own line, right under the heading, as a Markdown link that shows the line range and opens the file at that spot:
   `[path/to/file.ext:42-118](path/to/file.ext#L42-L118)`
   Write the file path the way the user gave it (relative if they gave it as relative).
2. **Purpose**: one sentence on what this block is for.
3. **Code snippet** in a fenced block with the correct language tag:
   - If the block is about 20 lines or fewer, show it in full.
   - If it is longer, show the first few lines (the declaration plus a couple of lines), then `// ... (~n lines omitted) ...` using that language's comment syntax, then the last few lines.
4. **Explanation**: go statement by statement, or group closely related statements together. Focus on *why* the code does something, not only *what* it does.

### 3. Domain notes (inline)
Where a domain term or concept comes up, explain it right there, in that block's section. Don't collect these into a glossary at the end.
- **The reader is a beginner in the domain**: explain each term in plain language. For pharmacy claims, that means what a *claim*, an *NDC*, or *adjudication* means here. For finance, it means terms like *accrual*, *reconciliation*, or *ledger*.
- **The reader knows the domain**: name the concept and explain it in **two sentences or fewer**.
- **No domain**: explain the logic on its own terms. Don't invent a domain.

### 4. ⚠️ Complex logic callouts (inline)
When a block contains non-trivial math, an algorithm, or complicated conditions (nested branches, window functions, recursion, bit manipulation, and so on), add a **⚠️ Complex Logic** note. Break it into numbered, step-by-step pieces. If it would help, trace through it with one small example input.

## Tone rules
- Write for an intelligent person who is new to this codebase or domain, not for someone new to thinking. Don't use "explain like I'm 5" phrasing.
- Avoid unneeded jargon. When you must use a technical term, define it briefly the first time it appears.
- Don't pad the explanation. If a line is self-explanatory (`count += 1`), leave it out or cover it in a few words.
