# Logging

Where log data comes from and where it goes: host log sources on each OS, and Splunk as the place they get centralised and searched.

**State:** partly written. The Splunk note is usable, the Linux note has real `auditd` commands, the Windows note is a single screenshot, and `Network-based/` is an empty placeholder.

## Tree

```text
Logging/
├── README.md               <- you are here
├── Splunk Central.md       Splunk components + SPL
├── Host-based/             logs the OS itself produces
│   ├── Linux.md            /var/log, rsyslog/journald, aureport/ausearch
│   └── Windows.md          stub — one screenshot
└── Network-based/          logs from the network, not the host
    └── Untitled.md         empty placeholder
```

## Notes

| Note | What it covers | State |
| --- | --- | --- |
| [Splunk Central](Splunk%20Central.md) | The four Splunk components — forwarders, indexers, search heads, deployment server — and what each does, plus the start of SPL | short, usable |
| [Host-based/Linux](Host-based/Linux.md) | `/var/log` and the logging daemons (`rsyslog`, `syslog-ng`, `journald`), then `aureport` and `ausearch` with the `--message` / `--success` / `--interpret` options for auditing logins | short, usable |
| [Host-based/Windows](Host-based/Windows.md) | One screenshot of the Windows event log. No text yet | **stub** |
| [Network-based/Untitled](Network-based/Untitled.md) | Nothing — empty file, not even renamed | **empty** |

## Subfolders

| Folder | Covers |
| --- | --- |
| [Host-based](Host-based/README.md) | Logs the operating system produces about itself — auth, process, audit subsystem |
| [Network-based](Network-based/README.md) | Logs from network devices and traffic capture — firewall, proxy, DNS, NetFlow, IDS |

## Gaps worth filling

- Windows event IDs that matter (4624/4625 logons, 4768/4769 Kerberos, 4688 process creation, 7045 service install) — these are what the [AD attacks](../../Offense/AD/README.md) actually generate.
- Anything at all in `Network-based/`, starting by renaming `Untitled.md`.
- SPL query examples to go with the Splunk architecture.

## Related

- What to look *for* in these logs: [SOC2](../SOC2/README.md)
- What generates the events: [Offense](../../Offense/README.md)
