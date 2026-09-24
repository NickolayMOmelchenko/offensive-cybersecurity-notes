# Linux — Enumeration & Privilege Escalation

Checklist for going from user shell to root on an authorized engagement. Run [[Linux Overview|LinPEAS/lse.sh]] to automate, but understand each vector so you can act on the output. Prefer misconfigs over kernel exploits.

## Enumeration checklist

- **Who/what am I:** `id`, `sudo -l`, `groups`, `cat /etc/passwd | grep -v nologin`
- **System:** `uname -a`, `/etc/os-release` (kernel + distro version → known exploits)
- **SUID/SGID binaries:** `find / -perm -4000 -type f 2>/dev/null`
- **Capabilities:** `getcap -r / 2>/dev/null`
- **Cron jobs:** `cat /etc/crontab`, `ls -la /etc/cron.*`, and run **pspy** to catch jobs + their scripts
- **Writable stuff:** world-writable files/dirs, writable `$PATH` entries, writable service/cron scripts
- **Network & services:** `ss -tulpn` (localhost-only services are prime targets after a pivot)
- **Loot:** SSH keys (`~/.ssh/`), history files, `.env`/config with creds, DB creds, backups, mounted shares
- **Containers:** check for `/.dockerenv`, cgroup hints; a container escape is a different (and sensitive) path — confirm scope

## Escalation vectors (map output → action)

### sudo rules (`sudo -l`)
- A binary you can run as root that GTFOBins lists = instant root (e.g. `sudo vim -c ':!/bin/sh'`, `sudo less` then `!sh`, `sudo find . -exec /bin/sh \;`).
- `env_keep`/`LD_PRELOAD` left in, or `sudo` version with a known CVE, can also work.

### SUID/SGID binaries
- Cross-reference results against **GTFOBins**; many common binaries (`find`, `nmap` old, `cp`, `bash -p`) drop a root shell when SUID.
- Custom SUID binaries: check what they exec and whether they use a relative path (PATH hijack).

### Capabilities
- `cap_setuid+ep` on something scriptable (e.g. python) → set uid 0. Example concept: python with setuid capability can call `os.setuid(0)` then spawn a shell.

### Cron / scheduled jobs
- Root cron running a script you can write, or a wildcard/relative-path command in a writable dir → inject your command. pspy reveals jobs not visible in your crontab.

### PATH & wildcard injection
- Root script calling a bare command (`tar`, `chown *`) from a writable directory → drop a malicious binary or abuse `--checkpoint-action` style wildcard tricks.

### Kernel exploits (last resort)
- Match `uname -r` to Linux Exploit Suggester output. Risky — can panic the box; only with clear scope and ideally on a snapshot/lab.

## Post-root

- Confirm `id` = 0, then loot `/etc/shadow`, root SSH keys, and any domain/cloud creds.
- Note persistence options for the report (authorized only) and record artifacts you created so they can be cleaned up.

## Defense / detection (for the report)

Least-privilege sudo (no shell-spawning binaries), remove unnecessary SUID bits, use `NOPASSWD` sparingly, patch kernels, file-integrity monitoring on cron dirs, and auditd rules for `execve` of shells by service accounts.
