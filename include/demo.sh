#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: QILNMP for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack
#
# Fork Maintainer:
#       summer <iticu@qq.com>
#       https://qiling.jingxialai.com
#       https://github.com/wujiit/qilnmp
# Based on upstream OneinStack, maintained by QILNMP fork.

DEMO() {
  pushd ${oneinstack_dir}/src > /dev/null

  get_first_line() {
    "$@" 2>&1 | head -n1 | sed 's/^[[:space:]]*//'
  }

  service_state() {
    local svc="$1"
    if command -v systemctl >/dev/null 2>&1; then
      local state
      state=$(systemctl is-active "${svc}" 2>/dev/null || true)
      [ -z "${state}" ] && state='not-found'
      echo "${state}"
    else
      echo "unknown(no-systemctl)"
    fi
  }

  service_state_first() {
    local svc
    for svc in "$@"; do
      if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-unit-files "${svc}.service" --no-legend 2>/dev/null | grep -q "${svc}.service"; then
          service_state "${svc}"
          return
        fi
      fi
    done
    if command -v systemctl >/dev/null 2>&1; then
      echo "not-found"
    else
      echo "unknown(no-systemctl)"
    fi
  }

  html_escape() {
    echo "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
  }

  add_component() {
    local comp_name="$1"
    local comp_ver
    local comp_state
    comp_ver=$(html_escape "$2")
    comp_state=$(html_escape "${3:-installed}")
    component_rows="${component_rows}
        <tr><td>${comp_name}</td><td>${comp_ver}</td><td>${comp_state}</td></tr>"
    component_count=$((component_count + 1))
  }

  add_quick_link() {
    local link_name="$1"
    local link_href="$2"
    quick_links_html="${quick_links_html}<a class=\"qbtn\" href=\"${link_href}\" target=\"_blank\">${link_name}</a>"
    quick_link_count=$((quick_link_count + 1))
  }

  [ ! -d "${wwwroot_dir}/default" ] && mkdir -p ${wwwroot_dir}/default

  component_rows=''
  component_count=0
  php_extensions_html='<p class="muted">PHP is not installed.</p>'
  quick_links_html=''
  quick_link_count=0

  [ -x "${nginx_install_dir}/sbin/nginx" ] && add_component "Nginx" "$(get_first_line "${nginx_install_dir}/sbin/nginx" -v)" "$(service_state_first nginx)"
  [ -x "${tengine_install_dir}/sbin/nginx" ] && add_component "Tengine" "$(get_first_line "${tengine_install_dir}/sbin/nginx" -v)" "$(service_state_first nginx)"
  [ -x "${openresty_install_dir}/nginx/sbin/nginx" ] && add_component "OpenResty" "$(get_first_line "${openresty_install_dir}/nginx/sbin/nginx" -V)" "$(service_state_first nginx)"
  [ -x "${caddy_install_dir}/bin/caddy" ] && add_component "Caddy" "$(get_first_line "${caddy_install_dir}/bin/caddy" version)" "$(service_state_first caddy)"
  [ -x "${apache_install_dir}/bin/httpd" ] && add_component "Apache" "$(get_first_line "${apache_install_dir}/bin/httpd" -v)" "$(service_state_first httpd apache2)"

  [ -x "${php_install_dir}/bin/php" ] && add_component "PHP" "$("${php_install_dir}/bin/php" -r 'echo PHP_VERSION;' 2>/dev/null)" "$(service_state_first php-fpm)"

  if [ -x "${mysql_install_dir}/bin/mysqld" ]; then
    add_component "MySQL" "$(get_first_line "${mysql_install_dir}/bin/mysqld" --version)" "$(service_state_first mysqld mysql)"
  elif [ -x "${mysql_install_dir}/bin/mysql" ]; then
    add_component "MySQL Client" "$(get_first_line "${mysql_install_dir}/bin/mysql" --version)" "installed"
  fi

  if [ -x "${mariadb_install_dir}/bin/mysqld" ]; then
    add_component "MariaDB" "$(get_first_line "${mariadb_install_dir}/bin/mysqld" --version)" "$(service_state_first mariadb)"
  elif [ -x "${mariadb_install_dir}/bin/mysql" ]; then
    add_component "MariaDB Client" "$(get_first_line "${mariadb_install_dir}/bin/mysql" --version)" "installed"
  fi

  if [ -x "${percona_install_dir}/bin/mysqld" ]; then
    add_component "Percona" "$(get_first_line "${percona_install_dir}/bin/mysqld" --version)" "$(service_state_first mysqld mysql)"
  elif [ -x "${percona_install_dir}/bin/mysql" ]; then
    add_component "Percona Client" "$(get_first_line "${percona_install_dir}/bin/mysql" --version)" "installed"
  fi

  if [ -x "${pgsql_install_dir}/bin/postgres" ]; then
    add_component "PostgreSQL" "$(get_first_line "${pgsql_install_dir}/bin/postgres" --version)" "$(service_state_first postgresql)"
  elif [ -x "${pgsql_install_dir}/bin/psql" ]; then
    add_component "PostgreSQL Client" "$(get_first_line "${pgsql_install_dir}/bin/psql" --version)" "installed"
  fi

  if [ -x "${mongo_install_dir}/bin/mongod" ]; then
    add_component "MongoDB" "$(get_first_line "${mongo_install_dir}/bin/mongod" --version)" "$(service_state_first mongod)"
  elif [ -x "${mongo_install_dir}/bin/mongo" ]; then
    add_component "MongoDB Shell" "$(get_first_line "${mongo_install_dir}/bin/mongo" --version)" "installed"
  fi

  [ -x "${redis_install_dir}/bin/redis-server" ] && add_component "Redis Server" "$(get_first_line "${redis_install_dir}/bin/redis-server" --version)" "$(service_state_first redis-server redis)"
  [ -x "${memcached_install_dir}/bin/memcached" ] && add_component "Memcached" "$(get_first_line "${memcached_install_dir}/bin/memcached" -h)" "$(service_state_first memcached)"
  [ -x "${pureftpd_install_dir}/sbin/pure-ftpd" ] && add_component "Pure-FTPd" "$(get_first_line "${pureftpd_install_dir}/sbin/pure-ftpd" -v)" "$(service_state_first pureftpd pure-ftpd)"

  if [ -d "${wwwroot_dir}/default/phpMyAdmin" ]; then
    if [ -f "${wwwroot_dir}/default/phpMyAdmin/README" ]; then
      phpmyadmin_ver=$(awk '/Version/{print $2; exit}' "${wwwroot_dir}/default/phpMyAdmin/README")
      [ -z "${phpmyadmin_ver}" ] && phpmyadmin_ver='installed'
      add_component "phpMyAdmin" "${phpmyadmin_ver}" "web-app"
    else
      add_component "phpMyAdmin" "installed" "web-app"
    fi
  fi

  if [ -x "${php_install_dir}/bin/php" ]; then
    php_ext_list=$(${php_install_dir}/bin/php -m 2>/dev/null | awk 'NF && $0 !~ /^\[/' | sort -u)
    if [ -n "${php_ext_list}" ]; then
      php_ext_count=$(printf "%s\n" "${php_ext_list}" | awk 'NF' | wc -l | awk '{print $1}')
      add_component "PHP Extensions" "${php_ext_count} modules" "loaded"
      php_extensions_html=$(printf "%s\n" "${php_ext_list}" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
      php_extensions_html="<pre>${php_extensions_html}</pre>"
    else
      php_extensions_html='<p class="muted">No PHP extensions detected.</p>'
    fi

    add_quick_link "探针 xprober" "/xprober.php"
    add_quick_link "phpinfo" "/phpinfo.php"
    if [ "${phpcache_option}" == '1' ] || [ -f "${wwwroot_dir}/default/ocp.php" ] || [ -f "ocp.php" ]; then
      add_quick_link "OPcache 面板 (ocp.php)" "/ocp.php"
    fi
    if [ "${phpcache_option}" == '4' ] || [ -f "${wwwroot_dir}/default/control.php" ]; then
      add_quick_link "eAccelerator 面板" "/control.php"
    fi
  fi

  [ -d "${wwwroot_dir}/default/phpMyAdmin" ] && add_quick_link "phpMyAdmin" "/phpMyAdmin/"

  [ ${quick_link_count} -eq 0 ] && quick_links_html='<p class="muted">暂无可用入口。</p>'

  [ ${component_count} -eq 0 ] && component_rows='
        <tr><td colspan="3">No known stack components detected.</td></tr>'

  cat > ${wwwroot_dir}/default/index.html << EOF
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>QILNMP 已安装软件清单</title>
  <style>
    :root { --bg:#f4f6fb; --card:#fff; --text:#222; --muted:#6b7280; --line:#e5e7eb; --head:#0f172a; }
    * { box-sizing: border-box; }
    body { margin:0; background:var(--bg); color:var(--text); font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"PingFang SC","Microsoft YaHei",sans-serif; }
    .wrap { max-width: 960px; margin: 40px auto; padding: 0 16px; }
    .card { background: var(--card); border:1px solid var(--line); border-radius:14px; padding: 24px; box-shadow: 0 8px 28px rgba(15,23,42,.06); margin-bottom:16px; }
    h1 { margin:0 0 8px; color:var(--head); font-size:30px; }
    p { margin:0; color:var(--muted); }
    h2 { margin: 24px 0 12px; font-size: 20px; color:var(--head); }
    table { width:100%; border-collapse: collapse; border:1px solid var(--line); border-radius: 10px; overflow: hidden; }
    th,td { padding: 12px 14px; border-bottom:1px solid var(--line); text-align: left; vertical-align: top; }
    th { background:#f8fafc; color:#111827; font-weight:600; }
    tr:last-child td { border-bottom:0; }
    pre { margin:0; padding:14px; border:1px solid var(--line); border-radius:10px; background:#f8fafc; overflow:auto; white-space:pre-wrap; word-break:break-word; font-size:13px; line-height:1.5; }
    .muted { color: var(--muted); }
    .foot { margin-top:16px; color:var(--muted); font-size:13px; }
    .quick-links { display:flex; flex-wrap:wrap; gap:10px; margin-top:8px; }
    .qbtn { display:inline-block; padding:8px 12px; border-radius:8px; border:1px solid var(--line); text-decoration:none; color:#0f172a; background:#f8fafc; }
    .qbtn:hover { background:#eef2ff; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>已安装软件清单</h1>
      <p>Host: $(hostname 2>/dev/null || echo unknown) | Generated: $(date '+%Y-%m-%d %H:%M:%S %z')</p>
      <h2>软件列表</h2>
      <table>
        <thead>
          <tr><th>组件</th><th>版本 / 说明</th><th>运行状态</th></tr>
        </thead>
        <tbody>${component_rows}
        </tbody>
      </table>
      <h2>快速入口</h2>
      <div class="quick-links">${quick_links_html}</div>
    </div>

    <div class="card">
      <h2>常用运维命令</h2>
      <pre># Nginx
systemctl status nginx
systemctl restart nginx
nginx -t

# PHP-FPM
systemctl status php-fpm
systemctl restart php-fpm
service php-fpm restart

# MySQL
systemctl status mysqld
systemctl restart mysqld

# Redis
systemctl status redis-server
systemctl restart redis-server

# Memcached
systemctl status memcached
systemctl restart memcached

# 查看最近日志（把 SERVICE_NAME 换成 nginx/php-fpm/mysqld/redis-server）
journalctl -u SERVICE_NAME -n 100 --no-pager</pre>
    </div>

    <div class="card">
      <h2>组件安装（常用）</h2>
      <pre># 进入 QILNMP 目录
cd ~/qilnmp

# 快速安装 fileinfo（PHP 扩展）
./install.sh --php_extensions fileinfo
systemctl restart php-fpm || service php-fpm restart
php --ri fileinfo

# 快速安装 redis 扩展
./install.sh --php_extensions redis
systemctl restart php-fpm || service php-fpm restart
php --ri redis

# 快速安装 imagick 扩展
./install.sh --php_extensions imagick
systemctl restart php-fpm || service php-fpm restart
php --ri imagick

# 一次安装多个扩展（示例）
./install.sh --php_extensions "fileinfo redis imagick"

# 快速安装 Redis 服务端（网站对象缓存要用）
./install.sh --redis
systemctl enable --now redis-server
/usr/local/redis/bin/redis-cli ping</pre>
    </div>

    <div class="card">
      <h2>PHP 扩展</h2>
      ${php_extensions_html}
      <div class="foot">Generated by QILNMP install script.</div>
      <div class="foot">
        作者: summer | Email: iticu@qq.com<br/>
        网址: <a href="https://qiling.jingxialai.com" target="_blank">qiling.jingxialai.com</a> |
        GitHub: <a href="https://github.com/wujiit/qilnmp" target="_blank">wujiit/qilnmp</a><br/>
        QQ 群号: 16966111
      </div>
    </div>
  </div>
</body>
</html>
EOF

  if [ -e "${php_install_dir}/bin/php" ]; then
    src_url=${mirror_link}/src/xprober.php && Download_src
    [ -f xprober.php ] && /bin/cp xprober.php ${wwwroot_dir}/default

    echo "<?php phpinfo() ?>" > ${wwwroot_dir}/default/phpinfo.php
    case "${phpcache_option}" in
      1)
        src_url=${mirror_link}/src/ocp.php && Download_src
        [ -f ocp.php ] && /bin/cp ocp.php ${wwwroot_dir}/default
        ;;
      4)
        [ -e eaccelerator-*/control.php ] && /bin/cp eaccelerator-*/control.php ${wwwroot_dir}/default
        ;;
    esac
  fi
  chown -R ${run_user}:${run_group} ${wwwroot_dir}/default
  [ -e /bin/systemctl ] && systemctl daemon-reload
  popd > /dev/null
}
