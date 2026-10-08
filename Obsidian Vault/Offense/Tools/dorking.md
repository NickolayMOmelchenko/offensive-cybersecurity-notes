# Dorking

Using search-engine operators to find exposed files, misconfigurations and leaked data a target never meant to publish — **Google hacking**. It's *passive*: you query the search engine, not the target, so nothing hits their logs. The syntax is easy; the value is knowing **what to look for**. This note leans on the use cases people overlook, not the operator list.

> Authorized engagements / OSINT only. Finding exposed data is passive — *using* it (logging in, pulling a private DB) is not. Stay in scope.

## Contents

- [Operators (the quick reference)](#operators-the-quick-reference)
- [Use cases you'll overlook](#use-cases-youll-overlook)
- [Dork patterns by goal](#dork-patterns-by-goal)
- [Hunting creds, API keys & secrets](#hunting-creds-api-keys--secrets)
- [GitHub & code leaks](#github--code-leaks)
- [Shodan, Censys & favicon pivoting](#shodan-censys--favicon-pivoting)
- [Tools & the GHDB](#tools--the-ghdb)
- [Defense](#defense)
- [Related](#related)

## Operators (the quick reference)

| Operator | Finds | Operator | Finds |
| --- | --- | --- | --- |
| `site:` | One domain | `"..."` | Exact phrase |
| `inurl:` | String in URL | `-term` | Exclude |
| `intitle:` | String in title | `OR` / `\|` | Either |
| `intext:` | String in body | `*` | Any-word wildcard |
| `filetype:` / `ext:` | File type | `AROUND(n)` | Terms within n words |
| `cache:` | Google's cached copy | `before:` / `after:` | By date |

`site:` scopes almost every dork; the rest you stack onto it.

## Use cases you'll overlook

The operators are trivia. These are the angles that actually turn up findings and that most people skip:

**1. The data leaks *off* the target's domain.** The most valuable results aren't on `target.com` at all — they're on third-party services employees used and forgot. Check each:

```text
site:pastebin.com "target.com"              # dumped creds, configs, source
site:trello.com "Target Inc"                 # public boards with passwords, roadmaps
site:docs.google.com "target.com"            # world-readable Google Docs/Sheets
"target.com" site:scribd.com                 # uploaded internal documents
site:s3.amazonaws.com "target"               # open buckets (also blob.core.windows.net, storage.googleapis.com)
site:groups.google.com "target.com"          # internal discussion on public mailing lists
site:gitlab.com OR site:bitbucket.org "target"
```

**2. `cache:` and the Wayback Machine see what was taken down.** A file removed *today* is still in Google's cache and in `web.archive.org` for months. When you find a `403`/`404` on something interesting, pull the old copy — removed admin pages, old API docs, deleted employee lists, retired endpoints that still work.

```text
cache:target.com/old-admin
# then: web.archive.org/web/*/target.com/*   — browse every path ever archived
```

**3. Documents are a free username list.** `ext:pdf`/`docx`/`xlsx` on the target, downloaded and run through `exiftool`, leak **author names, internal usernames, software versions and local file paths** in their metadata. That's your naming convention (`jsmith`, `john.smith`) handed to [password spraying](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) for free — no interaction with the target at all.

**4. Find staging/dev before prod.** Pre-production is where auth is weakest and debug is on:

```text
site:target.com -www                         # everything that ISN'T the main site
inurl:(dev | staging | uat | test | qa | beta) site:target.com
```

**5. Swagger / API docs expose the whole attack surface.** Developers publish API docs they think are internal:

```text
site:target.com inurl:(swagger | api-docs | openapi | graphql | wsdl)
intitle:"Swagger UI" site:target.com
```

A live Swagger page is a map of every endpoint and parameter — feed it straight into [Web Overview → triage](../Web/Web%20Overview.md#input--likely-bug-triage).

**6. Error messages reveal the stack.** A reflected SQL error or stack trace tells you the DB, framework and sometimes a file path — before you send a single payload:

```text
site:target.com intext:("SQL syntax" | "stack trace" | "Warning: mysql" | "Fatal error")
```

**7. People, not just machines.** Google indexes LinkedIn/press better than LinkedIn's own search. Build an org chart and email format passively:

```text
site:linkedin.com/in "Target Inc"            # employees -> names -> email format -> spray/phish list
"@target.com" -site:target.com               # email addresses mentioned anywhere else
```

## Dork patterns by goal

Once you know what you're hunting, the ready-made patterns:

| Goal | Dork |
| --- | --- |
| Subdomains / scope | `site:*.target.com -www` |
| Directory listings | `site:target.com intitle:"index of"` |
| Login / admin panels | `site:target.com inurl:(login \| admin \| portal \| dashboard)` |
| Config & backups | `site:target.com ext:(env \| ini \| conf \| bak \| old \| sql)` |
| Creds in files | `site:target.com ext:(txt \| log \| sql) intext:(password \| pwd)` |
| Git / env exposure | `site:target.com inurl:(.git \| .env \| wp-config)` |
| Open redirects | `site:target.com inurl:(redirect \| url= \| next=)` |
| Leaked DB dumps | `site:target.com ext:sql intext:"INSERT INTO"` |

## Hunting creds, API keys & secrets

The specific craft of finding secrets, across every source. Two things make this far more effective than generic "password" searches:

**Search for the key's *signature*, not the word "key".** Every provider's tokens have a fixed prefix/shape — searching those finds live keys that no one labelled "api_key". Grep found files, JS, and code hosts for these:

| Provider | Pattern to search |
| --- | --- |
| AWS access key | `AKIA[0-9A-Z]{16}` |
| Google API | `AIza[0-9A-Za-z_-]{35}` |
| Google OAuth token | `ya29.` |
| Slack token / webhook | `xox[baprs]-...` · `hooks.slack.com/services/` |
| GitHub token | `ghp_...` (classic) · `github_pat_...` (fine-grained) |
| Stripe | `sk_live_...` · `rk_live_...` |
| Twilio | `SK[0-9a-f]{32}` · account `AC...` |
| SendGrid / Mailgun | `SG.` · `key-[0-9a-f]{32}` |
| npm / Heroku | `npm_...` · UUID in `.npmrc` / `_netrc` |
| Private keys | `-----BEGIN (RSA\|OPENSSH\|EC\|DSA\|PGP) PRIVATE KEY-----` |
| JWT | `eyJ` (the base64 of `{"`) — decode at jwt.io, check the claims |

```text
# drop a signature straight into a search
site:target.com (ext:js | ext:json | ext:env) "AKIA"
"AIza" site:target.com
intext:"-----BEGIN RSA PRIVATE KEY-----" site:target.com
```

**Keys hide in the front-end — the overlooked goldmine.** Developers hardcode API keys into client-side JavaScript assuming "no one reads minified JS." They do:

```bash
# pull every JS file the app serves, then grep the signatures above
katana -u https://target.tld -jc -silent | grep '\.js' | while read u; do curl -s "$u"; done \
  | grep -Eireo 'AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|sk_live_[0-9a-zA-Z]{24}|ghp_[0-9A-Za-z]{36}'
# or point SecretFinder / linkfinder at the bundles:
python3 SecretFinder.py -i https://target.tld -e
```

Google Maps keys, Firebase configs and Stripe publishable keys in JS are common — and a *restricted* key is low-impact while an *unrestricted* one bills the target or reads their data.

**Where else secrets sit** (each a dork or a place to look):

| Source | Find it with |
| --- | --- |
| Indexed secret files | `site:target.com ext:(env \| pem \| ppk \| sql \| log \| bak \| kdbx)` |
| Cloud cred files | `site:target.com (inurl:.aws/credentials \| inurl:.git-credentials \| inurl:.npmrc)` |
| CI/CD logs | public Jenkins/GitLab/Actions logs echo env vars — `site:target.com inurl:(jenkins \| actions) intext:token` |
| Open buckets | `site:s3.amazonaws.com target` → list the bucket; configs/dumps inside |
| Firebase DBs | `target.firebaseio.com/.json` — open DBs return everything |
| Paste / leak sites | `site:pastebin.com "target.com"` · ghostbin · controlc |
| Mobile apps | decompile the APK (`apktool`, `jadx`) — keys baked into the binary |

**Validate before you report — and before you get excited.** A found key may be dead, restricted or a honeypot. Check what it actually grants (read-only, never destructive, scope permitting):

```bash
aws sts get-caller-identity                 # does this AWS key work, and whose is it?
curl "https://maps.googleapis.com/maps/api/geocode/json?address=x&key=AIza..."   # Google key live?
curl -s https://api.github.com/user -H "Authorization: token ghp_..."            # GitHub token + scopes
```

**keyhacks** (GitHub) documents a safe validation + impact check for dozens of key types — the reference for "I found a key, now what."

**Has it already leaked?** Correlate target emails (from [the people angle](#use-cases-youll-overlook)) against breach data — **HaveIBeenPwned**, **Dehashed**, **IntelX**, **LeakCheck**. A reused breach password is a login, not just a finding. Record each in `evidence/credentials/` with its source; see [exfiltration of secrets](../Privilege%20Escalation/exfiltrationofsecrets.md) for on-host hunting once you're in.

## GitHub & code leaks

Developers commit secrets to public repos constantly — and it's often the single highest-value source. The web UI misses deleted/history commits, so automate it:

```text
"target.com" password          org:TargetOrg filename:.env
"target.com" api_key            filename:config.php dbpassword
```

Tools: **trufflehog**, **gitleaks**, **gitrob**, **github-dorks**. Check commit *history* (`git log -p`) and forks — a secret removed in `HEAD` is still in the history and in every fork made before the deletion. See also [exfiltration of secrets](../Privilege%20Escalation/exfiltrationofsecrets.md).

## Shodan, Censys & favicon pivoting

Dorking for exposed **devices and services**, not web pages — this is where the forgotten RDP/VNC/database/ICS box turns up, usually the softest target:

```text
# Shodan
hostname:target.com                          org:"Target Inc"
ssl.cert.subject.cn:"target.com"             port:3389                 # exposed RDP
http.favicon.hash:-1234567890                # find EVERY host sharing the target's favicon
```

The overlooked trick is **favicon hashing**: compute the hash of the target's favicon, then `http.favicon.hash:` finds every internet host serving that same icon — pulling in shadow IT, forgotten staging servers and regional assets that share no DNS with the main domain. Also do **certificate transparency** (`crt.sh/?q=target.com`) for subdomains Google never indexed. Feed the IPs into [nmap](nmap.md).

## Tools & the GHDB

- **[Google Hacking Database (GHDB)](https://www.exploit-db.com/google-hacking-database)** — Exploit-DB's curated dork library, by category (Files Containing Passwords, Sensitive Directories, …). The reference.
- **theHarvester** — emails/subdomains/hosts from many engines in one run.
- **recon-ng** — modular OSINT framework.
- **Pagodo / dorks-eye** — automate many dorks (throttle them; Google CAPTCHAs aggressive automation fast).

## Defense

- **`robots.txt` hides nothing** — it *advertises* your sensitive paths to anyone who reads it and doesn't stop indexing. Never treat it as access control.
- Assume anything on the public web is indexed, cached, and archived forever. Removing a file doesn't remove the cache or the Wayback copy — require auth, then use Search Console removal + `noindex`.
- **Scrub document metadata** before publishing (authors, paths, versions).
- Govern third parties: leaks on Trello/Pastebin/S3/GitHub are *your* exposure. Run GHDB categories and secret-scanners against your own org continuously — before an attacker does.
- See [Web Overview](../Web/Web%20Overview.md) and [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md).

## Related

[nmap](nmap.md) · [smb](../Protocols/smb.md) · [feroxbuster](feroxbuster.md) · [folder README](README.md) · [Web Overview](../Web/Web%20Overview.md) · [exfiltration of secrets](../Privilege%20Escalation/exfiltrationofsecrets.md) · [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md)
