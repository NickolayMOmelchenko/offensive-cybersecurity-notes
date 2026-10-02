# Windows

Local work on a Windows host: enumerate, escalate to SYSTEM, and the PowerShell tradecraft that makes it practical. Domain-wide attacks live next door in [AD](../AD/README.md).

Read [Windows Overview](Windows%20Overview.md) first — it indexes the folder and lists the escalation vectors with the check for each.

## Tree

```text
Windows/
├── README.md                   <- you are here
├── Windows Overview.md         index, local enum, vectors, PowerShell tradecraft
├── Privilege Escalation.md     the full escalation reference
└── Powershell.md               stub — one screenshot
```

Image assets for these notes live in [../Screenshots](../Screenshots/README.md).

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [Windows Overview](Windows%20Overview.md) | Folder index, local enumeration commands, the escalation vectors with the one-liner that tests each (`whoami /priv`, unquoted service paths, AlwaysInstallElevated), PowerShell tradecraft, credential access | index |
| [Privilege Escalation](Privilege%20Escalation.md) | Enumeration, token-privilege abuse (SeImpersonate → potato attacks, SeBackup), service misconfigurations, registry and installer escalations, UAC bypass, credential hunting (unattended installs, GPP `cpassword`) | long |
| [Powershell](Powershell.md) | **Stub.** One screenshot: an `-ep Bypass` download cradle hidden in an MP3's metadata, found with exiftool. The real PowerShell material is in the *PowerShell tradecraft* section of [Windows Overview](Windows%20Overview.md) | stub |

## Reading order

1. [Windows Overview](Windows%20Overview.md) — enumerate and pick a vector
2. [Privilege Escalation](Privilege%20Escalation.md) — exploit it

## Related

- Domain attacks from this foothold: [AD](../AD/README.md), especially [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md)
- Getting the shell: [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) (WinRM, SMB, RDP)
- Meterpreter on Windows: [Metasploit](../Tools/Metasploit.md)
- SANS handouts for PowerShell and the Windows CLI: [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md)
- Defensive side: [2. Windows Hardening](../../Defense/System%20and%20Services%20Hardening/2.%20Windows%20Hardening.md), [Host-based logging on Windows](../../Defense/Logging/Host-based/Windows.md)
