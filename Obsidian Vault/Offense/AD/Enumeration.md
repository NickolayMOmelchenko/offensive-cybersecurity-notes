# Active Directory — Enumeration

Recon of the domain once you have any foothold (even an unprivileged user or just network access). Goal: build a map of principals, groups, ACLs, and services so you can find a path. See [AD Attacks Overview](AD%20Attacks%20Overview.md) for where this sits.

## Contents

- [Unauthenticated / from the network](#unauthenticated--from-the-network)
- [Authenticated — from Linux](#authenticated--from-linux)
- [SMB enumeration (445)](#smb-enumeration-445)
- [Authenticated — from Windows (PowerView / AD module)](#authenticated--from-windows-powerview--ad-module)
- [What to look for (the checklist)](#what-to-look-for-the-checklist)
- [BloodHound workflow](#bloodhound-workflow)
- [Defense / detection](#defense--detection)

## Unauthenticated / from the network

The DC runs DNS + LDAP + Kerberos. Null/guest SMB sessions are often disabled now, but always worth a try; RID cycling lists users when null access exists.

```bash
# Find the domain controller via DNS SRV records
nslookup -type=SRV _ldap._tcp.dc._msdcs.<domain>

# SMB null / guest session enumeration
enum4linux-ng -A <dc-ip>
smbclient -L //<dc-ip> -N

# RID cycling to pull the user list (Impacket)
lookupsid.py <domain>/guest@<dc-ip>
```

## Authenticated — from Linux

```bash
# Raw LDAP dump
ldapsearch -x -H ldap://<dc-ip> -D '<user>@<domain>' -w '<pass>' -b 'DC=corp,DC=local'

# Validate creds + find where you are local admin, then enumerate
nxc smb <subnet> -u <user> -p <pass>
nxc smb <dc-ip> -u <user> -p <pass> --users --groups --shares

# Collect for BloodHound, then import the JSON into the GUI
bloodhound-python -u <user> -p <pass> -d <domain> -ns <dc-ip> -c All
```

`windapsearch` is a friendlier alternative to raw `ldapsearch` for users/groups/computers.

## SMB enumeration (445)

> Per-tool flag reference for all of these: [smb](../Tools/smb.md).

SMB is the richest early source on a Windows/AD network — shares, users, password policy, and live sessions, often before you're privileged. Try it unauthenticated first, then with any creds you have.

```bash
# Banner + signing + dialect (signing:False = NTLM-relay target)
nxc smb <subnet>                              # sweep: hostname, domain, OS, signing, SMBv1
nxc smb <subnet> --gen-relay-list relay.txt   # save hosts with SMB signing disabled

# Null / guest sessions (often disabled now, still always worth a try)
nxc smb <target> -u '' -p ''                   # null session
nxc smb <target> -u guest -p ''                # guest
smbclient -L //<target> -N                     # list shares with no creds
rpcclient -U '' -N <target>                    # then: enumdomusers / querydominfo / enumdomgroups
```

```bash
# With creds: shares + read/write perms, then loot the readable ones
nxc smb <target> -u <user> -p <pass> --shares          # per-share READ/WRITE
smbmap -H <target> -u <user> -p <pass>                 # access map
smbmap -H <target> -u <user> -p <pass> -R <share>      # recurse a share's tree
nxc smb <target> -u <user> -p <pass> -M spider_plus    # index files across all shares
smbclient "//<target>/<share>" -U '<domain>\<user>%<pass>'   # interactive: ls / get / recurse / mget
```

```bash
# Users, groups, policy, sessions — this feeds spraying and roasting
nxc smb <target> -u <user> -p <pass> --users           # domain users (+ badpwdcount)
nxc smb <target> -u <user> -p <pass> --rid-brute       # users even when --users is blocked
nxc smb <target> -u <user> -p <pass> --groups --local-groups
nxc smb <target> -u <user> -p <pass> --pass-pol        # lockout threshold -> safe spray rate
nxc smb <target> -u <user> -p <pass> --sessions --loggedon-users   # where admins are logged on
enum4linux-ng -A <target> -u <user> -p <pass>          # one-shot: shares/users/groups/policy
```

- **Check `--pass-pol` first** — the lockout threshold sets how hard you can [spray](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md); `badpwdcount` from `--users` shows who's near lockout.
- **`signing:False`** hosts are relay targets — see [Impacket → NTLM relay](Impacket%20Toolkit.md#d-ntlm-relay-escalate-without-cracking).
- **`--loggedon-users`** across hosts reveals where Domain Admins have sessions → prime [lateral-movement](Lateral%20Movement%20%26%20Credential%20Access.md) targets.
- Loot shares for **GPP `cpassword`** (SYSVOL), scripts, configs, and keys before moving on.

## Authenticated — from Windows (PowerView / AD module)

Query the directory the same way admins do, just looking for weaknesses.

```powershell
# Baseline
Get-NetDomain
Get-NetUser
Get-NetGroup "Domain Admins"
Get-NetComputer

# High-value finds
Get-NetUser -SPN                 # SPNs -> Kerberoastable
Get-NetUser -PreauthNotRequired  # no pre-auth -> AS-REP roastable
Find-LocalAdminAccess            # hosts where you are local admin
Get-NetGPO; Get-DomainObjectAcl  # delegated rights / ACL abuse paths
```

The Kerberoastable and AS-REP-roastable results feed straight into [Kerberos Attacks](Kerberos%20Attacks.md).

Collect BloodHound data from a Windows host with SharpHound:

```powershell
Import-Module .\SharpHound.ps1
Invoke-BloodHound -CollectionMethod All -ZipFileName loot.zip
# or the standalone binary:  SharpHound.exe -c All,GPOLocalGroup
```

## What to look for (the checklist)

- Users with **SPNs** or **no Kerberos pre-auth** (crackable offline).
- **Nested group membership** into privileged groups (Domain/Enterprise Admins, Backup Operators, DnsAdmins, Account Operators).
- **ACL edges:** `GenericAll`, `GenericWrite`, `WriteDACL`, `WriteOwner`, `ForceChangePassword`, `AddMember`.
- **Delegation** flags on accounts (unconstrained / constrained / resource-based) — see [Kerberos Attacks](Kerberos%20Attacks.md).
- **Passwords in places they shouldn't be:** SYSVOL scripts, GPP `cpassword`, description fields, shares.
- **Stale/legacy:** hosts unsupported OS, LLMNR/NBT-NS enabled (poisoning), SMB signing off.

## BloodHound workflow

1. Collect with SharpHound (Windows) or bloodhound-python (Linux).
2. Mark your owned principals as **Owned**.
3. Run **Shortest Paths to Domain Admins** and the pre-built queries.
4. Follow the graph edges; each edge type has a documented abuse in the tooltip.

## Defense / detection

Enumeration is quiet but not invisible: heavy LDAP queries, SharpHound's session collection, and null-session attempts show up. Mitigations: disable LLMNR/NBT-NS, require SMB signing, remove null sessions, tier admins, and alert on abnormal LDAP volume and BloodHound-style collection.
