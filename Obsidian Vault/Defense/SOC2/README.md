# SOC2

SOC analyst notes: what log data looks like, where to find it, how to chew through it on the command line, and which patterns are worth an alert. Short notes — these are study notes, not references.

## Tree

```text
SOC2/
├── README.md                            <- you are here
├── Logging Structure Types and Format.md structured / semi / unstructured logs
├── Log file location.md                  where logs live (screenshot)
├── Useful Commands.md                    CLI triage one-liners
└── Abnormal User Behavior.md             what to actually alert on
```

## Notes

| Note | What it covers | State |
| --- | --- | --- |
| [Logging Structure Types and Format](Logging%20Structure%20Types%20and%20Format.md) | The three log shapes — **structured** (strict format, easy to parse), **semi-structured** (mixed), **unstructured** (free text, rich but awkward) — plus a terminology screenshot | short, mostly screenshots |
| [Log file location](Log%20file%20location.md) | A reference table of log paths, as a screenshot | **screenshot only** |
| [Useful Commands](Useful%20Commands.md) | Shell triage on an Apache log: `cut -d ' ' -f 1 \| sort -n \| uniq -c` to count hits per IP, and a `grep` for one IP hitting `/login.php` | short, usable |
| [Abnormal User Behavior](Abnormal%20User%20Behavior.md) | The indicators worth alerting on — repeated failed logins, unusual hours, geographic impossibilities, simultaneous logins from two countries, frequent password changes, and tell-tale user-agents (Nmap's "Nmap Scripting Engine", Hydra's "(Hydra)"). Names the UBA products: Splunk UBA, IBM QRadar UBA, Azure AD Identity Protection | short, usable |

## Reading order

1. [Logging Structure Types and Format](Logging%20Structure%20Types%20and%20Format.md) — know what you're parsing
2. [Log file location](Log%20file%20location.md) — find it
3. [Useful Commands](Useful%20Commands.md) — triage it
4. [Abnormal User Behavior](Abnormal%20User%20Behavior.md) — decide what matters

## Gaps worth filling

- The detection indicators here are generic; the [Offense](../../Offense/README.md) notes each end with a *Defense / detection* section that is more specific. Pulling those into detection rules would make this folder much stronger.
- `Useful Commands` could grow into a proper log-triage cookbook (`awk`, `sort -rn | head`, time-window filtering).

## Related

- Where the logs come from: [Logging](../Logging/README.md)
- The behaviour being detected: [Password Attacks & Brute Forcing](../../Offense/Networking/Password%20Attacks%20%26%20Brute%20Forcing.md)
