[qilnmp-nginx-cc]
enabled = @ENABLED@
filter = qilnmp-nginx-cc
port = http,https
logpath = @LOGPATH@
backend = auto
findtime = @FINDTIME@
maxretry = @MAXRETRY@
bantime = @BANTIME@
ignoreip = @IGNOREIP@
banaction = @BANACTION@
action = %(action_)s
