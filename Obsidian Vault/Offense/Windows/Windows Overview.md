# Windows — Offensive Notes Overview

Index for Windows host offense: local enumeration, privilege escalation, and the PowerShell tradecraft used throughout. Domain-wide attacks live in [[../AD/AD Attacks Overview|Active Directory]].

## Notes in this folder

- [[Powershell]] — download-cradle / execution-policy bypass concept

## Local enumeration

```powershell
whoami /all              # user, groups, privileges (look for SeImpersonate, SeBackup, etc.)
systeminfo               # OS build + hotfixes -> missing patches
ipconfig /all; netstat -ano
```

- Automate with **winPEAS** or **PowerUp** (`Invoke-AllChecks`).
- Key privileges to spot: **SeImpersonatePrivilege** (potato attacks), **SeBackupPrivilege** (read any file, incl. SAM/NTDS), **SeDebugPrivilege**.

## Privilege escalation vectors

```powershell
# Check your privileges (SeImpersonate -> potato attacks; SeBackup -> read SAM/NTDS)
whoami /priv

# Unquoted service paths (auto-start services whose path has a space and no quotes)
wmic service get name,displayname,pathname,startmode | findstr /i "auto" | findstr /i /v "c:\windows"

# AlwaysInstallElevated (both must return 0x1 to be exploitable)
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

- **Unquoted service paths** — space in a path + writable dir = plant a binary Windows runs as SYSTEM.
- **Weak service permissions** — reconfigure a service `binPath` you can modify (`sc config`).
- **AlwaysInstallElevated** — if both registry keys are set, any `.msi` runs as SYSTEM.
- **Token impersonation** — with SeImpersonate, the "potato" family (RoguePotato/PrintSpoofer) escalates to SYSTEM.
- **Registry / autoruns** — writable Run keys or startup binaries for persistence and escalation.
- **DLL hijacking** — a program loading a missing DLL from a writable path.

Automate the checks, but confirm each finding manually before exploiting on a client box.

## PowerShell tradecraft

- **Execution policy is not a security boundary** — it's trivially bypassed (`-ep bypass`, download cradles). See [[Powershell]].
- **Download cradle concept:** pull a script from your server into memory and run it, avoiding disk. This is why defenders rely on AMSI, Constrained Language Mode, and script-block logging rather than execution policy.
- **Living off the land (LOLBins):** `certutil`, `bitsadmin`, `mshta`, `rundll32` — legit binaries with dual use; know them for both offense and detection.

## Credential access on Windows

Covered in depth under AD since the techniques overlap: see [[../AD/Lateral Movement & Credential Access]] for LSASS, SAM, DPAPI, and pass-the-hash.

For the network route — dumping hashes and getting a SYSTEM shell remotely with local-admin creds/hashes (`secretsdump.py`, `psexec.py`, `wmiexec.py`) — see [[../AD/Impacket Toolkit]].

## Defense / detection (for the report)

Enable **AMSI**, **Constrained Language Mode**, **script-block + module logging** (4104), and **Attack Surface Reduction** rules; apply LAPS; remove local admin; monitor service creation (7045), suspicious parent/child process trees (Office → PowerShell), and LOLBin misuse.
