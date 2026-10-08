# fuzz

Substituting a keyword into a request thousands of times and reading the differences. Mostly **ffuf**, plus feroxbuster for recursion and wordlists for all of it.

The tool is the easy part. **Filtering is the skill** — an unfiltered run returns 4,000 "hits" and tells you nothing.

Flags verified against **ffuf v2.3.0**.

> Authorized targets only. This is thousands of requests a minute: agree a rate limit, keep `-rate`/`-p` on anything production, and never point a fuzzer at a payment or email-sending endpoint without asking.

## Contents

- [The method](#the-method)
- [ffuf — core flags](#ffuf--core-flags)
- [The FUZZ keyword and multi-wordlist modes](#the-fuzz-keyword-and-multi-wordlist-modes)
- [What to fuzz](#what-to-fuzz)
- [Filtering and calibration](#filtering-and-calibration)
- [feroxbuster — recursion by default](#feroxbuster--recursion-by-default)
- [Wordlists](#wordlists)
- [Which tool](#which-tool)
- [Defense / detection](#defense--detection)
- [Related](#related)

## The method

| Step | Why |
| --- | --- |
| 1. **Baseline** — request something you know doesn't exist | Tells you what "not found" looks like: status, size, words, lines |
| 2. Pick a wordlist that matches the target | A PHP list against a .NET app wastes the whole run |
| 3. **Filter or calibrate** against that baseline | `-ac`, or `-fs`/`-fc`/`-fw` from step 1 |
| 4. Re-run narrow, then verify by hand | A fuzzer result is a candidate, not a finding |

Skipping step 1 is why people end up filtering by trial and error.

## ffuf — core flags

```bash
ffuf -u https://target.tld/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt
```

### Input

| Flag | Does |
| --- | --- |
| `-w <file>` | Wordlist. `-w list.txt:KEY` names the keyword (default `FUZZ`) |
| `-u <url>` | Target URL, containing the keyword |
| `-e <exts>` | "Comma separated list of extensions. Extends FUZZ keyword" |
| `-request <file>` | **Fuzz a raw saved request** — paste from Burp, mark the spot with `FUZZ` |
| `-request-proto` | `https` (default) or `http` for that raw request |
| `-mode <m>` | `clusterbomb` (default), `pitchfork`, `sniper` |
| `-ic` | Ignore `#` comments in the wordlist |
| `-enc 'FUZZ:urlencode'` | Encode the payload — also `b64encode` |
| `-input-cmd <cmd>` | Generate input from a command (needs `-input-num`) |
| `-D` | DirSearch wordlist compatibility, with `-e` |

### Matchers — what to keep

| Flag | Does |
| --- | --- |
| `-mc` | Status codes. Default `200-299,301,302,307,401,403,405,500`; `all` for everything |
| `-ms` / `-ml` / `-mw` | Match response size / lines / words |
| `-mr` | Match a regex in the response |
| `-mt` | Match time to first byte, e.g. `>500` — **how you find time-based injection** |
| `-mmode` | Combine matchers with `and` / `or` (default `or`) |

### Filters — what to drop

| Flag | Does |
| --- | --- |
| `-fc` | Filter out status codes |
| `-fs` / `-fl` / `-fw` | Filter out by size / lines / words (comma lists and ranges) |
| `-fr` | Filter out by regex — e.g. `-fr 'Not Found'` for soft 404s |
| `-ft` | Filter by response time |
| `-fmode` | Combine filters with `and` / `or` (default `or`) |

### Calibration

| Flag | Does |
| --- | --- |
| **`-ac`** | "Automatically calibrate filtering options" — sends known-bad requests, builds the filter itself |
| `-acc <str>` | Custom calibration string, repeatable. Implies `-ac` |
| `-ach` | Calibrate per host (use with vhost fuzzing) |
| `-acs` | Custom calibration strategy. Implies `-ac` |

### HTTP

| Flag | Does |
| --- | --- |
| `-X` | Method |
| `-d` | POST body |
| `-H 'Name: Value'` | Header, repeatable |
| `-b 'N=V; N2=V2'` | Cookies |
| `-r` | Follow redirects |
| `-x` | Proxy (`http://127.0.0.1:8080` or `socks5://…`) |
| **`-replay-proxy`** | **Replay only matches through this proxy** — hits land in Burp, noise doesn't |
| `-recursion` | Recurse. URL must end in `FUZZ` |
| `-recursion-depth` | Max depth |
| `-recursion-strategy` | `default` (redirect-based) or `greedy` (all matches) |
| `-http2`, `-sni`, `-timeout`, `-raw`, `-ignore-body` | Transport tweaks |

### Performance and output

| Flag | Does |
| --- | --- |
| `-t` | Threads (default 40) |
| `-rate` | Requests per second cap — **set this on production** |
| `-p` | Delay between requests, or a range like `0.1-2.0` |
| `-maxtime` / `-maxtime-job` | Overall / per-job time cap |
| `-o <file>` / `-of <fmt>` | Output; formats `json, ejson, html, md, csv, ecsv, all` |
| `-od <dir>` | Store matched responses to disk |
| `-s` | Silent (clean piping) |
| `-v` | Verbose — full URL and redirect location |
| `-c` | Colour |
| `-sf` | Stop if >95% of responses are 403 (you've been blocked) |
| `-se` / `-sa` | Stop on spurious errors / all errors |

## The FUZZ keyword and multi-wordlist modes

`FUZZ` is just a placeholder — put it anywhere in the URL, a header, or the body.

| Mode | Behaviour | Use |
| --- | --- | --- |
| `clusterbomb` *(default)* | Every combination of every list | user x password lists |
| `pitchfork` | Lists advance in lockstep, pairwise | A file of known user:pass pairs, split in two |
| `sniper` | One list, substituted into each marked position in turn | Probe many parameters with one payload |

```bash
# two keywords, every combination
ffuf -u https://target.tld/FUZZ/FUZ2Z -w dirs.txt:FUZZ -w files.txt:FUZ2Z

# pairwise
ffuf -u https://target.tld/login -X POST -d 'u=U&p=P' -w users.txt:U -w pass.txt:P -mode pitchfork

# one payload into several marked spots
ffuf -request req.txt -mode sniper -w payloads.txt
```

## What to fuzz

| Target | Command |
| --- | --- |
| Directories | `ffuf -u https://t/FUZZ -w common.txt -ac` |
| Files with extensions | `ffuf -u https://t/FUZZ -w list.txt -e .php,.bak,.txt,.old -ac` |
| Recursively | `ffuf -u https://t/FUZZ -w list.txt -recursion -recursion-depth 2 -ac` |
| GET parameter **names** | `ffuf -u 'https://t/page?FUZZ=test' -w params.txt -fs <baseline>` |
| GET parameter **values** | `ffuf -u 'https://t/page?id=FUZZ' -w values.txt -ac` |
| POST body fields | `ffuf -u https://t/api -X POST -d 'FUZZ=test' -H 'Content-Type: application/x-www-form-urlencoded' -w params.txt` |
| JSON fields | `ffuf -u https://t/api -X POST -d '{"FUZZ":"test"}' -H 'Content-Type: application/json' -w params.txt` |
| Virtual hosts | `ffuf -u https://t -H 'Host: FUZZ.target.tld' -w subs.txt -ac -ach` |
| Subdomains (DNS) | Prefer `gobuster dns` — see [gobuster](gobuster.md) |
| Headers | `ffuf -u https://t -H 'X-Forwarded-For: FUZZ' -w ips.txt -ac` |
| API routes | `ffuf -u https://t/api/v1/FUZZ -w api-endpoints.txt -mc all -fc 404` |
| Hidden API versions | `ffuf -u https://t/api/FUZZ/users -w versions.txt -ac` |
| A saved Burp request | `ffuf -request req.txt -request-proto https -w list.txt -ac` |

The last one is the most useful and least used: `-request` keeps every header, cookie and body field exactly as the app expects, so you fuzz authenticated endpoints without rebuilding the request by hand.

## Filtering and calibration

```bash
# 1. baseline — ask for something that cannot exist
curl -sD - https://target.tld/definitely-not-here-9f3a -o /dev/null | head -1
ffuf -u https://target.tld/definitely-not-here-9f3a -w /dev/null -mc all

# 2. let ffuf work it out (preferred)
ffuf -u https://target.tld/FUZZ -w common.txt -ac

# 3. or filter manually from the baseline
ffuf -u https://target.tld/FUZZ -w common.txt -fs 1234          # drop that size
ffuf -u https://target.tld/FUZZ -w common.txt -fr 'Not Found'   # drop soft 404s by content
ffuf -u https://target.tld/FUZZ -w common.txt -fw 42            # drop that word count

# size varies slightly per response? filter words or lines instead, or use a range
ffuf -u https://target.tld/FUZZ -w common.txt -fs 1200-1300
```

| Symptom | Fix |
| --- | --- |
| Every word "found", all same size | Soft 404 — `-ac`, or `-fs <size>` / `-fr '<text>'` |
| Nothing found at all | Default `-mc` is hiding it; try `-mc all -fc 404` |
| Hits vary in size because the path is echoed back | Filter `-fw` or `-fl` instead of `-fs` |
| Suddenly all 403 | You're blocked. `-sf` stops early; drop `-rate` and `-t` |
| Results clearly wrong behind a CDN | `-ach` for per-host calibration |

**Always finish with `-mc all -fc 404`** on an endpoint that matters. The default matcher silently drops codes like `405` and `502`, and a `502` on one path out of 10,000 is often the most interesting result in the run.

## feroxbuster — recursion by default

> Full cheatsheet: **[feroxbuster](feroxbuster.md)**.

```bash
feroxbuster -u https://target.tld                                 # recurses automatically
feroxbuster -u https://target.tld -w <list> -x php,bak -d 3        # extensions, depth 3
feroxbuster -u https://target.tld -H 'Cookie: SESSION=abc' -k      # authenticated, bad cert
feroxbuster -u https://target.tld --rate-limit 50 -o ferox.txt     # throttled, saved
feroxbuster --resume-from ferox.state                              # resume a killed run
```

| Flag | Does |
| --- | --- |
| `-u` / `-w` | URL / wordlist |
| `-d <n>` | Recursion depth (default 4) |
| `-x <exts>` | Extensions |
| `-s` / `-C` | Status codes to keep / filter out |
| `-S` / `-W` / `-N` | Filter by size / words / lines |
| `--rate-limit` | Requests per second |
| `-k` | Ignore TLS errors |
| `--resume-from` | Resume from a state file |

Pick feroxbuster when you want deep content discovery without managing recursion yourself. It auto-filters wildcard responses, which saves most of the `-fs` fiddling.

## Wordlists

[SecLists](https://github.com/danielmiessler/SecLists) is the standard set — `/usr/share/seclists/` on Kali.

| Job | List |
| --- | --- |
| First pass, any app | `Discovery/Web-Content/common.txt` (~4.7k) |
| Thorough | `Discovery/Web-Content/directory-list-2.3-medium.txt` (~220k) |
| Files by extension | `Discovery/Web-Content/raft-medium-files.txt` |
| API routes | `Discovery/Web-Content/api/api-endpoints.txt` |
| Parameter names | `Discovery/Web-Content/burp-parameter-names.txt` |
| Subdomains | `Discovery/DNS/subdomains-top1million-110000.txt` |
| Vhosts | `Discovery/DNS/namelist.txt` |
| Backup / temp files | `Discovery/Web-Content/Common-DB-Backups.txt` |
| Stack-specific | `Discovery/Web-Content/` has `apache`, `nginx`, `IIS`, `tomcat`, `Oracle`, `Jenkins`, … |

Two things that beat a bigger list:

- **Match the stack.** Fingerprint first ([nmap](nmap.md) `-sV`, whatweb), then use the matching list. A Tomcat list against Tomcat finds `/manager/html` in 200 requests; `directory-list-2.3-medium` might not find it in 220,000.
- **Build a target-specific list.** Scrape the app's own words — `cewl https://target.tld`, or pull paths from JS with `katana -jc`. Real apps use their own vocabulary.

## Which tool

| | gobuster | ffuf | feroxbuster |
| --- | --- | --- | --- |
| Content discovery | Good | Good | **Best** (auto-recursion) |
| Recursion | **No** | `-recursion` | Default |
| Soft-404 handling | Manual `-xl` | **`-ac`** | Automatic |
| Multiple wordlists | No | **Yes** | No |
| Fuzz a raw request | No | **`-request`** | No |
| Params / headers / JSON | Basic | **Best** | No |
| DNS subdomains | **Best** | Workable | No |
| Virtual hosts | **Best** | Good with `-ach` | No |
| Resume | `-wo` | No | **`--resume-from`** |

Practical split: **gobuster** for `dns`/`vhost`, **feroxbuster** for deep content discovery, **ffuf** for everything parameterised and anything needing real filtering.

## Defense / detection

- The signature is **404 rate per source**, plus a wordlist's alphabetical march through paths. Alert on the rate, not individual requests.
- Soft 404s (returning `200` for missing content) frustrate attackers slightly and break your own monitoring — return a real `404`.
- Never let an unguessable path be the access control; these tools exist specifically to defeat that.
- Block access to `.git/`, `.env`, `.bak`, `.old`, `.swp` and editor temp files at the server, not just by not linking them.
- Rate limiting plus per-IP throttling blunts discovery; a WAF catching `ffuf`/`gobuster` User-Agents is trivially bypassed with `-H`, so don't count it.
- See [Logging](../../Defense/Logging/README.md) and [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md).

## Related

[gobuster](gobuster.md) · [nmap](nmap.md) · [smb](../Protocols/smb.md) · [tmux](tmux.md) (run long fuzzes detached) · [folder README](README.md) · [Web Overview](../Web/Web%20Overview.md) · [SQL Injection](../Web/SQL%20Injection.md) · [RCE](../Web/RCE.md) · [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md)
