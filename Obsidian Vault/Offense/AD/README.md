# AD — Active Directory

The attack chain against an Active Directory domain, from a single set of credentials to Domain Admin. This is the biggest folder in the vault because most internal pentests become AD pentests.

Read [AD Attacks Overview](AD%20Attacks%20Overview.md) first — it holds the kill chain and the tooling table. This README is just the map.

## Tree

```text
AD/
├── README.md                               <- you are here
├── AD Attacks Overview.md                  index, kill chain, core toolkit
├── Enumeration.md                          map the domain before you touch it
├── Impacket Toolkit.md                     the Impacket scripts, script by script
├── Kerberos Attacks.md                     roasting, delegation, forged tickets
├── Privilege Escalation.md                 ACL abuse, shadow creds, GPO abuse
├── Lateral Movement & Credential Access.md dump secrets, reuse them, hop hosts
└── Attacking the Domain Controller.md      the whole chain as one walkthrough
```

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [AD Attacks Overview](AD%20Attacks%20Overview.md) | The six-stage kill chain, what each tool is for, a quick start from one set of domain creds, recurring concepts, the defensive lens for the report | index |
| [Enumeration](Enumeration.md) | Unauthenticated (DNS SRV, SMB null session, RID cycling) then authenticated (LDAP dump, BloodHound collection, SMB signing, share hunting) | medium |
| [Impacket Toolkit](Impacket%20Toolkit.md) | `Example.py` vs `impacket-example` naming, the `domain/user:pass@target` spec, NTLM vs Kerberos auth, install, and what each script is for | long |
| [Kerberos Attacks](Kerberos%20Attacks.md) | Kerberos in 30 seconds, Kerberoasting, AS-REP roasting, hashcat modes, delegation abuse, golden/silver tickets | medium |
| [Privilege Escalation](Privilege%20Escalation.md) | Picking a path from BloodHound edges: ForceChangePassword, WriteDACL→DCSync, AddMember, shadow credentials, privileged groups, GPO abuse | long |
| [Lateral Movement & Credential Access](Lateral%20Movement%20%26%20Credential%20Access.md) | Where secrets live, SAM/LSA dumping, DCSync, the two reuse primitives (pass-the-hash / pass-the-ticket), PsExec/WMI/WinRM | medium |
| [Attacking the Domain Controller](Attacking%20the%20Domain%20Controller.md) | Everything above in order, as a numbered end-to-end run with both Impacket and Metasploit commands at each step | longest |

## Reading order

1. [AD Attacks Overview](AD%20Attacks%20Overview.md) — the mental model
2. [Enumeration](Enumeration.md) — you attack what you can see; this is 80% of the work
3. [Kerberos Attacks](Kerberos%20Attacks.md) → [Privilege Escalation](Privilege%20Escalation.md) → [Lateral Movement & Credential Access](Lateral%20Movement%20%26%20Credential%20Access.md)
4. [Attacking the Domain Controller](Attacking%20the%20Domain%20Controller.md) — to see it joined up

[Impacket Toolkit](Impacket%20Toolkit.md) is a lookup, not a read-through — the other notes link into it.

## Related

- Get the first credential: [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md)
- Metasploit equivalents: [Metasploit](../Tools/Metasploit.md)
- From the Windows foothold: [Windows Overview](../Windows/Windows%20Overview.md)
- Defensive side: [3. Active Directory Hardening](../../Defense/System%20and%20Services%20Hardening/3.%20Active%20Directory%20Hardening.md)
