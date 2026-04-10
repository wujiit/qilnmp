#!/bin/bash
# Author:  summer <iticu@qq.com>
# Notes:  QILNMP Nginx + Fail2ban basic security module

QILNMP_SECURITY_NAME=${QILNMP_SECURITY_NAME:-qilnmp-nginx-cc}
QILNMP_SECURITY_ROOT=${QILNMP_SECURITY_ROOT:-/etc/qilnmp-security}
QILNMP_SECURITY_STATE_FILE=${QILNMP_SECURITY_ROOT}/state.conf
QILNMP_SECURITY_BACKUP_ROOT=${QILNMP_SECURITY_ROOT}/backups
QILNMP_SECURITY_RELATIVE_CONF=${QILNMP_SECURITY_RELATIVE_CONF:-security/qilnmp-security.conf}
QILNMP_SECURITY_TEMPLATE_DIR=${oneinstack_dir}/config/security

QILNMP_SECURITY_RATE=${QILNMP_SECURITY_RATE:-15r/s}
QILNMP_SECURITY_BURST=${QILNMP_SECURITY_BURST:-30}
QILNMP_SECURITY_CONN=${QILNMP_SECURITY_CONN:-30}
QILNMP_SECURITY_FINDTIME=${QILNMP_SECURITY_FINDTIME:-60}
QILNMP_SECURITY_MAXRETRY=${QILNMP_SECURITY_MAXRETRY:-20}
QILNMP_SECURITY_BANTIME=${QILNMP_SECURITY_BANTIME:-3600}
QILNMP_SECURITY_IGNOREIP=${QILNMP_SECURITY_IGNOREIP:-127.0.0.1/8}

QILNMP_security_main_conf() {
  echo "${web_install_dir}/conf/nginx.conf"
}

QILNMP_security_conf_file() {
  echo "${web_install_dir}/conf/${QILNMP_SECURITY_RELATIVE_CONF}"
}

QILNMP_security_conf_dir() {
  echo "$(dirname "$(QILNMP_security_conf_file)")"
}

QILNMP_security_jail_file() {
  echo "/etc/fail2ban/jail.d/${QILNMP_SECURITY_NAME}.conf"
}

QILNMP_security_filter_file() {
  echo "/etc/fail2ban/filter.d/${QILNMP_SECURITY_NAME}.conf"
}

QILNMP_security_logpath() {
  echo "${wwwlogs_dir}/*nginx.log"
}

QILNMP_security_current_status() {
  if [ -e "${QILNMP_SECURITY_STATE_FILE}" ]; then
    . "${QILNMP_SECURITY_STATE_FILE}"
    echo "${STATUS:-unknown}"
  elif [ -e "$(QILNMP_security_conf_file)" ] && [ -e "$(QILNMP_security_jail_file)" ]; then
    echo "installed"
  else
    echo "not-installed"
  fi
}

QILNMP_security_write_state() {
  local status=$1
  local backup_dir=$2

  mkdir -p "${QILNMP_SECURITY_ROOT}"
  cat > "${QILNMP_SECURITY_STATE_FILE}" << EOF
STATUS='${status}'
WEB_INSTALL_DIR='${web_install_dir}'
NGINX_MAIN_CONF='$(QILNMP_security_main_conf)'
SECURITY_CONF='$(QILNMP_security_conf_file)'
FAIL2BAN_JAIL='$(QILNMP_security_jail_file)'
FAIL2BAN_FILTER='$(QILNMP_security_filter_file)'
LOGPATH='$(QILNMP_security_logpath)'
BACKUP_DIR='${backup_dir}'
RATE='${QILNMP_SECURITY_RATE}'
BURST='${QILNMP_SECURITY_BURST}'
CONN='${QILNMP_SECURITY_CONN}'
FINDTIME='${QILNMP_SECURITY_FINDTIME}'
MAXRETRY='${QILNMP_SECURITY_MAXRETRY}'
BANTIME='${QILNMP_SECURITY_BANTIME}'
IGNOREIP='${QILNMP_SECURITY_IGNOREIP}'
EOF
}

QILNMP_security_backup_context() {
  local backup_dir=$1
  local main_conf
  local security_conf
  local jail_file
  local filter_file

  main_conf=$(QILNMP_security_main_conf)
  security_conf=$(QILNMP_security_conf_file)
  jail_file=$(QILNMP_security_jail_file)
  filter_file=$(QILNMP_security_filter_file)

  mkdir -p "${backup_dir}"
  cat > "${backup_dir}/manifest.conf" << EOF
HAS_MAIN_CONF=0
HAS_SECURITY_CONF=0
HAS_JAIL=0
HAS_FILTER=0
HAS_STATE=0
EOF

  if [ -e "${main_conf}" ]; then
    cp -a "${main_conf}" "${backup_dir}/nginx.conf"
    sed -i "s@^HAS_MAIN_CONF=0@HAS_MAIN_CONF=1@" "${backup_dir}/manifest.conf"
  fi
  if [ -e "${security_conf}" ]; then
    cp -a "${security_conf}" "${backup_dir}/qilnmp-security.conf"
    sed -i "s@^HAS_SECURITY_CONF=0@HAS_SECURITY_CONF=1@" "${backup_dir}/manifest.conf"
  fi
  if [ -e "${jail_file}" ]; then
    cp -a "${jail_file}" "${backup_dir}/qilnmp-nginx-cc.jail.conf"
    sed -i "s@^HAS_JAIL=0@HAS_JAIL=1@" "${backup_dir}/manifest.conf"
  fi
  if [ -e "${filter_file}" ]; then
    cp -a "${filter_file}" "${backup_dir}/qilnmp-nginx-cc.filter.conf"
    sed -i "s@^HAS_FILTER=0@HAS_FILTER=1@" "${backup_dir}/manifest.conf"
  fi
  if [ -e "${QILNMP_SECURITY_STATE_FILE}" ]; then
    cp -a "${QILNMP_SECURITY_STATE_FILE}" "${backup_dir}/state.conf"
    sed -i "s@^HAS_STATE=0@HAS_STATE=1@" "${backup_dir}/manifest.conf"
  fi
}

QILNMP_security_restore_context() {
  local backup_dir=$1
  local main_conf
  local security_conf
  local jail_file
  local filter_file

  [ -e "${backup_dir}/manifest.conf" ] || return 1
  . "${backup_dir}/manifest.conf"

  main_conf=$(QILNMP_security_main_conf)
  security_conf=$(QILNMP_security_conf_file)
  jail_file=$(QILNMP_security_jail_file)
  filter_file=$(QILNMP_security_filter_file)

  if [ "${HAS_MAIN_CONF}" == '1' ] && [ -e "${backup_dir}/nginx.conf" ]; then
    cp -a "${backup_dir}/nginx.conf" "${main_conf}"
  fi

  if [ "${HAS_SECURITY_CONF}" == '1' ] && [ -e "${backup_dir}/qilnmp-security.conf" ]; then
    mkdir -p "$(dirname "${security_conf}")"
    cp -a "${backup_dir}/qilnmp-security.conf" "${security_conf}"
  else
    rm -f "${security_conf}"
  fi

  if [ "${HAS_JAIL}" == '1' ] && [ -e "${backup_dir}/qilnmp-nginx-cc.jail.conf" ]; then
    mkdir -p "$(dirname "${jail_file}")"
    cp -a "${backup_dir}/qilnmp-nginx-cc.jail.conf" "${jail_file}"
  else
    rm -f "${jail_file}"
  fi

  if [ "${HAS_FILTER}" == '1' ] && [ -e "${backup_dir}/qilnmp-nginx-cc.filter.conf" ]; then
    mkdir -p "$(dirname "${filter_file}")"
    cp -a "${backup_dir}/qilnmp-nginx-cc.filter.conf" "${filter_file}"
  else
    rm -f "${filter_file}"
  fi

  if [ "${HAS_STATE}" == '1' ] && [ -e "${backup_dir}/state.conf" ]; then
    mkdir -p "${QILNMP_SECURITY_ROOT}"
    cp -a "${backup_dir}/state.conf" "${QILNMP_SECURITY_STATE_FILE}"
  else
    rm -f "${QILNMP_SECURITY_STATE_FILE}"
  fi
}

QILNMP_security_transaction_dir() {
  mktemp -d /tmp/qilnmp-security.XXXXXX
}

QILNMP_security_persistent_backup_dir() {
  local backup_dir

  mkdir -p "${QILNMP_SECURITY_BACKUP_ROOT}"
  backup_dir=${QILNMP_SECURITY_BACKUP_ROOT}/$(date +%Y%m%d-%H%M%S)
  mkdir -p "${backup_dir}"
  echo "${backup_dir}"
}

QILNMP_security_detect_banaction() {
  if [ "${PM}" == 'apt-get' ] && command -v ufw >/dev/null 2>&1 && ufw status | grep -wq active; then
    echo "ufw"
    return 0
  elif [ "${PM}" == 'yum' ] && command -v firewall-cmd >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
    echo "firewallcmd-ipset"
    return 0
  elif command -v iptables >/dev/null 2>&1; then
    echo "iptables-multiport"
    return 0
  else
    return 1
  fi
}

QILNMP_security_existing_banaction() {
  local jail_file

  jail_file=$(QILNMP_security_jail_file)
  [ -e "${jail_file}" ] || return 1
  awk -F= '/^[[:space:]]*banaction[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${jail_file}"
}

QILNMP_security_resolve_banaction() {
  local mode=$1
  local banaction

  banaction=$(QILNMP_security_detect_banaction 2>/dev/null) && {
    echo "${banaction}"
    return 0
  }

  if [ "${mode}" != 'enabled' ]; then
    banaction=$(QILNMP_security_existing_banaction 2>/dev/null)
    [ -n "${banaction}" ] || banaction=iptables-multiport
    echo "${banaction}"
    return 0
  fi

  echo "${CFAILURE}Error: no supported fail2ban banaction backend detected. Enable ufw/firewalld or ensure iptables is available.${CEND}" >&2
  return 1
}

QILNMP_security_require_nginx() {
  local main_conf

  . "${oneinstack_dir}/include/check_dir.sh"
  main_conf=$(QILNMP_security_main_conf)

  [ -n "${web_install_dir}" ] || {
    echo "${CFAILURE}Error: Nginx/Tengine/OpenResty was not detected.${CEND}"
    return 1
  }
  [ -x "${web_install_dir}/sbin/nginx" ] || {
    echo "${CFAILURE}Error: ${web_install_dir}/sbin/nginx not found.${CEND}"
    return 1
  }
  [ -e "${main_conf}" ] || {
    echo "${CFAILURE}Error: Nginx main config not found: ${main_conf}${CEND}"
    return 1
  }
}

QILNMP_security_render_nginx_conf() {
  local mode=$1
  local security_conf

  security_conf=$(QILNMP_security_conf_file)
  mkdir -p "$(dirname "${security_conf}")"
  if [ "${mode}" == 'enabled' ]; then
    sed \
      -e "s|@RATE@|${QILNMP_SECURITY_RATE}|g" \
      -e "s|@BURST@|${QILNMP_SECURITY_BURST}|g" \
      -e "s|@CONN@|${QILNMP_SECURITY_CONN}|g" \
      "${QILNMP_SECURITY_TEMPLATE_DIR}/nginx-qilnmp-cc.conf.tpl" > "${security_conf}"
  else
    cat > "${security_conf}" << EOF
# QILNMP security module is disabled.
# The include remains in place so it can be re-enabled safely.
EOF
  fi
}

QILNMP_security_render_fail2ban_filter() {
  local filter_file

  filter_file=$(QILNMP_security_filter_file)
  mkdir -p "$(dirname "${filter_file}")"
  cp -f "${QILNMP_SECURITY_TEMPLATE_DIR}/fail2ban-qilnmp-nginx-cc.filter" "${filter_file}"
}

QILNMP_security_render_fail2ban_jail() {
  local mode=$1
  local jail_file
  local enabled_flag=false
  local banaction

  jail_file=$(QILNMP_security_jail_file)
  banaction=$(QILNMP_security_resolve_banaction "${mode}") || return 1
  [ "${mode}" == 'enabled' ] && enabled_flag=true
  mkdir -p "$(dirname "${jail_file}")"
  sed \
    -e "s|@ENABLED@|${enabled_flag}|g" \
    -e "s|@LOGPATH@|$(QILNMP_security_logpath)|g" \
    -e "s|@FINDTIME@|${QILNMP_SECURITY_FINDTIME}|g" \
    -e "s|@MAXRETRY@|${QILNMP_SECURITY_MAXRETRY}|g" \
    -e "s|@BANTIME@|${QILNMP_SECURITY_BANTIME}|g" \
    -e "s|@IGNOREIP@|${QILNMP_SECURITY_IGNOREIP}|g" \
    -e "s|@BANACTION@|${banaction}|g" \
    "${QILNMP_SECURITY_TEMPLATE_DIR}/fail2ban-qilnmp-nginx-cc.conf.tpl" > "${jail_file}"
}

QILNMP_security_ensure_include() {
  local main_conf
  local tmp_conf

  main_conf=$(QILNMP_security_main_conf)
  grep -q 'QILNMP_SECURITY_BEGIN' "${main_conf}" && return 0
  grep -q 'include security/qilnmp-security.conf;' "${main_conf}" && return 0

  tmp_conf=$(mktemp /tmp/qilnmp-nginx-conf.XXXXXX)
  awk '
    BEGIN { inserted=0 }
    /^[[:space:]]*include[[:space:]]+vhost\/\*\.conf;[[:space:]]*$/ && inserted==0 {
      print "  # QILNMP_SECURITY_BEGIN"
      print "  include security/qilnmp-security.conf;"
      print "  # QILNMP_SECURITY_END"
      inserted=1
    }
    { print }
    END {
      if (inserted==0) {
        exit 1
      }
    }
  ' "${main_conf}" > "${tmp_conf}" || {
    rm -f "${tmp_conf}"
    echo "${CFAILURE}Error: failed to insert QILNMP security include into ${main_conf}.${CEND}"
    return 1
  }
  cat "${tmp_conf}" > "${main_conf}"
  rm -f "${tmp_conf}"
}

QILNMP_security_remove_include() {
  local main_conf
  local tmp_conf

  main_conf=$(QILNMP_security_main_conf)
  tmp_conf=$(mktemp /tmp/qilnmp-nginx-conf.XXXXXX)
  if grep -q 'QILNMP_SECURITY_BEGIN' "${main_conf}"; then
    sed '/QILNMP_SECURITY_BEGIN/,/QILNMP_SECURITY_END/d' "${main_conf}" > "${tmp_conf}"
  else
    sed '/^[[:space:]]*include[[:space:]]\+security\/qilnmp-security\.conf;[[:space:]]*$/d' "${main_conf}" > "${tmp_conf}"
  fi
  cat "${tmp_conf}" > "${main_conf}"
  rm -f "${tmp_conf}"
}

QILNMP_security_test_nginx() {
  "${web_install_dir}/sbin/nginx" -t >/dev/null 2>&1
}

QILNMP_security_reload_nginx() {
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^nginx\.service'; then
    systemctl reload nginx >/dev/null 2>&1 || systemctl restart nginx >/dev/null 2>&1
  elif command -v service >/dev/null 2>&1; then
    service nginx reload >/dev/null 2>&1 || service nginx restart >/dev/null 2>&1
  else
    "${web_install_dir}/sbin/nginx" -s reload >/dev/null 2>&1
  fi
}

QILNMP_security_reload_fail2ban() {
  Restart_fail2ban_service
}

QILNMP_security_postcheck() {
  local manage_fail2ban=$1

  QILNMP_security_test_nginx || {
    echo "${CFAILURE}Error: nginx configuration test failed.${CEND}"
    return 1
  }
  if [ "${manage_fail2ban}" == 'y' ]; then
    Test_fail2ban_config || {
      echo "${CFAILURE}Error: fail2ban configuration test failed.${CEND}"
      return 1
    }
  fi
  return 0
}

QILNMP_security_rollback() {
  local backup_dir=$1

  [ -n "${backup_dir}" ] && [ -d "${backup_dir}" ] && QILNMP_security_restore_context "${backup_dir}" >/dev/null 2>&1
  QILNMP_security_test_nginx && QILNMP_security_reload_nginx >/dev/null 2>&1
  if Fail2ban_server_installed; then
    Test_fail2ban_config >/dev/null 2>&1 && QILNMP_security_reload_fail2ban >/dev/null 2>&1
  fi
}

QILNMP_security_apply_mode() {
  local mode=$1
  local ensure_fail2ban=${2:-y}
  local manage_fail2ban=n
  local txn_dir
  local backup_dir

  QILNMP_security_require_nginx || return 1
  if [ "${ensure_fail2ban}" == 'y' ]; then
    Ensure_fail2ban_installed || {
      echo "${CFAILURE}Error: fail2ban is not available on this server.${CEND}"
      return 1
    }
    manage_fail2ban=y
  elif Fail2ban_server_installed; then
    manage_fail2ban=y
  fi

  txn_dir=$(QILNMP_security_transaction_dir)
  backup_dir=$(QILNMP_security_persistent_backup_dir)
  QILNMP_security_backup_context "${txn_dir}"
  QILNMP_security_backup_context "${backup_dir}"

  QILNMP_security_ensure_include || {
    QILNMP_security_rollback "${txn_dir}"
    rm -rf "${txn_dir}"
    return 1
  }
  QILNMP_security_render_nginx_conf "${mode}" || {
    QILNMP_security_rollback "${txn_dir}"
    rm -rf "${txn_dir}"
    return 1
  }
  QILNMP_security_render_fail2ban_filter || {
    QILNMP_security_rollback "${txn_dir}"
    rm -rf "${txn_dir}"
    return 1
  }
  QILNMP_security_render_fail2ban_jail "${mode}" || {
    QILNMP_security_rollback "${txn_dir}"
    rm -rf "${txn_dir}"
    return 1
  }
  QILNMP_security_postcheck "${manage_fail2ban}" || {
    QILNMP_security_rollback "${txn_dir}"
    rm -rf "${txn_dir}"
    return 1
  }
  QILNMP_security_reload_nginx || {
    echo "${CFAILURE}Error: failed to reload nginx.${CEND}"
    QILNMP_security_rollback "${txn_dir}"
    rm -rf "${txn_dir}"
    return 1
  }
  if [ "${manage_fail2ban}" == 'y' ]; then
    QILNMP_security_reload_fail2ban || {
      echo "${CFAILURE}Error: failed to reload fail2ban.${CEND}"
      QILNMP_security_rollback "${txn_dir}"
      rm -rf "${txn_dir}"
      return 1
    }
  fi

  QILNMP_security_write_state "${mode}" "${backup_dir}"
  rm -rf "${txn_dir}"
  echo "${CSUCCESS}QILNMP security module ${mode} successfully! ${CEND}"
}

QILNMP_security_disable() {
  QILNMP_security_apply_mode disabled n
}

QILNMP_security_enable() {
  QILNMP_security_apply_mode enabled
}

QILNMP_security_uninstall() {
  local txn_dir
  local backup_dir
  local security_conf

  QILNMP_security_require_nginx || return 1
  txn_dir=$(QILNMP_security_transaction_dir)
  backup_dir=$(QILNMP_security_persistent_backup_dir)
  QILNMP_security_backup_context "${txn_dir}"
  QILNMP_security_backup_context "${backup_dir}"

  QILNMP_security_remove_include || {
    QILNMP_security_rollback "${txn_dir}"
    rm -rf "${txn_dir}"
    return 1
  }

  security_conf=$(QILNMP_security_conf_file)
  rm -f "${security_conf}" "$(QILNMP_security_jail_file)" "$(QILNMP_security_filter_file)"
  rmdir "$(dirname "${security_conf}")" >/dev/null 2>&1

  if QILNMP_security_test_nginx; then
    QILNMP_security_reload_nginx >/dev/null 2>&1 || {
      echo "${CFAILURE}Error: failed to reload nginx during uninstall.${CEND}"
      QILNMP_security_rollback "${txn_dir}"
      rm -rf "${txn_dir}"
      return 1
    }
  else
    echo "${CFAILURE}Error: nginx configuration test failed during uninstall.${CEND}"
    QILNMP_security_rollback "${txn_dir}"
    rm -rf "${txn_dir}"
    return 1
  fi

  if Fail2ban_server_installed; then
    Test_fail2ban_config || {
      echo "${CFAILURE}Error: fail2ban configuration test failed during uninstall.${CEND}"
      QILNMP_security_rollback "${txn_dir}"
      rm -rf "${txn_dir}"
      return 1
    }
    QILNMP_security_reload_fail2ban || {
      echo "${CFAILURE}Error: failed to reload fail2ban during uninstall.${CEND}"
      QILNMP_security_rollback "${txn_dir}"
      rm -rf "${txn_dir}"
      return 1
    }
  fi

  rm -f "${QILNMP_SECURITY_STATE_FILE}"
  rm -rf "${txn_dir}"
  echo "${CSUCCESS}QILNMP security module uninstalled successfully! Backup saved to ${backup_dir}${CEND}"
}

QILNMP_security_access_log_off_sites() {
  local vhost_dir

  vhost_dir=${web_install_dir}/conf/vhost
  [ -d "${vhost_dir}" ] || return 0
  grep -Rns --include='*.conf' 'access_log off;' "${vhost_dir}" 2>/dev/null
}

QILNMP_security_status() {
  local status
  local access_log_off

  QILNMP_security_require_nginx || return 1
  status=$(QILNMP_security_current_status)
  echo "QILNMP security status: ${status}"
  echo "Web install dir: ${web_install_dir}"
  echo "Nginx main conf: $(QILNMP_security_main_conf)"
  echo "Security conf: $(QILNMP_security_conf_file)"
  echo "Fail2ban jail: $(QILNMP_security_jail_file)"
  echo "Fail2ban filter: $(QILNMP_security_filter_file)"
  echo "Log path: $(QILNMP_security_logpath)"
  if action_name=$(QILNMP_security_detect_banaction 2>/dev/null); then
    echo "Banaction: ${action_name}"
  else
    echo "Banaction: unavailable (enable ufw/firewalld or ensure iptables exists)"
  fi
  if Fail2ban_server_installed; then
    echo "Fail2ban installed: yes"
    if command -v systemctl >/dev/null 2>&1; then
      echo "Fail2ban service: $(systemctl is-active fail2ban 2>/dev/null || echo unknown)"
    fi
  else
    echo "Fail2ban installed: no"
  fi

  access_log_off=$(QILNMP_security_access_log_off_sites)
  if [ -n "${access_log_off}" ]; then
    echo
    echo "The following vhost files disable access_log and will not contribute to auto-ban:"
    echo "${access_log_off}"
  fi
}
