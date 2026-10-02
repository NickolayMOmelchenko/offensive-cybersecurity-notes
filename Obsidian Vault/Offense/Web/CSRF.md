# Web — Cross-Site Request Forgery (CSRF)

Tricking a logged-in victim's browser into sending a state-changing request to the target, so the action runs **with their session**. Scope: authorized web testing only. Impact = any single state-changing action the victim can do: change email/password (→ account takeover), transfer funds, change settings, add an admin.

> A working CSRF PoC acts as the victim. Demonstrate it against a test account you control; don't fire it at real users. Pair with [XSS](XSS.md) when a token blocks you — XSS reads the token from the page and defeats CSRF entirely.

## Contents

- [When it's exploitable](#when-its-exploitable)
- [Build the PoC](#build-the-poc)
- [Token bypasses](#token-bypasses)
- [SameSite & other cookie defenses — bypasses](#samesite--other-cookie-defenses--bypasses)
- [JSON / CORS CSRF](#json--cors-csrf)
- [Tooling](#tooling)
- [Defense / detection (for the report)](#defense--detection-for-the-report)

## When it's exploitable

All three must hold:

1. **Cookie-based session** sent automatically by the browser (no `Authorization` header / no custom header required).
2. A **state-changing action** worth forging (email/password/settings/money).
3. **No unpredictable per-request token** — or the token can be bypassed ([below](#token-bypasses)) — and `SameSite` doesn't block the request.

Check the request in Burp: strip the anti-CSRF token and the `Referer`; if it still succeeds, it's vulnerable.

## Build the PoC

```html
<!-- GET-based action: just force the request (image auto-loads cross-site) -->
<img src="https://target.tld/account/delete?confirm=yes">

<!-- POST-based action: auto-submitting form (urlencoded, no token needed) -->
<form action="https://target.tld/account/email" method="POST" id="x">
  <input type="hidden" name="email" value="attacker@evil.com">
</form>
<script>document.getElementById('x').submit();</script>

<!-- No JS allowed? body onload submit -->
<body onload="document.forms[0].submit()">
```

Host the HTML, get the logged-in victim to open it. **Expected result:** the victim's email changes to yours; you then trigger a password reset → takeover. Burp's *Engagement tools → Generate CSRF PoC* builds this from any captured request.

`multipart/form-data` or `text/plain` bodies can be sent cross-site with a form too (no preflight) — useful when the endpoint accepts them.

## Token bypasses

Test these in order — many "protected" apps fall to one:

- **Token not validated on the server** — remove the token param entirely; if it still works, it's decorative.
- **Token validated only if present** — send an empty token (`csrf=`) or drop the field.
- **Token not tied to the session** — use a *valid token from your own account* in a request for the victim (static/pooled tokens).
- **Token tied to a non-session cookie** — if the token is validated against a cookie you can set (e.g. via a cookie-injection/subdomain), "double-submit" is bypassable: set both to the same value.
- **Method change** — endpoint accepts `GET` for a `POST` action (`?_method=POST` override, or just `GET`) where the token is only checked on POST.
- **Token in the body only** — move the action to GET/query where the token isn't checked.
- **Predictable/weak token** — reused, sequential, or a hash of something known.

## SameSite & other cookie defenses — bypasses

- **`SameSite=Lax` (modern default)** blocks cross-site POST but **allows top-level GET navigation**. If a sensitive action is reachable by GET (or method-override), a top-level `window.location`/link still carries the cookie.
- **`SameSite=None`** (or not set on older browsers) → classic CSRF fully works.
- **Same-site, not cross-site:** an **XSS or subdomain** you control is *same-site* — SameSite won't stop a request from there. Chain a subdomain takeover / XSS.
- **Lax + 2-minute window:** some browsers historically treated brand-new cookies as `None` for ~120s after login — a tight race, mostly historical.
- **Referer-based defense** — if the app checks `Referer`: try omitting it (`<meta name="referrer" content="no-referrer">`), or a permissive match (`https://target.tld.attacker.com`, or `Referer` containing the target as a substring).

## JSON / CORS CSRF

APIs taking `application/json` resist classic form CSRF (a form can't set that `Content-Type`, and JS cross-site hits CORS preflight). Bypass when:

- The endpoint **accepts `text/plain`** (or ignores `Content-Type`) — send JSON as a `text/plain` form body, no preflight:
  ```html
  <form action="https://target.tld/api/x" method="POST" enctype="text/plain">
    <input name='{"email":"attacker@evil.com","x":"' value='"}'>
  </form>
  ```
- **CORS is misconfigured** (`Access-Control-Allow-Origin` reflects your origin **and** `Allow-Credentials: true`) — then you can read responses too; test with a cross-origin `fetch(..., {credentials:'include'})`. This is a CORS finding as much as CSRF.

## Tooling

- **Burp Suite** — capture the request → *Generate CSRF PoC* (handles forms, auto-submit, multipart); test token/Referer removal in Repeater.
- **OWASP ZAP** — CSRF token detection and PoC generation.
- Browser dev tools — confirm which cookies are `SameSite`/`HttpOnly` and whether the token is bound to the session.

## Defense / detection (for the report)

- **Anti-CSRF tokens** — unpredictable, per-session (ideally per-request), validated server-side, tied to the user's session. Framework built-ins (synchronizer token) over home-grown.
- **`SameSite=Lax` or `Strict`** on session cookies (Lax is the sane default; Strict for the most sensitive), plus `Secure`.
- **Double-submit** only if the token cookie can't be set by an attacker (beware subdomain cookie injection); prefer the synchronizer pattern.
- **Require a custom header** (e.g. `X-Requested-With`) for state-changing API calls — can't be sent cross-site without CORS.
- **Re-authenticate / step-up** for the most sensitive actions (password/email change, payments).
- **Don't use GET for state changes**; validate `Origin`/`Referer` as defense-in-depth.
- **Detect:** state-changing requests with a foreign/absent `Origin`/`Referer`; missing-or-invalid CSRF token rates; a spike of the same action across many sessions from one referrer.

## Related

[Web Overview](Web%20Overview.md) · [XSS](XSS.md) (reads the token → beats CSRF defenses)
