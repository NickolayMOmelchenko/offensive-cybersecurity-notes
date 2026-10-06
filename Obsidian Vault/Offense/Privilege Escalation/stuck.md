# Stuck?

When the obvious vectors ([general](general.md), [PEASS](PEASS.md)) turn up nothing. A second-pass checklist of the things people skip on the first run. Work down it; most "impossible" boxes are one overlooked file.

> Authorized testing only.

## Re-enumerate harder

- Re-run the scripts with the **thorough** flags you skipped: `linpeas.sh -a`, `./LinEnum.sh -t`, `winPEAS.exe all searchall`.
- Run **pspy** (`./pspy64`) and wait — catches cron/root jobs that aren't in any crontab you can read.
- Run enumeration **again with any creds you've since found** — authenticated enum shows far more.
- Did the script finish, or did it error out half-way? Scroll up.

## Files & data you skipped

- **Unzip / extract every archive and re-scan** — `.zip`, `.tar.gz`, `.7z`, `.jar`, backups. `unzip x.zip -d /tmp/x` then run LinEnum again over it. Configs, keys and creds hide in archives.
- **Backup / temp / swap files:** `*.bak`, `*.old`, `*~`, `.*.swp`, `*.1`, copies in `/tmp`, `/var/backups`.
- **Read everything** in `/home/*`, `/opt`, `/var/www`, `/srv`, `/tmp`, `/root` (if readable) — notes, `.txt`, `README`, `TODO`, config files.
- **Hidden files:** `ls -la` everywhere, not `ls`. Dotfiles, `.git/` (dump history for secrets).
- **Mail:** `/var/mail/*`, `/var/spool/mail/*`.
- **History again** (all users, all shells) and **env** — see [exfiltration of secrets](exfiltrationofsecrets.md).
- **KeePass / browser / app stores** — `.kdbx`, saved logins; run [LaZagne](exfiltrationofsecrets.md#lazagne--automate-it).

## Reuse what you've found

- **Spray found passwords everywhere** — SSH, [SMB](../Tools/smb.md), DB, sudo, other users. People reuse.
- **Log into local services** you couldn't before: `mysql -u root -p`, `psql`, redis — DBs hold creds and sometimes give file write / RCE.
- **Local-only ports:** `ss -tlnp` / `netstat -ano`. A service bound to `127.0.0.1` is often unauthenticated — reach it by [port-forwarding](../Networking/Pivoting%20%26%20Tunneling.md).

## Linux — second pass

- **Groups:** `id` — `docker`, `lxd`, `disk`, `adm`, `shadow`, `video`, `wheel` are each an escalation path (GTFOBins → each).
- **Known-CVE quick wins:** `sudo --version` (Baron Samedit **CVE-2021-3156**), `pkexec` present+SUID (PwnKit **CVE-2021-4034**), polkit, dirty pipe (kernel 5.8–5.16).
- **NFS** `no_root_squash` in `/etc/exports`; **mounts** in `/etc/fstab` and unmounted drives (`lsblk`).
- **Wildcards** in root cron/scripts (`tar *`, `rsync`, `chown`) → argument injection.
- **Writable `PATH` dir** + a root script calling a bare command name.
- **Capabilities** again: `getcap -r / 2>/dev/null`.
- **Hijack** a root-owned `tmux`/`screen` socket (`/tmp/tmux-0/`), or other users' sessions.
- **Kernel exploit** — last resort: `uname -r` → searchsploit.

## Windows — second pass

- `whoami /priv` — **SeImpersonate/SeAssignPrimaryToken** → Potato → SYSTEM; **SeBackup/SeRestore** → read SAM+SYSTEM.
- **Unattend / GPP / web.config / registry autologon / `cmdkey /list`** — see [exfiltration of secrets](exfiltrationofsecrets.md#windows-specific-locations).
- **Service misconfigs:** `accesschk` — writable service binary, writable service config, unquoted path with a writable segment.
- **AlwaysInstallElevated** (both HKLM+HKCU = `0x1`) → `.msi` as SYSTEM.
- **Scheduled tasks** running as SYSTEM calling a writable path.
- **DLL hijacking** — missing DLL in a writable dir on a privileged process's search path.
- **Installed software** → `searchsploit`; unpatched build from `systeminfo` → known local exploit.

## Step back

- Re-read the box's **purpose** — the intended path usually matches what the app *does* (a web app → its config/DB; a dev box → scripts/keys).
- Is this even privesc, or **lateral** movement to another user first? Enumerate as *each* user you can become.
- Diff what changed: a file with a recent **mtime** (`find / -mmin -30`) often points at the intended vector.

## Related

[folder README](README.md) · [general](general.md) · [exfiltration of secrets](exfiltrationofsecrets.md) · [PEASS](PEASS.md) · [LinEnum](LinEnum.md) · [Seatbelt](Seatbelt.md) · [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) · [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md) · [GTFOBins](https://gtfobins.github.io)
