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

Fail2ban_client_bin() {
  if [ -x "/usr/local/bin/fail2ban-client" ]; then
    echo "/usr/local/bin/fail2ban-client"
  elif command -v fail2ban-client >/dev/null 2>&1; then
    command -v fail2ban-client
  fi
}

Fail2ban_server_installed() {
  [ -x "/usr/local/bin/fail2ban-server" ] || command -v fail2ban-server >/dev/null 2>&1
}

Restart_fail2ban_service() {
  local fail2ban_client

  fail2ban_client=$(Fail2ban_client_bin)

  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload >/dev/null 2>&1
    if systemctl is-active fail2ban >/dev/null 2>&1; then
      if [ -n "${fail2ban_client}" ]; then
        ${fail2ban_client} reload >/dev/null 2>&1 || systemctl restart fail2ban >/dev/null 2>&1
      else
        systemctl restart fail2ban >/dev/null 2>&1
      fi
    else
      systemctl start fail2ban >/dev/null 2>&1 || systemctl restart fail2ban >/dev/null 2>&1
    fi
  else
    if [ -n "${fail2ban_client}" ] && ${fail2ban_client} ping >/dev/null 2>&1; then
      ${fail2ban_client} reload >/dev/null 2>&1 || service fail2ban restart >/dev/null 2>&1
    else
      service fail2ban start >/dev/null 2>&1 || service fail2ban restart >/dev/null 2>&1
    fi
  fi
}

Test_fail2ban_config() {
  local fail2ban_client

  fail2ban_client=$(Fail2ban_client_bin)
  [ -z "${fail2ban_client}" ] && return 1
  ${fail2ban_client} -t >/dev/null 2>&1
}

Install_fail2ban_core() {
  local fail2ban_client

  pushd ${oneinstack_dir}/src > /dev/null
  src_url=${mirror_link}/src/fail2ban-${fail2ban_ver}.tar.gz && Download_src
  rm -rf fail2ban-${fail2ban_ver}
  tar xzf fail2ban-${fail2ban_ver}.tar.gz
  pushd fail2ban-${fail2ban_ver} > /dev/null
  if command -v python3 > /dev/null 2>&1; then
    python3 setup.py install
  else
    python setup.py install
  fi
  /bin/cp build/fail2ban.service /lib/systemd/system/
  mkdir -p /etc/fail2ban /etc/fail2ban/jail.d /etc/fail2ban/filter.d
  fail2ban_client=$(Fail2ban_client_bin)
  [ -z "${fail2ban_client}" ] && fail2ban_client=/usr/local/bin/fail2ban-client
  cat > /etc/logrotate.d/fail2ban << EOF
/var/log/fail2ban.log {
    missingok
    notifempty
    postrotate
      ${fail2ban_client} flushlogs >/dev/null || true
    endscript
}
EOF
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable fail2ban >/dev/null 2>&1
  fi
  popd > /dev/null
  popd > /dev/null
}

Write_default_fail2ban_sshd_jail() {
  local now_ssh_port

  [ -z "`grep ^Port /etc/ssh/sshd_config`" ] && now_ssh_port=22 || now_ssh_port=`grep ^Port /etc/ssh/sshd_config | awk '{print $2}' | head -1`
  if [ "${PM}" == 'yum' ]; then
  cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime  = 86400
findtime = 600
maxretry = 5
backend = auto
banaction = firewallcmd-ipset
action = %(action_mwl)s

[sshd]
enabled = true
filter  = sshd
port    = ${now_ssh_port}
action = %(action_mwl)s
logpath = /var/log/secure
bantime  = 86400
findtime = 600
maxretry = 5
EOF
  elif [ "${PM}" == 'apt-get' ]; then
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -wq inactive; then
      ufw default allow incoming
      ufw --force enable
    fi
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime  = 86400
findtime = 600
maxretry = 5
backend = auto
banaction = ufw
action = %(action_mwl)s

[sshd]
enabled = true
filter  = sshd
port    = ${now_ssh_port}
action = %(action_mwl)s
logpath = /var/log/auth.log
bantime  = 86400
findtime = 600
maxretry = 5
EOF
  fi
}

Ensure_fail2ban_installed() {
  Fail2ban_server_installed || Install_fail2ban_core
  mkdir -p /etc/fail2ban /etc/fail2ban/jail.d /etc/fail2ban/filter.d
  [ -e "/lib/systemd/system/fail2ban.service" ] && command -v systemctl >/dev/null 2>&1 && systemctl enable fail2ban >/dev/null 2>&1
  Fail2ban_server_installed
}

Install_fail2ban() {
  Install_fail2ban_core
  Write_default_fail2ban_sshd_jail
  Restart_fail2ban_service
  if [ -e "/usr/local/bin/fail2ban-server" ] || command -v fail2ban-server >/dev/null 2>&1; then
    echo; echo "${CSUCCESS}fail2ban installed successfully! ${CEND}"
  else
    echo; echo "${CFAILURE}fail2ban install failed, Please try again! ${CEND}"
  fi
}

Uninstall_fail2ban() {
  systemctl stop fail2ban
  systemctl disable fail2ban
  rm -rf /usr/local/bin/fail2ban* /etc/init.d/fail2ban /etc/fail2ban /etc/logrotate.d/fail2ban /var/log/fail2ban.* /var/run/fail2ban /lib/systemd/system/fail2ban.service
  echo; echo "${CMSG}fail2ban uninstall completed${CEND}";
}
