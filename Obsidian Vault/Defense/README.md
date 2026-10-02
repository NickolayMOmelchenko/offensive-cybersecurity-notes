# Defense

Blue team notes: where the evidence lands, how to search it, and how to configure a system so the attack in the [Offense](../Offense/README.md) notes doesn't work in the first place.

**Maturity warning:** these are rougher than the Offense notes. Several are raw study notes, a few are a single screenshot, and one folder is still empty. The tables below mark the stubs so you don't open a note expecting a reference.

## Tree

```text
Defense/
├── README.md                       <- you are here
├── Logging/                        where logs live and how to centralise them
│   ├── Splunk Central.md           Splunk architecture + SPL
│   ├── Host-based/                 Linux & Windows log sources (2 notes)
│   └── Network-based/              placeholder — not written yet
├── SOC2/                           log analysis, formats, anomaly hunting (4 notes)
├── System and Services Hardening/  numbered hardening checklists (4 notes)
└── screenshoots/                   image assets for the notes above
```

## Folders

| Folder | Covers | State |
| --- | --- | --- |
| [Logging](Logging/README.md) | Splunk components and SPL; Linux `auditd`/`journald`; Windows event logs | Splunk note usable, Windows note is a screenshot, Network-based empty |
| [SOC2](SOC2/README.md) | Structured vs unstructured log formats, log file locations, CLI triage one-liners, abnormal-user-behaviour indicators | Short but usable |
| [System and Services Hardening](System%20and%20Services%20Hardening/README.md) | Linux, Windows, Active Directory and network-device hardening, as numbered checklists | The most complete part of Defense |
| [screenshoots](screenshoots/README.md) | Image assets — nothing to read | Folder name is misspelled; see its README |

## How this pairs with Offense

| Attack | Read the defensive side in |
| --- | --- |
| [Kerberoasting / AS-REP](../Offense/AD/Kerberos%20Attacks.md) | [3. Active Directory Hardening](System%20and%20Services%20Hardening/3.%20Active%20Directory%20Hardening.md) |
| [Password spraying](../Offense/Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) | [Abnormal User Behavior](SOC2/Abnormal%20User%20Behavior.md) — failed logins, odd hours, geo anomalies, tool user-agents |
| [Linux privilege escalation](../Offense/Linux/Privilege%20Escalation.md) | [1. Linux Hardening](System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md) + [Host-based/Linux](Logging/Host-based/Linux.md) |
| [Windows privilege escalation](../Offense/Windows/Privilege%20Escalation.md) | [2. Windows Hardening](System%20and%20Services%20Hardening/2.%20Windows%20Hardening.md) |
| [VLAN hopping](../Offense/Networking/VLAN%20Hopping.md) | [4. Network Devices & Services Hardening](System%20and%20Services%20Hardening/4.%20Network%20Devices%20%26%20Services%20Hardening.md) |

## Related

- The red-team half: [Offense](../Offense/README.md)
- Repo conventions: [CLAUDE.md](../../CLAUDE.md)
