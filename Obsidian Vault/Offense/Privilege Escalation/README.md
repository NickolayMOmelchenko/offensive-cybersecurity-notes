# Privilege Escalation

Automated enumeration **tools** for finding privesc vectors on a host you already have a shell on: run the script, read the output, confirm by hand. The *manual* techniques these feed into live in the per-platform notes — [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) and [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md).

## Tree

```text
Privilege Escalation/
├── README.md              <- you are here
├── general.md             manual checklist: sudo -l, SUID, cron, SSH keys
├── exfiltrationofsecrets.md  credential hunting: history, env, configs, LaZagne
├── stuck.md               second-pass checklist when nothing obvious works
├── PEASS.md               linPEAS + winPEAS (PEASS-ng) — run this first
├── LinEnum.md             Linux, bash — light second opinion
├── linuxprivchecker.md    Linux, python — cross-check
└── Seatbelt.md            Windows, C# — deeper grouped host/AD checks
```

## Manual checklists

Run these by hand — the quick wins, and credential hunting — alongside the automated tools below.

| Note | Covers |
| --- | --- |
| [general](general.md) | `sudo -l`, SUID/SGID, capabilities, scheduled tasks (cron/timers), SSH keys, writable files, Windows quick wins |
| [exfiltration of secrets](exfiltrationofsecrets.md) | Shell history (incl. PSReadLine), env/export, config grep sweep, Windows cred stores, and **LaZagne** |
| [stuck?](stuck.md) | What to check when the obvious vectors fail — re-enumerate, unzip archives, reuse creds, known-CVE quick wins, Linux/Windows second pass |

## Automated tools

| Tool | OS | Lang | Reach for it when |
| --- | --- | --- | --- |
| [PEASS](PEASS.md) | Linux + Windows | sh / C# | **Default.** Broadest checks, colour-coded by likelihood |
| [LinEnum](LinEnum.md) | Linux | bash | Lighter, faster second opinion; no colour |
| [linuxprivchecker](linuxprivchecker.md) | Linux | python | python-only box, or a cross-check |
| [Seatbelt](Seatbelt.md) | Windows | C# | Deeper grouped host/AD checks; .NET tradecraft |

In practice: **run PEASS first**, then a second tool to catch what it rated low. Two tools disagreeing on what's interesting is useful signal.

## The workflow is the same for all of them

1. **Transfer** the script to the target — serve with `python3 -m http.server 80`, pull with `curl`/`wget`/`iwr`. Prefer running **in memory** (pipe to `sh`, or `execute-assembly`) to stay quiet and leave nothing to clean up. Channels: [netcat](../Shell/netcat.md), [smb](../Protocols/smb.md).
2. **Run** it (each note has the flags).
3. **Read** the output — these surface *candidates*, not findings.
4. **Confirm by hand** against [Linux](../Linux/Privilege%20Escalation.md) / [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md) and [GTFOBins](https://gtfobins.github.io); the manual reproduction is also your report's PoC.
5. **Loot** creds they surface → [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md).

> Authorized testing only. These are **loud** — they trip AV/EDR and fill logs. Record anything dropped on a target in your engagement `tools.txt`.

## Related

- Manual techniques: [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md), [Linux — Enumeration & Privilege Escalation](../Linux/Enumeration%20%26%20Privilege%20Escalation.md), [Windows Privilege Escalation](../Windows/Privilege%20Escalation.md)
- Getting the initial shell: [Shell](../Shell/README.md), [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)
- Metasploit's suggester: [Metasploit](../Tools/Metasploit.md) (`local_exploit_suggester`)
