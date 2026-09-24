# CLAUDE.md

This repo is an Obsidian vault of security notes (`Obsidian Vault/`), published on GitHub. Every note must render correctly in **both** Obsidian and GitHub's Markdown viewer.

Don't touch `.obsidian/workspace.json`, `.DS_Store` files, or the PDFs/DOCX in `Offense/GPEN Cheatsheet/`.

## Internal links (note-to-note)

Use **standard Markdown links**, not Obsidian `[[wikilinks]]`. GitHub and the VS Code preview render `[[Note Name]]` as literal text with the brackets showing; only Obsidian resolves it.

- Format: `[display text](relative/Path%20To%20Note.md)`.
- Path is relative to the linking note; **URL-encode** it — space → `%20`, `&` → `%26` (e.g. `[Kerberos](Kerberos%20Attacks.md)`, `[spray](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md)`). Obsidian resolves these too, so links work in both.
- Never write `[[Note]]` or `[[Note|text]]` for note links. (Image embeds are covered separately below.)

## Image format

Check the whole vault with:

```bash
python3 scripts/check_images.py
```

It must print `OK` when you finish any change that touches images.

### Rules

Every image embed must look like this:

```md
Some text about the setting.

![Group Policy editor with SMB signing enabled](../Screenshots/active-directory-hardening-2.png)

Next Heading
```

1. **Standard Markdown syntax only.** Never `![[file.png]]`. GitHub doesn't render Obsidian wikilink embeds and shows the raw text instead.
2. **Path relative to the note.** Obsidian finds a wikilinked file anywhere in the vault by name, but GitHub needs the real path. Work it out from the note's folder. For example, `Defense/Logging/Host-based/Windows.md` uses `../../Screenshots/…`.
3. **Location.** Images for notes under `Offense/` go in `Offense/Screenshots/`, and images for notes under `Defense/` go in `Defense/Screenshots/`.
4. **Filename:** `<note-slug>-<n>.png`, using lowercase ASCII letters, digits and hyphens only.
   - `note-slug` is the note's filename without its number prefix or `.md`. For example, `3. Active Directory Hardening.md` becomes `active-directory-hardening`.
   - `n` counts from 1 in the order the images appear in the note.
   - If a name collides with another note's image in the same folder, put the parent folder's slug first, e.g. `host-based-windows-1.png`.
5. **Alt text** describes what the screenshot shows in a few words. Open the image to write it. Obsidian reads a number or `|` in alt text as a size (`![300](…)`), so the alt text must not be only a number and must not contain `|`.
6. **Placement:** put the image on its own line with no leading tab or spaces, and leave a blank line before it.
   - Add a blank line after the image too, unless the next line is indented. On GitHub, an indented line that follows a blank line becomes a code block. A line containing only a tab also counts as blank.
   - If an image sits at the end of a line of text, move it onto its own line.
7. **Change only the image lines.** The notes use tab-indented outlines on purpose, so leave the rest of the text as it is.

### Traps in the existing files

- **Hidden U+202F in filenames.** macOS screenshot names often contain U+202F (a narrow no-break space) before `AM`/`PM`, where it looks like a normal space. Some notes contain that same character in their `![[…]]` references. Don't retype these names. Match them with a glob (`Screenshot 2023-10-17 at 7.57.55*`) or copy the bytes from `ls`/`grep` output.
- **Misspelled folder.** The Defense image folder is misspelled as `Defense/screenshoots/`. Rename it to `Defense/Screenshots/`.
- **Duplicate images.** Some are copies with a ` 1` suffix (e.g. `Screenshot 2023-09-17 at 11.21.45 PM.png` and `… PM 1.png`).
  - Delete an image only if no note references it **and** `cmp` shows it is byte-identical to one that is referenced.
  - Otherwise, list the unreferenced image for the user and leave it in place.

### Procedure for fixing images

1. Run `python3 scripts/check_images.py` to get the list of problems.
2. Handle one note at a time. For each `![[…]]` in the note:
   1. Find the file by name anywhere in the vault.
   2. Move it with `git mv` to its new name and folder, so git keeps its history.
   3. Rewrite the reference to follow the rules above.
3. Obsidian isn't running your renames, so it won't update links for you. After moving a file, `grep` the whole vault for the old name and update every reference.
4. Set `Obsidian Vault/.obsidian/app.json` so images pasted in the future get Markdown links. This file is currently `{}`. Add these keys and keep any keys that already exist:

   ```json
   {
     "useMarkdownLinks": true,
     "newLinkFormat": "relative",
     "alwaysUpdateLinks": true
   }
   ```

   Obsidian overwrites this file while it is running, so tell the user to close Obsidian first or to change these settings under Settings → Files and links.
5. Re-run `python3 scripts/check_images.py` until it prints `OK`.
6. Show the user `git status` and a short list of what you renamed, moved and deleted. Don't commit unless they ask.

Pasted images still arrive as `Pasted image <timestamp>.png` in the vault root. When the user asks you to tidy new notes, apply the same procedure to those images.
