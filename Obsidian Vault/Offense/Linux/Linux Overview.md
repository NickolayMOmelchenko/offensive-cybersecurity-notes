# Linux — Offensive Notes Overview

Index for the Linux post-exploitation notes. Scope: what to do **after** you land a shell on a Linux host during an authorized test — orient, enumerate, escalate, and understand the impact. Getting the initial shell is a service/web problem covered elsewhere.

## Contents

- [Post-exploitation loop](#post-exploitation-loop)
- [Stabilize a shell (do this first)](#stabilize-a-shell-do-this-first)
- [Orientation one-liners](#orientation-one-liners)
- [Tooling](#tooling)
- [Notes in this folder](#notes-in-this-folder)
- [Principle](#principle)

## Post-exploitation loop

1. **Stabilize** the shell (below).
2. **[Enumerate](Enumeration%20%26%20Privilege%20Escalation.md)** — who am I, what can I reach, what is misconfigured.
3. **Escalate** to root via a concrete misconfig (SUID, sudo, cron, capability, kernel).
4. **Loot & pivot** — creds, keys, config, then use the host as a foothold into the network.
5. **Document** everything for the report and clean up artifacts you created.

## Stabilize a shell (do this first)

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'   # upgrade dumb shell
# then: Ctrl-Z, stty raw -echo; fg, export TERM=xterm
```

Also try `script -qc /bin/bash /dev/null`. A proper TTY makes `sudo`, `su`, and job control work.

## Orientation one-liners

```bash
id; hostname; uname -a; cat /etc/os-release
sudo -l                 # what can I run as root without/with a password
ip a; ss -tulpn         # interfaces and listening services (pivot targets)
```

## Tooling

- **Enumeration:** LinPEAS, linux-smart-enumeration (lse.sh), pspy (watch cron/processes without root).
- **Exploit suggestion:** Linux Exploit Suggester (kernel), GTFOBins (abuse legit binaries).
- **Loot:** manual grep for keys/creds, then transfer off-host.

```bash
# Quick loot sweep
grep -rIl -e 'password' -e 'secret' -e 'api_key' /etc /opt /var/www 2>/dev/null
find / \( -name 'id_rsa' -o -name '*.kdbx' -o -name '.env' \) 2>/dev/null
```

## Notes in this folder

- [Enumeration & Privilege Escalation](Enumeration%20%26%20Privilege%20Escalation.md) — the main checklist and the common escalation vectors
- [Privilege Escalation](Privilege%20Escalation.md) — worked exploitation for each vector (sudo/SUID/caps/cron/NFS/docker/kernel CVEs)
- [Container Escape](Container%20Escape.md) — breaking out of a Docker/containerd container onto the host

## Principle

Prefer **misconfiguration over kernel exploits**. Sudo rules, SUID binaries, writable cron, and capabilities are reliable and low-risk; kernel exploits can crash the box (bad on a client engagement). Always confirm scope before running anything that could cause instability.
