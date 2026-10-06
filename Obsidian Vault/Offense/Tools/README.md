# Tools

Notes tied to a specific tool rather than to a platform or a phase. Anything here is a tool you drive across several phases of an engagement — the technique itself is documented in the platform folders.

## Tree

```text
Tools/
├── README.md       <- you are here
├── Metasploit.md   the Metasploit Framework, end to end
├── fuzz.md         ffuf, feroxbuster, wordlists — and how to filter
├── feroxbuster.md  recursive content discovery — the full cheatsheet
├── gobuster.md     dir, dns, vhost and fuzz modes
├── nmap.md         flag reference, scan types, and all 609 NSE scripts
├── smb.md          which SMB tool to reach for, and its main flags
├── tmux.md         keep scans alive, split the screen, name and log panes
└── vim.md          edit anything on any host — and a root shell if it's in sudo -l
```

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [Metasploit](Metasploit.md) | Console basics and workspace/database use, validating and spraying credentials over SMB, getting a shell (`psexec`, Impacket-backed exec modules, WinRM, SSH), pass-the-hash, Meterpreter essentials, catching a shell with a bare handler, pivoting and routing | long |
| [feroxbuster](feroxbuster.md) | Recursive content-discovery cheatsheet: the enumeration checklist, every flag (incl. `--scan-dir-listings`, `--thorough`, collectors), filtering, and the vs-gobuster/ffuf matrix | cheatsheet |
| [fuzz](fuzz.md) | The baseline-then-filter method, **ffuf** flags grouped by job (input, matchers, filters, calibration, HTTP, output), `FUZZ` keyword modes, a what-to-fuzz table, **feroxbuster**, wordlist picks, and a tool-comparison matrix | cheatsheet |
| [gobuster](gobuster.md) | All modes (`dir`, `dns`, `vhost`, `fuzz`, `s3`, `gcs`, `tftp`) with their flags, the `-s` vs `-b` trap, and a gotchas table — starting with the fact that it does **not** recurse | cheatsheet |
| [nmap](nmap.md) | The main scan types with samples, a grouped flag reference, what the shorthand flags actually expand to (`-A` = `-O -sV -sC --traceroute`), two-stage scan recipes, NSE categories, and an appendix listing **all 609 NSE scripts** | reference |
| [smb](smb.md) | Tool-selection table then the main flags for **netexec**, **smbclient**, **smbmap**, **enum4linux-ng**, **rpcclient**, nmap NSE, Impacket and `smbserver.py`. Enumeration-first, with what to carry into the report | cheatsheet |
| [tmux](tmux.md) | Keyboard tables for sessions, two- and four-pane splits, layouts, naming, navigation, zoom and `pipe-pane` logging, in an **essential** tier and an **occasional** tier (pane sync, shared sessions, nested tmux) | cheatsheet |
| [vim](vim.md) | Keyboard tables for modes, movement, editing, search/replace, visual block and splits, plus `:set paste` and `:set ff=unix` — the two that bite. Includes **vim as a privesc primitive** when it appears in `sudo -l` | cheatsheet |

> Start every long-running scan inside tmux. A four-hour `nmap -p-` that dies at hour three because the VPN flapped is the most avoidable loss on an engagement — see [tmux](tmux.md).

## Related

The platform notes give the non-Metasploit equivalent of most of this, which is usually what you want when you need to be quiet:

- [AD](../AD/README.md) — Impacket instead of `psexec`; see [Impacket Toolkit](../AD/Impacket%20Toolkit.md)
- [Networking](../Networking/README.md) — Nmap and hydra instead of the auxiliary scanners
- [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) — SSH and chisel instead of `route`/`autoroute`
- SANS Metasploit handout: [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md)
