# Linux — Enumeration & Privilege Escalation

Checklist for going from user shell to root on an authorized engagement. Run [LinPEAS/lse.sh](Linux%20Overview.md) to automate, but understand each vector so you can act on the output. Prefer misconfigs over kernel exploits.

## Enumeration checklist

Quick copy-paste sweep — then read the annotated list below for what each finding means:

```bash
id; groups; sudo -l                        # who am I, what can I run as root
uname -a; cat /etc/os-release              # kernel + distro -> known exploits
find / -perm -4000 -type f 2>/dev/null     # SUID binaries
getcap -r / 2>/dev/null                    # file capabilities
cat /etc/crontab; ls -la /etc/cron.*       # scheduled jobs
ss -tulpn                                  # listening services (pivot targets)
find / -writable -type d 2>/dev/null       # writable directories
```

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
- A binary you can run as root that GTFOBins lists = instant root. Always check GTFOBins for the exact binary.
- `env_keep`/`LD_PRELOAD` left in, or a `sudo` version with a known CVE, can also work.

```bash
# Classic GTFOBins root shells when the binary is allowed via sudo
sudo vim -c ':!/bin/sh'
sudo find . -exec /bin/sh \; -quit
sudo less /etc/profile      # then type  !/bin/sh
```

### SUID/SGID binaries
- Cross-reference results against **GTFOBins**; many common binaries (`find`, old `nmap`, `cp`, `bash -p`) drop a root shell when SUID.
- Custom SUID binaries: check what they exec and whether they use a relative path (PATH hijack).

### Capabilities
- `cap_setuid+ep` on something scriptable (e.g. python) → set uid 0.

```bash
getcap -r / 2>/dev/null | grep cap_setuid            # find the capability
python3 -c 'import os; os.setuid(0); os.system("/bin/sh")'
```

### Cron / scheduled jobs
- Root cron running a script you can write, or a wildcard/relative-path command in a writable dir → inject your command. pspy reveals jobs not visible in your crontab.

### PATH & wildcard injection
- Root script calling a bare command (`tar`, `chown *`) from a writable directory → drop a malicious binary or abuse `--checkpoint-action` style wildcard tricks.

### Kernel exploits (last resort)
- Match `uname -r` to Linux Exploit Suggester output. Risky — can panic the box; only with clear scope and ideally on a snapshot/lab.

## Post-root

- Confirm `id` = 0, then loot `/etc/shadow`, root SSH keys, and any domain/cloud creds.
- Note persistence options for the report (authorized only) and record artifacts you created so they can be cleaned up.

## Impacket note (Linux as attacker, or a domain-joined box)

Impacket is **not** a local Linux privesc tool — the vectors above (SUID, sudo, cron, capabilities, kernel) are how you get root on a Linux target. Impacket runs *from* your Linux attack box against **Windows/AD**. It becomes relevant here in two cases:

- **Pivoting:** you root a Linux host, find domain creds in configs/keytabs, and use them with Impacket to attack the Windows side.
- **Domain-joined Linux** (SSSD/realmd): loot `/etc/krb5.keytab`, cached tickets in `/tmp/krb5cc_*`, or `/etc/sssd/` — those AD creds/tickets feed straight into Impacket and [pass-the-ticket](../AD/Kerberos%20Attacks.md).

Full setup, delivery, and the escalation scripts: [Impacket Toolkit](../AD/Impacket%20Toolkit.md).

## Defense / detection (for the report)

Least-privilege sudo (no shell-spawning binaries), remove unnecessary SUID bits, use `NOPASSWD` sparingly, patch kernels, file-integrity monitoring on cron dirs, and auditd rules for `execve` of shells by service accounts.
