# Active Directory — Lateral Movement & Credential Access

Once you have credentials or admin on one host, credential access harvests more secrets and lateral movement reuses them to reach new hosts. See [[AD Attacks Overview]].

## Credential access (where secrets live)

- **LSASS memory** — cached logons, tickets, plaintext in some configs. Dumped by Mimikatz `sekurlsa::logonpasswords`, comsvcs.dll minidump, or nanodump. Requires local admin/SeDebug.
- **SAM + SYSTEM (local accounts)** — `reg save` the hives or `secretsdump.py -sam ...`; gives local account NT hashes (useful for password reuse across hosts).
- **DPAPI** — decrypts saved browser/RDP/Wi-Fi creds with the user's master key.
- **NTDS.dit (the whole directory)** — on a DC, every domain hash. Pull via `secretsdump.py`, ntdsutil `IFM`, or VSS snapshot. This is domain compromise — report it.
- **DCSync** — ask a DC to replicate an account's hash using `Replicating Directory Changes` rights; no code on the DC needed.

```bash
# Dump local SAM + LSA secrets from a host
secretsdump.py <domain>/<user>:<pass>@<target>

# DCSync a single account (e.g. krbtgt) from a DC
secretsdump.py <domain>/<user>:<pass>@<dc> -just-dc-user krbtgt
```

## The two reuse primitives

- **Pass-the-Hash (PtH):** NTLM auth only needs the hash, not the plaintext. Authenticate as the user with their NT hash.
- **Pass-the-Ticket (PtT):** inject a stolen/forged Kerberos TGT or TGS into your session and use it. See [[Kerberos Attacks]].

Both mean cracking is optional — a dumped hash or ticket is often enough to move.

## Lateral movement techniques (need admin on the target)

| Technique | Tooling | Notes |
| --- | --- | --- |
| SMB / service exec | `psexec.py`, `smbexec.py` | Classic, noisy, creates a service |
| WMI | `wmiexec.py`, `Invoke-WmiMethod` | Fileless-ish, no service |
| WinRM | `evil-winrm`, `Enter-PSSession` | Clean if 5985/5986 open |
| DCOM / scheduled tasks | `atexec.py` | Fallbacks when others are blocked |
| RDP | `xfreerdp`, restricted admin mode | Interactive; PtH works with restricted admin |

```bash
# Sweep a subnet with a password or an NT hash (pass-the-hash)
nxc smb <subnet> -u <user> -p <pass>
nxc smb <subnet> -u <user> -H <nt-hash>

# Get a shell on a host you are admin on (use -hashes for PtH)
psexec.py <domain>/<user>@<target>          # or -hashes :<nt-hash>
wmiexec.py <domain>/<user>@<target>         # quieter, no service
evil-winrm -i <target> -u <user> -p <pass>  # if WinRM (5985) is open
```

- **Overpass-the-hash:** turn an NT hash into a real Kerberos TGT (Rubeus `asktgt`) to move via Kerberos instead of NTLM.

## Method (keep it disciplined on an engagement)

1. Dump creds on current host → note hashes/tickets.
2. Check reuse breadth with a NetExec sweep.
3. Move to the highest-value reachable host that gets you closer to the goal in BloodHound.
4. Repeat; document each hop, timestamp, and technique for the report.

## Defense / detection

- **LAPS** kills local-admin password reuse (breaks most sweeps).
- **Credential Guard / Protected Users / disabling WDigest** reduce what LSASS leaks.
- **Tiered admin model** stops DA creds landing on workstations.
- Detect: 4624 type 3/9 logons, service creation (7045), `secretsdump`/DCSync replication from non-DC accounts (4662 with replication GUIDs), and PtH patterns (NTLM logons for accounts that normally use Kerberos).
