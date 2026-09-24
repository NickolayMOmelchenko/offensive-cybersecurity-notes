# Active Directory — Attacks Overview

Index and mental model for the AD notes in this folder. AD is the identity backbone of most enterprises, so a pentest usually becomes an AD pentest. Everything here assumes an **authorized engagement** (scope, rules of engagement, written permission).

## The kill chain (how the notes fit together)

1. **Foothold** — one set of domain credentials or code execution on one domain-joined host. Often from phishing, a weak service, or [[../Networking/Password Attacks & Brute Forcing|password spray]].
2. **[[Enumeration]]** — map users, groups, computers, ACLs, and trust. You attack what you can see; enumeration is 80% of AD work.
3. **Credential access** — pull hashes/tickets from memory, disk, or the directory. See [[Lateral Movement & Credential Access]].
4. **Privilege escalation** — local admin → domain user → privileged group → Domain Admin, usually via misconfigured ACLs, [[Kerberos Attacks|Kerberos]], or delegation.
5. **Lateral movement** — reuse creds/tickets to hop hosts (PsExec, WMI, WinRM). See [[Lateral Movement & Credential Access]].
6. **Domain dominance / persistence** — DCSync, golden/silver tickets, AdminSDHolder. Report these; rarely needed to prove impact.

## Core toolkit (know what each is for)

| Tool | Purpose |
| --- | --- |
| BloodHound / SharpHound | Graph ACL + session data to find attack paths |
| PowerView / ADModule | Ad-hoc PowerShell enumeration |
| Impacket | Python implementations of SMB/Kerberos/DCE-RPC attacks — see [[Impacket Toolkit]] |
| Rubeus | Kerberos abuse from Windows |
| Mimikatz / nanodump | Credential extraction from memory/registry |
| CrackMapExec / NetExec | Sweep many hosts for access, shares, and creds |
| ldapsearch / windapsearch | Raw LDAP queries, works from Linux |

## Recurring concepts

- **SID / RID** — every principal has a SID; RID 500 = built-in admin, 512 = Domain Admins.
- **Kerberos vs NTLM** — Kerberos is ticket-based and default; NTLM is challenge/response and the fallback most attacks still abuse.
- **ACL abuse** — rights like `GenericAll`, `WriteDACL`, `ForceChangePassword` on a principal let you take it over. BloodHound surfaces these paths.
- **Tickets** — TGT proves identity; TGS grants access to a service. Stealing/forging either is the heart of most AD attacks.

## Defensive lens (write this in every report)

For each finding note the detection and fix, not just the exploit: tiered admin model, LAPS for local admin passwords, disable NTLM where possible, gMSA for service accounts, alert on Kerberos anomalies (event IDs 4768/4769/4624), and Protected Users / AES-only where supported.

## Notes in this folder

- [[Enumeration]] — recon of the domain
- [[Kerberos Attacks]] — Kerberoasting, AS-REP roasting, delegation, forged tickets
- [[Lateral Movement & Credential Access]] — hashes, tickets, and host-to-host movement
- [[Impacket Toolkit]] — the Impacket scripts for exec, credential access, Kerberos, and relay, with setup + delivery

## References

- SANS SEC560 handouts in [[../GPEN Cheatsheet/README|GPEN Cheatsheet]]
- The Hacker Recipes (adsecurity techniques), BloodHound docs, HTB Academy AD tracks
