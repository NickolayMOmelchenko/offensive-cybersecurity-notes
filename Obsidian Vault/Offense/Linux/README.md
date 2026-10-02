# Linux

What to do once you have a shell on a Linux host: stabilise it, work out what you are, and get root. Plus escaping a container, since the "host" is often a container these days.

Read [Linux Overview](Linux%20Overview.md) first — it has the post-exploitation loop and the shell-stabilisation sequence you want before anything else.

## Tree

```text
Linux/
├── README.md                               <- you are here
├── Linux Overview.md                       index, post-ex loop, stabilise a shell
├── Enumeration & Privilege Escalation.md   the short checklist: output -> action
├── Privilege Escalation.md                 the long reference for each vector
└── Container Escape.md                     Docker/container breakout
```

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [Linux Overview](Linux%20Overview.md) | Index for the folder, the post-exploitation loop, upgrading a dumb shell to a full TTY, orientation one-liners, tooling and a quick loot sweep | index |
| [Enumeration & Privilege Escalation](Enumeration%20%26%20Privilege%20Escalation.md) | The **checklist** version — an enumeration list, then a map from what you see to which vector to try, plus post-root steps | short |
| [Privilege Escalation](Privilege%20Escalation.md) | The **deep** version — sudo rules, SUID/SGID, capabilities, cron and systemd timers, writable `/etc/passwd`/`shadow`/`sudoers`, NFS `no_root_squash` | long |
| [Container Escape](Container%20Escape.md) | Am I in a container, what to enumerate, an escape matrix keyed by finding, then privileged containers, `CAP_SYS_ADMIN` + cgroup `release_agent`, docker socket, host mounts | longest |

> **Two escalation notes, on purpose.** Use [Enumeration & Privilege Escalation](Enumeration%20%26%20Privilege%20Escalation.md) live on a box to decide *what to try*; open [Privilege Escalation](Privilege%20Escalation.md) for the actual commands and edge cases of the vector you picked.

## Reading order

1. [Linux Overview](Linux%20Overview.md) — stabilise the shell before you enumerate
2. [Enumeration & Privilege Escalation](Enumeration%20%26%20Privilege%20Escalation.md) — run the checklist
3. [Privilege Escalation](Privilege%20Escalation.md) — exploit the vector it pointed at
4. [Container Escape](Container%20Escape.md) — if step 1 told you you're in a container

## Related

- Getting the shell in the first place: [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)
- Using the host as a route onward: [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md)
- Defensive side: [1. Linux Hardening](../../Defense/System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md), [Host-based logging on Linux](../../Defense/Logging/Host-based/Linux.md)
