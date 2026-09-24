# Active Directory — Enumeration

Recon of the domain once you have any foothold (even an unprivileged user or just network access). Goal: build a map of principals, groups, ACLs, and services so you can find a path. See [[AD Attacks Overview]] for where this sits.

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

The Kerberoastable and AS-REP-roastable results feed straight into [[Kerberos Attacks]].

## What to look for (the checklist)

- Users with **SPNs** or **no Kerberos pre-auth** (crackable offline).
- **Nested group membership** into privileged groups (Domain/Enterprise Admins, Backup Operators, DnsAdmins, Account Operators).
- **ACL edges:** `GenericAll`, `GenericWrite`, `WriteDACL`, `WriteOwner`, `ForceChangePassword`, `AddMember`.
- **Delegation** flags on accounts (unconstrained / constrained / resource-based) — see [[Kerberos Attacks]].
- **Passwords in places they shouldn't be:** SYSVOL scripts, GPP `cpassword`, description fields, shares.
- **Stale/legacy:** hosts unsupported OS, LLMNR/NBT-NS enabled (poisoning), SMB signing off.

## BloodHound workflow

1. Collect with SharpHound (Windows) or bloodhound-python (Linux).
2. Mark your owned principals as **Owned**.
3. Run **Shortest Paths to Domain Admins** and the pre-built queries.
4. Follow the graph edges; each edge type has a documented abuse in the tooltip.

## Defense / detection

Enumeration is quiet but not invisible: heavy LDAP queries, SharpHound's session collection, and null-session attempts show up. Mitigations: disable LLMNR/NBT-NS, require SMB signing, remove null sessions, tier admins, and alert on abnormal LDAP volume and BloodHound-style collection.
