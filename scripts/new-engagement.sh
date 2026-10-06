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
CHECK_TOOLS=1        # check the toolchain as part of scaffolding
INSTALL_TOOLS=0      # only ever installs when asked
CHECK_ONLY=0
ASSUME_YES=0

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
      --no-tools     Skip the toolchain check.
      --check-tools  Only check the toolchain, then exit. No scaffolding.
      --install-tools Install the tools that are missing (asks first).
  -y, --yes          Don't prompt before installing. (--dry-run still installs nothing.)
  -h, --help         This text.

EXAMPLES
  $PROG "Acme Company"                      # ./Projects/Acme Company/{EPT,IPT}/...
  $PROG -t EPT "Acme Company"               # external only
  $PROG -t "EPT,IPT,WEBAPP" "Acme Company"  # add your own type
  $PROG --htb Lame                          # ./Projects/HTB/Lame/box/...
  $PROG -b ~/engagements "Acme Company"     # somewhere else entirely
  PENTEST_BASE=~/engagements $PROG "Acme"
  $PROG --check-tools                       # just audit the attack box
  $PROG --install-tools "Acme Company"      # scaffold and fill in what's missing

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
    tools/installed-versions.txt  auto-generated inventory of your local toolchain
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
    --no-tools)     CHECK_TOOLS=0;                                   shift ;;
    --check-tools)  CHECK_ONLY=1;                                    shift ;;
    --install-tools) INSTALL_TOOLS=1;                                shift ;;
    -y|--yes)       ASSUME_YES=1;                                    shift ;;
    -h|--help)      usage; exit 0 ;;
    -*)             die "unknown option: $1  (try --help)" ;;
    *)
      [ -z "$CLIENT" ] || die "unexpected argument: $1  (quote names with spaces)"
      CLIENT="$1"; shift ;;
  esac
done

if [ -z "$CLIENT" ] && [ "$CHECK_ONLY" -eq 0 ]; then usage >&2; exit 1; fi
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

# ----------------------------------------------------------- toolchain ------
# One record per tool:  group | kind | check | apt | brew | fallback
#   kind     bin = look for it on PATH;  dir = look for a directory
#   check    binary name, or colon-separated candidate paths for kind=dir
#   apt      Debian/Kali package, "-" if none
#   brew     Homebrew formula, "cask:NAME" for a cask, "-" if none
#   fallback how to get it when the package manager has no entry
TOOLS='
core|bin|nmap|nmap|nmap|-
core|bin|tmux|tmux|tmux|-
core|bin|vim|vim|vim|-
core|bin|git|git|git|-
core|bin|curl|curl|curl|-
core|bin|jq|jq|jq|-
core|bin|python3|python3|python@3.13|-
core|bin|pipx|pipx|pipx|python3 -m pip install --user pipx
wordlists|dir|/usr/share/seclists:/usr/share/wordlists/seclists:/opt/seclists:$HOME/seclists|seclists|-|git clone --depth 1 https://github.com/danielmiessler/SecLists ~/seclists
recon|bin|whatweb|whatweb|-|git clone --depth 1 https://github.com/urbanadventurer/WhatWeb ~/tools/WhatWeb
recon|bin|nuclei|nuclei|nuclei|-
recon|bin|subfinder|subfinder|subfinder|-
recon|bin|httpx|httpx-toolkit|httpx|-
recon|bin|katana|katana|katana|-
web|bin|ffuf|ffuf|ffuf|-
web|bin|gobuster|gobuster|gobuster|-
web|bin|feroxbuster|feroxbuster|feroxbuster|-
web|bin|sqlmap|sqlmap|sqlmap|-
smb|bin|smbclient|smbclient|samba|-
smb|bin|rpcclient|samba-common-bin|samba|-
smb|bin|smbmap|smbmap|-|pipx install smbmap
smb|bin|nxc|netexec|-|pipx install git+https://github.com/Pennyw0rth/NetExec
smb|bin|enum4linux-ng|enum4linux-ng|-|pipx install enum4linux-ng
ad|bin|impacket-smbserver|impacket-scripts|-|pipx install impacket
ad|bin|bloodhound-python|bloodhound.py|-|pipx install bloodhound
ad|bin|responder|responder|-|git clone --depth 1 https://github.com/lgandx/Responder ~/tools/Responder
crack|bin|hashcat|hashcat|hashcat|-
crack|bin|john|john|john-jumbo|-
crack|bin|hydra|hydra|hydra|-
exploit|bin|msfconsole|metasploit-framework|cask:metasploit|-
pivot|bin|proxychains4|proxychains4|proxychains-ng|-
pivot|bin|socat|socat|socat|-
'

PKGMGR=""
detect_pkgmgr() {
  if   command -v apt-get >/dev/null 2>&1; then PKGMGR=apt
  elif command -v brew    >/dev/null 2>&1; then PKGMGR=brew
  elif command -v pacman  >/dev/null 2>&1; then PKGMGR=pacman
  elif command -v dnf     >/dev/null 2>&1; then PKGMGR=dnf
  else PKGMGR=unknown
  fi
}

# tool_present <kind> <check>  -> 0 present, 1 missing. Echoes where it found it.
tool_present() {
  if [ "$1" = "dir" ]; then
    OLD="$IFS"; IFS=':'
    for d in $2; do
      IFS="$OLD"
      d="$(eval printf '%s' \""$d"\")"      # expand $HOME
      if [ -d "$d" ]; then printf '%s' "$d"; return 0; fi
      IFS=':'
    done
    IFS="$OLD"
    return 1
  fi
  command -v "$2" >/dev/null 2>&1 || return 1
  command -v "$2"
}

# tool_version <bin> — best effort, never hangs the script
tool_version() {
  case "$1" in
    msfconsole|responder) printf 'installed'; return 0 ;;   # too slow to probe
  esac
  v="$("$1" --version 2>&1 | head -1)" || v=""
  [ -n "$v" ] || v="$("$1" -V 2>&1 | head -1)" || v=""
  [ -n "$v" ] || v="installed"
  printf '%s' "$(printf '%s' "$v" | tr -d '\r' | cut -c1-44)"
}

MISSING_LIST=""; PRESENT_N=0; MISSING_N=0
TOOLS_TMP=""
cleanup_tmp() { [ -n "$TOOLS_TMP" ] && rm -f "$TOOLS_TMP" "$TOOLS_TMP.missing"; }
trap cleanup_tmp EXIT INT TERM

# Sets the global TOOLS_TMP. Must NOT be called in a command substitution,
# or the assignment happens in a subshell and is lost.
init_tools_file() {
  if [ -z "$TOOLS_TMP" ]; then
    TOOLS_TMP="$(mktemp "${TMPDIR:-/tmp}/newengage.XXXXXX")"
    printf '%s\n' "$TOOLS" | grep -v '^[[:space:]]*$' > "$TOOLS_TMP"
  fi
}

check_tools() {
  detect_pkgmgr
  init_tools_file
  tf="$TOOLS_TMP"
  : > "$tf.missing"
  PRESENT_N=0; MISSING_N=0

  printf '\n%s\n' "TOOLCHAIN  (package manager: $PKGMGR)"
  printf '%s\n' "------------------------------------------------------------------"
  last_group=""
  # redirect, not a pipe: keeps the counters in THIS shell
  while IFS='|' read -r grp kind chk apt brew fb; do
    [ -n "${grp:-}" ] || continue
    if [ "$grp" != "$last_group" ]; then printf '\n  [%s]\n' "$grp"; last_group="$grp"; fi
    # a dir entry's "check" is a path list, so label it by its apt package name
    if [ "$kind" = "dir" ]; then label="$apt"; else label="$chk"; fi
    if where="$(tool_present "$kind" "$chk")"; then
      PRESENT_N=$((PRESENT_N + 1))
      if [ "$kind" = "dir" ]; then
        printf '   ok      %-22s %s\n' "$label" "$where"
      else
        printf '   ok      %-22s %s\n' "$label" "$(tool_version "$chk")"
      fi
    else
      MISSING_N=$((MISSING_N + 1))
      printf '%s|%s|%s|%s|%s|%s\n' "$grp" "$kind" "$chk" "$apt" "$brew" "$fb" >> "$tf.missing"
      printf '   MISSING %-22s install: %s\n' "$label" "$(install_cmd "$apt" "$brew" "$fb")"
    fi
  done < "$tf"

  printf '\n  %d present, %d missing\n' "$PRESENT_N" "$MISSING_N"
  [ "$MISSING_N" -eq 0 ] || printf '  Install them with:  %s --install-tools\n' "$PROG"
}

# install_cmd <apt> <brew> <fallback>
install_cmd() {
  _apt="$1"; _brew="$2"; _fb="$3"
  case "$PKGMGR" in
    apt)    [ "$_apt"  != "-" ] && { printf 'sudo apt-get install -y %s' "$_apt"; return 0; } ;;
    brew)   if [ "$_brew" != "-" ]; then
              case "$_brew" in
                cask:*) printf 'brew install --cask %s' "${_brew#cask:}" ;;
                *)      printf 'brew install %s' "$_brew" ;;
              esac
              return 0
            fi ;;
    pacman) [ "$_apt"  != "-" ] && { printf 'sudo pacman -S --needed %s' "$_apt"; return 0; } ;;
    dnf)    [ "$_apt"  != "-" ] && { printf 'sudo dnf install -y %s' "$_apt"; return 0; } ;;
  esac
  if [ "$_fb" != "-" ]; then printf '%s' "$_fb"; else printf '(no automatic install - see the tool docs)'; fi
}

install_missing() {
  init_tools_file
  tf="$TOOLS_TMP"
  [ -f "$tf.missing" ] || { printf '%s: run the check first.\n' "$PROG" >&2; return 1; }
  if [ "$MISSING_N" -eq 0 ]; then printf '\n%s: nothing to install.\n' "$PROG"; return 0; fi

  printf '\n%s: these commands will be run:\n\n' "$PROG"
  while IFS='|' read -r grp kind chk apt brew fb; do
    [ -n "${chk:-}" ] || continue
    printf '    %s\n' "$(install_cmd "$apt" "$brew" "$fb")"
  done < "$tf.missing"

  # --dry-run must never install, even with --install-tools and -y
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\n%s: DRY RUN - nothing installed.\n' "$PROG"
    return 0
  fi

  if [ "$ASSUME_YES" -eq 0 ]; then
    printf '\nProceed? [y/N] '
    # stdin first: covers both a terminal and a piped answer. Only fall back to
    # /dev/tty if stdin is closed, and swallow its error if there is no tty.
    reply=""
    if read -r reply 2>/dev/null; then :
    else
      reply="$( { read -r _r < /dev/tty && printf '%s' "$_r"; } 2>/dev/null || true )"
    fi
    case "${reply:-n}" in
      y|Y|yes|YES) ;;
      *) printf '%s: skipped - run the commands above yourself, or re-run with -y.\n' "$PROG"; return 0 ;;
    esac
  fi

  failed=0
  while IFS='|' read -r grp kind chk apt brew fb; do
    [ -n "${chk:-}" ] || continue
    cmd="$(install_cmd "$apt" "$brew" "$fb")"
    case "$cmd" in
      '(no automatic install'*) printf '\n  -- %-20s no package available, skipping\n' "$chk"; continue ;;
    esac
    printf '\n==> %s\n    %s\n' "$chk" "$cmd"
    if sh -c "$cmd"; then :; else
      failed=$((failed + 1))
      printf '  !! %s failed - carrying on\n' "$chk"
    fi
  done < "$tf.missing"

  if [ "$failed" -gt 0 ]; then
    printf '\n%s: %d install(s) failed. Re-run --check-tools to see what is still missing.\n' "$PROG" "$failed"
  fi
  return 0
}

# write_tool_inventory <dir>
write_tool_inventory() {
  init_tools_file
  inv="$1/installed-versions.txt"
  [ "$DRY_RUN" -eq 0 ] || { printf '  + file  %s\n' "$inv"; return 0; }
  {
    printf 'TOOL INVENTORY\n'
    printf '%s\n\n' "$RULE"
    printf 'Generated %s on %s by %s.\n' "$(date -u +%FT%TZ)" "$(hostname)" "$PROG"
    printf 'Versions matter for reproducibility - a finding that depends on a tool\n'
    printf 'version needs that version in the report. See tools.txt for what you used.\n\n'
    printf '%-24s %s\n' "TOOL" "VERSION / PATH"
    printf '%-24s %s\n' "------------------------" "----------------------------------------"
    while IFS='|' read -r grp kind chk apt brew fb; do
      [ -n "${grp:-}" ] || continue
      if [ "$kind" = "dir" ]; then label="$apt"; else label="$chk"; fi
      if where="$(tool_present "$kind" "$chk")"; then
        if [ "$kind" = "dir" ]; then printf '%-24s %s\n' "$label" "$where"
        else printf '%-24s %s\n' "$label" "$(tool_version "$chk")"; fi
      else
        printf '%-24s %s\n' "$label" "NOT INSTALLED"
      fi
    done < "$TOOLS_TMP"
  } > "$inv"
  printf '  + file  %s\n' "$inv"
}

# ----------------------------------------------------------------- build -----

# --check-tools: audit the box and stop. No client name needed.
if [ "$CHECK_ONLY" -eq 1 ]; then
  check_tools
  if [ "$INSTALL_TOOLS" -eq 1 ]; then install_missing; fi
  exit 0
fi

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

# toolchain: check (and optionally install) before reporting
if [ "$CHECK_TOOLS" -eq 1 ]; then
  check_tools
  if [ "$INSTALL_TOOLS" -eq 1 ]; then
    install_missing
    check_tools >/dev/null      # refresh the inventory after installing
  fi
  OLDIFS="$IFS"; IFS=','
  for t in $TYPES; do
    IFS="$OLDIFS"
    t="$(printf '%s' "$t" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -n "$t" ] && [ -d "$CLIENT_ROOT/$t/tools" ]; then
      write_tool_inventory "$CLIENT_ROOT/$t/tools"
    fi
    IFS=','
  done
  IFS="$OLDIFS"
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
