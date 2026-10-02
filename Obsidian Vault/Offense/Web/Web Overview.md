# Web — Offensive Notes Overview

Index and methodology for the web-application notes. Scope: testing a web app/API you are **authorized** to test — map it, find the injectable inputs, exploit the vuln class, prove impact, and write it up. Each vuln note pairs the attack with detection/defense so it works for the report and for blue team.

> Stay in scope (domains, APIs, accounts). Prove impact with the least-destructive evidence — a benign `id`, a Collaborator callback, a single test-account takeover — and get written approval before dumping real data, dropping a persistent shell, or pivoting internally.

## Contents

- [Methodology](#methodology)
- [Recon & mapping](#recon--mapping)
- [Parameter / content discovery](#parameter--content-discovery)
- [Input → likely bug (triage)](#input--likely-bug-triage)
- [Notes in this folder](#notes-in-this-folder)
- [Core tooling](#core-tooling)
- [Reporting](#reporting)

## Methodology

1. **Recon** — resolve scope, enumerate subdomains/hosts, fingerprint the stack (server, framework, WAF, DB).
2. **Map** — spider every page, form, parameter and API endpoint; capture an authenticated session in Burp.
3. **Test each input** against the vuln classes (below). Hit params, JSON, headers, cookies, path segments.
4. **Exploit & chain** — turn a finding into impact (e.g. [SSRF](SSRF.md) → cloud creds, [SQLi](SQL%20Injection.md) → [RCE](RCE.md), [XSS](XSS.md) → account takeover defeating [CSRF](CSRF.md)).
5. **Prove & document** — minimal PoC, affected endpoint, impact, remediation. Clean up anything you planted.

## Recon & mapping

```bash
# subdomains & live hosts
subfinder -d target.tld -silent | httpx -silent -title -tech-detect -status-code

# fingerprint the stack (also: Wappalyzer extension, whatweb)
whatweb https://target.tld
nuclei -u https://target.tld -t http/technologies/   # tech + known-CVE templates

# WAF present?  (changes every payload you'll try)
wafw00f https://target.tld
```

Then drive everything through **Burp** (or ZAP): browse the app logged in, let the proxy build the sitemap, and work from captured requests — far more reliable than hand-built ones.

## Parameter / content discovery

Hidden endpoints and params are where the bugs live.

```bash
# directories / files
ffuf -u https://target.tld/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt -mc 200,204,301,302,401,403
feroxbuster -u https://target.tld                      # recursive

# hidden GET/POST parameters
ffuf -u "https://target.tld/page?FUZZ=test" -w params.txt -fs 0        # -fs filter by size
arjun -u https://target.tld/page                       # param miner

# endpoints from JS files / history / wayback
katana -u https://target.tld -jc                       # crawl + parse JS
gau target.tld ; waybackurls target.tld                # archived URLs
```

## Input → likely bug (triage)

| The input looks like / does… | Test first |
| --- | --- |
| Echoed back into the page | [XSS](XSS.md) |
| Feeds a DB lookup / filter / sort | [SQL Injection](SQL%20Injection.md) |
| A URL / hostname the server fetches | [SSRF](SSRF.md) |
| A state-changing action on a cookie session | [CSRF](CSRF.md) |
| Passed to a shell / rendered as a template / deserialized / uploaded | [RCE](RCE.md) |
| File path / `include` | [RCE](RCE.md) (LFI→RCE) |

Always test the non-obvious inputs too: HTTP headers (`User-Agent`, `Referer`, `X-Forwarded-For`), cookies, JSON field names, and path segments.

## Notes in this folder

- [XSS](XSS.md) — run JS in a victim's browser (reflected/stored/DOM/blind, bypasses, weaponization)
- [SQL Injection](SQL%20Injection.md) — DB injection: manual per-DBMS, auth bypass, a commented **sqlmap** reference, WAF bypass
- [SSRF](SSRF.md) — make the server fetch your URL: cloud metadata, internal recon, gopher smuggling
- [CSRF](CSRF.md) — forge state-changing actions as a logged-in victim; token & SameSite bypasses
- [RCE](RCE.md) — command injection, template injection (SSTI), deserialization, file upload, LFI→RCE

## Core tooling

| Job | Tools |
| --- | --- |
| Intercept / manual testing | **Burp Suite**, OWASP ZAP |
| Recon / fingerprint | subfinder, httpx, whatweb, Wappalyzer, wafw00f |
| Content & param discovery | ffuf, feroxbuster, arjun, katana, gau |
| Vuln scanning | nuclei (templated), Burp Scanner |
| Per-class automation | sqlmap, dalfox/XSStrike, tplmap, commix, SSRFmap, Gopherus |
| Out-of-band | Burp Collaborator, interactsh |
| Shells after RCE | see [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) |

## Reporting

For each finding: **endpoint + parameter**, a minimal reproducible PoC (request/response or a short HTML page), the **concrete impact** (what data/action/access it yields), severity, and the fix from each note's *Defense / detection* section. Note anything you created (test accounts, uploaded files, shells) so it can be removed.
