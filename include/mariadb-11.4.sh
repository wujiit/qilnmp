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

declare -F Install_MariaDB_Generic >/dev/null 2>&1 || . include/mariadb-common.sh

Install_MariaDB114() {
  local target_ver="${mariadb114_ver}"
  local detected_ver=""

  if [ -d "${oneinstack_dir}/src" ]; then
    pushd "${oneinstack_dir}/src" >/dev/null 2>&1
    if [ "${dbinstallmethod}" == "1" ]; then
      detected_ver=$(ls mariadb-11.4.*-linux-systemd-x86_64.tar.gz 2>/dev/null | sort -V | tail -1 | sed -E 's/.*mariadb-(11\.4\.[0-9]+)-linux-systemd-x86_64\.tar\.gz$/\1/')
    elif [ "${dbinstallmethod}" == "2" ]; then
      detected_ver=$(ls mariadb-11.4.*.tar.gz 2>/dev/null | grep -v 'linux-systemd' | sort -V | tail -1 | sed -E 's/.*mariadb-(11\.4\.[0-9]+)\.tar\.gz$/\1/')
    fi
    popd >/dev/null 2>&1
    [ -n "${detected_ver}" ] && target_ver="${detected_ver}"
  fi

  Install_MariaDB_Generic "${target_ver}" "n"
}
