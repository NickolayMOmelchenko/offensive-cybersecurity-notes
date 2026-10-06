# offensive-cybersecurity-notes

Personal cybersecurity notes kept as an [Obsidian](https://obsidian.md) vault and browsable here on GitHub. Covers **offensive** (red team / GPEN·SEC560) and **defensive** (blue team) topics. Each attack note pairs techniques with detection/defense so it works for both sides.

> Repo conventions (image format, internal links) live in [CLAUDE.md](CLAUDE.md).

## Contents

Every folder has its own `README.md` with a tree and a one-line description of each note — the **README** links below are the quickest way in. Start at [the vault root](Obsidian%20Vault/README.md).

### Offense

- [general](Obsidian%20Vault/Offense/general.md) — cross-cutting notes (moving files, …)
- **AD/** — [README](Obsidian%20Vault/Offense/AD/README.md)
  - [AD Attacks Overview](Obsidian%20Vault/Offense/AD/AD%20Attacks%20Overview.md)
  - [Enumeration](Obsidian%20Vault/Offense/AD/Enumeration.md)
  - [Impacket Toolkit](Obsidian%20Vault/Offense/AD/Impacket%20Toolkit.md)
  - [Kerberos Attacks](Obsidian%20Vault/Offense/AD/Kerberos%20Attacks.md)
  - [Privilege Escalation](Obsidian%20Vault/Offense/AD/Privilege%20Escalation.md)
  - [Lateral Movement & Credential Access](Obsidian%20Vault/Offense/AD/Lateral%20Movement%20%26%20Credential%20Access.md)
  - [Attacking the Domain Controller](Obsidian%20Vault/Offense/AD/Attacking%20the%20Domain%20Controller.md)
- **Linux/** — [README](Obsidian%20Vault/Offense/Linux/README.md)
  - [Linux Overview](Obsidian%20Vault/Offense/Linux/Linux%20Overview.md)
  - [Enumeration & Privilege Escalation](Obsidian%20Vault/Offense/Linux/Enumeration%20%26%20Privilege%20Escalation.md)
  - [Privilege Escalation](Obsidian%20Vault/Offense/Linux/Privilege%20Escalation.md)
  - [Container Escape](Obsidian%20Vault/Offense/Linux/Container%20Escape.md)
- **Networking/** — [README](Obsidian%20Vault/Offense/Networking/README.md)
  - [Networking Overview](Obsidian%20Vault/Offense/Networking/Networking%20Overview.md)
  - [Password Attacks & Brute Forcing](Obsidian%20Vault/Offense/Networking/Password%20Attacks%20%26%20Brute%20Forcing.md)
  - [Remote Access & Getting a Shell](Obsidian%20Vault/Offense/Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md)
  - [Pivoting & Tunneling](Obsidian%20Vault/Offense/Networking/Pivoting%20%26%20Tunneling.md)
  - [VLAN Hopping](Obsidian%20Vault/Offense/Networking/VLAN%20Hopping.md)
- **Privilege Escalation/** — [README](Obsidian%20Vault/Offense/Privilege%20Escalation/README.md)
  - [general](Obsidian%20Vault/Offense/Privilege%20Escalation/general.md)
  - [exfiltration of secrets](Obsidian%20Vault/Offense/Privilege%20Escalation/exfiltrationofsecrets.md)
  - [stuck?](Obsidian%20Vault/Offense/Privilege%20Escalation/stuck.md)
  - [PEASS](Obsidian%20Vault/Offense/Privilege%20Escalation/PEASS.md)
  - [LinEnum](Obsidian%20Vault/Offense/Privilege%20Escalation/LinEnum.md)
  - [linuxprivchecker](Obsidian%20Vault/Offense/Privilege%20Escalation/linuxprivchecker.md)
  - [Seatbelt](Obsidian%20Vault/Offense/Privilege%20Escalation/Seatbelt.md)
- **Shell/** — [README](Obsidian%20Vault/Offense/Shell/README.md)
  - [shell](Obsidian%20Vault/Offense/Shell/shell.md)
  - [netcat](Obsidian%20Vault/Offense/Shell/netcat.md)
  - [pwncat](Obsidian%20Vault/Offense/Shell/pwncat.md)
- **Tools/** — [README](Obsidian%20Vault/Offense/Tools/README.md)
  - [Metasploit](Obsidian%20Vault/Offense/Tools/Metasploit.md)
- **Web/** — [README](Obsidian%20Vault/Offense/Web/README.md)
  - [Web Overview](Obsidian%20Vault/Offense/Web/Web%20Overview.md)
  - [XSS](Obsidian%20Vault/Offense/Web/XSS.md)
  - [SQL Injection](Obsidian%20Vault/Offense/Web/SQL%20Injection.md)
  - [SSRF](Obsidian%20Vault/Offense/Web/SSRF.md)
  - [CSRF](Obsidian%20Vault/Offense/Web/CSRF.md)
  - [RCE](Obsidian%20Vault/Offense/Web/RCE.md)
- **Windows/** — [README](Obsidian%20Vault/Offense/Windows/README.md)
  - [Windows Overview](Obsidian%20Vault/Offense/Windows/Windows%20Overview.md)
  - [Powershell](Obsidian%20Vault/Offense/Windows/Powershell.md)
  - [Privilege Escalation](Obsidian%20Vault/Offense/Windows/Privilege%20Escalation.md)
- **Screenshots/** — image assets for the Offense notes ([README](Obsidian%20Vault/Offense/Screenshots/README.md))
- **GPEN Cheatsheet/** — [README](Obsidian%20Vault/Offense/GPEN%20Cheatsheet/README.md)
  - [README](Obsidian%20Vault/Offense/GPEN%20Cheatsheet/README.md)
  - [SANS-Pivoting-Cheat-Sheet-v1.2.pdf](Obsidian%20Vault/Offense/GPEN%20Cheatsheet/SANS-Pivoting-Cheat-Sheet-v1.2.pdf)
  - [SEC560HANDOUT_Metasploit_D02_01.pdf](Obsidian%20Vault/Offense/GPEN%20Cheatsheet/SEC560HANDOUT_Metasploit_D02_01.pdf)
  - [SEC560HANDOUT_NetcatCheatSheet_D02_01.pdf](Obsidian%20Vault/Offense/GPEN%20Cheatsheet/SEC560HANDOUT_NetcatCheatSheet_D02_01.pdf)
  - [SEC560HANDOUT_NmapCheatSheetv1.1_D02_01.pdf](Obsidian%20Vault/Offense/GPEN%20Cheatsheet/SEC560HANDOUT_NmapCheatSheetv1.1_D02_01.pdf)
  - [SEC560HANDOUT_PowerShellCheat_D02_01.pdf](Obsidian%20Vault/Offense/GPEN%20Cheatsheet/SEC560HANDOUT_PowerShellCheat_D02_01.pdf)
  - [SEC560HANDOUT_WinComLine_V1_D02_01.pdf](Obsidian%20Vault/Offense/GPEN%20Cheatsheet/SEC560HANDOUT_WinComLine_V1_D02_01.pdf)

### Defense

- **Logging/** — [README](Obsidian%20Vault/Defense/Logging/README.md)
  - [Splunk Central](Obsidian%20Vault/Defense/Logging/Splunk%20Central.md)
  - **Host-based/** — [README](Obsidian%20Vault/Defense/Logging/Host-based/README.md)
    - [Linux](Obsidian%20Vault/Defense/Logging/Host-based/Linux.md)
    - [Windows](Obsidian%20Vault/Defense/Logging/Host-based/Windows.md)
  - **Network-based/** — [README](Obsidian%20Vault/Defense/Logging/Network-based/README.md)
    - [Untitled](Obsidian%20Vault/Defense/Logging/Network-based/Untitled.md)
- **SOC2/** — [README](Obsidian%20Vault/Defense/SOC2/README.md)
  - [Abnormal User Behavior](Obsidian%20Vault/Defense/SOC2/Abnormal%20User%20Behavior.md)
  - [Log file location](Obsidian%20Vault/Defense/SOC2/Log%20file%20location.md)
  - [Logging Structure Types and Format](Obsidian%20Vault/Defense/SOC2/Logging%20Structure%20Types%20and%20Format.md)
  - [Useful Commands](Obsidian%20Vault/Defense/SOC2/Useful%20Commands.md)
- **System and Services Hardening/** — [README](Obsidian%20Vault/Defense/System%20and%20Services%20Hardening/README.md)
  - [1. Linux Hardening](Obsidian%20Vault/Defense/System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md)
  - [2. Windows Hardening](Obsidian%20Vault/Defense/System%20and%20Services%20Hardening/2.%20Windows%20Hardening.md)
  - [3. Active Directory Hardening](Obsidian%20Vault/Defense/System%20and%20Services%20Hardening/3.%20Active%20Directory%20Hardening.md)
  - [4. Network Devices & Services Hardening](Obsidian%20Vault/Defense/System%20and%20Services%20Hardening/4.%20Network%20Devices%20%26%20Services%20Hardening.md)
- **screenshoots/** — image assets for the Defense notes ([README](Obsidian%20Vault/Defense/screenshoots/README.md))

> ⚠️ For authorized security testing, labs, and study only.
