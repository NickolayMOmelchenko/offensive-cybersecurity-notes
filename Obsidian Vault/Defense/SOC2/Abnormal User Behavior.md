Some examples of these solutions include [_Splunk User Behavior Analytics (UBA)_](https://www.splunk.com/en_us/products/user-behavior-analytics.html), _[IBM QRadar UBA](https://www.ibm.com/docs/en/qradar-common?topic=app-qradar-user-behavior-analytics)_, and _[Azure AD Identity Protection](https://learn.microsoft.com/en-us/azure/active-directory/identity-protection/overview-identity-protection)_.
- **Multiple failed login attempts**
- **Unusual login times**
- **Geographic anomalies**
    - IP addresses in different country
    - Simultaneous logins from different geographic locations
- **Frequent password changes**
- **Unusual user-agent strings**
    - For example, by default, the [Nmap scanner](https://tryhackme.com/room/furthernmap) will log a user agent containing "Nmap Scripting Engine." The [Hydra brute-forcing tool](https://tryhackme.com/room/hydra), by default, will include "(Hydra)" in its user-agent. These indicators can be useful in log files to detect potential malicious activity.