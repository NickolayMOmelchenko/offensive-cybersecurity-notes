# Protocols

Per-protocol enumeration and attack notes — pick the note for the port in front of you. These were tools-folder notes; they live here now because they're organised by *protocol on the wire*, not by a single binary.

## Tree

```text
Protocols/
├── README.md       <- you are here
├── smb.md          SMB/CIFS (445/139) — shares, users, creds, exec
├── nfs.md          NFS (2049/111) — exports, mounting, no_root_squash → root
└── dns.md          DNS (53) — zone transfers, enumeration, subdomains
```

## Notes

| Protocol | Ports | Note | The headline attack |
| --- | --- | --- | --- |
| **SMB/CIFS** | 445, 139 | [smb](smb.md) | Null/guest enum → creds → `Pwn3d!` local admin; SMB-signing relay |
| **NFS** | 2049, 111 | [nfs](nfs.md) | Mount a world-readable export; `no_root_squash` → root |
| **DNS** | 53 | [dns](dns.md) | Zone transfer (AXFR) dumping every record; subdomain enum |

## Where this sits

- **Find the ports first** with [nmap](../Tools/nmap.md), then open the matching note.
- Web content discovery (HTTP) is its own thing — [fuzz](../Tools/fuzz.md) / [feroxbuster](../Tools/feroxbuster.md) / [Web Overview](../Web/Web%20Overview.md).
- Getting a shell once a protocol gives you creds/exec: [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md), [Shell](../Shell/README.md).
- Domain-wide work after SMB creds: [AD](../AD/README.md).

## Related

[nmap](../Tools/nmap.md) · [Networking Overview](../Networking/Networking%20Overview.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · [Password Attacks & Brute Forcing](../Networking/Password%20Attacks%20%26%20Brute%20Forcing.md) · [AD](../AD/README.md) · [Offense README](../README.md)
