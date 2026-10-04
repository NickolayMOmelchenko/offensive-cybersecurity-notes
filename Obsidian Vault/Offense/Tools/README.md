# Tools

Notes tied to a specific tool rather than to a platform or a phase. Anything here is a tool you drive across several phases of an engagement — the technique itself is documented in the platform folders.

## Tree

```text
Tools/
├── README.md       <- you are here
├── Metasploit.md   the Metasploit Framework, end to end
├── tmux.md         keep scans alive, split the screen, name and log panes
└── vim.md          edit anything on any host — and a root shell if it's in sudo -l
```

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [Metasploit](Metasploit.md) | Console basics and workspace/database use, validating and spraying credentials over SMB, getting a shell (`psexec`, Impacket-backed exec modules, WinRM, SSH), pass-the-hash, Meterpreter essentials, catching a shell with a bare handler, pivoting and routing | long |
| [tmux](tmux.md) | Keyboard tables for sessions, two- and four-pane splits, layouts, naming, navigation, zoom and `pipe-pane` logging, in an **essential** tier and an **occasional** tier (pane sync, shared sessions, nested tmux) | cheatsheet |
| [vim](vim.md) | Keyboard tables for modes, movement, editing, search/replace, visual block and splits, plus `:set paste` and `:set ff=unix` — the two that bite. Includes **vim as a privesc primitive** when it appears in `sudo -l` | cheatsheet |

> Start every long-running scan inside tmux. A four-hour `nmap -p-` that dies at hour three because the VPN flapped is the most avoidable loss on an engagement — see [tmux](tmux.md).

## Related

The platform notes give the non-Metasploit equivalent of most of this, which is usually what you want when you need to be quiet:

- [AD](../AD/README.md) — Impacket instead of `psexec`; see [Impacket Toolkit](../AD/Impacket%20Toolkit.md)
- [Networking](../Networking/README.md) — Nmap and hydra instead of the auxiliary scanners
- [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) — SSH and chisel instead of `route`/`autoroute`
- SANS Metasploit handout: [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md)
