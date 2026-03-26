#!/bin/bash
# QILNMP environment status inspector
# Usage:
#   bash tools/stack_status.sh

set -u

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

print_kv() {
  printf "%-28s %s\n" "$1" "$2"
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

get_first_line() {
  local out
  out="$("$@" 2>&1 | head -n 1)"
  if [ -n "$out" ]; then
    echo "$out"
  else
    echo "unknown"
  fi
}

service_state() {
  local svc="$1"
  if cmd_exists systemctl; then
    local state
    state="$(systemctl is-active "$svc" 2>/dev/null || true)"
    [ -z "$state" ] && state="not-found"
    echo "$state"
  else
    echo "unknown(no-systemctl)"
  fi
}

service_state_first() {
  local svc
  for svc in "$@"; do
    if cmd_exists systemctl; then
      if systemctl list-unit-files "${svc}.service" --no-legend 2>/dev/null | grep -q "${svc}.service"; then
        service_state "$svc"
        return
      fi
    fi
  done
  if cmd_exists systemctl; then
    echo "not-found"
  else
    echo "unknown(no-systemctl)"
  fi
}

version_or_not_installed() {
  local bin="$1"
  shift
  if [ -x "$bin" ]; then
    get_first_line "$bin" "$@"
  else
    echo "not-installed"
  fi
}

detect_php_bin() {
  if [ -x "/usr/local/php/bin/php" ]; then
    echo "/usr/local/php/bin/php"
    return
  fi
  if cmd_exists php; then
    command -v php
    return
  fi
  echo ""
}

echo "================ QILNMP Status Report ================"
echo "Report Time: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo

if [ -f /etc/os-release ]; then
  . /etc/os-release
  print_kv "OS" "${PRETTY_NAME:-unknown}"
else
  print_kv "OS" "$(uname -a)"
fi
print_kv "Kernel" "$(uname -r)"
print_kv "Hostname" "$(hostname 2>/dev/null || echo unknown)"
echo

echo "[Web Server]"
print_kv "Nginx" "$(version_or_not_installed /usr/local/nginx/sbin/nginx -v)"
print_kv "Tengine" "$(version_or_not_installed /usr/local/tengine/sbin/nginx -v)"
print_kv "OpenResty" "$(version_or_not_installed /usr/local/openresty/nginx/sbin/nginx -V)"
print_kv "Caddy" "$(version_or_not_installed /usr/local/caddy/bin/caddy version)"
print_kv "Apache" "$(version_or_not_installed /usr/local/apache/bin/httpd -v)"
print_kv "nginx service" "$(service_state nginx)"
print_kv "php-fpm service" "$(service_state php-fpm)"
echo

echo "[Database]"
print_kv "MySQL client" "$(version_or_not_installed /usr/local/mysql/bin/mysql --version)"
print_kv "MariaDB client" "$(version_or_not_installed /usr/local/mariadb/bin/mysql --version)"
print_kv "Percona client" "$(version_or_not_installed /usr/local/percona/bin/mysql --version)"
print_kv "PostgreSQL client" "$(version_or_not_installed /usr/local/pgsql/bin/psql --version)"
print_kv "MongoDB shell" "$(version_or_not_installed /usr/local/mongodb/bin/mongo --version)"
print_kv "mysqld service" "$(service_state mysqld)"
print_kv "mariadb service" "$(service_state mariadb)"
print_kv "postgresql service" "$(service_state postgresql)"
print_kv "mongod service" "$(service_state mongod)"
echo

echo "[Cache / Other Services]"
print_kv "Redis server" "$(version_or_not_installed /usr/local/redis/bin/redis-server --version)"
print_kv "Memcached" "$(version_or_not_installed /usr/local/memcached/bin/memcached -h)"
print_kv "Pure-FTPd" "$(version_or_not_installed /usr/local/pureftpd/sbin/pure-ftpd -v)"
print_kv "redis service" "$(service_state_first redis-server redis)"
print_kv "memcached service" "$(service_state memcached)"
print_kv "pure-ftpd service" "$(service_state_first pureftpd pure-ftpd)"
echo

echo "[PHP]"
php_bin="$(detect_php_bin)"
if [ -n "$php_bin" ]; then
  print_kv "PHP binary" "$php_bin"
  print_kv "PHP version" "$("$php_bin" -r 'echo PHP_VERSION;' 2>/dev/null || echo unknown)"
  print_kv "PHP SAPI" "$("$php_bin" -r 'echo PHP_SAPI;' 2>/dev/null || echo unknown)"
  print_kv "PHP INI" "$("$php_bin" --ini 2>/dev/null | sed -n '2p' | sed 's/^.*: //' | tr -d '"')"
  print_kv "OPcache loaded" "$("$php_bin" -r 'echo extension_loaded("Zend OPcache") ? "yes" : "no";' 2>/dev/null || echo unknown)"
  print_kv "fileinfo loaded" "$("$php_bin" -r 'echo extension_loaded("fileinfo") ? "yes" : "no";' 2>/dev/null || echo unknown)"
  print_kv "imagick loaded" "$("$php_bin" -r 'echo extension_loaded("imagick") ? "yes" : "no";' 2>/dev/null || echo unknown)"
  print_kv "redis ext loaded" "$("$php_bin" -r 'echo extension_loaded("redis") ? "yes" : "no";' 2>/dev/null || echo unknown)"
  php_ext_list="$("$php_bin" -m 2>/dev/null | awk 'NF && $0 !~ /^\[/' | sort -u)"
  php_ext_count="$(printf "%s\n" "$php_ext_list" | awk 'NF' | wc -l | awk '{print $1}')"
  print_kv "PHP extensions count" "${php_ext_count:-0}"
  echo
  echo "PHP extensions list:"
  printf "%s\n" "$php_ext_list"
else
  print_kv "PHP" "not-installed"
fi

echo
echo "================ End Of Report ================"
