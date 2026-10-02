# Host-based

Logs the operating system produces about itself — authentication, process execution, and the audit subsystem. This is the first place to look when you're asked to prove whether something ran on a box.

**State:** the Linux note has usable commands; the Windows note is a screenshot with no text.

## Tree

```text
Host-based/
├── README.md       <- you are here
├── Linux.md        /var/log, rsyslog/journald, aureport & ausearch
└── Windows.md      stub — one screenshot, no text
```

## Notes

| Note | What it covers | State |
| --- | --- | --- |
| [Linux](Linux.md) | Log location (`/var/log`) and the daemons that manage it (`rsyslog`, `syslog-ng`, `journald`). Then `aureport --summary` and `ausearch` for auditing logins: `--message` (`USER_LOGIN`, `ADD_GROUP`, `DEL_USER`, `ROLE_ASSIGN`, …), `--success yes` / `no`, `--interpret` to turn UIDs into names, and piping to `grep ct=root` to isolate failed root logins | short, usable |
| [Windows](Windows.md) | A single screenshot of the event log. Nothing written up | **stub** |

## Related

- Centralising these: [Splunk Central](../Splunk%20Central.md)
- Searching them: [SOC2/Useful Commands](../../SOC2/Useful%20Commands.md), [SOC2/Log file location](../../SOC2/Log%20file%20location.md)
- Turning the logs off / tampering with them is what an attacker does after [privilege escalation](../../../Offense/Linux/Privilege%20Escalation.md) — hardening that: [1. Linux Hardening](../../System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md)
