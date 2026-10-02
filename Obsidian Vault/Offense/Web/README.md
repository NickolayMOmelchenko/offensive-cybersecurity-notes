# Web

Web application testing: map the app, triage each input to the bug class it's likely to carry, then exploit it. One note per bug class, each ending with the detection/defense wording for the report.

Read [Web Overview](Web%20Overview.md) first — the recon and triage sections tell you which of the other notes to open.

## Tree

```text
Web/
├── README.md               <- you are here
├── Web Overview.md         index, methodology, recon, input -> bug triage
├── XSS.md                  cross-site scripting
├── SQL Injection.md        SQLi, manual and sqlmap
├── SSRF.md                 server-side request forgery
├── CSRF.md                 cross-site request forgery
└── RCE.md                  command injection, SSTI, upload -> shell
```

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [Web Overview](Web%20Overview.md) | Methodology, subdomain and live-host recon, stack fingerprinting, WAF detection, directory/parameter/JS endpoint discovery, and an input→likely-bug triage table | index |
| [XSS](XSS.md) | Reflected/stored/DOM, detection, a context→payload table, filter and WAF bypasses, weaponizing for real impact, blind XSS, tooling | medium |
| [SQL Injection](SQL%20Injection.md) | Injection types, detection, manual UNION / error-based / blind boolean and time-based, auth bypass, per-DBMS cheat columns, file read-write and RCE, then a full `sqlmap` reference — the extraction ladder, `--level`/`--risk`, hands-off crawling, and scoped `--dump` | longest |
| [SSRF](SSRF.md) | Where it hides, confirming it out-of-band, blind vs full-response, cloud metadata (IMDSv1 **and** the IMDSv2 token dance), filter bypasses, protocol smuggling | medium |
| [CSRF](CSRF.md) | When it's actually exploitable, building the PoC, token bypasses, SameSite and cookie defenses, JSON/CORS CSRF, tooling | medium |
| [RCE](RCE.md) | OS command injection (incl. blind, proved out-of-band or by timing), filter bypasses, reverse shells, SSTI detection and exploitation, file upload → execution | long |

## Reading order

1. [Web Overview](Web%20Overview.md) — recon, then use the triage table
2. Whichever bug class the triage pointed at
3. [RCE](RCE.md) last — it's usually where the other bugs end up

## Related

- Catching shells from an RCE: [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)
- After the shell: [Linux](../Linux/README.md) / [Windows](../Windows/README.md)
- SSRF into cloud metadata often yields the first credential for [AD](../AD/README.md)
