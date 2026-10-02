# Offense

Red team / pentest notes, organised by **where you are in an engagement**, not by tool. Scoped for GPEN / SANS SEC560 but written as working references: every command block says what the flags do and what a hit looks like.

Each subfolder has its own README with a tree. The platform folders also carry an `… Overview.md` note — that's the deeper index with the kill chain and tooling tables; the README is just the map.

## Tree

```text
Offense/
├── README.md                       <- you are here
├── AD/                             the Active Directory attack chain (7 notes)
├── Linux/                          post-exploitation and root on Linux (4 notes)
├── Networking/                     scanning, shells, pivoting (5 notes)
├── Tools/                          framework-specific notes (1 note)
├── Web/                            web application bug classes (6 notes)
├── Windows/                        local escalation and tradecraft (3 notes)
├── GPEN Cheatsheet/                SANS SEC560 reference PDFs (read-only)
└── Screenshots/                    image assets for the notes above
```

## Folders

| Folder | Covers | Start with |
| --- | --- | --- |
| [AD](AD/README.md) | Enumeration, Kerberos, ACL abuse, lateral movement, DCSync, an end-to-end DC walkthrough | [AD Attacks Overview](AD/AD%20Attacks%20Overview.md) |
| [Linux](Linux/README.md) | Shell stabilisation, enumeration, sudo/SUID/caps/cron escalation, container escape | [Linux Overview](Linux/Linux%20Overview.md) |
| [Networking](Networking/README.md) | Nmap, password spraying, service→shell, SSH/SOCKS/chisel pivoting, VLAN hopping | [Networking Overview](Networking/Networking%20Overview.md) |
| [Tools](Tools/README.md) | Metasploit: console, credential spraying, Meterpreter, pivoting, handlers | [Metasploit](Tools/Metasploit.md) |
| [Web](Web/README.md) | Recon and triage, then XSS, SQLi, SSRF, CSRF, RCE | [Web Overview](Web/Web%20Overview.md) |
| [Windows](Windows/README.md) | Token privileges, service misconfigs, AlwaysInstallElevated, UAC, credential hunting | [Windows Overview](Windows/Windows%20Overview.md) |
| [GPEN Cheatsheet](GPEN%20Cheatsheet/README.md) | SANS handouts for Nmap, Netcat, Metasploit, PowerShell, Windows CLI, pivoting | [the folder README](GPEN%20Cheatsheet/README.md) |
| [Screenshots](Screenshots/README.md) | Image assets — nothing to read | — |

## A typical path through these notes

1. **Recon & scanning** — [Networking Overview](Networking/Networking%20Overview.md)
2. **Get credentials** — [Password Attacks & Brute Forcing](Networking/Password%20Attacks%20%26%20Brute%20Forcing.md), or a web bug from [Web](Web/README.md)
3. **Get a shell** — [Remote Access & Getting a Shell](Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)
4. **Escalate locally** — [Linux](Linux/Privilege%20Escalation.md) or [Windows](Windows/Privilege%20Escalation.md)
5. **Own the domain** — [AD](AD/AD%20Attacks%20Overview.md) → [Attacking the Domain Controller](AD/Attacking%20the%20Domain%20Controller.md)
6. **Pivot deeper** — [Pivoting & Tunneling](Networking/Pivoting%20%26%20Tunneling.md)
7. **Write it up** — the *Defense / detection* section of each note is the remediation half of the report

## Related

- The blue-team half: [Defense](../Defense/README.md)
- Repo conventions: [CLAUDE.md](../../CLAUDE.md)

> ⚠️ Authorized engagements, labs and study only — scope and written permission first.
