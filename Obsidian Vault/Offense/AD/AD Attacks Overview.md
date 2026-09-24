# Active Directory — Attacks Overview

Index and mental model for the AD notes in this folder. AD is the identity backbone of most enterprises, so a pentest usually becomes an AD pentest. Everything here assumes an **authorized engagement** (scope, rules of engagement, written permission).

## The kill chain (how the notes fit together)

1. **Foothold** — one set of domain credentials or code execution on one domain-joined host. Often from phishing, a weak service, or [password spray](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md).
2. **[Enumeration](Enumeration.md)** — map users, groups, computers, ACLs, and trust. You attack what you can see; enumeration is 80% of AD work.
3. **Credential access** — pull hashes/tickets from memory, disk, or the directory. See [Lateral Movement & Credential Access](Lateral%20Movement%20%26%20Credential%20Access.md).
4. **Privilege escalation** — local admin → domain user → privileged group → Domain Admin, usually via misconfigured ACLs, [Kerberos](Kerberos%20Attacks.md), or delegation.
5. **Lateral movement** — reuse creds/tickets to hop hosts (PsExec, WMI, WinRM). See [Lateral Movement & Credential Access](Lateral%20Movement%20%26%20Credential%20Access.md).
6. **Domain dominance / persistence** — DCSync, golden/silver tickets, AdminSDHolder. Report these; rarely needed to prove impact.

## Core toolkit (know what each is for)

| Tool | Purpose |
| --- | --- |
| BloodHound / SharpHound | Graph ACL + session data to find attack paths |
| PowerView / ADModule | Ad-hoc PowerShell enumeration |
| Impacket | Python implementations of SMB/Kerberos/DCE-RPC attacks — see [Impacket Toolkit](Impacket%20Toolkit.md) |
| Rubeus | Kerberos abuse from Windows |
| Mimikatz / nanodump | Credential extraction from memory/registry |
| CrackMapExec / NetExec | Sweep many hosts for access, shares, and creds |
| ldapsearch / windapsearch | Raw LDAP queries, works from Linux |

## Quick start (one set of domain creds)

```bash
nxc smb <subnet> -u <user> -p <pass>                          # where am I local admin?
bloodhound-python -u <user> -p <pass> -d <domain> -ns <dc-ip> -c All
GetUserSPNs.py <domain>/<user>:<pass> -dc-ip <dc> -request    # kerberoast in one shot
```

## Recurring concepts

- **SID / RID** — every principal has a SID; RID 500 = built-in admin, 512 = Domain Admins.
- **Kerberos vs NTLM** — Kerberos is ticket-based and default; NTLM is challenge/response and the fallback most attacks still abuse.
- **ACL abuse** — rights like `GenericAll`, `WriteDACL`, `ForceChangePassword` on a principal let you take it over. BloodHound surfaces these paths.
- **Tickets** — TGT proves identity; TGS grants access to a service. Stealing/forging either is the heart of most AD attacks.

## Defensive lens (write this in every report)

For each finding note the detection and fix, not just the exploit: tiered admin model, LAPS for local admin passwords, disable NTLM where possible, gMSA for service accounts, alert on Kerberos anomalies (event IDs 4768/4769/4624), and Protected Users / AES-only where supported.

## Notes in this folder

- [Enumeration](Enumeration.md) — recon of the domain
- [Kerberos Attacks](Kerberos%20Attacks.md) — Kerberoasting, AS-REP roasting, delegation, forged tickets
- [Lateral Movement & Credential Access](Lateral%20Movement%20%26%20Credential%20Access.md) — hashes, tickets, and host-to-host movement
- [Impacket Toolkit](Impacket%20Toolkit.md) — the Impacket scripts for exec, credential access, Kerberos, and relay, with setup + delivery

## References

- SANS SEC560 handouts in [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md)
- The Hacker Recipes (adsecurity techniques), BloodHound docs, HTB Academy AD tracks
