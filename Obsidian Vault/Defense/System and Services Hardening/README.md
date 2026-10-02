# System and Services Hardening

Configuration-level defense: the settings that make the attacks in [Offense](../../Offense/README.md) fail outright. Four numbered checklists, read in order — host, then OS, then directory, then network.

This is the most complete part of [Defense](../README.md).

## Tree

```text
System and Services Hardening/
├── README.md                                   <- you are here
├── 1. Linux Hardening.md                       boot, disk, SSH, accounts, firewall
├── 2. Windows Hardening.md                     registry, SMB, DNS, ARP, Office
├── 3. Active Directory Hardening.md            LM hash, SMB signing, LDAP signing
└── 4. Network Devices & Services Hardening.md  VPN, routers and switches
```

## Notes

| Note | What it covers | Blocks |
| --- | --- | --- |
| [1. Linux Hardening](1.%20Linux%20Hardening.md) | GRUB/UEFI boot passwords (`grub2-mkpasswd-pbkdf2`), full LUKS disk encryption step by step, `ufw`/`iptables`/`nftables`, SSH hardening (no root login, key-only auth, the `sshd_config` lines and the lock-yourself-out warning), sudoers and disabling the `root` shell, password policy | [Linux privilege escalation](../../Offense/Linux/Privilege%20Escalation.md) |
| [2. Windows Hardening](2.%20Windows%20Hardening.md) | Locking down `regedit`, disabling SMB, protecting the local `hosts` file, clearing the ARP cache against ARP spoofing, safe app installation, Office hardening (macros off, Attack Surface Reduction rules) | [Windows privilege escalation](../../Offense/Windows/Privilege%20Escalation.md) |
| [3. Active Directory Hardening](3.%20Active%20Directory%20Hardening.md) | Three Group Policy changes with the full click-path for each: stop storing the **LM hash**, require **SMB signing**, require **LDAP signing** — with the reasoning (MiTM, relay, replay) for each | [NTLM relay](../../Offense/AD/Enumeration.md), [credential access](../../Offense/AD/Lateral%20Movement%20%26%20Credential%20Access.md) |
| [4. Network Devices & Services Hardening](4.%20Network%20Devices%20%26%20Services%20Hardening.md) | OpenVPN done properly (AES-256-CBC, SHA-256/512, Perfect Forward Secrecy via `tls-crypt`, a dedicated service user), then switch port security, ARP spoofing and rogue-DHCP prevention, and IPv6's built-in IPsec | [VLAN hopping](../../Offense/Networking/VLAN%20Hopping.md), LAN attacks |

## Why "SMB signing" keeps coming up

Note 3 is short but it is the highest-value page in Defense: *SMB signing off* is exactly what [AD Enumeration](../../Offense/AD/Enumeration.md) looks for (`signing:False` marks a relay target), and *LM hash stored* is what makes a cracked hash trivial. Two Group Policy settings remove both.

## Related

- Detecting what gets through anyway: [Logging](../Logging/README.md), [SOC2](../SOC2/README.md)
- The attacks these checklists answer: [Offense](../../Offense/README.md)
