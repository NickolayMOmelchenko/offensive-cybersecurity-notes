cut -d ' ' -f 1 apache.log | sort -n | uniq -c


grep '110.122.65.76.*GET /login.php' apache.log

![[Screenshot 2024-12-01 at 9.19.28 PM.png]]