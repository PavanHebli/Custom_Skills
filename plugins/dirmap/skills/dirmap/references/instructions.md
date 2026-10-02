## Dirmap
This project has `DIRMAP.md` files: short maps of what each folder and file is for. The root `DIRMAP.md` has a feature map.

**Rule 1: finding code.** Before you use grep, glob, find or a search agent, read the root `DIRMAP.md`, then the folder's `DIRMAP.md`, then open the candidate files. Search only if the maps don't lead to the file, or you need every use of a symbol. If a map and the code disagree, trust the code.

**Rule 2: keep the maps current. This is the LAST step of every task that adds, removes, renames or edits files.**
Before your final reply, once:
1. For each file you touched, decide which it was: **formatting only**, **new or changed code that fits what the file is already for**, or **a change to what the file is for** (it now does something new, or no longer does its main job).
2. Run `bash .dirmap/sync.sh <the files and folders you touched>`. It fixes rows, symbol lists and new files for you and prints anything left for you. Do what it lists. Don't run it if you changed no files.
3. Rewrite a row's **Purpose** only for the third kind of change, even if the script printed nothing about it. Don't touch it for formatting, bug fixes, refactors, or additions that fit.
Never edit the Key symbols column or delete rows by hand: the script owns them.
