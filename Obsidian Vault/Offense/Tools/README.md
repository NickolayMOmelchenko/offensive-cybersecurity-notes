# Tools

Notes tied to a specific framework rather than to a platform or a phase. Anything here is a tool you drive across several phases of an engagement — the technique itself is documented in the platform folders.

## Tree

```text
Tools/
├── README.md       <- you are here
└── Metasploit.md   the Metasploit Framework, end to end
```

## Notes

| Note | What it covers | Size |
| --- | --- | --- |
| [Metasploit](Metasploit.md) | Console basics and workspace/database use, validating and spraying credentials over SMB, getting a shell (`psexec`, Impacket-backed exec modules, WinRM, SSH), pass-the-hash, Meterpreter essentials, catching a shell with a bare handler, pivoting and routing | long |

## Related

The platform notes give the non-Metasploit equivalent of most of this, which is usually what you want when you need to be quiet:

- [AD](../AD/README.md) — Impacket instead of `psexec`; see [Impacket Toolkit](../AD/Impacket%20Toolkit.md)
- [Networking](../Networking/README.md) — Nmap and hydra instead of the auxiliary scanners
- [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) — SSH and chisel instead of `route`/`autoroute`
- SANS Metasploit handout: [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md)
