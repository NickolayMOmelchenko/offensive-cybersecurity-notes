# Active Directory — Kerberos Attacks

Kerberos is the default AD auth protocol; most privilege-escalation paths abuse how it issues tickets. Study-note level; see [AD Attacks Overview](AD%20Attacks%20Overview.md) and [Enumeration](Enumeration.md) first.

## Contents

- [How Kerberos works (the 30-second version)](#how-kerberos-works-the-30-second-version)
- [Kerberoasting](#kerberoasting)
- [AS-REP Roasting](#as-rep-roasting)
- [Delegation abuse](#delegation-abuse)
- [Forged tickets (domain dominance — report, don't overuse)](#forged-tickets-domain-dominance--report-dont-overuse)
- [Using tickets (pass-the-ticket)](#using-tickets-pass-the-ticket)
- [Detection summary](#detection-summary)

## How Kerberos works (the 30-second version)

- **AS-REQ/AS-REP:** client proves identity to the KDC, gets a **TGT** (encrypted with the krbtgt hash).
- **TGS-REQ/TGS-REP:** client presents the TGT, gets a **TGS** service ticket for a specific SPN (encrypted with that service account's hash).
- The service decrypts the TGS with its own hash and trusts the contents. Every attack below abuses one of these steps.

## Kerberoasting

- **Idea:** any domain user can request a TGS for any account that has an **SPN**. The TGS is encrypted with the service account's password hash → crack it offline. No special privileges needed.
- **Why it works:** service accounts often have weak, non-expiring passwords. Prefer AES over RC4 when both are offered.

```bash
# From Linux (Impacket): list SPNs, then request the tickets
GetUserSPNs.py <domain>/<user>:<pass> -dc-ip <dc>
GetUserSPNs.py <domain>/<user>:<pass> -dc-ip <dc> -request -outputfile kerb.hashes

# Crack offline (RC4 = mode 13100, AES = 19600/19700)
hashcat -m 13100 kerb.hashes wordlist.txt
```

```powershell
# From Windows
Rubeus.exe kerberoast /outfile:kerb.hashes
```

- **Defense:** gMSA (auto-rotated 120-char passwords), long passwords on service accounts, AES-only, alert on 4769 with RC4 for many SPNs.

## AS-REP Roasting

- **Idea:** accounts with **"Do not require Kerberos pre-authentication"** set will hand out an AS-REP encrypted with the user's hash *without* proving identity → crack offline.

```bash
# Request AS-REP hashes for users without pre-auth (Impacket)
GetNPUsers.py <domain>/ -usersfile users.txt -dc-ip <dc> -no-pass -format hashcat -outputfile asrep.hashes

# Crack offline
hashcat -m 18200 asrep.hashes wordlist.txt
```

- **Defense:** remove the pre-auth exemption, strong passwords, monitor 4768 with pre-auth = 0.

## Delegation abuse

- **Unconstrained delegation:** a host set for it caches the TGTs of anyone who connects. Compromise that host, harvest TGTs (including DA if you can coerce one to authenticate). High impact — flag it.
- **Constrained delegation:** account can request tickets to *specific* services on behalf of users; abuse via S4U to impersonate.
- **Resource-based constrained delegation (RBCD):** if you can write `msDS-AllowedToActOnBehalfOfOtherIdentity` on a computer object (an ACL edge from [Enumeration](Enumeration.md)), you can impersonate any user to it.
- **Defense:** avoid unconstrained delegation, mark sensitive accounts "cannot be delegated" / add to Protected Users, lock down write access to computer objects.

## Forged tickets (domain dominance — report, don't overuse)

- **Golden ticket:** forged **TGT** signed with the **krbtgt** hash → impersonate anyone, including DA, for the ticket's lifetime. Requires you already own the domain (you have krbtgt). Proof of full compromise.
- **Silver ticket:** forged **TGS** signed with a single service account's hash → access just that service, stealthier, no DC contact.
- **Defense:** the only real remediation for golden tickets is rotating the krbtgt password **twice**; treat krbtgt hash exposure as full-domain compromise.

## Using tickets (pass-the-ticket)

```bash
# Linux: request a TGT with creds, then reuse the ccache (Impacket reads KRB5CCNAME)
getTGT.py <domain>/<user>:<pass> -dc-ip <dc>
export KRB5CCNAME=<user>.ccache
psexec.py -k -no-pass <domain>/<target-host>
```

```powershell
# Windows: inject a .kirbi into the current logon session (Rubeus), then confirm
Rubeus.exe ptt /ticket:ticket.kirbi
klist
```

## Detection summary

Watch Kerberos event IDs: **4768** (TGT requested), **4769** (TGS requested — spikes/RC4 = roasting), **4770** (renewed). Anomalous ticket lifetimes, RC4 where AES is expected, and TGS requests for many SPNs from one user are the tells.
