# DNS

The name service — **port 53** (UDP for queries, TCP for zone transfers and big responses). On an engagement DNS is mostly **recon**: it maps a target's hosts, subdomains and infrastructure before you touch anything, and a misconfigured server hands you the entire network in one query.

> Authorized testing only. Passive DNS lookups are low-risk; a zone transfer and brute forcing are active — stay in scope.

## Contents

- [Discover & query](#discover--query)
- [Subdomain enumeration](#subdomain-enumeration)
  - [1. Passive (OSINT) — do this first, zero traffic to the target](#1-passive-osint--do-this-first-zero-traffic-to-the-target)
  - [2. Active brute force](#2-active-brute-force)
  - [3. Permutation / alteration — the step most people skip](#3-permutation--alteration--the-step-most-people-skip)
  - [4. Recursive / iterative](#4-recursive--iterative)
  - [5. Validate & get live hosts](#5-validate--get-live-hosts)
  - [6. Virtual host discovery (different from DNS!)](#6-virtual-host-discovery-different-from-dns)
- [Zone transfer (AXFR) — the big win](#zone-transfer-axfr--the-big-win)
- [NSEC / NSEC3 zone walking (DNSSEC)](#nsec--nsec3-zone-walking-dnssec)
- [Record types worth asking for](#record-types-worth-asking-for)
- [Reverse DNS](#reverse-dns)
- [DNS cache snooping](#dns-cache-snooping)
- [AD & DNS](#ad--dns)
- [DNS as a covert channel](#dns-as-a-covert-channel)
- [Tools](#tools)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Discover & query

`dig` is the tool; `host` and `nslookup` are the preinstalled fallbacks.

```bash
dig target.com                       # default A record
dig target.com ANY                   # everything the server will return (often filtered now)
dig +short target.com                # just the answer, scriptable
dig NS target.com                    # name servers — you need these for a zone transfer
dig MX target.com                    # mail servers
dig TXT target.com                   # SPF/DKIM/verification — leaks services & sometimes hosts
host target.com                      # quick A/AAAA/MX
nslookup target.com                  # interactive fallback (Windows too)
nmap -p53 --script "dns-nsid,dns-recursion" <dns-ip>
```

`dig NS` first — the name servers are both targets themselves and what you aim the zone-transfer attempt at.

**Once you have a shell, find the *internal* resolver** — it usually serves internal-only zones and is itself a high-value host:

```bash
cat /etc/resolv.conf                 # Linux: nameserver + search domain (your internal domain name!)
resolvectl status 2>/dev/null        # systemd-resolved equivalent
ipconfig /all                        # Windows: DNS servers + primary DNS suffix
# then query that internal resolver for internal names:
dig @<internal-dns> target.local ANY
```

The `search` domain in `resolv.conf` often reveals the AD domain name — the starting point for [AD & DNS](#ad--dns) below.

## Subdomain enumeration

When AXFR is refused (the usual case), you assemble the subdomain list from many sources. The mistake is stopping after one brute run — the techniques below each find names the others miss, so run them in order and merge. The flow: **passive → brute → permutate → recurse → validate → vhost**.

### 1. Passive (OSINT) — do this first, zero traffic to the target

Pulls names from certificate transparency, public DNS datasets and search indexes — the target never sees a packet, and it often returns more than brute forcing.

```bash
subfinder -d target.com -all -silent                 # aggregates ~30 sources; -all includes the slow ones
amass enum -passive -d target.com                     # deepest passive aggregation
assetfinder --subs-only target.com                    # quick extra source
# certificate transparency directly:
curl -s "https://crt.sh/?q=%25.target.com&output=json" | jq -r '.[].name_value' | sort -u
# scrape names out of archived URLs too:
gau --subs target.com | unfurl -u domains | sort -u
github-subdomains -d target.com -t <token>            # names leaked in public GitHub code
```

More sources pay off: give **subfinder/amass API keys** (SecurityTrails, Shodan, Censys, VirusTotal, etc.) — they roughly double the yield. See [dorking](../Tools/dorking.md) for crt.sh and CT-log tradecraft.

### 2. Active brute force

Guess names against the resolver. Match the wordlist to the effort — start small, escalate.

```bash
gobuster dns -d target.com -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
dnsrecon -d target.com -D <wordlist> -t brt           # dnsrecon's brute mode
# at scale — puredns/shuffledns drive massdns, wildcard-aware, tens of thousands/sec:
puredns bruteforce best-dns-wordlist.txt target.com -r resolvers.txt
```

Wordlists: `SecLists/Discovery/DNS/` — `subdomains-top1million-5000.txt` (fast first pass) up to `-110000` (thorough), and `n0kovo_subdomains` or `best-dns-wordlist.txt` for big jobs. **Fetch a fresh resolver list** (`-r resolvers.txt`) for massdns/puredns — stale resolvers wreck accuracy.

### 3. Permutation / alteration — the step most people skip

Take the names you already found and generate variations — `dev-`, `dev2-`, `staging.`, `admin.`, `uat-`, region/number swaps — then resolve them. This finds the *sibling* of a real host (`api.target.com` → `api-dev.target.com`) that no wordlist contains.

```bash
# feed KNOWN subdomains in, get permutations out, then resolve them
gotator -sub known.txt -perm permutations.txt -depth 1 -numbers 5 | puredns resolve -r resolvers.txt
dnsgen known.txt | dnsx -silent                       # alternative generator -> fast resolver
# altdns / ripgen do the same with different permutation logic
```

### 4. Recursive / iterative

Subdomains have subdomains. Re-run passive + brute **against each discovered subdomain** (`corp.target.com` → `vpn.corp.target.com`). `subfinder` and `amass` can recurse; or loop your found list back through step 1–2.

```bash
subfinder -d target.com -recursive -silent
```

### 5. Validate & get live hosts

Everything above produces *candidates* — resolve them, drop wildcards, and find which are actually serving:

```bash
# wildcard check FIRST — if *.target.com resolves, every guess "succeeds" and the run is junk
dig +short random$RANDOM-nope.target.com              # returns an IP? -> wildcard; puredns/shuffledns filter it automatically
# resolve candidates to live names, then probe for web:
cat all-candidates.txt | puredns resolve -r resolvers.txt | httpx -silent -title -sc -td
```

`httpx` confirms which resolved names actually answer HTTP(S) and grabs titles/tech — the shortlist you hand to [nmap](../Tools/nmap.md) and [Web Overview](../Web/Web%20Overview.md).

### 6. Virtual host discovery (different from DNS!)

A server can host many sites on one IP, served by the `Host:` header — these have **no DNS record at all**, so subdomain enumeration never finds them. Once you have an IP, fuzz the Host header:

```bash
gobuster vhost -u http://<ip> --append-domain -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
ffuf -u http://<ip>/ -H "Host: FUZZ.target.com" -w <wordlist> -ac    # -ac auto-filters the default-site response
```

Staging/admin interfaces hide here precisely because they're not in DNS — see [gobuster → vhost](../Tools/gobuster.md#vhost--virtual-hosts) and [fuzz](../Tools/fuzz.md).

## Zone transfer (AXFR) — the big win

A zone transfer (AXFR) is meant for secondary name servers to replicate a zone. If a server allows it to **anyone**, it dumps **every record in the domain** — every host, subdomain and internal IP — in one request. Still found in the wild, and an instant map of the target.

```bash
# 1. get the name servers
dig +short NS target.com
# 2. ask EACH of them for the whole zone
dig axfr target.com @ns1.target.com
dig axfr target.com @ns2.target.com
# host does it too:
host -l target.com ns1.target.com
```

A successful AXFR prints the full record list (`Transfer failed` / `connection timed out` = refused, which is the correct config). Try every name server — often only one is misconfigured. Feed every hostname it returns straight into [nmap](../Tools/nmap.md).

## NSEC / NSEC3 zone walking (DNSSEC)

When AXFR is refused but the zone is **DNSSEC-signed**, you can often still enumerate every name — a side effect of how DNSSEC proves a name *doesn't* exist. `NSEC` records chain each name to the next, so you "walk" the whole zone one hop at a time; `NSEC3` hashes the names but they're crackable offline.

```bash
ldns-walk @ns1.target.com target.com        # walk an NSEC-signed zone -> every record
dnsrecon -d target.com -z                    # -z = attempt NSEC/NSEC3 zone walk
nsec3walker target.com                       # collect NSEC3 hashes, then crack them
```

It's the overlooked backup to AXFR: operators lock down zone transfers but forget that NSEC leaks the same data. Check if the zone is signed first: `dig DNSKEY target.com +short` (any output = DNSSEC in play).

## Record types worth asking for

| Type | Tells you |
| --- | --- |
| `A` / `AAAA` | IPv4 / IPv6 of a host |
| `NS` | Authoritative name servers (zone-transfer targets) |
| `MX` | Mail servers — often on-prem, often a foothold |
| `TXT` | SPF/DKIM/DMARC + verification strings — leaks SaaS in use, sometimes IPs |
| `CNAME` | Aliases — reveals CDNs, cloud, dangling records (subdomain takeover) |
| `SOA` | Zone admin email + primary NS |
| `SRV` | Service locations — the AD goldmine (below) |
| `PTR` | IP → name (reverse lookups) |

A `CNAME` pointing at a deprovisioned cloud resource is a **subdomain takeover** — register the dangling target and you own the subdomain.

## Reverse DNS

Map an IP range back to names — often leaks internal naming conventions.

```bash
dig +short -x 10.10.10.40                  # single PTR
for i in $(seq 1 254); do host 10.10.10.$i | grep -v 'not found'; done   # sweep a /24
dnsrecon -r 10.10.10.0/24                  # built-in reverse sweep
```

## DNS cache snooping

Ask a resolver what's **already in its cache** without recursing — if a name is cached, someone on that network recently looked it up. It reveals what internal users and servers talk to (cloud providers, AV vendors, partner sites, internal apps) with zero interaction with those hosts.

```bash
dig @<resolver> target-site.com A +norecurse    # ANSWER present + 'ra' but no 'aa' = it was cached (someone visited)
                                                 # no answer / status NOERROR with 0 answers = not cached
```

Works only against resolvers that allow your queries and don't scrub recursion. Loop it over a list of interesting domains (SaaS, banks, competitors, update servers) to profile the environment.

## AD & DNS

In an Active Directory domain, DNS *is* the service locator — `SRV` records point straight at the domain controllers and services:

```bash
dig SRV _ldap._tcp.dc._msdcs.target.local @<dc-ip>     # find domain controllers
dig SRV _kerberos._tcp.target.local @<dc-ip>           # KDCs
dig SRV _gc._tcp.target.local @<dc-ip>                 # global catalog
nslookup -type=SRV _ldap._tcp.dc._msdcs.target.local   # Windows-native equivalent
```

This is how you find the DC with nothing but domain DNS — then pivot to [AD enumeration](../AD/Enumeration.md).

**ADIDNS — you can often *write* records, not just read them.** AD-integrated DNS lets any authenticated domain user create DNS records by default. That turns DNS into an attack surface:

```bash
# add a record pointing a name at your box (needs any domain creds)
dnstool.py -u 'DOMAIN\user' -p 'pass' -a add -r evil.target.local -d <attacker-ip> <dc-ip>   # krbrelayx
# PowerShell equivalent: Powermad's  Invoke-DNSUpdate / New-ADIDNSNode
nsupdate                                                # generic dynamic-update client (interactive)
```

Why it matters: create a **wildcard** (`*`) record and you answer for every unresolved name in the domain — mass credential interception, the same payoff as LLMNR poisoning but domain-wide. Pairs with **mitm6** (fox-it), which abuses the fact that Windows prefers IPv6: it hands out an attacker as the IPv6 DNS server over DHCPv6, then relays the authentication that follows. Both feed [NTLM relay / credential access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md).

## DNS as a covert channel

DNS almost always egresses even when everything else is filtered, so it's the fallback for C2 and exfiltration — **dnscat2**, **iodine** (full IP-over-DNS tunnel). When only DNS leaves the network, this is your route out; see the filter-bypass table in [general → firewall](../general.md#when-the-firewall-blocks-it--encode--paste) and [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md).

## Tools

| Tool | For |
| --- | --- |
| `dig` / `host` / `nslookup` | Manual queries; preinstalled everywhere (`nslookup` is the Windows default) |
| **dnsrecon** | All-in-one: std records, brute, AXFR, NSEC zone walk (`-z`), reverse |
| **dnsenum** / **fierce** | Brute + AXFR + scraping |
| **gobuster dns** | Fast, clean subdomain brute — [its note](../Tools/gobuster.md#dns--subdomains) |
| **amass** / **subfinder** | Passive subdomain aggregation (many sources) |
| **puredns** / **massdns** / **dnsx** | Mass resolution + wildcard filtering for huge wordlists |
| **ldns-walk** / **nsec3walker** | NSEC / NSEC3 zone walking |
| **dnstool.py** (krbrelayx) / **Powermad** | ADIDNS record create/modify |
| **mitm6** | IPv6 DNS takeover → NTLM relay |
| **dnscat2** / **iodine** | DNS tunnelling (C2 / exfil) |
| crt.sh | Passive subdomains from certificate transparency — see [dorking](../Tools/dorking.md) |

## Defense / detection

- **Restrict zone transfers** to known secondaries only (`allow-transfer`) — an open AXFR hands an attacker the whole network map. This is the one to check first on your own servers.
- **Split-horizon DNS** so internal names aren't served to the internet; don't put internal IPs in public TXT/records.
- Watch for **AXFR requests from non-secondary IPs**, high-volume `NXDOMAIN` (subdomain brute forcing), and long/high-entropy query names (DNS tunnelling/exfil) — see [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md).
- Clean up **dangling CNAMEs** to prevent subdomain takeover. DNSSEC gives integrity but **NSEC can leak the zone** — use NSEC3 (and know even that is crackable).
- **ADIDNS:** don't leave dynamic updates fully open; monitor for new/wildcard records and disable IPv6 (or set DHCPv6 guard) to blunt mitm6.
- Disable **cache snooping** by refusing recursion to untrusted clients (`allow-recursion` to internal only).
- See [4. Network Devices & Services Hardening](../../Defense/System%20and%20Services%20Hardening/4.%20Network%20Devices%20%26%20Services%20Hardening.md).

## Related

[smb](smb.md) · [nfs](nfs.md) · [folder README](README.md) · [nmap](../Tools/nmap.md) · [gobuster](../Tools/gobuster.md) · [dorking](../Tools/dorking.md) (crt.sh, passive recon) · [AD → Enumeration](../AD/Enumeration.md) · [Networking Overview](../Networking/Networking%20Overview.md)
