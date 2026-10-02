# screenshoots

Image assets for the notes under [Defense](../README.md). Nothing to read here.

> **The folder name is misspelled.** It should be `Screenshots/`, matching [Offense/Screenshots](../../Offense/Screenshots/README.md). The repo [CLAUDE.md](../../../CLAUDE.md) flags the rename as outstanding. The notes embed these images with Obsidian wikilinks, which resolve by filename rather than by path — so renaming the folder won't break them, but the [root README](../../../README.md) names the path and would need updating.

## Tree

```text
screenshoots/                                   17 images
├── README.md                                   <- you are here
├── Pasted image 20230918223052.png             LM hash group policy
├── Pasted image 20230918223417.png             SMB signing group policy
├── Pasted image 20230918223535.png             LDAP signing group policy
├── Screenshot 2023-09-17 at 10.02.01 PM.png    Linux hardening
├── Screenshot 2023-09-17 at 11.04.04 PM.png    Office ASR rules
├── Screenshot 2023-09-17 at 11.21.45 PM 1.png  Windows hardening
├── Screenshot 2023-09-17 at 11.21.45 PM.png    ORPHAN — identical copy of the line above
├── Screenshot 2023-09-18 at 11.06.11 PM.png    AD hardening
├── Screenshot 2023-09-18 at 11.18.04 PM.png    OpenVPN tls-crypt config
├── Screenshot 2023-09-18 at 11.34.38 PM.png    switch / router hardening
├── Screenshot 2023-09-22 at 12.54.16 PM.png    Windows event log
├── Screenshot 2023-10-17 at 7.57.55 PM.png     semi-structured log example
├── Screenshot 2023-10-17 at 7.58.36 PM.png     structured log formats
├── Screenshot 2023-10-17 at 7.59.04 PM.png     unstructured log example
├── Screenshot 2023-10-17 at 8.05.43 PM.png     log types overview
├── Screenshot 2023-10-17 at 9.24.37 PM.png     logging terminology
├── Screenshot 2023-10-22 at 4.06.04 PM.png     log file locations
└── Screenshot 2024-12-01 at 9.19.28 PM.png     apache log triage
```

## Which note uses which

| Note | Images |
| --- | --- |
| [3. Active Directory Hardening](../System%20and%20Services%20Hardening/3.%20Active%20Directory%20Hardening.md) | `Pasted image 20230918223052`, `…223417`, `…223535`, `Screenshot 2023-09-18 at 11.06.11 PM` |
| [Logging Structure Types and Format](../SOC2/Logging%20Structure%20Types%20and%20Format.md) | `Screenshot 2023-10-17 at 8.05.43 PM`, `7.57.55 PM`, `7.58.36 PM`, `7.59.04 PM`, `9.24.37 PM` |
| [4. Network Devices & Services Hardening](../System%20and%20Services%20Hardening/4.%20Network%20Devices%20%26%20Services%20Hardening.md) | `Screenshot 2023-09-18 at 11.18.04 PM`, `11.34.38 PM` |
| [2. Windows Hardening](../System%20and%20Services%20Hardening/2.%20Windows%20Hardening.md) | `Screenshot 2023-09-17 at 11.04.04 PM`, `11.21.45 PM 1` |
| [1. Linux Hardening](../System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md) | `Screenshot 2023-09-17 at 10.02.01 PM` |
| [Log file location](../SOC2/Log%20file%20location.md) | `Screenshot 2023-10-22 at 4.06.04 PM` |
| [Useful Commands](../SOC2/Useful%20Commands.md) | `Screenshot 2024-12-01 at 9.19.28 PM` |
| [Host-based/Windows](../Logging/Host-based/Windows.md) | `Screenshot 2023-09-22 at 12.54.16 PM` |
| *(none)* | `Screenshot 2023-09-17 at 11.21.45 PM` — orphan |

## Cleanup owed

These files don't follow the repo's image rules yet, and the Defense notes still embed them the Obsidian-only way:

1. **Embeds** should be standard Markdown with a real relative path and alt text. These notes all use Obsidian's double-bracket embed form instead, which GitHub renders as raw text — so **every image in Defense is currently invisible on GitHub.** This is the one that actually matters.
2. **Filenames** should be `<note-slug>-<n>.png` in lowercase ASCII — e.g. `active-directory-hardening-1.png`, not `Pasted image 20230918223052.png`.
3. **The duplicate is safe to delete.** `Screenshot 2023-09-17 at 11.21.45 PM.png` is referenced by nothing and is byte-identical (`cmp` clean, 730649 bytes) to `… PM 1.png`, which *is* referenced. Note that it's the copy **without** the ` 1` suffix that's the orphan.
4. **Hidden characters** — these macOS names contain U+202F (narrow no-break space) before `AM`/`PM`, not a normal space. Don't retype them; match with a glob or copy the bytes from `ls` output.
5. **Folder name** — rename to `Screenshots/`.

Check the whole vault from the repo root:

```bash
python3 scripts/check_images.py
```

The step-by-step procedure for fixing all of this is in [CLAUDE.md](../../../CLAUDE.md).
