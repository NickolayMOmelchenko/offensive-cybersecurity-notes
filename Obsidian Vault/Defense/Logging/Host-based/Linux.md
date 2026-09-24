Logs location: `var/log`
	For handling logs, many Linux distributions use system logging daemons like `rsyslog`, `syslog-ng`, and `journald` to manage, process, and store log events.
Tools
	##aureport## -  efficient CLI tool to audit system logs on Linux.
	`aureport -- summary` shows summary of logs
	`ausearch --message USER_LOGIN --success yes --interpret` returns successful logins, `ausearch --message USER_LOGIN --success no --interpret` returns the failed logins. The options are:
	- `--message` is followed  by: `USER_LOGIN`, `DEL_USER`, `ADD_GROUP`, `USER_CHAUTHTOK`, `DEL_GROUP`, `CHGRP_ID`, `ROLE_ASSIGN`, and `ROLE_REMOVE`.
	- `--success` is followed by `yes` or `no` 
	- `--interpret` converts numeric entities, such as UID (User ID), into text.
	If we only want to display the failed login attempts for the `root` account, we can pipe the output via `grep`. The command becomes`ausearch --message USER_LOGIN --success no --interpret | grep ct=root`
	
	root@TryHackMe# ausearch -m USER_LOGIN -sv no -i | grep ct=root | wc -l 76

