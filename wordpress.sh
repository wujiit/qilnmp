#!/bin/bash
# Author:  summer <iticu@qq.com>
#
# Notes: WordPress one-click site deploy helper for QILNMP

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
clear
printf "
#######################################################################
#       QILNMP WordPress Deployer                                   #
#      For more information please visit https://qiling.jingxialai.com #
#######################################################################
"

oneinstack_dir=$(dirname "$(readlink -f "$0")")
pushd "${oneinstack_dir}" > /dev/null || exit 1

. ./options.conf
. ./include/color.sh
. ./include/check_dir.sh
. ./include/download.sh

Show_Help() {
  echo
  cat <<EOF
Usage: $0 [options]

  --help, -h                  Show this help message
  --quiet, -q                 Quiet mode for destructive confirmations
  --domain DOMAIN             Primary domain, for example: www.example.com
  --dir PATH                  Site root directory
  --ssl MODE                  SSL mode: none | own | letsencrypt
  --ssl-crt PATH              Optional existing certificate path when --ssl own
  --ssl-key PATH              Optional existing private key path when --ssl own
  --letsencrypt-email EMAIL   Register/issue Let's Encrypt with this email
  --db-create [y|n]           Create database and DB user automatically (default: y)
  --db-name NAME              Database name
  --db-user NAME              Database user
  --db-pass PASS              Database user password
  --db-host HOST              WordPress DB_HOST, for example: localhost or 127.0.0.1
  --db-user-host HOST         MySQL grant host when auto creating DB user
  --table-prefix PREFIX       WordPress table prefix
  --db-root-pass PASS         Database root password
  --mphp_ver [70~85]          Use another PHP-FPM socket, for example: 84
  --wp-version VERSION        WordPress version or latest (default: latest)
  --ssl-redirect [y|n]        Redirect HTTP to HTTPS when SSL is enabled

Examples:
  $0 --domain blog.example.com --ssl none
  $0 --domain blog.example.com --ssl own
  $0 --domain blog.example.com --ssl own --ssl-crt /path/fullchain.pem --ssl-key /path/privkey.pem
  $0 --domain blog.example.com --ssl letsencrypt --letsencrypt-email admin@example.com
  $0 --domain blog.example.com --ssl own --ssl-redirect n --db-user wpblog --table-prefix blog_
  $0 --domain blog.example.com --db-create n --db-host 127.0.0.1 --db-name wp_blog --db-user wp_blog_user --db-pass 'StrongPass_123456'
EOF
}

version_ge() {
  [ "$1" = "$2" ] && return 0
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

random_string() {
  local len=${1:-16}
  < /dev/urandom tr -dc 'A-Za-z0-9' | head -c "${len}"
}

random_salt() {
  < /dev/urandom tr -dc 'A-Za-z0-9!@#%^*()-_=+,.?' | head -c 64
}

normalize_identifier() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/_/g; s/__*/_/g; s/^_*//; s/_*$//' \
    | cut -c1-24
}

fail() {
  echo "${CFAILURE}Error: $1${CEND}"
  exit 1
}

sql_escape_string() {
  printf '%s' "$1" | sed "s/'/''/g"
}

php_single_quote_escape() {
  printf '%s' "$1" | sed "s/[\\\\']/\\\\&/g"
}

need_root() {
  [ "$(id -u)" = '0' ] || fail "You must be root to run this script"
}

prompt_domain() {
  while :; do
    echo
    read -e -p "Please input domain(example: www.example.com): " domain
    if [[ "${domain}" =~ ^[A-Za-z0-9.-]+$ ]] && [[ "${domain}" == *.* ]]; then
      break
    fi
    echo "${CWARNING}Domain format is invalid.${CEND}"
  done
}

prompt_directory() {
  while :; do
    echo
    read -e -p "(Default directory: ${wwwroot_dir}/${domain}): " vhostdir
    vhostdir=${vhostdir:-${wwwroot_dir}/${domain}}
    case "${vhostdir}" in
      /*) break ;;
      *) echo "${CWARNING}Please use an absolute path.${CEND}" ;;
    esac
  done
}

prompt_ssl_mode() {
  while :; do
    echo
    echo "Please select SSL mode:"
    echo -e "\t${CMSG}1${CEND}. HTTP only"
    echo -e "\t${CMSG}2${CEND}. Generate placeholder cert or import your own"
    echo -e "\t${CMSG}3${CEND}. Use Let's Encrypt"
    read -e -p "Please input a number:(Default 1 press Enter) " ssl_pick
    ssl_pick=${ssl_pick:-1}
    case "${ssl_pick}" in
      1) ssl_mode=none; break ;;
      2) ssl_mode=own; break ;;
      3) ssl_mode=letsencrypt; break ;;
      *) echo "${CWARNING}Please only input 1~3.${CEND}" ;;
    esac
  done
}

prompt_letsencrypt_email() {
  while :; do
    echo
    read -e -p "Please input your Let's Encrypt email: " letsencrypt_email
    if [[ "${letsencrypt_email}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
      break
    fi
    echo "${CWARNING}Email format is invalid.${CEND}"
  done
}

prompt_db_root_password() {
  while :; do
    echo
    read -e -p "Please input the root password of database: " db_root_pass
    [ -n "${db_root_pass}" ] && break
    echo "${CWARNING}Database root password can not be empty.${CEND}"
  done
}

prompt_db_create() {
  while :; do
    echo
    read -e -p "Create database and DB user automatically? [y/n] (Default y): " db_create
    db_create=${db_create:-y}
    if [[ "${db_create}" =~ ^[yYnN]$ ]]; then
      db_create=$(echo "${db_create}" | tr '[:upper:]' '[:lower:]')
      break
    fi
    echo "${CWARNING}Please only input 'y' or 'n'.${CEND}"
  done
}

prompt_db_host() {
  while :; do
    echo
    read -e -p "(Default database host: ${db_host}): " tmp_db_host
    tmp_db_host=${tmp_db_host:-${db_host}}
    if [ -n "${tmp_db_host}" ]; then
      db_host=${tmp_db_host}
      break
    fi
    echo "${CWARNING}Database host can not be empty.${CEND}"
  done
}

prompt_db_name() {
  while :; do
    echo
    read -e -p "(Default database name: ${db_name}): " tmp_db_name
    tmp_db_name=${tmp_db_name:-${db_name}}
    if [[ "${tmp_db_name}" =~ ^[A-Za-z0-9_]+$ ]]; then
      db_name=${tmp_db_name}
      break
    fi
    echo "${CWARNING}Database name only supports letters, numbers and underscores.${CEND}"
  done
}

prompt_db_user_host() {
  while :; do
    echo
    read -e -p "(Default database user host: ${db_user_host}): " tmp_db_user_host
    tmp_db_user_host=${tmp_db_user_host:-${db_user_host}}
    if [ -n "${tmp_db_user_host}" ]; then
      db_user_host=${tmp_db_user_host}
      break
    fi
    echo "${CWARNING}Database user host can not be empty.${CEND}"
  done
}

prompt_db_user() {
  while :; do
    echo
    read -e -p "(Default database user: ${db_user}): " tmp_db_user
    tmp_db_user=${tmp_db_user:-${db_user}}
    if [[ "${tmp_db_user}" =~ ^[A-Za-z0-9_]+$ ]]; then
      db_user=${tmp_db_user}
      break
    fi
    echo "${CWARNING}Database user only supports letters, numbers and underscores.${CEND}"
  done
}

prompt_db_pass() {
  while :; do
    echo
    read -e -p "(Default database password: ${db_pass}): " tmp_db_pass
    tmp_db_pass=${tmp_db_pass:-${db_pass}}
    if [ -n "${tmp_db_pass}" ]; then
      db_pass=${tmp_db_pass}
      break
    fi
    echo "${CWARNING}Database password can not be empty.${CEND}"
  done
}

prompt_table_prefix() {
  while :; do
    echo
    read -e -p "(Default table prefix: ${table_prefix}): " tmp_table_prefix
    tmp_table_prefix=${tmp_table_prefix:-${table_prefix}}
    if [[ "${tmp_table_prefix}" =~ ^[A-Za-z0-9_]+$ ]]; then
      table_prefix=${tmp_table_prefix}
      break
    fi
    echo "${CWARNING}Table prefix only supports letters, numbers and underscores.${CEND}"
  done
}

prompt_ssl_redirect() {
  while :; do
    echo
    read -e -p "Redirect HTTP to HTTPS? [y/n] (Default y): " ssl_redirect
    ssl_redirect=${ssl_redirect:-y}
    if [[ "${ssl_redirect}" =~ ^[yYnN]$ ]]; then
      ssl_redirect=$(echo "${ssl_redirect}" | tr '[:upper:]' '[:lower:]')
      break
    fi
    echo "${CWARNING}Please only input 'y' or 'n'.${CEND}"
  done
}

validate_db_name() {
  [[ "${db_name}" =~ ^[A-Za-z0-9_]+$ ]] || fail "Database name only supports letters, numbers and underscores"
}

validate_db_user() {
  [[ "${db_user}" =~ ^[A-Za-z0-9_]+$ ]] || fail "Database user only supports letters, numbers and underscores"
}

validate_table_prefix() {
  [[ "${table_prefix}" =~ ^[A-Za-z0-9_]+$ ]] || fail "Table prefix only supports letters, numbers and underscores"
}

validate_db_host() {
  [ -n "${db_host}" ] || fail "Database host can not be empty"
}

validate_db_user_host() {
  [ -n "${db_user_host}" ] || fail "Database user host can not be empty"
}

validate_wp_version() {
  [[ "${wp_version}" =~ ^latest$|^[0-9.]+$ ]] || fail "WordPress version only supports latest or version numbers such as 6.8.1"
}

detect_php_socket() {
  if [ -n "${mphp_ver}" ]; then
    php_sock="/dev/shm/php${mphp_ver}-cgi.sock"
  else
    php_sock="/dev/shm/php-cgi.sock"
  fi
  [ -S "${php_sock}" ] || fail "PHP-FPM socket ${php_sock} not found"
}

detect_ipv6() {
  if ifconfig 2>/dev/null | grep -q 'inet6'; then
    has_ipv6=y
  else
    has_ipv6=n
  fi
}

detect_https_options() {
  http2_directive=""
  https_listen="443 ssl http2"
  https_listen_v6="443 ssl http2"

  if "${web_install_dir}/sbin/nginx" -V 2>&1 | grep -q 'with-http_v2_module'; then
    nginx_ver="$("${web_install_dir}/sbin/nginx" -v 2>&1 | sed -n 's@^nginx version: nginx/\([0-9.]*\)$@\1@p')"
    if [ -n "${nginx_ver}" ] && version_ge "${nginx_ver}" "1.25.1"; then
      https_listen="443 ssl"
      https_listen_v6="443 ssl"
      http2_directive="  http2 on;"
    fi
  else
    https_listen="443 ssl"
    https_listen_v6="443 ssl"
  fi
}

stdin_is_tty() {
  [ -t 0 ]
}

derive_db_user_host() {
  case "$1" in
    localhost|localhost:*)
      echo "localhost"
      ;;
    127.0.0.1|127.0.0.1:*)
      echo "127.0.0.1"
      ;;
    *)
      echo "${1%%:*}"
      ;;
  esac
}

is_local_db_host() {
  case "$1" in
    localhost|localhost:*|127.0.0.1|127.0.0.1:*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ensure_environment() {
  [ -n "${web_install_dir}" ] && [ -x "${web_install_dir}/sbin/nginx" ] || fail "Nginx/Tengine/OpenResty is not installed"
  [ -x "${php_install_dir}/bin/php" ] || fail "PHP is not installed"
}

ensure_local_database_environment() {
  [ -n "${db_install_dir}" ] && [ -x "${db_install_dir}/bin/mysql" ] || fail "MySQL/MariaDB/Percona client is required when --db-create y"
}

ensure_inputs() {
  [ -n "${domain}" ] || prompt_domain
  [[ "${domain}" =~ ^[A-Za-z0-9.-]+$ ]] && [[ "${domain}" == *.* ]] || fail "Domain format is invalid"

  [ -n "${vhostdir}" ] || prompt_directory
  case "${vhostdir}" in
    /*) ;;
    *) fail "Site directory must be an absolute path" ;;
  esac

  [ -n "${ssl_mode}" ] || prompt_ssl_mode
  case "${ssl_mode}" in
    none|own|letsencrypt) ;;
    *) fail "SSL mode only supports none, own or letsencrypt" ;;
  esac

  if [ -n "${db_create}" ]; then
    case "${db_create}" in
      y|n) ;;
      Y|N) db_create=$(echo "${db_create}" | tr '[:upper:]' '[:lower:]') ;;
      *) fail "db create only supports y or n" ;;
    esac
  elif stdin_is_tty; then
    prompt_db_create
  else
    db_create=y
  fi

  if [ "${ssl_mode}" != 'none' ]; then
    if [ -n "${ssl_redirect}" ]; then
      case "${ssl_redirect}" in
        y|n) ;;
        Y|N) ssl_redirect=$(echo "${ssl_redirect}" | tr '[:upper:]' '[:lower:]') ;;
        *) fail "ssl redirect only supports y or n" ;;
      esac
    elif stdin_is_tty; then
      prompt_ssl_redirect
    else
      ssl_redirect=y
    fi
  else
    ssl_redirect=n
  fi

  if [ "${ssl_mode}" = 'own' ]; then
    if [ -n "${ssl_crt}" ] || [ -n "${ssl_key}" ]; then
      [ -n "${ssl_crt}" ] && [ -n "${ssl_key}" ] || fail "--ssl own with custom certificate requires both --ssl-crt and --ssl-key"
      [ -s "${ssl_crt}" ] || fail "Certificate file not found"
      [ -s "${ssl_key}" ] || fail "Private key file not found"
    fi
  fi

  if [ "${ssl_mode}" = 'letsencrypt' ]; then
    if [ -n "${letsencrypt_email}" ]; then
      :
    elif stdin_is_tty; then
      prompt_letsencrypt_email
    else
      fail "Please specify --letsencrypt-email in non-interactive mode"
    fi
  fi

  site_ident=$(normalize_identifier "${domain}")
  [ -n "${site_ident}" ] || site_ident=wordpress
  db_host=${db_host:-localhost}
  if [ "${db_host_given}" != 'y' ] && stdin_is_tty; then
    prompt_db_host
  fi
  validate_db_host

  if [ "${db_create}" = 'y' ]; then
    is_local_db_host "${db_host}" || fail "Automatic database creation only supports local DB hosts such as localhost or 127.0.0.1"
    db_root_pass=${db_root_pass:-${dbrootpwd}}
    if [ -n "${db_root_pass}" ]; then
      :
    elif stdin_is_tty; then
      prompt_db_root_password
    else
      fail "Please specify --db-root-pass in non-interactive mode"
    fi
    db_user_host=${db_user_host:-$(derive_db_user_host "${db_host}")}
    if [ "${db_user_host_given}" != 'y' ] && stdin_is_tty; then
      prompt_db_user_host
    fi
    validate_db_user_host
    db_name=${db_name:-wp_${site_ident}}
    db_user=${db_user:-wpu_${site_ident}}
    db_pass=${db_pass:-$(random_string 18)}
  fi
  table_prefix=${table_prefix:-wp_}
  db_name=$(echo "${db_name}" | cut -c1-32)
  db_user=$(echo "${db_user}" | cut -c1-32)

  if [ "${db_name_given}" != 'y' ] && stdin_is_tty; then
    prompt_db_name
  fi
  if [ -n "${db_name}" ]; then
    validate_db_name
  elif stdin_is_tty; then
    prompt_db_name
  else
    fail "Database name can not be empty"
  fi

  if [ "${db_user_given}" != 'y' ] && stdin_is_tty; then
    prompt_db_user
  fi
  if [ -n "${db_user}" ]; then
    validate_db_user
  elif stdin_is_tty; then
    prompt_db_user
  else
    fail "Database user can not be empty"
  fi

  if [ "${db_pass_given}" != 'y' ] && stdin_is_tty; then
    prompt_db_pass
  fi
  if [ -n "${db_pass}" ]; then
    :
  elif stdin_is_tty; then
    prompt_db_pass
  else
    fail "Database password can not be empty"
  fi

  if [ "${table_prefix_given}" != 'y' ] && stdin_is_tty; then
    prompt_table_prefix
  fi
  validate_table_prefix

  if [ -n "${mphp_ver}" ] && [[ ! "${mphp_ver}" =~ ^7[0-4]$|^8[0-5]$ ]]; then
    fail "mphp_ver only supports 70~85"
  fi

  validate_wp_version
}

ensure_site_not_exists() {
  [ ! -e "${web_install_dir}/conf/vhost/${domain}.conf" ] || fail "Virtual host ${domain} already exists"
  if [ -d "${vhostdir}" ] && find "${vhostdir}" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    fail "Directory ${vhostdir} is not empty"
  fi
}

prepare_directories() {
  mkdir -p "${vhostdir}" "${wwwlogs_dir}" "${web_install_dir}/conf/vhost" "${web_install_dir}/conf/rewrite"
  chown -R "${run_user}:${run_group}" "${vhostdir}"
  /bin/cp -f "${oneinstack_dir}/config/wordpress.conf" "${web_install_dir}/conf/rewrite/wordpress.conf"
}

mysql_exec() {
  local defaults_file
  defaults_file=$(mktemp /tmp/qilnmp-mysql.XXXXXX) || fail "Create temporary MySQL defaults file failed"
  cat > "${defaults_file}" <<EOF
[client]
user=root
password=${db_root_pass}
EOF
  chmod 600 "${defaults_file}"
  "${db_install_dir}/bin/mysql" --defaults-extra-file="${defaults_file}" -Nse "$1"
  local ret=$?
  rm -f "${defaults_file}"
  return ${ret}
}

check_db_root_login() {
  mysql_exec "select 1;" >/dev/null 2>&1 || fail "Database root login failed, please check --db-root-pass"
}

create_database() {
  local table_count
  local sql_db_user
  local sql_db_user_host
  local sql_db_pass

  sql_db_user=$(sql_escape_string "${db_user}")
  sql_db_user_host=$(sql_escape_string "${db_user_host}")
  sql_db_pass=$(sql_escape_string "${db_pass}")

  mysql_exec "CREATE DATABASE IF NOT EXISTS \`${db_name}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null \
    || fail "Create database ${db_name} failed"

  table_count=$(mysql_exec "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db_name}';" 2>/dev/null)
  table_count=${table_count:-0}
  if [ "${table_count}" != '0' ]; then
    fail "Database ${db_name} is not empty"
  fi

  if ! mysql_exec "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${sql_db_user}'@'${sql_db_user_host}' IDENTIFIED BY '${sql_db_pass}'; FLUSH PRIVILEGES;" >/dev/null 2>&1; then
    mysql_exec "CREATE USER IF NOT EXISTS '${sql_db_user}'@'${sql_db_user_host}' IDENTIFIED BY '${sql_db_pass}';" >/dev/null 2>&1 \
      || fail "Create database user ${db_user} failed"
    mysql_exec "ALTER USER '${sql_db_user}'@'${sql_db_user_host}' IDENTIFIED BY '${sql_db_pass}';" >/dev/null 2>&1 \
      || fail "Alter database user ${db_user} failed"
    mysql_exec "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${sql_db_user}'@'${sql_db_user_host}'; FLUSH PRIVILEGES;" >/dev/null 2>&1 \
      || fail "Grant database privileges for ${db_user} failed"
  fi
}

download_wordpress() {
  local archive_name=""
  local tmp_dir=""

  if [ "${wp_version}" = 'latest' ]; then
    archive_name="wordpress-latest.tar.gz"
    src_url="${mirror_link}/src/${archive_name}"
    src_url_backup="https://wordpress.org/latest.tar.gz"
  else
    archive_name="wordpress-${wp_version}.tar.gz"
    src_url="${mirror_link}/src/${archive_name}"
    src_url_backup="https://wordpress.org/wordpress-${wp_version}.tar.gz"
  fi

  pushd "${oneinstack_dir}/src" > /dev/null || exit 1
  Download_src
  popd > /dev/null || exit 1
  unset src_url src_url_backup

  tmp_dir=$(mktemp -d /tmp/qilnmp-wordpress.XXXXXX)
  tar xzf "${oneinstack_dir}/src/${archive_name}" -C "${tmp_dir}" >/dev/null 2>&1 || {
    rm -rf "${tmp_dir}"
    fail "Extract WordPress package failed"
  }
  [ -d "${tmp_dir}/wordpress" ] || {
    rm -rf "${tmp_dir}"
    fail "WordPress package structure is invalid"
  }
  cp -a "${tmp_dir}/wordpress/." "${vhostdir}/" || {
    rm -rf "${tmp_dir}"
    fail "Copy WordPress files failed"
  }
  rm -rf "${tmp_dir}"
  chown -R "${run_user}:${run_group}" "${vhostdir}"
}

write_wp_config() {
  local php_db_name
  local php_db_user
  local php_db_pass
  local php_db_host
  local php_table_prefix

  php_db_name=$(php_single_quote_escape "${db_name}")
  php_db_user=$(php_single_quote_escape "${db_user}")
  php_db_pass=$(php_single_quote_escape "${db_pass}")
  php_db_host=$(php_single_quote_escape "${db_host}")
  php_table_prefix=$(php_single_quote_escape "${table_prefix}")

  [ -f "${vhostdir}/wp-config-sample.php" ] || fail "wp-config-sample.php not found in ${vhostdir}"
  [ ! -f "${vhostdir}/wp-config.php" ] || fail "wp-config.php already exists in ${vhostdir}"

  cat > "${vhostdir}/wp-config.php" <<EOF
<?php
define( 'DB_NAME', '${php_db_name}' );
define( 'DB_USER', '${php_db_user}' );
define( 'DB_PASSWORD', '${php_db_pass}' );
define( 'DB_HOST', '${php_db_host}' );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

define( 'AUTH_KEY',         '${wp_auth_key}' );
define( 'SECURE_AUTH_KEY',  '${wp_secure_auth_key}' );
define( 'LOGGED_IN_KEY',    '${wp_logged_in_key}' );
define( 'NONCE_KEY',        '${wp_nonce_key}' );
define( 'AUTH_SALT',        '${wp_auth_salt}' );
define( 'SECURE_AUTH_SALT', '${wp_secure_auth_salt}' );
define( 'LOGGED_IN_SALT',   '${wp_logged_in_salt}' );
define( 'NONCE_SALT',       '${wp_nonce_salt}' );

\$table_prefix = '${php_table_prefix}';

define( 'WP_DEBUG', false );
define( 'DISALLOW_FILE_EDIT', true );

if ( ! defined( 'ABSPATH' ) ) {
  define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOF

  chown "${run_user}:${run_group}" "${vhostdir}/wp-config.php"
  chmod 640 "${vhostdir}/wp-config.php"
}

build_ssl_block() {
  cat <<EOF
  ssl_certificate ${active_ssl_crt};
  ssl_certificate_key ${active_ssl_key};
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ecdh_curve X25519:prime256v1:secp384r1:secp521r1;
  ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256;
  ssl_conf_command Ciphersuites TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256;
  ssl_conf_command Options PrioritizeChaCha;
  ssl_prefer_server_ciphers on;
  ssl_session_timeout 10m;
  ssl_session_cache shared:SSL:10m;
  ssl_buffer_size 2k;
  add_header Strict-Transport-Security max-age=15768000;
  ssl_stapling on;
  ssl_stapling_verify on;
EOF
}

build_wordpress_locations() {
  cat <<EOF
  include ${web_install_dir}/conf/rewrite/wordpress.conf;

  location = /robots.txt {
    allow all;
    log_not_found off;
    access_log off;
  }

  location ~* \.(log|logs|debug|txt)$ {
    deny all;
    access_log off;
    log_not_found off;
  }

  location = /wp-content/debug.log {
    deny all;
  }

  location ~* ^/wp-content/.*\.(log|txt|dat|BIN|debug)$ {
    deny all;
  }

  location ~ /\.(?!well-known).* {
    deny all;
  }

  location ~* ^/(wp-config\.php|readme\.html|license\.txt)$ {
    deny all;
  }

  location ~* ^/wp-includes/.*\.php$ {
    deny all;
  }

  location ~ [^/]\.php(/|$) {
    fastcgi_pass unix:${php_sock};
    fastcgi_index index.php;
    include fastcgi.conf;
  }

  location ~* \.(gif|jpg|jpeg|png|bmp|swf|flv|mp4|ico|webp)$ {
    expires 30d;
    access_log off;
  }

  location ~* \.(js|css|svg|woff|woff2)$ {
    expires 7d;
    access_log off;
  }

  location ~ /\.ht {
    deny all;
  }
EOF
}

build_http_wordpress_server() {
  local wordpress_locations

  wordpress_locations=$(build_wordpress_locations)

  cat <<EOF
server {
  listen 80;
$( [ "${has_ipv6}" = 'y' ] && echo "  listen [::]:80;" )
  server_name ${domain};
  access_log ${wwwlogs_dir}/${domain}_nginx.log combined;
  index index.html index.htm index.php;
  root ${vhostdir};

${wordpress_locations}
}
EOF
}

build_http_redirect_server() {
  cat <<EOF
server {
  listen 80;
$( [ "${has_ipv6}" = 'y' ] && echo "  listen [::]:80;" )
  server_name ${domain};
  return 301 https://\$host\$request_uri;
}
EOF
}

install_own_cert() {
  mkdir -p "${web_install_dir}/conf/ssl"
  active_ssl_crt="${web_install_dir}/conf/ssl/${domain}.crt"
  active_ssl_key="${web_install_dir}/conf/ssl/${domain}.key"

  if [ -n "${ssl_crt}" ] && [ -n "${ssl_key}" ]; then
    /bin/cp -f "${ssl_crt}" "${active_ssl_crt}" || fail "Copy certificate file failed"
    /bin/cp -f "${ssl_key}" "${active_ssl_key}" || fail "Copy private key file failed"
    return 0
  fi

  command -v openssl >/dev/null 2>&1 || fail "openssl command not found"
  openssl req -utf8 -new -newkey rsa:2048 -sha256 -nodes \
    -out "${web_install_dir}/conf/ssl/${domain}.csr" \
    -keyout "${active_ssl_key}" \
    -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Example Inc./OU=IT Dept./CN=${domain}" >/dev/null 2>&1 \
    || fail "Create self-signed certificate request failed"
  openssl x509 -req -days 36500 -sha256 \
    -in "${web_install_dir}/conf/ssl/${domain}.csr" \
    -signkey "${active_ssl_key}" \
    -out "${active_ssl_crt}" >/dev/null 2>&1 \
    || fail "Create self-signed certificate failed"
}

write_http_vhost() {
  build_http_wordpress_server > "${web_install_dir}/conf/vhost/${domain}.conf"
}

write_ssl_vhost() {
  local ssl_block
  local http_server_block
  local wordpress_locations
  ssl_block=$(build_ssl_block)
  wordpress_locations=$(build_wordpress_locations)
  if [ "${ssl_redirect}" = 'y' ]; then
    http_server_block=$(build_http_redirect_server)
  else
    http_server_block=$(build_http_wordpress_server)
  fi

  cat > "${web_install_dir}/conf/vhost/${domain}.conf" <<EOF
${http_server_block}

server {
  listen ${https_listen};
$( [ "${has_ipv6}" = 'y' ] && echo "  listen [::]:${https_listen_v6};" )
${http2_directive}
  server_name ${domain};
  access_log ${wwwlogs_dir}/${domain}_nginx.log combined;
  index index.html index.htm index.php;
  root ${vhostdir};

${ssl_block}
${wordpress_locations}
}
EOF
}

write_letsencrypt_bootstrap_vhost() {
  cat > "${web_install_dir}/conf/vhost/${domain}.conf" <<EOF
server {
  listen 80;
$( [ "${has_ipv6}" = 'y' ] && echo "  listen [::]:80;" )
  server_name ${domain};
  root ${vhostdir};
  access_log off;

  location /.well-known/acme-challenge/ {
    allow all;
  }

  location / {
    try_files \$uri \$uri/ =404;
  }
}
EOF
}

reload_nginx() {
  "${web_install_dir}/sbin/nginx" -t >/dev/null 2>&1 || fail "Nginx configuration test failed"
  "${web_install_dir}/sbin/nginx" -s reload >/dev/null 2>&1 || fail "Reload Nginx failed"
}

install_acme_if_needed() {
  [ -x "${HOME}/.acme.sh/acme.sh" ] && return 0

  pushd "${oneinstack_dir}/src" > /dev/null || exit 1
  src_url="${mirror_link}/src/acme.sh-master.tar.gz"
  src_url_backup="https://github.com/acmesh-official/acme.sh/archive/refs/heads/master.tar.gz"
  Download_src
  tar xzf acme.sh-master.tar.gz >/dev/null 2>&1 || fail "Extract acme.sh failed"
  pushd acme.sh-master > /dev/null || exit 1
  ./acme.sh --install >/dev/null 2>&1 || fail "Install acme.sh failed"
  popd > /dev/null || exit 1
  popd > /dev/null || exit 1
  unset src_url src_url_backup
}

issue_letsencrypt_cert() {
  local auth_file=""
  local auth_str="oneinstack"
  local curl_str=""

  install_acme_if_needed
  [ -e "${HOME}/.acme.sh/account.conf" ] && sed -i '/^CERT_HOME=/d' "${HOME}/.acme.sh/account.conf"

  if [ ! -e "${HOME}/.acme.sh/ca/acme.zerossl.com/v2/DV90/account.key" ]; then
    "${HOME}/.acme.sh/acme.sh" --register-account -m "${letsencrypt_email}" >/dev/null 2>&1 \
      || fail "Register Let's Encrypt account failed"
  fi

  mkdir -p "${web_install_dir}/conf/ssl"
  write_letsencrypt_bootstrap_vhost
  reload_nginx

  auth_file="$(random_string 8).html"
  echo "${auth_str}" > "${vhostdir}/${auth_file}"
  curl_str=$(curl --connect-timeout 30 -4 -s "http://${domain}/${auth_file}" 2>/dev/null || true)
  rm -f "${vhostdir}/${auth_file}"
  [ "${curl_str}" = "${auth_str}" ] || fail "Let's Encrypt pre-check failed, please confirm ${domain} already resolves to this server"

  "${HOME}/.acme.sh/acme.sh" --force --issue -k 2048 -w "${vhostdir}" -d "${domain}" >/dev/null 2>&1 \
    || fail "Issue Let's Encrypt certificate failed"

  "${HOME}/.acme.sh/acme.sh" --force --install-cert -d "${domain}" \
    --fullchain-file "${web_install_dir}/conf/ssl/${domain}.crt" \
    --key-file "${web_install_dir}/conf/ssl/${domain}.key" \
    --reloadcmd "${web_install_dir}/sbin/nginx -s reload" >/dev/null 2>&1 \
    || fail "Install Let's Encrypt certificate failed"

  active_ssl_crt="${web_install_dir}/conf/ssl/${domain}.crt"
  active_ssl_key="${web_install_dir}/conf/ssl/${domain}.key"
}

print_summary() {
  local site_url="http://${domain}"

  [ "${ssl_mode}" != 'none' ] && site_url="https://${domain}"

  printf "
#######################################################################
#       QILNMP WordPress Deployer                                   #
#      For more information please visit https://qiling.jingxialai.com #
#######################################################################
"
  echo "$(printf "%-30s" "Your domain:")${CMSG}${domain}${CEND}"
  echo "$(printf "%-30s" "Site directory:")${CMSG}${vhostdir}${CEND}"
  echo "$(printf "%-30s" "Virtualhost conf:")${CMSG}${web_install_dir}/conf/vhost/${domain}.conf${CEND}"
  echo "$(printf "%-30s" "WordPress URL:")${CMSG}${site_url}${CEND}"
  echo "$(printf "%-30s" "Install URL:")${CMSG}${site_url}/wp-admin/install.php${CEND}"
  echo "$(printf "%-30s" "Database create mode:")${CMSG}${db_create}${CEND}"
  echo "$(printf "%-30s" "Database host:")${CMSG}${db_host}${CEND}"
  echo "$(printf "%-30s" "Database name:")${CMSG}${db_name}${CEND}"
  echo "$(printf "%-30s" "Database user:")${CMSG}${db_user}${CEND}"
  echo "$(printf "%-30s" "Database password:")${CMSG}${db_pass}${CEND}"
  [ "${db_create}" = 'y' ] && echo "$(printf "%-30s" "Database user host:")${CMSG}${db_user_host}${CEND}"
  echo "$(printf "%-30s" "Table prefix:")${CMSG}${table_prefix}${CEND}"
  echo "$(printf "%-30s" "SSL mode:")${CMSG}${ssl_mode}${CEND}"
  if [ "${ssl_mode}" = 'own' ] || [ "${ssl_mode}" = 'letsencrypt' ]; then
    echo "$(printf "%-30s" "HTTPS redirect:")${CMSG}${ssl_redirect}${CEND}"
    echo "$(printf "%-30s" "SSL certificate:")${CMSG}${active_ssl_crt}${CEND}"
    echo "$(printf "%-30s" "SSL private key:")${CMSG}${active_ssl_key}${CEND}"
  fi
}

ARG_NUM=$#
wp_version=latest
TEMP=$(getopt -o hq --long help,quiet,domain:,dir:,ssl:,ssl-crt:,ssl-key:,letsencrypt-email:,db-create:,db-name:,db-user:,db-pass:,db-host:,db-user-host:,table-prefix:,db-root-pass:,mphp_ver:,wp-version:,ssl-redirect: -- "$@" 2>/dev/null)
[ $? != 0 ] && echo "${CWARNING}ERROR: unknown argument! ${CEND}" && Show_Help && exit 1
eval set -- "${TEMP}"
while :; do
  [ -z "$1" ] && break
  case "$1" in
    -h|--help)
      Show_Help
      exit 0
      ;;
    -q|--quiet)
      quiet_flag=y
      shift 1
      ;;
    --domain)
      domain=$2
      shift 2
      ;;
    --dir)
      vhostdir=$2
      shift 2
      ;;
    --ssl)
      ssl_mode=$2
      shift 2
      ;;
    --ssl-crt)
      ssl_crt=$2
      shift 2
      ;;
    --ssl-key)
      ssl_key=$2
      shift 2
      ;;
    --letsencrypt-email)
      letsencrypt_email=$2
      shift 2
      ;;
    --db-create)
      db_create=$2
      shift 2
      ;;
    --db-name)
      db_name=$2
      db_name_given=y
      shift 2
      ;;
    --db-user)
      db_user=$2
      db_user_given=y
      shift 2
      ;;
    --db-pass)
      db_pass=$2
      db_pass_given=y
      shift 2
      ;;
    --db-host)
      db_host=$2
      db_host_given=y
      shift 2
      ;;
    --db-user-host)
      db_user_host=$2
      db_user_host_given=y
      shift 2
      ;;
    --table-prefix)
      table_prefix=$2
      table_prefix_given=y
      shift 2
      ;;
    --db-root-pass)
      db_root_pass=$2
      shift 2
      ;;
    --mphp_ver)
      mphp_ver=$2
      shift 2
      ;;
    --wp-version)
      wp_version=$2
      shift 2
      ;;
    --ssl-redirect)
      ssl_redirect=$2
      shift 2
      ;;
    --)
      shift
      ;;
    *)
      echo "${CWARNING}ERROR: unknown argument! ${CEND}"
      Show_Help
      exit 1
      ;;
  esac
done

need_root
ensure_environment
ensure_inputs
if [ "${db_create}" = 'y' ]; then
  ensure_local_database_environment
fi
detect_php_socket
detect_ipv6
detect_https_options
if [ "${db_create}" = 'y' ]; then
  check_db_root_login
fi
ensure_site_not_exists
prepare_directories
if [ "${db_create}" = 'y' ]; then
  create_database
fi
download_wordpress

wp_auth_key=$(random_salt)
wp_secure_auth_key=$(random_salt)
wp_logged_in_key=$(random_salt)
wp_nonce_key=$(random_salt)
wp_auth_salt=$(random_salt)
wp_secure_auth_salt=$(random_salt)
wp_logged_in_salt=$(random_salt)
wp_nonce_salt=$(random_salt)
write_wp_config

case "${ssl_mode}" in
  none)
    write_http_vhost
    ;;
  own)
    install_own_cert
    write_ssl_vhost
    ;;
  letsencrypt)
    issue_letsencrypt_cert
    write_ssl_vhost
    ;;
esac

reload_nginx
print_summary
