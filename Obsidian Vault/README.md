# Obsidian Vault

The vault itself. Two halves that mirror each other: **[Offense](Offense/README.md)** is how an attack is carried out, **[Defense](Defense/README.md)** is how it is logged, detected and prevented. Most attack notes end with a *Defense / detection* section, so you can read a technique from either side.

Every folder in here has a `README.md` with a tree and one line per note — start at the folder, not at the file list.

## Tree

```text
Obsidian Vault/
├── README.md                       <- you are here
├── Offense/                        red team — attack techniques, by platform
│   ├── AD/                         7 notes — the Active Directory attack chain
│   ├── Linux/                      4 notes — post-exploitation & root
│   ├── Networking/                 5 notes — scanning, shells, pivoting
│   ├── Tools/                      1 note  — Metasploit
│   ├── Web/                        6 notes — web app bug classes
│   ├── Windows/                    3 notes — local escalation & tradecraft
│   ├── GPEN Cheatsheet/            6 PDFs  — SANS SEC560 reference handouts
│   └── Screenshots/                2 images — assets for Offense notes
└── Defense/                        blue team — logging, detection, hardening
    ├── Logging/                    1 note + 2 subfolders
    │   ├── Host-based/             2 notes — Linux & Windows log sources
    │   └── Network-based/          placeholder, not written yet
    ├── SOC2/                       4 notes — log analysis & anomaly hunting
    ├── System and Services Hardening/  4 notes — Linux, Windows, AD, network gear
    └── screenshoots/               17 images — assets for Defense notes
```

## Where to start

| If you want to… | Go to |
| --- | --- |
| Attack a domain | [Offense/AD](Offense/AD/README.md) → [AD Attacks Overview](Offense/AD/AD%20Attacks%20Overview.md) |
| Get in from the network | [Offense/Networking](Offense/Networking/README.md) |
| Escalate on a box you own | [Offense/Linux](Offense/Linux/README.md) or [Offense/Windows](Offense/Windows/README.md) |
| Test a web app | [Offense/Web](Offense/Web/README.md) |
| Study for the GPEN | [Offense/GPEN Cheatsheet](Offense/GPEN%20Cheatsheet/README.md) |
| Know what the attack leaves behind | [Defense/Logging](Defense/Logging/README.md) and [Defense/SOC2](Defense/SOC2/README.md) |
| Stop it happening | [Defense/System and Services Hardening](Defense/System%20and%20Services%20Hardening/README.md) |

## Conventions

- **Note shape** — H1 title, a short framing paragraph, a `## Contents` list of anchors, then command blocks with comments explaining *why*, not just *what*.
- **Links** — standard Markdown with URL-encoded paths, so they resolve in Obsidian **and** on GitHub. Not `[[wikilinks]]`.
- **Images** — standard Markdown embeds with a path relative to the note, kept in the `Screenshots/` folder of the matching half. Never Obsidian's double-bracket embed form. Validate with `python3 scripts/check_images.py` from the repo root.
- Full rules live in the repo's [CLAUDE.md](../CLAUDE.md).

## Maturity

The **Offense** notes are written up and cross-linked. The **Defense** notes are rougher — closer to raw study notes, several are a screenshot or a few lines, and `Logging/Network-based/` is still empty. Folder READMEs call out which notes are stubs.

> ⚠️ For authorized security testing, labs, and study only.
