# Networking

The network phase: find what's there, get a credential, turn it into a shell, then turn that host into a route to everything behind it.

Read [Networking Overview](Networking%20Overview.md) first for the scanning commands and a summary of the rest.

## Tree

```text
Networking/
├── README.md                           <- you are here
├── Networking Overview.md              index, scanning, LAN attacks, pivot summary
├── Password Attacks & Brute Forcing.md spraying, wordlists, lockout policy
├── Remote Access & Getting a Shell.md  service -> tool -> shell
├── Pivoting & Tunneling.md             SSH tunnels, SOCKS, chisel, sshuttle
└── VLAN Hopping.md                     switch spoofing & double tagging (short)
```

Image assets for these notes live in [../Screenshots](../Screenshots/README.md), not in this folder.

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [Networking Overview](Networking%20Overview.md) | Folder index, host discovery and Nmap scan recipes, common LAN attacks (LLMNR/NBT-NS poisoning → NetNTLMv2), and a pivoting summary | index |
| [Password Attacks & Brute Forcing](Password%20Attacks%20%26%20Brute%20Forcing.md) | Picking the right attack type, enumerating **before** you brute (incl. reading the password policy so you don't lock accounts out), wordlists and rule-based mutation, per-service spraying | medium |
| [Remote Access & Getting a Shell](Remote%20Access%20%26%20Getting%20a%20Shell.md) | IP vs FQDN (it matters for Kerberos), a service→tool quick reference, then SSH, Telnet, SMB, WinRM, RDP, and credential sweeping across a subnet | long |
| [Pivoting & Tunneling](Pivoting%20%26%20Tunneling.md) | Choosing a technique, enumerating the pivot host, SSH local/dynamic/reverse forwards, `sshuttle`, proxychains, chisel, and Metasploit routing | long |
| [VLAN Hopping](VLAN%20Hopping.md) | Switch spoofing via DTP (Yersinia) and 802.1Q double tagging (Scapy), with the defensive config | short |

## Reading order

1. [Networking Overview](Networking%20Overview.md) — scan and map
2. [Password Attacks & Brute Forcing](Password%20Attacks%20%26%20Brute%20Forcing.md) — get a credential
3. [Remote Access & Getting a Shell](Remote%20Access%20%26%20Getting%20a%20Shell.md) — turn it into access
4. [Pivoting & Tunneling](Pivoting%20%26%20Tunneling.md) — reach the next subnet

## Related

- Once you're on the box: [Linux](../Linux/README.md) / [Windows](../Windows/README.md)
- Once you have domain creds: [AD](../AD/README.md)
- Metasploit's versions of all of this: [Metasploit](../Tools/Metasploit.md)
- SANS pivoting handout: [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md)
- Defensive side: [4. Network Devices & Services Hardening](../../Defense/System%20and%20Services%20Hardening/4.%20Network%20Devices%20%26%20Services%20Hardening.md)
