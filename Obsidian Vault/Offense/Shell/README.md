# Shell

Getting a shell on a target and keeping it: reverse/bind shell payloads, the tools that catch them, and TTY stabilisation. The *post-access* companion to [Networking](../Networking/README.md), which covers getting in via a service.

## Tree

```text
Shell/
├── README.md       <- you are here
├── shell.md        reverse/bind payloads, listeners, TTY upgrade — starts with revshells.com
├── netcat.md       nc: catch shells, transfer files, the -e trap, ncat
└── pwncat.md       pwncat-cs: auto-stabilising catcher with privesc/persistence modules
```

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [shell](shell.md) | [revshells.com](https://www.revshells.com) up top, bind vs reverse, one-liners per language (bash, sh, nc, python, perl, php, PowerShell), and the full TTY-upgrade sequence | cheatsheet |
| [netcat](netcat.md) | `nc` flags, catching shells, the OpenBSD-vs-traditional `-e` trap + `mkfifo` workaround, file transfer, quick port scans, `ncat` | cheatsheet |
| [pwncat](pwncat.md) | `pwncat-cs`: auto-TTY, `Ctrl-D` prompt toggle, `upload`/`download`, enum/privesc/persistence modules, and when to pick it over netcat | cheatsheet |

## Reading order

1. [shell](shell.md) — pick a payload, start a listener
2. [netcat](netcat.md) — the default catcher
3. [pwncat](pwncat.md) — when you want stabilisation and looting in one place

## Related

- Getting the foothold first: [Networking → Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)
- Where web bugs turn into shells: [Web → RCE](../Web/RCE.md)
- After the shell: [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md), [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md)
- Catching with a framework: [Metasploit](../Tools/Metasploit.md) (`multi/handler`)
