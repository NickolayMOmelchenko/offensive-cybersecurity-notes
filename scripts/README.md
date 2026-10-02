# scripts

Repo tooling. One script, which enforces the image rules from [CLAUDE.md](../CLAUDE.md) so that every screenshot renders both in Obsidian and on GitHub.

## Tree

```text
scripts/
├── README.md           <- you are here
└── check_images.py     validate every image embed in the vault
```

## check_images.py

```bash
# always from the repo root
python3 scripts/check_images.py
```

No dependencies — standard library only. Exits **0** with `OK: all images follow the format`, or **1** with one line per problem, each prefixed `note.md:<line>`.

### What it checks

Walking every `.md` under `Obsidian Vault/` (skipping `.obsidian/`):

| Check | Why |
| --- | --- |
| No `![[file.png]]` wikilink embeds | GitHub shows them as raw text instead of the image |
| `![alt](path)` targets resolve on disk | Catches a moved or renamed image |
| Alt text present, not purely numeric, no `\|` | Obsidian reads a bare number or a pipe as a display size, so the alt text disappears |
| Image alone on its line, no indentation | An indented line after a blank line becomes a code block on GitHub |

Then walking every image file:

| Check | Why |
| --- | --- |
| Filename matches `[a-z0-9-]+\.[a-z]+` | Keeps paths URL-safe; rejects spaces, capitals and the U+202F in macOS screenshot names |
| Parent folder is named `Screenshots` | Keeps assets out of the note folders |
| Referenced by at least one note | Finds orphans. A wikilink reference counts, so this doesn't double-report a file whose embed syntax is already flagged |

### Current state

The script does **not** pass yet. The notes under `Defense/` still use wikilink embeds with the original macOS filenames, so it reports those — see [Defense/screenshoots](../Obsidian%20Vault/Defense/screenshoots/README.md) for the cleanup owed and [CLAUDE.md](../CLAUDE.md) for the procedure. The notes under `Offense/` are already clean.

Run it after any change that touches an image; it should print `OK` before you commit.
