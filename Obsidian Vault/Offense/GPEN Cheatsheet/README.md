# GPEN / SEC560 Cheatsheet

Reference handouts for the **GPEN** certification and SANS **SEC560** course. These are static PDFs kept here as quick lookups; the *working* notes live in the sibling folders and link back here.

## Contents

- [Tree](#tree)
- [What's in this folder](#whats-in-this-folder)
- [Exam prep workflow (the GPEN is open-book)](#exam-prep-workflow-the-gpen-is-open-book)
- [Related vault notes](#related-vault-notes)
- [The GPEN methodology (the phases the exam tests)](#the-gpen-methodology-the-phases-the-exam-tests)

## Tree

```text
GPEN Cheatsheet/
├── README.md                                   <- you are here
├── SEC560HANDOUT_NmapCheatSheetv1.1_D02_01.pdf scanning
├── SEC560HANDOUT_NetcatCheatSheet_D02_01.pdf   listeners & transfers
├── SEC560HANDOUT_Metasploit_D02_01.pdf         framework reference
├── SEC560HANDOUT_PowerShellCheat_D02_01.pdf    offensive PowerShell
├── SEC560HANDOUT_WinComLine_V1_D02_01.pdf      Windows command line
└── SANS-Pivoting-Cheat-Sheet-v1.2.pdf          port forwarding & tunneling
```

## What's in this folder

| File | Use it for | Pairs with |
| --- | --- | --- |
| `SEC560HANDOUT_NmapCheatSheetv1.1_D02_01.pdf` | Nmap flags, scan types, NSE, timing | [Networking Overview](../Networking/Networking%20Overview.md) |
| `SEC560HANDOUT_NetcatCheatSheet_D02_01.pdf` | Netcat listeners, transfers, relays | [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) |
| `SEC560HANDOUT_Metasploit_D02_01.pdf` | msfconsole, sessions, Meterpreter | [Metasploit](../Tools/Metasploit.md) |
| `SEC560HANDOUT_PowerShellCheat_D02_01.pdf` | Offensive PowerShell one-liners | [Windows Overview](../Windows/Windows%20Overview.md) |
| `SEC560HANDOUT_WinComLine_V1_D02_01.pdf` | Windows command-line reference | [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md) |
| `SANS-Pivoting-Cheat-Sheet-v1.2.pdf` | Port forwarding, proxychains, tunneling | [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) |

> These files are treated as read-only reference. See the repo [CLAUDE.md](../../../CLAUDE.md) — don't edit the PDFs; add or edit `.md` notes instead.
>
> The course book index and the IPv6/TCPIP protocol handouts are **not** in this repo — they're part of the paid courseware. If you add them, list them above.

## Exam prep workflow (the GPEN is open-book)

1. **Build a physical/PDF index** — the exam is open-book with a time limit, so fast lookup beats memorization. Build it from your own course books and extend it with page references as you work the labs.
2. **Tab your books** by phase: recon → scanning → exploitation → post-exploitation → password attacks → reporting.
3. **Practice the labs** until commands are muscle memory; use the cheatsheets only to confirm flags.
4. **Time yourself** on the practice tests; note weak domains and revisit the matching vault notes.

## Related vault notes

- [Active Directory attacks](../AD/AD%20Attacks%20Overview.md)
- [Linux post-exploitation](../Linux/Linux%20Overview.md)
- [Networking & pivoting](../Networking/Networking%20Overview.md)
- [Password attacks & brute forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md)
- [Windows offense](../Windows/Windows%20Overview.md)
- [Web application attacks](../Web/Web%20Overview.md)

## The GPEN methodology (the phases the exam tests)

Planning/scoping → recon (OSINT) → scanning & enumeration → exploitation → password attacks → post-exploitation & pivoting → **reporting**. Reporting and scoping are graded topics, not afterthoughts — keep notes on both, not just the attacks.
