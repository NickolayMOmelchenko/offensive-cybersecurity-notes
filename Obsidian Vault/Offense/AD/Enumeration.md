# Active Directory — Enumeration

Recon of the domain once you have any foothold (even an unprivileged user or just network access). Goal: build a map of principals, groups, ACLs, and services so you can find a path. See [[AD Attacks Overview]] for where this sits.

## Unauthenticated / from the network

- **Find the DC:** it runs DNS + LDAP + Kerberos. `nslookup -type=SRV _ldap._tcp.dc._msdcs.<domain>` or DNS SRV lookups.
- **SMB null/guest session** (often disabled now, always worth a try):
  - `enum4linux-ng -A <dc-ip>`
  - `smbclient -L //<dc-ip> -N`
- **RID cycling / user list** via `lookupsid.py <domain>/guest@<dc-ip>` (Impacket) when null access exists.

## Authenticated — from Linux

- **LDAP dump:** `ldapsearch -x -H ldap://<dc-ip> -D '<user>@<domain>' -w '<pass>' -b 'DC=corp,DC=local'`
- **windapsearch** for users/groups/computers with friendlier output.
- **CrackMapExec / NetExec** to validate creds and sweep:
  - `nxc smb <subnet> -u <user> -p <pass>` — where do these creds work + who is local admin.
  - `nxc smb <dc-ip> -u <user> -p <pass> --users --groups --shares`
- **BloodHound (Python ingestor):** `bloodhound-python -u <user> -p <pass> -d <domain> -ns <dc-ip> -c All` → import the JSON into the BloodHound GUI.

## Authenticated — from Windows (PowerView / AD module)

Concept: query the directory the same way admins do, just looking for weaknesses.

- `Get-NetDomain`, `Get-NetUser`, `Get-NetGroup "Domain Admins"`, `Get-NetComputer`
- **High-value finds:**
  - `Get-NetUser -SPN` — accounts with SPNs → [[Kerberos Attacks|Kerberoastable]].
  - `Get-NetUser -PreauthNotRequired` — → [[Kerberos Attacks|AS-REP roastable]].
  - `Find-LocalAdminAccess` — hosts where your user is local admin.
  - `Get-NetGPO`, `Get-DomainObjectAcl` — delegated rights and ACL abuse paths.

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
