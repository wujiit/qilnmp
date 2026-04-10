# Managed by QILNMP security.sh. Changes may be overwritten.
limit_req_zone $binary_remote_addr zone=qilnmp_cc:20m rate=@RATE@;
limit_conn_zone $binary_remote_addr zone=qilnmp_conn:20m;
limit_req_status 429;
limit_conn_status 429;
limit_req_log_level warn;
limit_conn_log_level warn;
limit_req zone=qilnmp_cc burst=@BURST@ nodelay;
limit_conn qilnmp_conn @CONN@;
