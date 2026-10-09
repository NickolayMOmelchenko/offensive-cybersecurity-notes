# nmap

Port scanner, service fingerprinter and — via NSE — a vulnerability scanner. First tool on almost every engagement, and the one whose flags are most often cargo-culted.

Everything below verified against **nmap 7.95**. Flag text is quoted from `nmap --help`.

> Raw-socket scans (`-sS`, `-sU`, `-O`, and anything crafting packets) need root. Without it nmap silently falls back to `-sT`. Prefix with `sudo` or you are not running the scan you think you are.

## Contents

- [Run everything safe — one command per box](#run-everything-safe--one-command-per-box)
- [Visualize the results — XML → HTML](#visualize-the-results--xml--html)
- [The main scan types](#the-main-scan-types)
- [Pick the scan for the situation](#pick-the-scan-for-the-situation)
- [Getting through a firewall — top 4](#getting-through-a-firewall--top-4)
- [What the shorthand flags actually expand to](#what-the-shorthand-flags-actually-expand-to)
- [Flag reference](#flag-reference)
- [Recipes](#recipes)
- [NSE: categories and finding a script](#nse-categories-and-finding-a-script)
- [Blue team note](#blue-team-note)
- [Related](#related)
- [Appendix — all 609 NSE scripts (nmap 7.95)](#appendix--all-609-nse-scripts-nmap-795)

## Run everything safe — one command per box

Copy-paste, swap the IP, let it run. Each is a **single pass** that throws every non-destructive flag and script at the host: all 65535 TCP ports, the UDP ports that actually matter for that OS, version + OS detection, and every NSE script that is **safe** — nothing in `intrusive`, `dos`, `brute`, `exploit`, `fuzzer`, `broadcast` or `external`, so nothing crashes a service, locks an account, changes state, or phones a third party. Authorized targets only.

### Windows box

```bash
sudo nmap -Pn -sS -sU -sV -O --version-all --osscan-guess \
  -p T:1-65535,U:53,88,123,135,137,138,161,389,445,500,1434,1900,4500,5353,5355 \
  --script "(default or discovery or safe or vuln) and not (intrusive or dos or brute or exploit or fuzzer or broadcast or external)" \
  -T4 --min-rate 1000 --open --reason -oA scans/win-full 10.10.10.40
```

### Linux box

```bash
sudo nmap -Pn -sS -sU -sV -O --version-all --osscan-guess \
  -p T:1-65535,U:53,67,69,111,123,161,500,514,520,2049,5353 \
  --script "(default or discovery or safe or vuln) and not (intrusive or dos or brute or exploit or fuzzer or broadcast or external)" \
  -T4 --min-rate 1000 --open --reason -oA scans/linux-full 10.10.10.40
```

The two differ only in the **UDP port list** — the TCP sweep is all ports on both, so the service lands wherever it's hiding. Windows adds the SMB/NetBIOS/LDAP/Kerberos/MSRPC/mDNS-LLMNR set (137/138/389/88/135/5353/5355); Linux adds rpcbind/NFS/TFTP/syslog/RIP (111/2049/69/514/520). Run the other list too if you're not sure what you're looking at — the extra ports just come back closed.

**Why these flags** — `-Pn` so a host that blocks ping isn't written off as down (the [most common cause of an empty scan](#getting-through-a-firewall--top-4)); `-sS -sU` cover TCP and UDP in one pass, with UDP capped at the ports each OS actually serves (never `-sU -p-` — see [The main scan types](#the-main-scan-types)); `-sV --version-all` and `-O --osscan-guess` identify every service and the OS; the script filter runs the whole safe/default/discovery/vuln set while the `not (...)` clause strips anything that could take the box down or alter it. `--open --reason` keep the output to what answered and why; `-oA` writes all three formats.

**It is slow** — a full TCP + UDP pass with OS/version detection and scripts can take a long while per host; that's the cost of one-command completeness. For a fast loop, split it — a quick `-p-` sweep, then `-sCV` on just the open ports — see [Recipes](#recipes). Drop `--version-all` first if you want most of the speed back.

**It is not quiet** — this is the opposite of a stealth scan. When detection is a concern, see [Pick the scan for the situation](#pick-the-scan-for-the-situation).

**To go further, separately and in scope** — the risky checks are left out on purpose. Once you know they're allowed, run them on their own: `brute` scripts (lockout risk), `vuln` without the `safe` filter, or `exploit` scripts. See [NSE: categories and finding a script](#nse-categories-and-finding-a-script).

## Visualize the results — XML → HTML

Scan to **XML** (`-oX`, or `-oA` which writes it alongside the others), then turn it into a readable HTML report with **`xsltproc`** and nmap's built-in stylesheet. Far easier to skim — and to paste into a report — than raw terminal output.

```bash
# scan to XML
nmap -sCV -oX scan.xml 10.10.10.40
#   or -oA scans/host  -> writes scan.xml + .nmap + .gnmap in one go

# convert XML -> HTML (nmap's XML already references its nmap.xsl stylesheet)
xsltproc scan.xml -o scan.html
xdg-open scan.html          # macOS: open scan.html — a clean, sortable report in the browser
```

Two gotchas:

- **Moving the XML to another box** (e.g. your reporting machine) breaks the stylesheet reference — it points at a local `nmap.xsl`. Bake a portable copy in at scan time with `--webxml` (references the stylesheet from nmap.org over HTTPS):

  ```bash
  nmap -sCV --webxml -oX scan.xml 10.10.10.40
  xsltproc scan.xml -o scan.html
  ```

- No `xsltproc`? It's in the `xsltproc` / `libxslt` package (`sudo apt install xsltproc`). For many hosts at once, `nmap-bootstrap-xsl` gives a prettier multi-host template, and tools like **nmap-parse-output** or importing the XML into Metasploit (`db_import scan.xml`) are alternatives — see [Recipes](#recipes) and [Metasploit](Metasploit.md).

## The main scan types

### 1. SYN scan — `-sS` (the default workhorse)

Half-open: sends SYN, reads the reply, never completes the handshake.

```bash
sudo nmap -sS -p- --min-rate 1000 -oA scans/syn 10.10.10.40
```

Fast, works everywhere, and the default when you have root — so `sudo nmap <target>` is already a SYN scan.

### 2. TCP connect — `-sT`

Completes the full three-way handshake using the OS socket API.

```bash
nmap -sT -p 1-1000 10.10.10.40
proxychains nmap -sT -Pn -n -p 445,3389 10.10.10.40    # the only kind that works through a SOCKS proxy
```

Use when you don't have root, or when [pivoting](../Networking/Pivoting%20%26%20Tunneling.md) through proxychains — `-sS` can't work through a proxy because there's no raw socket. Noisier: it completes connections, so it lands in application logs.

### 3. UDP scan — `-sU` (the one everyone skips)

```bash
sudo nmap -sU --top-ports 100 --reason -oA scans/udp 10.10.10.40
sudo nmap -sU -sV -p 53,69,123,161,500 10.10.10.40     # targeted, with version probes
```

Slow by design — closed UDP ports are reported via ICMP unreachable, which hosts rate-limit. **Never run `-sU -p-`** on a real engagement; use `--top-ports 100`. This is where SNMP (161), TFTP (69), IKE (500) and DNS (53) hide, and it's routinely the only path in.

### 4. Ping sweep / host discovery — `-sn`

```bash
sudo nmap -sn 10.10.10.0/24 -oA scans/sweep              # what's alive, no port scan
# the best single-host check — ICMP echo only, and SHOW the packets so you can see the reply:
sudo nmap -sn -PE --packet-trace 10.10.10.40             # confirm one host is up and watch the probe/reply
sudo nmap -sn -PE -PS22,80,443 -PA3389 10.10.10.0/24     # custom probes when ICMP is filtered
nmap -sL 10.10.10.0/24                                    # list targets only — sends nothing
```

Do this first to narrow a /24 to the ten live hosts. `-sL` is the scope sanity check: it resolves and lists what you *would* scan without sending a packet.

The three flags together — `-sn -PE --packet-trace` — are the clearest way to prove a single host is (or isn't) up:

| Flag | Does |
| --- | --- |
| `-sn` | Host discovery only — **no port scan** |
| `-PE` | Use an **ICMP echo request** (a plain ping) as the probe — the most reliable single check when ICMP isn't filtered |
| `--packet-trace` | Print every packet **sent and received** — you literally watch the echo request go out and the reply come back |

```text
SENT (0.0030s) ICMP ... echo request ...
RCVD (0.0051s) ICMP ... echo reply ...     <- host is up
```

`--packet-trace` is the teaching/diagnostic flag: when a host "should" be up but nmap says down, it shows you whether your probe left and whether anything answered — i.e. whether you're being firewalled (`-sn -PE` with no `RCVD` line) versus the host genuinely being offline. Drop `--packet-trace` for normal sweeps; it's noisy on a whole subnet.

### 5. Version + default scripts — `-sV -sC`

Turns "port 445 open" into "Windows Server 2016, SMB signing disabled".

```bash
sudo nmap -sV -sC -p 22,80,139,445,3389 -oA scans/enum 10.10.10.40
sudo nmap -sCV -A -p- -oA scans/full 10.10.10.40          # -sCV is accepted shorthand
```

The standard two-stage approach: a fast `-p-` SYN sweep to find open ports, then `-sV -sC` against only those ports.

### 6. Targeted NSE script — one question, one answer

```bash
nmap --script smb-os-discovery.nse -p445 10.10.10.40
```

> **Is there a better command that already includes this?** Yes — `smb-os-discovery` is in categories `{"default", "discovery", "safe"}`, so **`-sC` and `-A` already run it** against port 445. `sudo nmap -sC -p445 10.10.10.40` gets you the same output plus `smb-security-mode`, `smb2-security-mode` and `smb2-time`, which is strictly more useful on a Windows host.
>
> The targeted form is still worth keeping for two reasons: it runs **1 script instead of the 116** in the `default` category, so it's much faster and much quieter; and it's how you run a *non-default* script, which is most of them — `--script smb-vuln-ms17-010` will never fire from `-sC`.

| Goal | Command |
| --- | --- |
| One script, fast and quiet | `nmap --script smb-os-discovery -p445 10.10.10.40` |
| Everything default on SMB (includes the above) | `sudo nmap -sC -p445 10.10.10.40` |
| All SMB scripts | `sudo nmap --script "smb*" -p445 10.10.10.40` |
| SMB vuln checks only (not in `default`) | `sudo nmap --script "smb-vuln*" -p445 10.10.10.40` |
| Safe SMB scripts, skip the intrusive ones | `sudo nmap --script "smb* and safe" -p445 10.10.10.40` |

The `.nse` extension is optional — `--script smb-os-discovery` works identically.

### The other scan types

| Flag | Scan | When |
| --- | --- | --- |
| `-sA` | ACK | Map firewall rules — tells you filtered vs unfiltered, not open |
| `-sW` | Window | Like ACK but some stacks leak open/closed |
| `-sN` / `-sF` / `-sX` | Null / FIN / Xmas | Evade stateless filters; useless against Windows |
| `-sM` | Maimon | FIN/ACK — works on some BSD stacks |
| `-sI <zombie>` | Idle | Scan via a third host; your IP never touches the target |
| `-sY` / `-sZ` | SCTP INIT / COOKIE-ECHO | Telecom and SIGTRAN networks |
| `-sO` | IP protocol | Which IP protocols a host answers, not ports |
| `-b <relay>` | FTP bounce | Legacy, almost always patched |

## Pick the scan for the situation

Start from the goal, not the flags. The three you'll reach for most:

### Thorough — "scan everything, don't let the host skip the queue"

When you want full coverage and don't care about noise — a lab, HTB, or an authorized loud internal test:

```bash
sudo nmap -Pn -p- -sCV -T4 -oA scans/thorough 10.10.10.40
```

- **`-Pn`** — treat the host as **up, skip host discovery**. This is the important one. By default nmap pings first and, if there's no reply, **reports the host down and scans nothing** — and plenty of hosts (hardened Windows, anything blocking ICMP) don't answer pings while their ports are wide open. `-Pn` says "I know it's there, just scan it," so you don't miss a live host that simply refused the ping. The cost: against a genuinely dead IP, `-Pn` scans all 65535 ports anyway and is slow.
- **`-p-`** — all 65535 ports, not just the top 1000. The interesting service is often on a high port.
- **`-sCV`** — default scripts + version detection on whatever's open.
- **`-T4`** — faster timing; fine on a LAN or lab, ease off on fragile targets.

Rule of thumb: **if nmap says "host seems down" but you were told it's up, add `-Pn`.** It's the single most common fix for an empty scan.

### Stealthy — "make less noise, stay under the radar"

When detection is a concern and evading it is in scope:

```bash
sudo nmap -sS -T2 -f --scan-delay 1s -Pn 10.10.10.40
sudo nmap -sS -T1 --max-retries 1 -p 1-1000 10.10.10.40        # slower, fewer packets
```

- **`sudo -sS`** — the **SYN / half-open** scan. It sends SYN, reads the reply, and sends RST instead of completing the handshake, so the connection is **never fully established and often isn't logged** by the application. It needs **root** (raw sockets) — that's why `sudo`. Without root nmap silently falls back to `-sT` (full connect), which *does* get logged, so for a quiet scan `sudo` is mandatory.
- **`-T2` / `-T1`** — "polite" / "sneaky" timing: slower, fewer parallel probes, far less likely to trip rate-based IDS than the default `-T3` or a loud `-T4`.
- **`--scan-delay 1s`** — space probes out to defeat threshold-based detection.
- **`-f`** — fragment packets so simple signature inspection can't reassemble the probe.
- Go further with `-D RND:5` (decoys), `-g 53` (source from a trusted port), `--spoof-mac` — see [Firewall / IDS evasion](#firewall--ids-evasion). Real stealth is slow: a `-T1` full scan can take hours, so scope the ports.

> `-sS` is "stealthy" only relative to `-sT` — a modern IDS/EDR still sees a SYN scan. Treat it as "won't land in the app's own logs," not "invisible."

### Fast — "give me the open ports now"

When you just need to move:

```bash
sudo nmap -sS -p- --min-rate 5000 -n -Pn -oA scans/fast 10.10.10.40
```

`--min-rate 5000` pushes packets hard, `-n` skips DNS, `-Pn` skips discovery. Loud and quick — the opposite of the stealth profile above. Then enumerate only the open ports (see [Recipes](#recipes)).

| Goal | Command | Key flags |
| --- | --- | --- |
| **Thorough** | `sudo nmap -Pn -p- -sCV -T4` | `-Pn` (don't skip "down" hosts), `-p-`, `-sCV` |
| **Stealthy** | `sudo nmap -sS -T2 -f --scan-delay 1s` | `sudo -sS` (half-open, needs root), slow timing |
| **Fast** | `sudo nmap -sS -p- --min-rate 5000 -n -Pn` | `--min-rate`, `-n`, `-Pn` |
| **Gentle on a fragile host** | `sudo nmap -sS -T2 --max-retries 1 -p 1-1000` | low timing, capped retries |

## Getting through a firewall — top 4

When a firewall is dropping or filtering your probes, these are the four to reach for, in order. Only on engagements where evading controls is in scope. Full flag list in [Firewall / IDS evasion](#firewall--ids-evasion).

```bash
# 1. -Pn — the host blocks pings so nmap calls it "down" and skips it. Scan anyway.
#    THE most common fix for an empty scan behind a firewall.
sudo nmap -Pn -sS 10.10.10.40

# 2. --source-port (-g) — firewalls often trust replies from DNS/Kerberos/HTTPS.
#    Source from 53 (or 88 / 443) and the filter may wave you through.
sudo nmap -sS --source-port 53 10.10.10.40

# 3. -f — fragment the probes into tiny packets so simple stateless inspection
#    can't reassemble and match them. --mtu <multiple of 8> for larger fragments.
sudo nmap -sS -f 10.10.10.40

# 4. -D — decoys: spray the scan from fake source IPs alongside yours (ME) so the
#    firewall/IDS logs can't tell which is real. RND:10 = 10 random decoys.
sudo nmap -sS -D RND:10 10.10.10.40
```

Before any of them, confirm it *is* a firewall: `--reason` shows `filtered`/`no-response`, and an **ACK scan maps the ruleset** — `sudo nmap -sA 10.10.10.40` tells you filtered vs unfiltered (not open/closed). Stack them when needed: `sudo nmap -Pn -f -g 53 -D RND:5 -T2 10.10.10.40`.

## What the shorthand flags actually expand to

The part that trips people up most:

| Shorthand | Equivalent to | Watch out |
| --- | --- | --- |
| **`-A`** | **`-O -sV -sC --traceroute`** | **Yes — `-A` includes `-sC`.** Help text: *"Enable OS detection, version detection, script scanning, and traceroute"* |
| `-sC` | `--script=default` | Runs the **116** scripts in the `default` category, out of 609 installed |
| no `-s` flag at all | `-sS` as root, `-sT` unprivileged | So `sudo nmap host` ≠ `nmap host` |
| `-F` | "Fast mode" — top 100 ports | The plain default is top **1000**, not all 65535 |
| `-p-` | `-p 1-65535` | |
| `-T0`…`-T5` | paranoid, sneaky, polite, normal *(default)*, aggressive, insane | |
| `-sCV` | `-sC -sV` | Combined `-s` letters parse fine |

> **`-A` does not scan all ports.** It still only covers the top 1000 unless you add `-p-`, and it doesn't change timing. `nmap -A host` is a common false sense of thoroughness — it's deep on few ports, not wide.
>
> `-A` is also loud: OS detection and 116 scripts against every open port. On a stealth-sensitive engagement, pick your scripts instead.

## Flag reference

### Targets and scope

| Flag | Does |
| --- | --- |
| `-iL <file>` | "Input from list of hosts/networks" — one per line |
| `--exclude <hosts>` | "Exclude hosts/networks" — **use this to enforce scope** |
| `--excludefile <file>` | Exclusions from a file |
| `-sL` | "List Scan - simply list targets to scan" — sends no packets |
| `-6` | IPv6 |
| `-e <iface>` | Use a specific interface (pick your VPN tunnel, not your home NIC) |
| `--iflist` | Print interfaces and routes |

### Host discovery

| Flag | Does |
| --- | --- |
| `-sn` | "Ping Scan - disable port scan" |
| `-Pn` | "Treat all hosts as online — skip host discovery" — essential when ICMP is blocked |
| `-PS/-PA/-PU/-PY[ports]` | TCP SYN / TCP ACK / UDP / SCTP discovery probes |
| `-PE/-PP/-PM` | ICMP echo / timestamp / netmask probes |
| `-PO[protos]` | IP protocol ping |
| `-n` / `-R` | Never / always resolve DNS (`-n` is a big speedup) |
| `--dns-servers <s>` | Custom resolvers — point at the target's own DNS for internal names |
| `--traceroute` | Trace the hop path |

### Ports

| Flag | Does |
| --- | --- |
| `-p 22,80,443` | Specific ports |
| `-p 1-1000` / `-p-` | Range / all 65535 |
| `-p U:53,T:80` | Mix protocols |
| `--top-ports <n>` | The n most common ports |
| `--exclude-ports <r>` | Skip these (fragile services, printers) |
| `-F` | Top 100 |
| `-r` | Scan ports sequentially, don't randomize |

### Service and OS detection

| Flag | Does |
| --- | --- |
| `-sV` | "Probe open ports to determine service/version info" |
| `--version-intensity <0-9>` | How many probes; `--version-light` = 2, `--version-all` = 9 |
| `-O` | OS detection |
| `--osscan-guess` | Guess more aggressively when fingerprints are inconclusive |
| `--osscan-limit` | Only fingerprint promising hosts (faster) |

### NSE

| Flag | Does |
| --- | --- |
| `-sC` | `--script=default` |
| `--script <spec>` | Names, wildcards (`"smb*"`), categories, or boolean expressions (`"smb* and not brute"`) |
| `--script-args <n=v>` | Pass arguments, e.g. `--script-args http.useragent="Mozilla"` |
| `--script-args-file <f>` | Arguments from a file |
| `--script-help <spec>` | **What a script does before you run it** |
| `--script-trace` | Show everything the script sends and receives |
| `--script-updatedb` | Rebuild the script index after adding a `.nse` |

### Timing and performance

| Flag | Does |
| --- | --- |
| `-T<0-5>` | Timing template; `-T4` is the usual LAN choice, `-T1`/`-T2` to stay quiet |
| `--min-rate` / `--max-rate` | Packets per second floor / ceiling |
| `--max-retries <n>` | Cap retransmissions (`--max-retries 1` on a fast, reliable LAN) |
| `--host-timeout <t>` | Give up on a host after this long |
| `--scan-delay <t>` | Delay between probes — defeats rate-based IDS, also what you set when asked to go gently |
| `--min-hostgroup` / `--max-hostgroup` | Hosts scanned in parallel |

### Firewall / IDS evasion

Only on engagements where evading detection is explicitly in scope.

| Flag | Does |
| --- | --- |
| `-f` / `--mtu <n>` | Fragment packets |
| `-D <d1,d2,ME>` | "Cloak a scan with decoys" |
| `-S <ip>` | Spoof the source address (you won't see replies) |
| `-g` / `--source-port <n>` | Source from a trusted port like 53 or 88 |
| `--spoof-mac <mac/vendor>` | Spoof MAC — useful on a NAC-controlled LAN |
| `--data-length <n>` | Pad packets past signature lengths |
| `--badsum` | Bogus checksums — replies reveal filtering devices |
| `--proxies <urls>` | Relay via HTTP/SOCKS4 |

### Output

| Flag | Does |
| --- | --- |
| **`-oA <base>`** | **"Output in the three major formats at once" — always use this** |
| `-oN` / `-oX` / `-oG` | Normal / XML / greppable individually |
| `--append-output` | Append rather than clobber |
| `--resume <file>` | Resume an aborted scan from its normal/greppable output |
| `-v` / `-vv` | Verbosity — `-v` shows ports as they're found instead of at the end |
| `-d` / `-dd` | Debug |
| `--open` | Only show open ports |
| `--reason` | Why a port is in that state (invaluable on UDP and filtered results) |
| `--packet-trace` | Every packet sent and received |

`-oA` writes `.nmap`, `.gnmap` and `.xml`. The XML feeds Metasploit (`db_import`) and report tooling; the greppable one feeds shell pipelines:

```bash
# live hosts with 445 open, as a plain list
awk '/445\/open/{print $2}' scans/syn.gnmap > smb-hosts.txt
```

## Recipes

```bash
# Two-stage, the standard approach: find ports fast, then enumerate only those
sudo nmap -p- --min-rate 1000 -T4 -oA scans/1-allports 10.10.10.40
ports=$(awk -F'[/,]' '/open/{printf "%s,",$1}' scans/1-allports.gnmap | sed 's/,$//')
sudo nmap -sCV -p "$ports" -oA scans/2-enum 10.10.10.40

# Sweep a /24 for one service
sudo nmap -sn 10.10.10.0/24 -oA scans/sweep
sudo nmap -p445 --open 10.10.10.0/24 -oA scans/smb

# Find SMB signing disabled across a subnet — the NTLM-relay target list
sudo nmap --script smb2-security-mode -p445 10.10.10.0/24 -oA scans/smb-signing

# Web stack across everything that answered
sudo nmap -p80,443,8080,8443 --script "http-title,http-headers,http-methods" -oA scans/web 10.10.10.0/24

# Known-vuln sweep (intrusive — confirm scope)
sudo nmap --script "vuln and safe" -p- 10.10.10.40 -oA scans/vuln

# Gentle: a fragile host, or a client who asked you to go easy
sudo nmap -sS -T2 --scan-delay 100ms --max-retries 1 -p 1-1000 10.10.10.40
```

## NSE: categories and finding a script

| Category | Contains | Safe to run? |
| --- | --- | --- |
| `default` | What `-sC` and `-A` run — 116 scripts | Yes |
| `safe` | Won't crash or change anything | Yes |
| `discovery` | Enumerate more about the service | Yes |
| `version` | Extensions to `-sV` | Yes |
| `auth` | Authentication bypass / anonymous access checks | Mostly |
| `vuln` | Checks for known vulnerabilities | Mixed — read first |
| `exploit` | Actively exploits | **No — confirm scope** |
| `intrusive` | May crash the service or lock accounts | **No — confirm scope** |
| `brute` | Credential brute force | **No — lockout risk** |
| `dos` | Denial of service | **Never, unless contracted** |
| `malware` | Detect backdoors on the target | Yes |
| `broadcast` / `external` | Sends broadcasts / queries third parties | Scope question |
| `fuzzer` | Fuzz the service | **No** |

```bash
ls /usr/share/nmap/scripts/ | wc -l          # how many you have (macOS/brew: /opt/homebrew/share/nmap/scripts/)
nmap --script-help "smb-vuln*"                # what they do, before running them
grep -l '"vuln"' /usr/share/nmap/scripts/*.nse | wc -l
nmap --script "http* and not intrusive" -p80,443 <target>
```

**Always `--script-help` an unfamiliar script before running it.** `brute`, `dos` and `exploit` scripts will lock accounts and drop services, and "I ran a script I hadn't read" is not something you want in a post-incident call.

## Blue team note

- Scanning is loud by default. Detect it on: SYN floods to many closed ports, connection attempts to unused IPs, nmap's `-sV` probe strings, and the default User-Agent `Mozilla/5.0 (compatible; Nmap Scripting Engine; https://nmap.org/book/nse.html)` in web logs.
- `smb2-security-mode` returning "signing not required" across your estate is your own NTLM-relay exposure — see [3. Active Directory Hardening](../../Defense/System%20and%20Services%20Hardening/3.%20Active%20Directory%20Hardening.md).
- Host-based: scans show up as a burst of failed connections. See [Host-based logging on Linux](../../Defense/Logging/Host-based/Linux.md) and [SOC2 — Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md).

## Related

[tmux](tmux.md) (run long scans detached) · [vim](vim.md) · [Metasploit](Metasploit.md) (`db_import` the XML) · [folder README](README.md) · [Networking Overview](../Networking/Networking%20Overview.md) · [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · SANS Nmap handout in [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md)

## Appendix — all 609 NSE scripts (nmap 7.95)

Grouped by service prefix. Drop the `.nse` when passing to `--script`. Check your own count with `ls /usr/share/nmap/scripts/*.nse | wc -l`; `--script-help <name>` explains any of them.

**afp** (5) — `afp-brute`, `afp-ls`, `afp-path-vuln`, `afp-serverinfo`, `afp-showmount`

**ajp** (5) — `ajp-auth`, `ajp-brute`, `ajp-headers`, `ajp-methods`, `ajp-request`

**auth** (2) — `auth-owners`, `auth-spoof`

**backorifice** (2) — `backorifice-brute`, `backorifice-info`

**bitcoin** (2) — `bitcoin-getaddr`, `bitcoin-info`

**broadcast** (34) — `broadcast-ataoe-discover`, `broadcast-avahi-dos`, `broadcast-bjnp-discover`, `broadcast-db2-discover`, `broadcast-dhcp-discover`, `broadcast-dhcp6-discover`, `broadcast-dns-service-discovery`, `broadcast-dropbox-listener`, `broadcast-eigrp-discovery`, `broadcast-hid-discoveryd`, `broadcast-igmp-discovery`, `broadcast-jenkins-discover`, `broadcast-listener`, `broadcast-ms-sql-discover`, `broadcast-netbios-master-browser`, `broadcast-networker-discover`, `broadcast-novell-locate`, `broadcast-ospf2-discover`, `broadcast-pc-anywhere`, `broadcast-pc-duo`, `broadcast-pim-discovery`, `broadcast-ping`, `broadcast-pppoe-discover`, `broadcast-rip-discover`, `broadcast-ripng-discover`, `broadcast-sonicwall-discover`, `broadcast-sybase-asa-discover`, `broadcast-tellstick-discover`, `broadcast-upnp-info`, `broadcast-versant-locate`, `broadcast-wake-on-lan`, `broadcast-wpad-discover`, `broadcast-wsdd-discover`, `broadcast-xdmcp-discover`

**cassandra** (2) — `cassandra-brute`, `cassandra-info`

**cics** (4) — `cics-enum`, `cics-info`, `cics-user-brute`, `cics-user-enum`

**citrix** (5) — `citrix-brute-xml`, `citrix-enum-apps`, `citrix-enum-apps-xml`, `citrix-enum-servers`, `citrix-enum-servers-xml`

**couchdb** (2) — `couchdb-databases`, `couchdb-stats`

**cups** (2) — `cups-info`, `cups-queue-info`

**cvs** (2) — `cvs-brute`, `cvs-brute-repository`

**dicom** (2) — `dicom-brute`, `dicom-ping`

**dns** (18) — `dns-blacklist`, `dns-brute`, `dns-cache-snoop`, `dns-check-zone`, `dns-client-subnet-scan`, `dns-fuzz`, `dns-ip6-arpa-scan`, `dns-nsec-enum`, `dns-nsec3-enum`, `dns-nsid`, `dns-random-srcport`, `dns-random-txid`, `dns-recursion`, `dns-service-discovery`, `dns-srv-enum`, `dns-update`, `dns-zeustracker`, `dns-zone-transfer`

**domcon** (2) — `domcon-brute`, `domcon-cmd`

**drda** (2) — `drda-brute`, `drda-info`

**ftp** (8) — `ftp-anon`, `ftp-bounce`, `ftp-brute`, `ftp-libopie`, `ftp-proftpd-backdoor`, `ftp-syst`, `ftp-vsftpd-backdoor`, `ftp-vuln-cve2010-4221`

**hadoop** (5) — `hadoop-datanode-info`, `hadoop-jobtracker-info`, `hadoop-namenode-info`, `hadoop-secondary-namenode-info`, `hadoop-tasktracker-info`

**hbase** (2) — `hbase-master-info`, `hbase-region-info`

**hostmap** (3) — `hostmap-bfk`, `hostmap-crtsh`, `hostmap-robtex`

**http** (134) — `http-adobe-coldfusion-apsa1301`, `http-affiliate-id`, `http-apache-negotiation`, `http-apache-server-status`, `http-aspnet-debug`, `http-auth`, `http-auth-finder`, `http-avaya-ipoffice-users`, `http-awstatstotals-exec`, `http-axis2-dir-traversal`, `http-backup-finder`, `http-barracuda-dir-traversal`, `http-bigip-cookie`, `http-brute`, `http-cakephp-version`, `http-chrono`, `http-cisco-anyconnect`, `http-coldfusion-subzero`, `http-comments-displayer`, `http-config-backup`, `http-cookie-flags`, `http-cors`, `http-cross-domain-policy`, `http-csrf`, `http-date`, `http-default-accounts`, `http-devframework`, `http-dlink-backdoor`, `http-dombased-xss`, `http-domino-enum-passwords`, `http-drupal-enum`, `http-drupal-enum-users`, `http-enum`, `http-errors`, `http-exif-spider`, `http-favicon`, `http-feed`, `http-fetch`, `http-fileupload-exploiter`, `http-form-brute`, `http-form-fuzzer`, `http-frontpage-login`, `http-generator`, `http-git`, `http-gitweb-projects-enum`, `http-google-malware`, `http-grep`, `http-headers`, `http-hp-ilo-info`, `http-huawei-hg5xx-vuln`, `http-icloud-findmyiphone`, `http-icloud-sendmsg`, `http-iis-short-name-brute`, `http-iis-webdav-vuln`, `http-internal-ip-disclosure`, `http-joomla-brute`, `http-jsonp-detection`, `http-litespeed-sourcecode-download`, `http-ls`, `http-majordomo2-dir-traversal`, `http-malware-host`, `http-mcmp`, `http-method-tamper`, `http-methods`, `http-mobileversion-checker`, `http-ntlm-info`, `http-open-proxy`, `http-open-redirect`, `http-passwd`, `http-php-version`, `http-phpmyadmin-dir-traversal`, `http-phpself-xss`, `http-proxy-brute`, `http-put`, `http-qnap-nas-info`, `http-referer-checker`, `http-rfi-spider`, `http-robots.txt`, `http-robtex-reverse-ip`, `http-robtex-shared-ns`, `http-sap-netweaver-leak`, `http-security-headers`, `http-server-header`, `http-shellshock`, `http-sitemap-generator`, `http-slowloris`, `http-slowloris-check`, `http-sql-injection`, `http-stored-xss`, `http-svn-enum`, `http-svn-info`, `http-title`, `http-tplink-dir-traversal`, `http-trace`, `http-traceroute`, `http-trane-info`, `http-unsafe-output-escaping`, `http-useragent-tester`, `http-userdir-enum`, `http-vhosts`, `http-virustotal`, `http-vlcstreamer-ls`, `http-vmware-path-vuln`, `http-vuln-cve2006-3392`, `http-vuln-cve2009-3960`, `http-vuln-cve2010-0738`, `http-vuln-cve2010-2861`, `http-vuln-cve2011-3192`, `http-vuln-cve2011-3368`, `http-vuln-cve2012-1823`, `http-vuln-cve2013-0156`, `http-vuln-cve2013-6786`, `http-vuln-cve2013-7091`, `http-vuln-cve2014-2126`, `http-vuln-cve2014-2127`, `http-vuln-cve2014-2128`, `http-vuln-cve2014-2129`, `http-vuln-cve2014-3704`, `http-vuln-cve2014-8877`, `http-vuln-cve2015-1427`, `http-vuln-cve2015-1635`, `http-vuln-cve2017-1001000`, `http-vuln-cve2017-5638`, `http-vuln-cve2017-5689`, `http-vuln-cve2017-8917`, `http-vuln-misfortune-cookie`, `http-vuln-wnr1000-creds`, `http-waf-detect`, `http-waf-fingerprint`, `http-webdav-scan`, `http-wordpress-brute`, `http-wordpress-enum`, `http-wordpress-users`, `http-xssed`

**iax2** (2) — `iax2-brute`, `iax2-version`

**imap** (3) — `imap-brute`, `imap-capabilities`, `imap-ntlm-info`

**informix** (3) — `informix-brute`, `informix-query`, `informix-tables`

**ip** (8) — `ip-forwarding`, `ip-geolocation-geoplugin`, `ip-geolocation-ipinfodb`, `ip-geolocation-map-bing`, `ip-geolocation-map-google`, `ip-geolocation-map-kml`, `ip-geolocation-maxmind`, `ip-https-discover`

**ipmi** (3) — `ipmi-brute`, `ipmi-cipher-zero`, `ipmi-version`

**ipv6** (3) — `ipv6-multicast-mld-list`, `ipv6-node-info`, `ipv6-ra-flood`

**irc** (5) — `irc-botnet-channels`, `irc-brute`, `irc-info`, `irc-sasl-brute`, `irc-unrealircd-backdoor`

**iscsi** (2) — `iscsi-brute`, `iscsi-info`

**jdwp** (4) — `jdwp-exec`, `jdwp-info`, `jdwp-inject`, `jdwp-version`

**knx** (2) — `knx-gateway-discover`, `knx-gateway-info`

**ldap** (4) — `ldap-brute`, `ldap-novell-getpass`, `ldap-rootdse`, `ldap-search`

**membase** (2) — `membase-brute`, `membase-http-info`

**metasploit** (3) — `metasploit-info`, `metasploit-msgrpc-brute`, `metasploit-xmlrpc-brute`

**mmouse** (2) — `mmouse-brute`, `mmouse-exec`

**mongodb** (3) — `mongodb-brute`, `mongodb-databases`, `mongodb-info`

**ms** (11) — `ms-sql-brute`, `ms-sql-config`, `ms-sql-dac`, `ms-sql-dump-hashes`, `ms-sql-empty-password`, `ms-sql-hasdbaccess`, `ms-sql-info`, `ms-sql-ntlm-info`, `ms-sql-query`, `ms-sql-tables`, `ms-sql-xp-cmdshell`

**mysql** (11) — `mysql-audit`, `mysql-brute`, `mysql-databases`, `mysql-dump-hashes`, `mysql-empty-password`, `mysql-enum`, `mysql-info`, `mysql-query`, `mysql-users`, `mysql-variables`, `mysql-vuln-cve2012-2122`

**nat** (2) — `nat-pmp-info`, `nat-pmp-mapport`

**ncp** (2) — `ncp-enum-users`, `ncp-serverinfo`

**ndmp** (2) — `ndmp-fs-info`, `ndmp-version`

**nessus** (2) — `nessus-brute`, `nessus-xmlrpc-brute`

**netbus** (4) — `netbus-auth-bypass`, `netbus-brute`, `netbus-info`, `netbus-version`

**nfs** (3) — `nfs-ls`, `nfs-showmount`, `nfs-statfs`

**nje** (2) — `nje-node-brute`, `nje-pass-brute`

**ntp** (2) — `ntp-info`, `ntp-monlist`

**omp2** (2) — `omp2-brute`, `omp2-enum-targets`

**oracle** (5) — `oracle-brute`, `oracle-brute-stealth`, `oracle-enum-users`, `oracle-sid-brute`, `oracle-tns-version`

**pop3** (3) — `pop3-brute`, `pop3-capabilities`, `pop3-ntlm-info`

**quake3** (2) — `quake3-info`, `quake3-master-getservers`

**rdp** (3) — `rdp-enum-encryption`, `rdp-ntlm-info`, `rdp-vuln-ms12-020`

**redis** (2) — `redis-brute`, `redis-info`

**rmi** (2) — `rmi-dumpregistry`, `rmi-vuln-classloader`

**rpcap** (2) — `rpcap-brute`, `rpcap-info`

**rsync** (2) — `rsync-brute`, `rsync-list-modules`

**rtsp** (2) — `rtsp-methods`, `rtsp-url-brute`

**sip** (4) — `sip-brute`, `sip-call-spoof`, `sip-enum-users`, `sip-methods`

**smb** (31) — `smb-brute`, `smb-double-pulsar-backdoor`, `smb-enum-domains`, `smb-enum-groups`, `smb-enum-processes`, `smb-enum-services`, `smb-enum-sessions`, `smb-enum-shares`, `smb-enum-users`, `smb-flood`, `smb-ls`, `smb-mbenum`, `smb-os-discovery`, `smb-print-text`, `smb-protocols`, `smb-psexec`, `smb-security-mode`, `smb-server-stats`, `smb-system-info`, `smb-vuln-conficker`, `smb-vuln-cve-2017-7494`, `smb-vuln-cve2009-3103`, `smb-vuln-ms06-025`, `smb-vuln-ms07-029`, `smb-vuln-ms08-067`, `smb-vuln-ms10-054`, `smb-vuln-ms10-061`, `smb-vuln-ms17-010`, `smb-vuln-regsvc-dos`, `smb-vuln-webexec`, `smb-webexec-exploit`

**smb2** (4) — `smb2-capabilities`, `smb2-security-mode`, `smb2-time`, `smb2-vuln-uptime`

**smtp** (9) — `smtp-brute`, `smtp-commands`, `smtp-enum-users`, `smtp-ntlm-info`, `smtp-open-relay`, `smtp-strangeport`, `smtp-vuln-cve2010-4344`, `smtp-vuln-cve2011-1720`, `smtp-vuln-cve2011-1764`

**snmp** (12) — `snmp-brute`, `snmp-hh3c-logins`, `snmp-info`, `snmp-interfaces`, `snmp-ios-config`, `snmp-netstat`, `snmp-processes`, `snmp-sysdescr`, `snmp-win32-services`, `snmp-win32-shares`, `snmp-win32-software`, `snmp-win32-users`

**socks** (3) — `socks-auth-info`, `socks-brute`, `socks-open-proxy`

**ssh** (5) — `ssh-auth-methods`, `ssh-brute`, `ssh-hostkey`, `ssh-publickey-acceptance`, `ssh-run`

**ssl** (9) — `ssl-ccs-injection`, `ssl-cert`, `ssl-cert-intaddr`, `ssl-date`, `ssl-dh-params`, `ssl-enum-ciphers`, `ssl-heartbleed`, `ssl-known-key`, `ssl-poodle`

**stun** (2) — `stun-info`, `stun-version`

**targets** (10) — `targets-asn`, `targets-ipv6-map4to6`, `targets-ipv6-multicast-echo`, `targets-ipv6-multicast-invalid-dst`, `targets-ipv6-multicast-mld`, `targets-ipv6-multicast-slaac`, `targets-ipv6-wordlist`, `targets-sniffer`, `targets-traceroute`, `targets-xml`

**telnet** (3) — `telnet-brute`, `telnet-encryption`, `telnet-ntlm-info`

**tftp** (2) — `tftp-enum`, `tftp-version`

**tls** (3) — `tls-alpn`, `tls-nextprotoneg`, `tls-ticketbleed`

**tso** (2) — `tso-brute`, `tso-enum`

**vnc** (3) — `vnc-brute`, `vnc-info`, `vnc-title`

**whois** (2) — `whois-domain`, `whois-ip`

**xmpp** (2) — `xmpp-brute`, `xmpp-info`

**other** (145) — `acarsd-info`, `address-info`, `allseeingeye-info`, `amqp-info`, `asn-query`, `bacnet-info`, `banner`, `bitcoinrpc-info`, `bittorrent-discovery`, `bjnp-discover`, `cccam-version`, `clamav-exec`, `clock-skew`, `coap-resources`, `creds-summary`, `daap-get-library`, `daytime`, `db2-das-info`, `deluge-rpc-brute`, `dhcp-discover`, `dict-info`, `distcc-cve2004-2687`, `docker-version`, `domino-enum-users`, `dpap-brute`, `duplicates`, `eap-info`, `enip-info`, `epmd-info`, `eppc-enum-processes`, `fcrdns`, `finger`, `fingerprint-strings`, `firewalk`, `firewall-bypass`, `flume-master-info`, `fox-info`, `freelancer-info`, `ganglia-info`, `giop-info`, `gkrellm-info`, `gopher-ls`, `gpsd-info`, `hartip-info`, `hddtemp-info`, `hnap-info`, `https-redirect`, `icap-info`, `iec-identify`, `iec61850-mms`, `ike-version`, `impress-remote-discover`, `ipidseq`, `isns-info`, `krb5-enum-users`, `lexmark-config`, `llmnr-resolve`, `lltd-discovery`, `lu-enum`, `maxdb-info`, `mcafee-epo-agent`, `memcached-info`, `mikrotik-routeros-brute`, `modbus-discover`, `mqtt-subscribe`, `mrinfo`, `msrpc-enum`, `mtrace`, `multicast-profinet-discovery`, `murmur-version`, `nbd-info`, `nbns-interfaces`, `nbstat`, `nexpose-brute`, `nntp-ntlm-info`, `nping-brute`, `nrpe-enum`, `omron-info`, `openflow-info`, `openlookup-info`, `openvas-otp-brute`, `openwebnet-discovery`, `ovs-agent-version`, `p2p-conficker`, `path-mtu`, `pcanywhere-brute`, `pcworx-info`, `pgsql-brute`, `pjl-ready-message`, `port-states`, `pptp-version`, `profinet-cm-lookup`, `puppet-naivesigning`, `qconn-exec`, `qscan`, `quake1-info`, `realvnc-auth-bypass`, `resolveall`, `reverse-index`, `rexec-brute`, `rfc868-time`, `riak-http-info`, `rlogin-brute`, `rpc-grind`, `rpcinfo`, `rsa-vuln-roca`, `rusers`, `s7-info`, `samba-vuln-cve-2012-1182`, `servicetags`, `shodan-api`, `skypev2-version`, `sniffer-detect`, `ssh2-enum-algos`, `sshv1`, `sslv2`, `sslv2-drown`, `sstp-discover`, `stuxnet-detect`, `supermicro-ipmi-conf`, `svn-brute`, `teamspeak2-version`, `tn3270-screen`, `tor-consensus-checker`, `traceroute-geolocation`, `ubiquiti-discovery`, `unittest`, `unusual-port`, `upnp-info`, `uptime-agent-info`, `url-snarf`, `ventrilo-info`, `versant-info`, `vmauthd-brute`, `vmware-version`, `voldemort-info`, `vtam-enum`, `vulners`, `vuze-dht-info`, `wdb-version`, `weblogic-t3-info`, `wsdd-discover`, `x11-access`, `xdmcp-discover`, `xmlrpc-methods`
