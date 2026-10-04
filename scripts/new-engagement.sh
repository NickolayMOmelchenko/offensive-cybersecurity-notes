#!/usr/bin/env bash
#
# new-engagement.sh — scaffold a pentest / HTB engagement directory.
#
# Pull this repo onto the attack box and run it at the start of every engagement:
#   ./scripts/new-engagement.sh "Acme Company"
#   ./scripts/new-engagement.sh --htb Lame
#
# No dependencies, portable bash (works on Kali and on macOS's bash 3.2).
# Idempotent: existing files are never overwritten, only missing ones are added,
# so it is safe to re-run mid-engagement to add another engagement type.

set -euo pipefail

PROG="$(basename "$0")"
RULE="============================================================"

# ---------------------------------------------------------------- defaults ---
BASE="${PENTEST_BASE:-./Projects}"   # where Projects/ lives; override with -b
TYPES="EPT,IPT"                      # one subtree per type
CLIENT=""
DRY_RUN=0
WRITE_GITIGNORE=1
SHOW_TREE=1

usage() {
  cat <<HELP_EOF
$PROG — scaffold a pentest / HTB engagement directory.

  $PROG [options] <client-or-box-name>

OPTIONS
  -b, --base DIR     Where the Projects/ tree lives.
                     Default: \$PENTEST_BASE, else ./Projects
  -t, --types LIST   Comma-separated engagement types, one subtree each.
                     Default: EPT,IPT   (External / Internal Penetration Test)
      --htb          Hack The Box mode: base <base>/HTB, single "box" subtree.
      --no-gitignore Don't drop a .gitignore that keeps client data out of git.
      --no-tree      Don't print the tree at the end.
  -n, --dry-run      Show what would be created, create nothing.
  -h, --help         This text.

EXAMPLES
  $PROG "Acme Company"                      # ./Projects/Acme Company/{EPT,IPT}/...
  $PROG -t EPT "Acme Company"               # external only
  $PROG -t "EPT,IPT,WEBAPP" "Acme Company"  # add your own type
  $PROG --htb Lame                          # ./Projects/HTB/Lame/box/...
  $PROG -b ~/engagements "Acme Company"     # somewhere else entirely
  PENTEST_BASE=~/engagements $PROG "Acme"

WHAT IT CREATES
  <base>/<client>/<TYPE>/
    engagement.txt              scope-of-work, authorization, contacts, status log
    findings.txt                running findings, written as you go
    scope/scope.txt             in/out of scope, constraints, provided accounts
    scans/scans.txt             naming convention, useful invocations, index
    logs/commands.txt           timestamped command log
    evidence/credentials/credentials.txt
    evidence/data/data.txt      what was reachable vs what you actually accessed
    evidence/screenshots/screenshots.txt
    tools/tools.txt             what you put on target, and whether you removed it
HELP_EOF
}

die() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 1; }

# ------------------------------------------------------------------- args ----
while [ $# -gt 0 ]; do
  case "$1" in
    -b|--base)      [ $# -ge 2 ] || die "--base needs a directory";  BASE="$2"; shift 2 ;;
    -t|--types)     [ $# -ge 2 ] || die "--types needs a list";      TYPES="$2"; shift 2 ;;
    --htb)          BASE="$BASE/HTB"; TYPES="box";                   shift ;;
    --no-gitignore) WRITE_GITIGNORE=0;                               shift ;;
    --no-tree)      SHOW_TREE=0;                                     shift ;;
    -n|--dry-run)   DRY_RUN=1;                                       shift ;;
    -h|--help)      usage; exit 0 ;;
    -*)             die "unknown option: $1  (try --help)" ;;
    *)
      [ -z "$CLIENT" ] || die "unexpected argument: $1  (quote names with spaces)"
      CLIENT="$1"; shift ;;
  esac
done

if [ -z "$CLIENT" ]; then usage >&2; exit 1; fi
case "$CLIENT" in
  */*)  die "client name must not contain a path separator: $CLIENT" ;;
  .|..) die "invalid client name: $CLIENT" ;;
esac

TODAY="$(date +%F)"

# ------------------------------------------------------------- primitives ----
created_dirs=0; created_files=0; skipped_files=0
type_count=0; last_type=""

mkdirp() {
  if [ -d "$1" ]; then return 0; fi
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  + dir   %s\n' "$1"
  else
    mkdir -p "$1"
  fi
  created_dirs=$((created_dirs + 1))
}

# write <path> <<EOF ... EOF   — never clobbers an existing file
write() {
  path="$1"
  if [ -e "$path" ]; then
    printf '  = keep  %s\n' "$path"
    skipped_files=$((skipped_files + 1))
    cat >/dev/null            # drain the heredoc so the caller still works
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    cat >/dev/null
  else
    cat >"$path"
  fi
  printf '  + file  %s\n' "$path"
  created_files=$((created_files + 1))
}

# -------------------------------------------------------------- scaffold -----
scaffold_type() {
  root="$1"; client="$2"; etype="$3"

  mkdirp "$root"
  mkdirp "$root/evidence/credentials"
  mkdirp "$root/evidence/data"
  mkdirp "$root/evidence/screenshots"
  mkdirp "$root/logs"
  mkdirp "$root/scans"
  mkdirp "$root/scope"
  mkdirp "$root/tools"

  write "$root/engagement.txt" <<ENG_EOF
ENGAGEMENT: $client — $etype
$RULE

Created:                $TODAY
Client:                 $client
Engagement type:        $etype
Start date:
End date:
Report due:

AUTHORIZATION
-------------
Do not send a single packet until this block is filled in and the authorization is
on file. "They said it was fine on a call" is not authorization.

Authorizing party:
Signed authorization:       (file path / ticket reference)
Rules of engagement doc:
Permitted testing window:
Explicitly permitted:       (exploitation? pivoting? persistence? password spraying?)
Explicitly prohibited:      (DoS, social engineering, physical, prod data changes)

CONTACTS
--------
Primary contact:
Technical contact:
Emergency / break-glass:    (who you call if you take something down, out of hours)
Escalation path:
Blue team aware?            (yes / no — decides whether you are testing detection)

YOUR INFRASTRUCTURE
-------------------
Attack box:
Source IP(s):               (hand these over so the client can attribute traffic)
VPN / access method:
Jump host:

DELIVERABLES
------------
Report format:
Retest included?
Data-handling / destruction terms:

STATUS LOG
----------
$TODAY  scaffold created
ENG_EOF

  write "$root/findings.txt" <<'FIND_EOF'
FINDINGS
========
One block per finding. Write it when you find it — reconstructing a finding a week
later from a scan file costs far more than typing it now.

Severity is impact x exploitability, in the client's terms. "Unauthenticated RCE on
an internet-facing host" is Critical; "missing security header" is Informational no
matter what the scanner badged it.

----------------------------------------------------------------------------
#001  <short title — the thing that is wrong, not the tool that found it>

  Severity:       Critical | High | Medium | Low | Info
  Affected:       host / URL / endpoint / parameter / account
  Discovered:     <UTC timestamp>

  Summary:
      What is wrong, in one or two sentences.

  Impact:
      What this actually gets an attacker, in the client's own terms. Not
      "SQL injection" — "any anonymous visitor can read the full customer
      table, including names, addresses and password hashes".

  Reproduction:
      Minimal steps or a single request. Must be something the client can run.

  Evidence:
      evidence/screenshots/<file>
      scans/<file>
      logs/commands.txt @ <timestamp>

  Remediation:
      The actual fix, plus the defensive note from the matching vault note.

  Status:         open | reported | retested | fixed | risk-accepted
----------------------------------------------------------------------------
FIND_EOF

  write "$root/scope/scope.txt" <<SCOPE_EOF
SCOPE — $client / $etype
$RULE

Confirm every line of this in writing before testing. ANYTHING NOT LISTED AS IN
SCOPE IS OUT OF SCOPE. When you find something adjacent to but not inside scope,
stop and ask — do not "just check".

IN SCOPE
--------
# One per line: CIDR, IP, hostname, URL, application, cloud account, AD domain.
# Note who confirmed it and when, so you can prove it later.
#
#   10.10.10.0/24            confirmed by <name> on <date>
#   app.acme.tld             confirmed by <name> on <date>


OUT OF SCOPE
------------
# Be explicit. Third-party / SaaS, shared hosting, prod databases, anything the
# client does not own, and any host they have flagged as fragile.


CONSTRAINTS
-----------
Testing window:             (dates + hours, and the timezone)
Rate limiting required?
Fragile hosts:              (do not scan hard / do not exploit)
Change freeze:
Prohibited techniques:
Data you may NOT exfiltrate or retain:

PROVIDED ACCESS
---------------
# Ask for TWO accounts at the same privilege level plus one per role — without
# them you cannot test access control at all. See the Web Overview vault note.
#
# USERNAME            ROLE          WORKS ON              PROVIDED BY / DATE
# ------------------  ------------  --------------------  ------------------


SCOPE CHANGES
-------------
# DATE  WHAT CHANGED                              AUTHORIZED BY
# ----  ----------------------------------------  -------------
SCOPE_EOF

  write "$root/scans/scans.txt" <<'SCAN_EOF'
SCANS
=====
Raw tool output lives in this folder. Keep it RAW — never hand-edit a scan file.
Parse or summarise elsewhere; the original is your evidence.

NAMING
------
<date>-<tool>-<target>.<ext>
    2026-10-03-nmap-10.10.10.0_24.gnmap
    2026-10-03-nuclei-app.acme.tld.txt

Replace / and : in targets with _ so the filenames stay portable.

USEFUL INVOCATIONS
------------------
# nmap — always -oA, so you get .nmap/.gnmap/.xml and can grep or re-import later
nmap -sC -sV -oA scans/$(date +%F)-nmap-<target> <target>
nmap -p- --min-rate 1000 -oA scans/$(date +%F)-nmap-allports-<target> <target>
nmap -sU --top-ports 100 -oA scans/$(date +%F)-nmap-udp-<target> <target>

# web
nuclei -list scope/live.txt -severity medium,high,critical \
       -o scans/$(date +%F)-nuclei.txt
ffuf -u https://<target>/FUZZ -w <wordlist> \
     -o scans/$(date +%F)-ffuf-<target>.json

# AD
bloodhound-python -d <domain> -u <user> -p <pass> -c All \
                  --zip -ni <dc-ip>      # move the zip into scans/

INDEX
-----
Keep this current — a folder of 40 scan files with no index is unusable.

FILE                                        TOOL      TARGET              NOTES
------------------------------------------  --------  ------------------  -----
SCAN_EOF

  write "$root/logs/commands.txt" <<'LOG_EOF'
COMMAND LOG
===========
Every command you run against the client, timestamped in UTC. This is:
  - your defence if something breaks ("show me exactly what you ran at 14:32")
  - what makes a finding reproducible
  - the record you need for an accurate timeline in the report

Log the whole session automatically:
    script -q -a logs/$(date +%F)-shell.log      # Linux / Kali
    script -a  logs/$(date +%F)-shell.log        # macOS
    # or, in tmux:  tmux pipe-pane -o 'cat >> logs/tmux.log'

Or append one line at a time — worth a shell alias:
    log() { echo "$(date -u +%FT%TZ)  $*" >> logs/commands.txt; }

UTC TIMESTAMP         TARGET               COMMAND / ACTION                        RESULT
--------------------  -------------------  --------------------------------------  ------
LOG_EOF

  write "$root/evidence/credentials/credentials.txt" <<'CRED_EOF'
CREDENTIALS
===========
*** SENSITIVE — CLIENT DATA ***
Do not commit this to git. Do not paste it into a chat tool, an LLM, a pastebin or a
ticket. Keep it on the engagement volume only, and destroy it per the data-handling
terms in engagement.txt once the report is accepted.

SOURCE                       USERNAME           SECRET (hash or password)   WORKS ON              CRACKED  NOTES
---------------------------  -----------------  --------------------------  --------------------  -------  -----

Record WHERE each credential came from — a credential with no provenance can't go in
the report, and "works on" is what turns it into a finding.

Hashes go to the Password Attacks & Brute Forcing note for mode and wordlist choice.
Record the hashcat mode and whether it cracked, not just the plaintext.
CRED_EOF

  write "$root/evidence/data/data.txt" <<'DATA_EOF'
DATA ACCESSED
=============
*** SENSITIVE — CLIENT DATA ***
Record what you could reach and what you actually touched. Do NOT retain client data
here unless you have written approval; a description beats a copy.

This is the client's breach-assessment input, so be precise and conservative. The way
to prove a data-exposure finding is one record, plus the count of records that were
*reachable* — not a full dump.

WHAT WAS REACHABLE            WHAT YOU ACTUALLY ACCESSED      RECORDS  WHERE IT IS NOW   UTC DATE
----------------------------  ------------------------------  -------  ----------------  --------


DESTRUCTION LOG
---------------
# WHAT                        DESTROYED (UTC)     HOW                 WITNESS / REF
# --------------------------  ------------------  ------------------  -------------
DATA_EOF

  write "$root/evidence/screenshots/screenshots.txt" <<'SHOT_EOF'
SCREENSHOT INDEX
================
A screenshot nobody can caption is not evidence. Name the file for what it proves,
and index it here while you still remember.

NAMING
------
<nnn>-<finding-slug>.png
    001-nmap-open-smb.png
    004-idor-invoice-read-as-user-b.png

CAPTURE CHECKLIST
-----------------
  - Include the URL bar / prompt / hostname so the target is visible in frame.
  - Include a timestamp (terminal clock, or the response's Date header).
  - Show the logged-in identity when the finding is about authorization.
  - Redact real customer data before it reaches the report; keep an unredacted
    original here only if the data-handling terms allow it.

FILE                                WHAT IT PROVES                                  FINDING  TAKEN (UTC)
----------------------------------  ----------------------------------------------  -------  -----------
SHOT_EOF

  write "$root/tools/tools.txt" <<'TOOL_EOF'
TOOLS & ARTIFACTS
=================

ON TARGET — YOU MUST REMOVE ALL OF THIS
---------------------------------------
Everything you upload, install, create or change on a client system. Fill in the
REMOVED column before you write the report, and list anything still outstanding in
the report itself so the client can finish the cleanup.

WHAT                      PATH ON TARGET                      HOST              ADDED (UTC)     REMOVED (UTC)
------------------------  ----------------------------------  ----------------  --------------  -------------


Also track: test accounts created, groups/ACLs modified, services installed,
scheduled tasks or cron entries, firewall rules, uploaded webshells, SSH keys added
to authorized_keys, and any password you changed.

LOCAL TOOLING USED
------------------
Versions matter for reproducibility — a finding that depends on a tool version needs
that version in the report.

TOOL                 VERSION          USED FOR
-------------------  ---------------  ----------------------------------------
TOOL_EOF
}

# ----------------------------------------------------------------- build -----
CLIENT_ROOT="$BASE/$CLIENT"

printf '%s: scaffolding %s\n' "$PROG" "$CLIENT_ROOT"
if [ "$DRY_RUN" -eq 1 ]; then
  printf '%s: DRY RUN — nothing will be written\n' "$PROG"
fi

mkdirp "$BASE"
mkdirp "$CLIENT_ROOT"

OLDIFS="$IFS"
IFS=','
for t in $TYPES; do
  IFS="$OLDIFS"
  t="$(printf '%s' "$t" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  if [ -n "$t" ]; then
    scaffold_type "$CLIENT_ROOT/$t" "$CLIENT" "$t"
    type_count=$((type_count + 1))
    last_type="$t"
  fi
  IFS=','
done
IFS="$OLDIFS"

if [ "$WRITE_GITIGNORE" -eq 1 ]; then
  write "$CLIENT_ROOT/.gitignore" <<'GI_EOF'
# Client data must never reach a git remote.
#
# This ignores everything, re-allows directories so git can descend, then re-allows
# only the .txt scaffolding. Scan output, screenshots, dumps, pcaps, key material and
# loot are therefore ignored by default — you have to add them deliberately with
# `git add -f`, which is the point.
*
!*/
!.gitignore
!*.txt

# Want the screenshots tracked? Uncomment below — but check the remote is private
# and that the data-handling terms allow it first.
# !evidence/screenshots/*.png
GI_EOF
fi

# ------------------------------------------------------------------ report ---
printf '\n%s: %d directories, %d files created' "$PROG" "$created_dirs" "$created_files"
if [ "$skipped_files" -gt 0 ]; then
  printf ', %d left as they were' "$skipped_files"
fi
printf '\n'

if [ "$SHOW_TREE" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  printf '\n'
  if command -v tree >/dev/null 2>&1; then
    tree -a "$CLIENT_ROOT"
  else
    find "$CLIENT_ROOT" | sort | sed -e 's|[^/]*/|  |g'
  fi
fi

if [ "$DRY_RUN" -eq 0 ]; then
  if [ "$type_count" -eq 1 ]; then
    where="$CLIENT_ROOT/$last_type"
  else
    where="$CLIENT_ROOT/<TYPE>"
  fi
  cat <<NEXT_EOF

Next:
  1. Fill in "$where/engagement.txt" — the authorization block first.
  2. Fill in "$where/scope/scope.txt" and get it confirmed in writing.
  3. Start the command log:
       script -q -a "$where/logs/$TODAY-shell.log"
NEXT_EOF
fi
