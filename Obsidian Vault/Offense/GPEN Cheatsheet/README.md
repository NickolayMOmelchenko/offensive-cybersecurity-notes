# GPEN / SEC560 Cheatsheet

Reference handouts for the **GPEN** certification and SANS **SEC560** course. These are static PDFs/DOCX kept here as quick lookups; the *working* notes live in the sibling folders and link back here.

## What's in this folder

| File | Use it for |
| --- | --- |
| `SEC560HANDOUT_NmapCheatSheetv1.1_D02_01.pdf` | Nmap flags, scan types, NSE, timing |
| `SEC560HANDOUT_NetcatCheatSheet_D02_01.pdf` | Netcat listeners, transfers, relays |
| `SEC560HANDOUT_Metasploit_D02_01.pdf` | msfconsole, sessions, Meterpreter |
| `SEC560HANDOUT_PowerShellCheat_D02_01.pdf` | Offensive PowerShell one-liners |
| `SEC560HANDOUT_WinComLine_V1_D02_01.pdf` | Windows command-line reference |
| `SANS-Pivoting-Cheat-Sheet-v1.2.pdf` | Port forwarding, proxychains, tunneling |
| `Index_SEC560_K01_03.pdf` / `.docx` | Course book index (exam lookup) |
| `IPv6_PRG.pdf`, `TCPIP_PRG.pdf` | Protocol/packet reference |

> These files are treated as read-only reference. See the repo `CLAUDE.md` — don't edit the PDFs/DOCX; add or edit `.md` notes instead.

## Exam prep workflow (the GPEN is open-book)

1. **Build a physical/PDF index** — the exam is open-book with a time limit, so fast lookup beats memorization. `Index_SEC560_K01_03` is the starting point; extend it with your own page references.
2. **Tab your books** by phase: recon → scanning → exploitation → post-exploitation → password attacks → reporting.
3. **Practice the labs** until commands are muscle memory; use the cheatsheets only to confirm flags.
4. **Time yourself** on the practice tests; note weak domains and revisit the matching vault notes.

## Related vault notes

- [[../AD/AD Attacks Overview|Active Directory attacks]]
- [[../Linux/Linux Overview|Linux post-exploitation]]
- [[../Networking/Networking Overview|Networking & pivoting]]
- [[../Networking/Password Attacks & Brute Forcing|Password attacks & brute forcing]]
- [[../Windows/Windows Overview|Windows offense]]

## The GPEN methodology (the phases the exam tests)

Planning/scoping → recon (OSINT) → scanning & enumeration → exploitation → password attacks → post-exploitation & pivoting → **reporting**. Reporting and scoping are graded topics, not afterthoughts — keep notes on both, not just the attacks.
