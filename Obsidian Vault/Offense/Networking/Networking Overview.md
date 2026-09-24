# Networking — Offensive Notes Overview

Index for network-layer attacks and the pivoting skills that tie an engagement together. See [[../GPEN Cheatsheet/README|GPEN Cheatsheet]] for the SANS pivoting handout.

## Notes in this folder

- [[VLAN Hopping]] — switch spoofing and double tagging on the link layer

## Scanning & enumeration (the front door)

- **Host discovery:** `nmap -sn <subnet>` (ping sweep).
- **Port + service:** `nmap -sC -sV -oA scan <target>` — default scripts, versions, all output formats.
- **Full/fast tradeoff:** `-p-` all ports, `-T4` faster, `--top-ports 1000` default. Note UDP (`-sU`) separately — slow but finds SNMP/DNS/TFTP.
- Always save output (`-oA`) so results are in the report and re-usable.

## Common LAN attacks (concept level)

- **LLMNR / NBT-NS / mDNS poisoning** — respond to broadcast name lookups to capture NetNTLM hashes (Responder). Fix: disable these fallbacks.
- **ARP spoofing** — MITM on a flat segment; useful for capture, high-risk for stability — confirm scope.
- **[[VLAN Hopping]]** — reach VLANs you shouldn't via DTP or double-tagging.
- **Rogue DHCP / DNS** — hand out attacker gateway/resolver.

Detection/defense for all of the above: segmentation, DHCP snooping, dynamic ARP inspection, disabling DTP, and disabling legacy name-resolution protocols.

## Pivoting & tunneling (turn one host into a route)

Once you own a host with a second interface, use it to reach networks you can't touch directly.

- **SSH local forward:** `ssh -L 8080:internal-host:80 user@pivot` — reach an internal service on your localhost.
- **SSH dynamic (SOCKS):** `ssh -D 1080 user@pivot` + `proxychains <tool>` — route whole tools through the pivot.
- **Chisel / ligolo-ng** — when SSH isn't available; build TCP/SOCKS tunnels through the foothold.
- **Meterpreter:** `run autoroute` + `socks_proxy` module for the same effect from a Metasploit session.

Rule of thumb: enumerate the pivot's `ip a` / `ss -tulpn` first, then forward only what you need. Keep a diagram of your tunnels for the report.
