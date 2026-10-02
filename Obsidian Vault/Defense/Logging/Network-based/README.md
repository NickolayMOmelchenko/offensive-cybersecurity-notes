# Network-based

Logs that come from the network rather than from the host: firewall and proxy logs, DNS query logs, NetFlow, and IDS/IPS alerts. Useful precisely when the host's own logs can't be trusted, because an attacker with root can edit those and can't edit these.

**State: empty.** `Untitled.md` is a 0-byte placeholder. Nothing here has been written yet.

## Tree

```text
Network-based/
├── README.md       <- you are here
└── Untitled.md     empty, 0 bytes — rename it when you write it
```

## To write

Rename `Untitled.md` to something real and cover:

| Source | What it answers |
| --- | --- |
| Firewall / NetFlow | Who talked to whom, when, how much — catches [pivoting and tunneling](../../../Offense/Networking/Pivoting%20%26%20Tunneling.md) and beaconing |
| DNS query logs | Lookups to attacker infrastructure; DNS tunneling and exfiltration |
| Proxy / HTTP logs | Download cradles, web attacks, [SSRF](../../../Offense/Web/SSRF.md) egress hits |
| IDS/IPS (Suricata, Zeek) | Signature and protocol-anomaly alerts |
| Switch / router logs | DTP and trunk negotiation — the detection for [VLAN Hopping](../../../Offense/Networking/VLAN%20Hopping.md) |

## Related

- The host-side counterpart: [Host-based](../Host-based/README.md)
- Where these would be centralised: [Splunk Central](../Splunk%20Central.md)
- Device config that produces them: [4. Network Devices & Services Hardening](../../System%20and%20Services%20Hardening/4.%20Network%20Devices%20%26%20Services%20Hardening.md)
