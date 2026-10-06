# scripts

Repo tooling. Two scripts: one scaffolds a new engagement, one enforces the vault's image rules.

## Tree

```text
scripts/
├── README.md             <- you are here
├── new-engagement.sh     scaffold a pentest / HTB engagement directory
└── check_images.py       validate every image embed in the vault
```

## new-engagement.sh

The one to pull onto the attack box at the start of every engagement. No dependencies, portable bash — works on Kali and on macOS's bash 3.2.

```bash
git pull
./scripts/new-engagement.sh "Acme Company"      # ./Projects/Acme Company/{EPT,IPT}/...
./scripts/new-engagement.sh --htb Lame          # ./Projects/HTB/Lame/box/...
./scripts/new-engagement.sh --help
```

### What it builds

```text
Projects/Acme Company/
├── .gitignore                  allows only *.txt — keeps loot out of git
├── EPT/
│   ├── engagement.txt          authorization, contacts, infra, status log
│   ├── findings.txt            one block per finding, written as you go
│   ├── evidence/
│   │   ├── credentials/credentials.txt
│   │   ├── data/data.txt       what was reachable vs what you accessed
│   │   └── screenshots/screenshots.txt
│   ├── logs/commands.txt       timestamped command log
│   ├── scans/scans.txt         naming convention, invocations, index
│   ├── scope/scope.txt         in/out of scope, constraints, accounts
│   └── tools/tools.txt         what you put on target, and if you removed it
└── IPT/                        same subtree
```

Every `.txt` is a filled-in template, not an empty placeholder — the prompts are the point.

### Options

| Flag | Effect |
| --- | --- |
| `-b, --base DIR` | Where `Projects/` lives. Default `$PENTEST_BASE`, else `./Projects` |
| `-t, --types LIST` | Comma-separated subtrees. Default `EPT,IPT`. Add your own, e.g. `-t "EPT,IPT,WEBAPP"` |
| `--htb` | HTB mode: `<base>/HTB/<box>/box/...` |
| `--no-gitignore` | Skip the `.gitignore` |
| `--no-tree` | Don't print the tree at the end |
| `-n, --dry-run` | Show what it would create, write nothing — **also blocks installs** |
| `--check-tools` | Audit the toolchain and exit. Needs no client name |
| `--install-tools` | Install what's missing. Prints the commands and asks first |
| `-y, --yes` | Skip the install confirmation |
| `--no-tools` | Skip the toolchain check |

### Toolchain check

Every scaffold run also audits the attack box and writes `<TYPE>/tools/installed-versions.txt`, so the engagement records which tool versions you actually had. Audit without scaffolding anything:

```bash
./scripts/new-engagement.sh --check-tools
```

It covers 32 tools in seven groups — core (`nmap`, `tmux`, `vim`, `git`, `curl`, `jq`, `python3`, `pipx`), wordlists (SecLists), recon (`whatweb`, `nuclei`, `subfinder`, `httpx`, `katana`), web (`ffuf`, `gobuster`, `feroxbuster`, `sqlmap`), smb (`smbclient`, `rpcclient`, `smbmap`, `nxc`, `enum4linux-ng`), ad (`impacket`, `bloodhound-python`, `responder`), crack (`hashcat`, `john`, `hydra`), exploit (`metasploit`) and pivot (`proxychains4`, `socat`).

**It never installs anything unless you ask.** `--install-tools` prints every command first and waits for a `y`; `-y` skips that prompt, and `--dry-run` blocks execution regardless. Package names resolve per platform — apt on Kali/Debian, Homebrew on macOS (including `--cask` for Metasploit), with `pipx` or `git clone` fallbacks for the tools no package manager carries (`smbmap`, `nxc`, `enum4linux-ng`, `impacket`, `bloodhound`, `responder`, `whatweb`, SecLists).

### Behaviour worth knowing

- **Idempotent.** Existing files are never overwritten — re-running reports them as `= keep`. Safe to re-run mid-engagement to add a type.
- **The `.gitignore` allows only `*.txt`.** Scan output, screenshots, dumps, pcaps and key material are ignored by default; committing one takes a deliberate `git add -f`. Verified: `git add -A` over a tree containing an `ntds.dit`, a `.png` and an `.gnmap` stages only the `.txt` scaffolding.
- **Client names with spaces work** — quote them.

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
