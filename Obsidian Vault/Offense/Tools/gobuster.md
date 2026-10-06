# gobuster

Brute-forces things that aren't listed anywhere: directories, files, DNS subdomains, virtual hosts, S3/GCS buckets, TFTP files. Fast, single-purpose, and it does one thing per run.

Flags verified against **gobuster v3.8.2**. v3 renamed a lot from v2 — if a flag errors, `gobuster <mode> --help` is the truth for your build.

> Authorized targets only. Directory brute forcing is thousands of requests a minute: agree a rate limit, and don't point it at anything fragile.

## Contents

- [Modes](#modes)
- [Flags shared by every mode](#flags-shared-by-every-mode)
- [dir — directories and files](#dir--directories-and-files)
- [dns — subdomains](#dns--subdomains)
- [vhost — virtual hosts](#vhost--virtual-hosts)
- [fuzz — arbitrary keyword](#fuzz--arbitrary-keyword)
- [s3, gcs, tftp](#s3-gcs-tftp)
- [Gotchas](#gotchas)
- [gobuster or ffuf?](#gobuster-or-ffuf)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Modes

| Mode | Finds | Minimum |
| --- | --- | --- |
| `dir` | Directories and files | `-u <url> -w <list>` |
| `dns` | Subdomains via DNS resolution | `-do <domain> -w <list>` |
| `vhost` | Virtual hosts on one IP | `-u <ip> -w <list> -do <domain>` |
| `fuzz` | Anything, via a `FUZZ` keyword | `-u <url-with-FUZZ> -w <list>` |
| `s3` / `gcs` | Open S3 / Google Cloud buckets | `-w <list>` |
| `tftp` | Files on a TFTP server | `-s <server> -w <list>` |

## Flags shared by every mode

| Flag | Alias | Does |
| --- | --- | --- |
| `--wordlist` | `-w` | Wordlist (`-` reads stdin) |
| `--threads` | `-t` | Concurrency (default 10) |
| `--delay` | `-d` | Delay between requests — use it when asked to go gently |
| `--output` | `-o` | Write results to a file |
| `--quiet` | `-q` | Suppress the banner |
| `--no-progress` | `-np` | No progress bar (for logs and pipelines) |
| `--no-error` | `-ne` | Hide errors |
| `--pattern` | `-p` | Apply a pattern file to each word |
| `--wordlist-offset` | `-wo` | Resume from word N |
| `--useragent` | `-a` | Set User-Agent |
| `--random-agent` | `-rua` | Rotate a real browser UA |
| `--proxy` | | Route through Burp, e.g. `http://127.0.0.1:8080` |
| `--no-tls-validation` | `-k` | Accept self-signed certs |
| `--timeout` | `-to` | Request timeout |
| `--retry` / `--retry-attempts` | `-ra` | Retry failed requests |
| `--cookies` | `-c` | Cookie header — **how you fuzz authenticated** |
| `--headers` | `-H` | Extra header, repeatable |
| `--username` / `--password` | `-U` / `-P` | HTTP Basic auth |
| `--method` | `-m` | HTTP method |
| `--follow-redirect` | `-r` | Follow redirects |
| `--interface` | `-iface` | Bind to an interface (pick your VPN, not your home NIC) |

## dir — directories and files

```bash
gobuster dir -u https://target.tld -w /usr/share/seclists/Discovery/Web-Content/common.txt
gobuster dir -u https://target.tld -w <list> -x php,html,txt,bak      # try extensions on every word
gobuster dir -u https://target.tld -w <list> -t 50 -o scans/gobuster-dir.txt
gobuster dir -u https://target.tld -w <list> -c 'SESSION=abc' -k      # authenticated, self-signed cert
gobuster dir -u https://target.tld -w <list> -b 404,403 -e            # custom blacklist, full URLs
```

| Flag | Alias | Does |
| --- | --- | --- |
| `--status-codes` | `-s` | **Whitelist** of codes to report (overridden by the blacklist if both set) |
| `--status-codes-blacklist` | `-b` | **Blacklist** of codes to hide. Ranges work: `200,300-400,404` |
| `--extensions` | `-x` | Extensions to append to each word — no leading dot |
| `--extensions-file` | `-X` | Read extensions from a file |
| `--expanded` | `-e` | Print full URLs instead of paths |
| `--add-slash` | `-f` | Append `/` to each request — finds directories that 404 without it |
| `--discover-backup` | `-db` | On a hit, also try backup extensions (`.bak`, `.old`, …) |
| `--hide-length` | `-hl` | Hide response length |
| `--no-status` | `-n` | Hide status codes |
| `--exclude-length` | `-xl` | Ignore these content lengths regardless of status |

**`-s` and `-b` are mutually exclusive in effect** — gobuster defaults to a blacklist (404). Setting `-s` while a blacklist is active does nothing, so if you want only `200,301`, clear the blacklist: `-b '' -s 200,301`.

`--discover-backup` is the highest-value flag here and most people miss it: on every hit it tries backup extensions, which is how `config.php.bak` turns up.

## dns — subdomains

```bash
gobuster dns -do target.tld -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt
gobuster dns -do target.tld -w <list> -c                      # also check CNAMEs
gobuster dns -do target.tld -w <list> --resolver 1.1.1.1 -t 50
gobuster dns -do target.tld -w <list> -wc                      # continue despite a wildcard
```

| Flag | Alias | Does |
| --- | --- | --- |
| `--domain` | `-do` | Target domain |
| `--check-cname` | `-c` | Also resolve CNAME records |
| `--wildcard` | `-wc` | Keep going when a wildcard record is detected |
| `--no-fqdn` | `-nf` | Don't append a trailing dot — lets the resolver use its search list |
| `--resolver` | | Custom DNS server (`server.com` or `server.com:port`) |
| `--timeout` | `-to` | Resolver timeout |

**Check for a wildcard first.** If `*.target.tld` resolves, every word "succeeds" and the run is worthless. gobuster warns and stops; `-wc` forces it on, but then you must filter by the wildcard's IP yourself.

Use your own resolver (`--resolver 1.1.1.1`) rather than the client's — faster, and it keeps your enumeration out of their DNS logs if that matters to the engagement.

## vhost — virtual hosts

Different sites on one IP, selected by the `Host` header. Finds staging and admin interfaces that have no DNS record at all.

```bash
gobuster vhost -u http://10.10.10.40 -w <list> -do target.tld --append-domain
gobuster vhost -u http://10.10.10.40 -w <list> -do target.tld -ad -xs 404
```

| Flag | Alias | Does |
| --- | --- | --- |
| `--append-domain` | `-ad` | Append the domain to each word. Without it, wordlist entries must already be FQDNs |
| `--domain` | `-do` | Domain to append when the URL is an IP |
| `--exclude-status` | `-xs` | Hide these status codes. Ranges work |
| `--exclude-length` | `-xl` | Hide these content lengths |
| `--force` | | Run even when the result isn't guaranteed |

Point `-u` at the **IP**, not the hostname — that's the whole point of the mode. `--append-domain` is almost always what you want; forgetting it is the usual reason a vhost scan returns nothing.

Filter by **length**, not status: a wrong `Host` usually returns the default site with `200`, so every word looks like a hit. Run one known-bad host first, note the length, then `-xl <that length>`.

## fuzz — arbitrary keyword

```bash
gobuster fuzz -u "https://target.tld/?FUZZ=test" -w params.txt -b 404
gobuster fuzz -u "https://target.tld/FUZZ" -w <list> -xl 1234
gobuster fuzz -u https://target.tld -H "X-Forwarded-Host: FUZZ" -w <list>
```

| Flag | Alias | Does |
| --- | --- | --- |
| `--exclude-statuscodes` | `-b` | Hide these codes. Ranges work |
| `--exclude-length` | `-xl` | Hide these content lengths, ignoring status |

Deliberately minimal — for real fuzzing with matchers, multiple wordlists and auto-calibration, use [ffuf](fuzz.md).

## s3, gcs, tftp

```bash
gobuster s3 -w bucket-names.txt            # open S3 buckets
gobuster gcs -w bucket-names.txt           # open Google Cloud Storage buckets
gobuster tftp -s 10.10.10.40 -w files.txt  # files on a TFTP server (UDP 69)
```

Bucket modes query the provider, not your target, so confirm this is in scope — you're sending traffic to a third party. TFTP pairs with the UDP findings from [nmap](nmap.md): port 69 open and no auth is a file read for free.

## Gotchas

| Gotcha | Detail |
| --- | --- |
| **No recursion** | gobuster does **not** recurse into directories it finds. Re-run against each hit, or use `feroxbuster` / `ffuf -recursion` — see [fuzz](fuzz.md) |
| `-b` beats `-s` | The default blacklist (404) wins over a whitelist. Use `-b '' -s 200,301` |
| `-x` takes no dots | `-x php,bak` not `-x .php,.bak` |
| Soft 404s | Apps that return `200` with "not found" defeat status filtering. Filter on length with `-xl`, or switch to `ffuf -ac` |
| Trailing slash | Some directories only answer with `/` — add `-f` |
| DNS wildcards | Check before you trust a `dns` run |
| vhost needs the IP | `-u <ip>` plus `-do <domain>` plus `-ad` |
| HTTPS with a bad cert | Add `-k`, or every request fails |

## gobuster or ffuf?

| Use gobuster when | Use ffuf when |
| --- | --- |
| You want one fast, simple pass | You need matchers, filters, or auto-calibration |
| DNS or vhost enumeration (its modes are cleaner) | Multiple wordlists at once (clusterbomb/pitchfork) |
| Scripting something predictable | Soft 404s are defeating you (`-ac`) |
| Bucket or TFTP enumeration | You need recursion, or to fuzz a raw saved request |

In practice: gobuster for `dns` and `vhost`, ffuf or feroxbuster for content discovery. Both in [fuzz](fuzz.md).

## Defense / detection

- Hundreds to thousands of `404`s from one source in a short window is the signature — alert on 404 *rate* per client IP, not on individual requests.
- Return a consistent, uninformative 404 for missing content, and don't let `.bak`/`.old`/`.swp`/`.git` be served at all — `--discover-backup` exists because this is so often forgotten.
- Rate limiting and a WAF both blunt it; neither fixes an exposed admin panel. Don't rely on an unguessable path as access control.
- Virtual hosts with no DNS record are not hidden — `vhost` mode finds them from the IP alone. Authenticate staging sites.
- See [Logging](../../Defense/Logging/README.md) and [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md) (tool User-Agents).

## Related

[fuzz](fuzz.md) (ffuf, feroxbuster, wordlists) · [nmap](nmap.md) · [smb](smb.md) · [folder README](README.md) · [Web Overview](../Web/Web%20Overview.md) · [SSRF](../Web/SSRF.md) · [RCE](../Web/RCE.md)
