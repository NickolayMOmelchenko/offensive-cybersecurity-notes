# Web — Offensive Notes Overview

Index and methodology for the web-application notes. Scope: testing a web app/API you are **authorized** to test — map it, find the injectable inputs, exploit the vuln class, prove impact, and write it up. Each vuln note pairs the attack with detection/defense so it works for the report and for blue team.

> Stay in scope (domains, APIs, accounts). Prove impact with the least-destructive evidence — a benign `id`, a Collaborator callback, a single test-account takeover — and get written approval before dumping real data, dropping a persistent shell, or pivoting internally.

## Contents

- [Methodology](#methodology)
- [Before you start — ask for two accounts](#before-you-start--ask-for-two-accounts)
- [Recon & mapping](#recon--mapping)
- [Parameter / content discovery](#parameter--content-discovery)
- [Input → likely bug (triage)](#input--likely-bug-triage)
- [Access control & IDOR](#access-control--idor)
- [APIs — REST & GraphQL](#apis--rest--graphql)
- [Authentication & session](#authentication--session)
- [Notes in this folder](#notes-in-this-folder)
- [Core tooling](#core-tooling)
- [Automation — scanners & pipelines](#automation--scanners--pipelines)
  - [Scanners](#scanners)
  - [Per-class automation](#per-class-automation)
  - [The glue — chaining them](#the-glue--chaining-them)
  - [Continuous monitoring](#continuous-monitoring)
  - [Full-chain frameworks](#full-chain-frameworks)
- [Reporting](#reporting)
- [Related](#related)

## Methodology

1. **Recon** — resolve scope, enumerate subdomains/hosts, fingerprint the stack (server, framework, WAF, DB).
2. **Map** — spider every page, form, parameter and API endpoint; capture an authenticated session in Burp.
3. **Test each input** against the vuln classes (below). Hit params, JSON, headers, cookies, path segments.
4. **Test each *object and action*** — not just inputs. Whose record is it, and who is allowed to call this? See [Access control & IDOR](#access-control--idor); this is the half that scanners miss.
5. **Exploit & chain** — turn a finding into impact (e.g. [SSRF](SSRF.md) → cloud creds, [SQLi](SQL%20Injection.md) → [RCE](RCE.md), [XSS](XSS.md) → account takeover defeating [CSRF](CSRF.md), IDOR → mass data access).
6. **Prove & document** — minimal PoC, affected endpoint, impact, remediation. Clean up anything you planted.

Steps 3 and 4 are different jobs. Step 3 asks *"is this input handled safely?"* and tooling helps a lot. Step 4 asks *"is this request authorized?"*, which needs two logged-in sessions and judgement — and it's where the findings that matter usually are.

## Before you start — ask for two accounts

Request this in the kick-off, because half the test is impossible without it and getting it later costs days:

- **Two accounts at the same privilege level** (user A, user B) — the only way to test horizontal access control. Note each one's object IDs.
- **One account per role** (user, manager, admin) — for vertical escalation.
- **An unauthenticated baseline** — know what the app looks like with no session at all.
- **Test data you're allowed to modify**, and a named contact for when you break something.
- **Confirmation of WAF/rate-limit posture** — whether it will be left on, and who to call when you get IP-banned mid-test.

Keep a scratch table of each account's identifiers (user id, org id, document ids, API keys). Every IDOR test is "swap A's identifier into B's request", and you can't do that from memory.

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

Two things worth doing before you start testing:

- **Walk every feature by hand, logged in, once.** Click through the whole app as a real user — signup, settings, upload, share, export, delete, payment. You're building the sitemap *and* learning what the app's objects are, which is what steps 3 and 4 both key off. Automated crawlers miss anything behind a multi-step flow.
- **Read the JavaScript.** Front-end bundles leak API routes, role names, feature flags and occasionally keys. `katana -jc` pulls them; then grep for `/api/`, `admin`, `role`, `token`, `secret`.

## Parameter / content discovery

Hidden endpoints and params are where the bugs live.

> Per-tool flag references: [fuzz](../Tools/fuzz.md) (ffuf, feroxbuster, wordlists) and [gobuster](../Tools/gobuster.md).

```bash
# directories / files — feroxbuster first: it RECURSES into found dirs automatically (dirb/gobuster don't)
feroxbuster -u https://target.tld                      # recursive by default + auto-filters wildcards; the go-to
feroxbuster -u https://target.tld -x php,bak -d 3 -k   # extensions, depth 3, ignore TLS errors
ffuf -u https://target.tld/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt -mc 200,204,301,302,401,403   # when you need matchers/filters
gobuster dir -u https://target.tld -w /usr/share/seclists/Discovery/Web-Content/common.txt   # simple + fast, but NO recursion

# hidden GET/POST parameters
ffuf -u "https://target.tld/page?FUZZ=test" -w params.txt -fs 0        # -fs filter by size
arjun -u https://target.tld/page                       # param miner

# endpoints from JS files / history / wayback
katana -u https://target.tld -jc                       # crawl + parse JS
gau target.tld ; waybackurls target.tld                # archived URLs

# API routes (different wordlists to web content — these are route-shaped, not file-shaped)
kiterunner scan https://target.tld -w routes-large.kite
ffuf -u https://target.tld/api/v1/FUZZ -w /usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt
```

**Fuzz with a session cookie.** An unauthenticated fuzz finds the login page; an authenticated one finds the admin panel. Pass `-H "Cookie: SESSION=..."` and re-run the interesting wordlists. Note `403` and `401` separately from `404` — "it exists but you can't have it" is a lead for the next section.

## Input → likely bug (triage)

Match what the input *does* to the class to test first. Classes without a note in this folder yet are marked — they're still part of the test, so don't let the folder's contents define your scope.

| The input looks like / does… | Test first |
| --- | --- |
| Echoed back into the page | [XSS](XSS.md) |
| Feeds a DB lookup / filter / sort | [SQL Injection](SQL%20Injection.md) |
| A URL / hostname the server fetches | [SSRF](SSRF.md) |
| A state-changing action on a cookie session | [CSRF](CSRF.md) |
| Passed to a shell / rendered as a template / deserialized / uploaded | [RCE](RCE.md) |
| File path / `include` | [RCE](RCE.md) (LFI→RCE) |
| **An id, uuid, filename or slug naming a record** | **[Access control & IDOR](#access-control--idor)** ← start here on any authenticated app |
| **An endpoint only an admin should be able to call** | **[Access control & IDOR](#access-control--idor)** (vertical) |
| XML, SVG, DOCX/XLSX or SAML upload | **XXE** *(no note yet)* — external entity → file read/SSRF |
| A redirect/`next`/`returnUrl` target | **Open redirect** *(no note yet)* — also chains into [SSRF](SSRF.md) and OAuth token theft |
| A JWT, or any client-held token/role claim | [Authentication & session](#authentication--session) — `alg:none`, weak HMAC key, `kid` abuse |
| A price, quantity, discount or state transition | **Business logic** *(no note yet)* — negative quantities, skipped steps, replayed coupons |
| Two requests that must not interleave (redeem, transfer, vote) | **Race condition** *(no note yet)* — Turbo Intruder single-packet attack |
| A cached response keyed on a header you control | **Cache poisoning/deception** *(no note yet)* — Param Miner |
| An email/username at signup that collides with an existing one | **Account takeover** via pre-registration / unverified-email flows *(no note yet)* |

Always test the non-obvious inputs too: HTTP headers (`User-Agent`, `Referer`, `X-Forwarded-For`, `Host`), cookies, JSON field names, path segments, and the HTTP **method** itself (`GET`→`POST`→`PUT`→`DELETE` on the same route).

## Access control & IDOR

The most commonly found and most commonly missed class — OWASP A01 — and the one no scanner will hand you, because only you know that document 1041 belongs to user B. No note of its own yet; this section is the method.

**The core test.** Capture a request as user A. Replay it with user B's session, changing nothing else. If B gets A's data, that's broken object-level authorization.

Four variants, in the order worth trying:

| Variant | Test |
| --- | --- |
| **Horizontal** | A's request + B's session. Does B read/modify A's object? |
| **Vertical** | An admin-only request + a normal user's session. Does it execute? |
| **Unauthenticated** | Drop the `Cookie`/`Authorization` header entirely. Does it still work? |
| **Method/verb** | Same URL, different method. `GET /api/user/1` is locked but `PUT` or `DELETE` isn't. |

**Where the identifiers hide.** The URL path (`/invoice/1041`), query string, JSON body, a nested field three levels down, a header (`X-Account-Id`), a cookie, a hidden form field, and the `jwt` payload. Change *one* at a time so you know what caused the result.

**When ids look unguessable.** A UUID is not access control. Harvest real ids from elsewhere in the app — a list endpoint, a search result, an export, a shared link, a notification email, an autocomplete, `/api/users?page=2`, or an error message that leaks the id of a record you can't read.

**Tells that it's worth digging:**

- The UI hides a button but the endpoint still exists (authorization in the front end only).
- `403` on the HTML page but `200` on the JSON API behind it.
- Sequential, predictable or enumerable ids anywhere.
- A role, tenant, `isAdmin` or org id present in a cookie, JWT or request body — i.e. client-supplied.
- Any multi-tenant app: cross-tenant access is the same bug with a bigger impact.

**Tooling.** Burp **Autorize** or **Auth Analyzer** — paste user B's session, browse as user A, and they flag every request B could also make. This turns a tedious manual pass into a continuous background check; set it up at the start of the engagement, not the end.

**Proving it without over-collecting.** One screenshot of B reading a single record belonging to A is a finding. Enumerating 50,000 records is a data-protection incident with your name on it. Show one, state that the ids are sequential, and stop — then say in the report how many were *reachable*, not how many you pulled.

## APIs — REST & GraphQL

Most of the app is now the API. The bug classes don't change, but the surface and the discovery do.

**REST:**

- Routes are route-shaped, not file-shaped — use API wordlists and `kiterunner`, not `common.txt`.
- Look for versioned siblings: `/api/v2/users` is hardened, `/api/v1/users` is still deployed and isn't.
- Check `/swagger.json`, `/openapi.json`, `/api-docs`, `/.well-known/`, `/graphql`. A published schema is a free, complete endpoint list — feed it straight into [triage](#input--likely-bug-triage).
- Mass assignment: add fields the client shouldn't set (`"role":"admin"`, `"verified":true`, `"balance":1000`) to a legitimate `PUT`/`PATCH` body.
- Rate limits and lockouts are frequently enforced on the web login and not on the API one.

**GraphQL:**

- **Introspection** is the whole schema if it's on: query `__schema`. If it's off, `clairvoyance` reconstructs it from error-message suggestions.
- One endpoint, many operations — a WAF rule keyed on URL path sees nothing. Authorization is per-resolver, so **test every mutation separately**; it's extremely common for one resolver to miss the check the others have.
- Nested queries are a DoS and a data-access path at once — deep nesting, aliases and batched operations also bypass per-request rate limiting.
- Tools: `graphw00f` (fingerprint the engine), `graphql-cop` (quick audit), **InQL** (Burp extension — turns the schema into testable requests).

## Authentication & session

No note of its own yet; the checks worth running on every app:

- **Registration/reset flows** — user enumeration from differing responses or timings, password-reset token predictability or reuse, reset links that don't expire or invalidate on use, host-header poisoning of the reset email.
- **Session handling** — does the session id rotate on login and privilege change? Is it invalidated server-side on logout and password change, or just dropped client-side?
- **JWTs** — `alg:none`, `HS256` signed with a guessable/public key, `RS256`→`HS256` confusion, `kid` path traversal, and above all whether claims like `role` or `user_id` are trusted without verification. `jwt_tool` covers these.
- **MFA** — can it be skipped by going straight to the post-MFA endpoint, is the code rate-limited, is it reusable, does "remember this device" accept an attacker-chosen token?
- **OAuth/SSO** — `redirect_uri` validation (prefix vs exact match), missing/replayable `state` (CSRF on the callback), implicit-flow token leakage via `Referer`.

## Notes in this folder

- [XSS](XSS.md) — run JS in a victim's browser (reflected/stored/DOM/blind, bypasses, weaponization)
- [SQL Injection](SQL%20Injection.md) — DB injection: manual per-DBMS, auth bypass, a full **sqlmap** automation/extraction reference, WAF bypass
- [SSRF](SSRF.md) — make the server fetch your URL: cloud metadata, internal recon, gopher smuggling
- [CSRF](CSRF.md) — forge state-changing actions as a logged-in victim; token & SameSite bypasses
- [RCE](RCE.md) — command injection, template injection (SSTI), deserialization, file upload, LFI→RCE

**Not written up yet**, but part of a real test — method above, in [triage](#input--likely-bug-triage), or linked out: access control/IDOR (covered [here](#access-control--idor) for now), XXE, open redirect, business logic, race conditions, cache poisoning, and [authentication & session](#authentication--session). The [PortSwigger Web Security Academy](https://portswigger.net/web-security) has a free lab track for each.

## Core tooling

| Job | Tools |
| --- | --- |
| Intercept / manual testing | **Burp Suite**, OWASP ZAP |
| Recon / fingerprint | subfinder, httpx, whatweb, Wappalyzer, wafw00f |
| Content & param discovery | ffuf, feroxbuster, arjun, katana, gau, kiterunner |
| Vuln scanning | **nuclei** (templated, `-as`, `-dast`), Burp Scanner, ZAP (`zap-baseline.py`), jaeles, nikto |
| CMS / stack-specific | wpscan, droopescan, joomscan, testssl.sh, sslyze |
| Pipeline glue | **anew**, qsreplace, gf, unfurl, notify, naabu, dnsx, amass |
| **Access control / IDOR** | **Burp Autorize**, Auth Analyzer |
| APIs & GraphQL | graphw00f, graphql-cop, clairvoyance, InQL, Postman, schemathesis, restler-fuzzer |
| Tokens | jwt_tool |
| Race conditions / hidden params | Turbo Intruder, Param Miner, x8, paramspider |
| Per-class automation | sqlmap/ghauri, dalfox/XSStrike, tplmap, commix, SSRFmap, Gopherus, Corsy, crlfuzz, NoSQLMap — full table in [Automation](#automation--scanners--pipelines) |
| Out-of-band | Burp Collaborator, interactsh |
| Shells after RCE | see [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) |

Burp's free Community edition covers everything here except the scanner and saved projects; Autorize, Auth Analyzer, InQL, Turbo Intruder and Param Miner are all free BApp Store extensions.

## Automation — scanners & pipelines

Automation's job is to clear the shallow findings fast so your hours go to [access control](#access-control--idor) and logic, which no tool will find for you. Everything below is **scope-bound**: feed it an explicit target list you're authorized to test, never a wildcard or a dork.

### Scanners

```bash
# nuclei — the workhorse. Three modes worth knowing:
nuclei -u https://target.tld                                  # all default templates (known CVEs, misconfigs, exposures)
nuclei -u https://target.tld -as                              # -as = automatic scan: fingerprint the stack, run only matching templates
nuclei -u https://target.tld -dast                            # fuzzing/DAST templates (XSS, SQLi, SSTI, LFI in params) — OFF by default
nuclei -list live.txt -severity medium,high,critical -o nuclei.txt
nuclei -list live.txt -t ~/my-templates/ -H "Cookie: SESSION=..."   # your own templates, authenticated

# OWASP ZAP, scriptable — good for CI and for a free second opinion to Burp
docker run -t ghcr.io/zaproxy/zaproxy zap-baseline.py -t https://target.tld -r zap.html
docker run -t ghcr.io/zaproxy/zaproxy zap-full-scan.py -t https://target.tld     # active scan, much louder

# CMS-specific — always run these if the fingerprint says WordPress/Joomla/Drupal
wpscan --url https://target.tld --enumerate vp,vt,u --api-token TOKEN   # vuln plugins/themes, users
droopescan scan drupal -u https://target.tld
joomscan -u https://target.tld

# TLS / transport
testssl.sh https://target.tld
sslyze target.tld

# Legacy but still turns up forgotten files and old server bugs
nikto -h https://target.tld

# Source available? SAST beats black-box for injection sinks
semgrep --config=p/owasp-top-ten .
```

### Per-class automation

| Class | Tools |
| --- | --- |
| SQLi | **sqlmap** (see [SQL Injection](SQL%20Injection.md)), **ghauri** (lighter, good on blind) |
| NoSQL injection | NoSQLMap, nosqli |
| XSS | **dalfox** (fast, pipeline-friendly), XSStrike |
| SSTI | tplmap, SSTImap |
| Command injection | commix |
| SSRF | SSRFmap, Gopherus (gopher:// payload gen) |
| CORS misconfig | Corsy |
| CRLF injection | crlfuzz |
| Request smuggling | smuggler.py, Burp **HTTP Request Smuggler** |
| JWT | jwt_tool |
| Hidden parameters | **x8** (fast), arjun, paramspider, Burp **Param Miner** |
| 401/403 bypass | nomore403, byp4xx |
| API from a schema | **schemathesis** (property-based from OpenAPI/GraphQL), restler-fuzzer (stateful) |
| Secrets in JS/bundles | trufflehog, gitleaks, SecretFinder |
| Race conditions | Burp **Turbo Intruder** (single-packet attack) |

### The glue — chaining them

The useful automation isn't any one scanner, it's a pipeline. These four small tools do most of the work:

- **`anew`** — append only lines you haven't seen. Turns any command into a diff, which is what makes monitoring possible.
- **`qsreplace`** — swap every query-string value for a payload.
- **`gf`** — saved grep patterns for candidate params (`gf xss`, `gf ssrf`, `gf redirect`, `gf sqli`).
- **`unfurl`** — split URLs into domains/paths/params to normalize and dedupe.

```bash
# scope -> live hosts -> crawled URLs, each stage deduped and resumable
subfinder -d target.tld -silent | dnsx -silent | httpx -silent | anew live.txt
katana -list live.txt -jc -silent | anew urls.txt
gau target.tld | anew urls.txt                                  # add archived URLs

# candidate params by class, then a reflection check (NOT proof of execution — verify by hand)
cat urls.txt | gf xss | qsreplace '"><svg onload=alert(1)>' \
  | httpx -silent -mc 200 -ms 'onload=alert(1)' | anew xss-candidates.txt

# hand the crawl to the fuzzing engine instead of guessing params
nuclei -list urls.txt -dast -severity medium,high,critical

# port/service sweep of the in-scope hosts, piped into http probing
naabu -list hosts.txt -silent | httpx -silent -title -tech-detect | anew services.txt
```

A reflection match is a *lead*. Confirm execution in a browser before it goes in the report — `dalfox` and Burp are better at that last step than a `grep`.

### Continuous monitoring

Because `anew` only prints new lines, the same pipeline on a schedule becomes an alerting system — useful on long engagements and continuous-testing scopes:

```bash
# cron: only ever notifies on assets that appeared since last run
subfinder -d target.tld -silent | httpx -silent | anew live.txt | notify -bulk
nuclei -list live.txt -severity high,critical -silent | notify -bulk     # notify -> Slack/Discord/Telegram
```

### Full-chain frameworks

`reconftw` and `osmedeus` wire the whole recon→scan chain together, and `axiom` distributes it across throwaway cloud boxes. They're a fast start and a convenient way to melt a scope you didn't mean to touch — read what they actually launch before pointing one at a client, keep the target list explicit, and expect to tune out the noise. On a tightly scoped single-app test, the hand-built pipeline above is usually less work than taming one of these.

> **Two standing cautions.** Active scanners submit forms, follow destructive links and can fire thousands of requests a minute — agree a rate limit and a maintenance window, and keep `--delay`/`-rl` flags on anything pointed at production. And every finding a scanner reports is a *candidate*: reproduce it by hand before it reaches the report, because a false positive you forwarded costs more credibility than the finding was worth.

## Reporting

For each finding: **endpoint + parameter**, a minimal reproducible PoC (request/response or a short HTML page), the **concrete impact** (what data/action/access it yields), severity, and the fix from each note's *Defense / detection* section. Note anything you created (test accounts, uploaded files, shells) so it can be removed.

Two things that make a web report land:

- **Impact in the client's terms, not the class name.** "IDOR on `/api/invoice/{id}`" is a label; "any logged-in customer can read every other customer's invoices, including names and addresses — ids are sequential, so all 40,000 are reachable" is a finding someone will fund a fix for.
- **Say what you did and didn't touch.** Which account you used, how many records you accessed, what you uploaded and whether you removed it. For access-control and data-exposure findings this is also the client's breach-assessment input, so be precise.

## Related

[SQL Injection](SQL%20Injection.md) · [XSS](XSS.md) · [SSRF](SSRF.md) · [CSRF](CSRF.md) · [RCE](RCE.md) · [folder README](README.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md)
