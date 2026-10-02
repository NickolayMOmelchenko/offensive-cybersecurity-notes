# Screenshots

Image assets for the notes under [Offense](../README.md). Nothing to read here — this folder exists so the notes can reference images by a real relative path, which is what GitHub needs. Obsidian resolves those paths too, so one form works in both.

## Tree

```text
Screenshots/
├── README.md               <- you are here
├── powershell-1.png        exiftool output: a PowerShell download cradle in MP3 metadata
└── vlan-hopping-1.png      802.1Q double tagging across a trunk
```

| Image | Used by |
| --- | --- |
| `powershell-1.png` | [Windows/Powershell.md](../Windows/Powershell.md) |
| `vlan-hopping-1.png` | [Networking/VLAN Hopping.md](../Networking/VLAN%20Hopping.md) |

## Previews

![exiftool output showing a PowerShell -ep Bypass download cradle hidden in an mp3's metadata](powershell-1.png)

![VLAN double-tagging: a frame tagged 802.1Q VLAN 10 then VLAN 20 crosses the trunk from the attacker on the native VLAN to the victim on VLAN 20](vlan-hopping-1.png)

## Naming rules

`<note-slug>-<n>.png`, lowercase ASCII letters, digits and hyphens only.

- `note-slug` is the note's filename without any number prefix or `.md` — so `3. Active Directory Hardening.md` becomes `active-directory-hardening`.
- `n` counts from 1 in the order the images appear in the note.
- On a collision with another note's image in the same folder, prefix the parent folder's slug: `host-based-windows-1.png`.

## Adding one

Copy the working form from [Windows/Powershell.md](../Windows/Powershell.md) or [Networking/VLAN Hopping.md](../Networking/VLAN%20Hopping.md) — both are already correct. In short:

- **Standard Markdown embeds only.** Obsidian's double-bracket embed form renders as raw text on GitHub, so never use it.
- **Path is relative to the note**, not to the vault root, so a note in `Offense/Windows/` points at `../Screenshots/…`.
- **Alt text** describes the screenshot in a few words. It must not be only a number and must not contain a pipe character — Obsidian reads both as a display size and the alt text vanishes.
- **Own line, no indentation, blank line before** (and after, unless the next line is indented). On GitHub an indented line after a blank line turns into a code block.

Validate the whole vault from the repo root:

```bash
python3 scripts/check_images.py
```

Full rules: [CLAUDE.md](../../../CLAUDE.md).
