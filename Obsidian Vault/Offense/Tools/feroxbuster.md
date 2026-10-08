# feroxbuster

A fast, **recursive** content-discovery scanner ([epi052/feroxbuster](https://github.com/epi052/feroxbuster)). The go-to for directory/file brute forcing on web targets because — unlike dirb and gobuster — it **recurses into every directory it finds automatically**, so you don't re-run it by hand against each hit.

Flags verified against **v2.13.1**. Full fuzzing comparison (ffuf, gobuster, wordlists) in [fuzz](fuzz.md).

> Authorized testing only. Thousands of requests a minute — agree a rate limit and keep `--rate-limit` on anything production.

## Contents

- [Quick start](#quick-start)
- [The enumeration cheatsheet](#the-enumeration-cheatsheet)
- [Flags](#flags)
- [Filtering out the noise](#filtering-out-the-noise)
- [feroxbuster vs gobuster vs ffuf](#feroxbuster-vs-gobuster-vs-ffuf)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Quick start

```bash
feroxbuster -u https://TARGET                                   # recurses by default, auto-filters wildcards
feroxbuster -u https://TARGET -w /usr/share/seclists/Discovery/Web-Content/common.txt
feroxbuster -u https://<IP> -w <wordlist path> --scan-dir-listings   # also recurse INTO open directory listings
```

`--scan-dir-listings` forces scans to recurse into directory-listing pages (Apache/nginx "Index of /" pages). Normally feroxbuster treats a listing as a leaf; this makes it keep digging through it — easy to miss files otherwise.

## The enumeration cheatsheet

Work top to bottom — don't stop at the first pass. The goal is to **not miss anything**.

```bash
# 1. FIRST PASS — default recursive scan, see the shape of the app
feroxbuster -u https://TARGET -k

# 2. ADD EXTENSIONS matched to the stack (fingerprint first: whatweb / nmap -sV)
feroxbuster -u https://TARGET -x php,html,txt,bak,zip,old -k

# 3. RECURSE INTO DIRECTORY LISTINGS — catch files behind "Index of /" pages
feroxbuster -u https://TARGET -w <wordlist> --scan-dir-listings -k

# 4. AUTHENTICATED — an unauth scan finds the login page; an authed one finds the admin panel
feroxbuster -u https://TARGET -b 'SESSION=<cookie>' -k
feroxbuster -u https://TARGET -H 'Authorization: Bearer <token>' -k

# 5. GO DEEP + COLLECT — let it harvest extensions, backups and words as it goes
feroxbuster -u https://TARGET -x php --collect-extensions --collect-backups --collect-words -d 4 -k

# 6. THE ONE-FLAG "everything" — --thorough = smart + collect-* + scan-dir-listings
feroxbuster -u https://TARGET --thorough -k

# 7. BIGGER WORDLIST once you know it's worth it (slower)
feroxbuster -u https://TARGET -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -k

# 8. SAVE + be able to resume a long scan
feroxbuster -u https://TARGET -o scans/ferox.txt --rate-limit 100 -k
feroxbuster --resume-from ferox.state
```

Don't-miss checklist:

- [ ] Ran at least one pass with **extensions matched to the stack** (`.php` vs `.aspx` vs `.jsp`).
- [ ] Used **`--scan-dir-listings`** so open directory indexes get walked, not just noted.
- [ ] Re-ran **authenticated** (`-b`/`-H`) — the admin panel isn't visible logged out.
- [ ] Noted **403/401** separately from 404 — "exists but forbidden" is a lead, not a dead end.
- [ ] Let **`--collect-backups`** run — `config.php.bak`, `.old`, `~` copies leak source and creds.
- [ ] Added a **custom wordlist** from the app's own words (`--collect-words`, or cewl) for anything bespoke.
- [ ] Checked a **bigger wordlist** before concluding "nothing there".

## Flags

| Flag | Does |
| --- | --- |
| `-u, --url` | Target URL (or `--stdin`, `--resume-from`, `--request-file`) |
| `-w, --wordlist` | Wordlist |
| `-x, --extensions` | Extensions to append, e.g. `-x php,bak,txt` (no leading dot) |
| `-d, --depth` | Max recursion depth (default 4; `0` = infinite) |
| `-n, --no-recursion` | Turn recursion **off** (one level only) |
| `--scan-dir-listings` | **Force scans to recurse into directory listings** |
| `-f, --add-slash` | Append `/` to each request — finds dirs that 404 without it |
| `-t, --threads` | Concurrent threads (default 50) |
| `-k, --insecure` | Skip TLS validation (self-signed certs — you'll want this a lot) |
| `-H, --headers` | Custom header, repeatable |
| `-b, --cookies` | Cookies — **authenticated scanning** |
| `-m, --methods` | HTTP methods beyond GET |
| `-r, --redirects` | Follow redirects |
| `-e, --extract-links` | Parse responses for more URLs to scan |
| `--dont-scan` | URL/regex to exclude (e.g. `logout`) |
| `--scope` | Extra in-scope domains/URLs |
| `--rate-limit` | Requests/sec per directory — set on production |
| `--time-limit` | Stop after e.g. `--time-limit 10m` |
| `-L, --scan-limit` | Cap concurrent directory scans |
| `-o, --output` | Write results to a file |
| `--resume-from` | Resume from a `.state` file |
| `-q, --quiet` | Hide bars/banner (good in tmux) |
| `--silent` | URLs only — good for piping |
| `-U, --update` | Self-update |

### Collectors & "do everything" modes

| Flag | Does |
| --- | --- |
| `-E, --collect-extensions` | Auto-discover extensions and add them to `-x` |
| `-B, --collect-backups` | Auto-request likely backup extensions for found URLs (`~`, `.bak`, `.old`, …) |
| `-g, --collect-words` | Harvest words from responses into the scan |
| `--smart` | `= --auto-tune --collect-words --collect-backups` |
| `--thorough` | `= --smart` + `--collect-extensions` + `--scan-dir-listings` — the maximal pass |
| `--auto-tune` | Lower the rate automatically when errors spike |
| `--burp` | Proxy through Burp at `127.0.0.1:8080` and set `--insecure` |

## Filtering out the noise

feroxbuster auto-filters wildcard responses, so you fiddle less than with gobuster — but when a target returns soft-200s:

| Flag | Does |
| --- | --- |
| `-s, --status-codes` | Only report these codes |
| `-C, --filter-status` | Hide these codes (e.g. `-C 404,403`) |
| `-S, --filter-size` | Hide these response sizes |
| `-W, --filter-words` | Hide by word count |
| `-N, --filter-lines` | Hide by line count |
| `-X, --filter-regex` | Hide responses matching a regex |
| `--filter-similar-to` | Hide pages similar to a given URL (soft-404 killer) |
| `-D, --dont-filter` | Turn the auto wildcard-filter **off** |

Method: note the size/words of a known-bogus path, then `-S`/`-W` it. For stubborn soft-404s, `--filter-similar-to https://TARGET/bogus`.

## feroxbuster vs gobuster vs ffuf

| | **feroxbuster** | gobuster | ffuf |
| --- | --- | --- | --- |
| Recursion | **Automatic, default** | None | `-recursion` (opt-in) |
| Directory listings | **`--scan-dir-listings`** | No | No |
| Soft-404 handling | Auto + `--filter-similar-to` | Manual | `-ac` |
| Collect backups/exts/words | **Built-in** | No | No |
| Resume a scan | **`--resume-from`** | No | No |
| Multiple wordlists | No | No | **Yes** |
| Fuzz params/headers/JSON | Paths mainly | Basic | **Best** |
| DNS / vhost | No | **Best** | Workable |

Rule of thumb: **feroxbuster for content discovery** (recursion wins), ffuf for parameters and anything needing matchers, gobuster for DNS/vhost. See [fuzz](fuzz.md) and [gobuster](gobuster.md).

## Defense / detection

- Signature is a burst of `404`s per source plus an alphabetical march through paths, now *per discovered directory* because of recursion. Alert on 404 **rate** per client IP.
- Return a consistent, uninformative 404; block `.git/`, `.env`, `.bak`, `.old`, `~` at the server, not just by not linking them. `--collect-backups`/`--scan-dir-listings` exist because these are so often left exposed.
- Disable directory listing (`Options -Indexes` on Apache, `autoindex off` on nginx) — `--scan-dir-listings` only pays off where it's left on.
- Never rely on an unguessable path as access control. See [Logging](../../Defense/Logging/README.md) and [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md).

## Related

[fuzz](fuzz.md) · [gobuster](gobuster.md) · [nmap](nmap.md) · [smb](../Protocols/smb.md) · [folder README](README.md) · [Web Overview](../Web/Web%20Overview.md) · [SQL Injection](../Web/SQL%20Injection.md) · [RCE](../Web/RCE.md)
