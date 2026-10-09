# Enum

Credentialed enumeration and access — you hold **one valid credential** (password, NT hash, Kerberos ticket, or SSH key) and want to turn it into enumeration and a foothold on whatever service answers. The counterpart to [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md), which is how you get that credential when you start with none.

## Tree

```text
Enum/
├── README.md                              <- you are here
└── Credentialed Enumeration & Access.md   validate a cred, then enumerate/access per service — SMB, WinRM, LDAP, FTP, SSH/SFTP, MSSQL, RDP; NetExec-centric
```

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [Credentialed Enumeration & Access](Credentialed%20Enumeration%20%26%20Access.md) | One credential across every service: the auth forms (password / `-H` hash / `-k` Kerberos / key), NetExec as the spine (`[+]` valid, `(Pwn3d!)` admin), then per-protocol validate → enumerate → access with cross-links to the shell and AD notes | cheatsheet |

## Where this sits

- **No credential yet** → [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) (spray / online brute / offline cracking).
- **Have a credential** → the note above decides what it unlocks and where it's admin.
- **Got access** → turn it into a stable shell with [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) and [Shell](../Shell/README.md).
- **Domain credential** → feeds the whole [AD](../AD/README.md) chain (LDAP dump → BloodHound → lateral movement).

## Related

[Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · [Protocols](../Protocols/README.md) · [AD](../AD/README.md) · [Shell](../Shell/README.md) · [Offense README](../README.md)
