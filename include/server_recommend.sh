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

Detect_Server_Profile() {
  SERVER_CPU_CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null)
  [ -z "${SERVER_CPU_CORES}" ] && SERVER_CPU_CORES=1

  if [ -r /proc/meminfo ]; then
    SERVER_MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    SERVER_SWAP_MB=$(awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo)
  else
    SERVER_MEM_MB=1024
    SERVER_SWAP_MB=0
  fi
  [ -z "${SERVER_MEM_MB}" ] && SERVER_MEM_MB=1024
  [ -z "${SERVER_SWAP_MB}" ] && SERVER_SWAP_MB=0

  SERVER_DISK_GB=$(df -Pk / 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}')
  [ -z "${SERVER_DISK_GB}" ] && SERVER_DISK_GB=20

  SERVER_GLIBC_VER=$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | tail -1)
  [ -z "${SERVER_GLIBC_VER}" ] && SERVER_GLIBC_VER=2.17
}

Version_GTE() {
  local current_ver=$1
  local required_ver=$2
  [ "$(printf '%s\n%s\n' "${required_ver}" "${current_ver}" | sort -V | head -1)" = "${required_ver}" ]
}

Recommend_Install_Versions() {
  local server_arch=${ARCH}
  [ -z "${server_arch}" ] && server_arch=$(uname -m 2>/dev/null)
  MODERN_MAINSTREAM_OS=n
  if { [ "${Family}" == 'rhel' ] && [ "${RHEL_ver}" -ge 9 >/dev/null 2>&1 ]; } || \
     { [ "${Family}" == 'debian' ] && [ "${Debian_ver}" -ge 12 >/dev/null 2>&1 ]; } || \
     { [ "${Family}" == 'ubuntu' ] && [ "${Ubuntu_ver}" -ge 24 >/dev/null 2>&1 ]; }; then
    MODERN_MAINSTREAM_OS=y
  fi

  php_recommend_option=14
  php_recommend_name="PHP-8.4"
  db_recommend_option=1
  db_recommend_name="MySQL-8.0"
  web_recommend_option=1
  web_recommend_name="Nginx"
  dbinstallmethod_recommend=1
  dbinstallmethod_recommend_name="Binary package"
  phpcache_recommend_option=1
  phpcache_recommend_name="Zend OPcache"
  server_profile_level="balanced"
  server_profile_note="Recommended for most servers."

  mysql90_binary_supported=n
  if [[ "${server_arch}" =~ x86_64|amd64 ]] && Version_GTE "${SERVER_GLIBC_VER}" "2.28"; then
    mysql90_binary_supported=y
  fi
  mysql_binary_supported=n
  if [[ "${server_arch}" =~ x86_64|amd64 ]]; then
    mysql_binary_supported=y
  fi
  if [ "${mysql_binary_supported}" != 'y' ]; then
    dbinstallmethod_recommend=2
    dbinstallmethod_recommend_name="Source package (arch requires source)"
  fi

  if [ "${SERVER_MEM_MB}" -lt 2048 ] || [ "${SERVER_CPU_CORES}" -lt 2 ] || [ "${SERVER_DISK_GB}" -lt 20 ]; then
    php_recommend_option=14
    php_recommend_name="PHP-8.4"
    db_recommend_option=5
    db_recommend_name="MariaDB-10.11"
    web_recommend_option=1
    web_recommend_name="Nginx"
    server_profile_level="low"
    server_profile_note="Low-resource server detected, prefer modern but lighter LNMP defaults for higher install success."
  elif [ "${SERVER_MEM_MB}" -lt 6144 ] || [ "${SERVER_CPU_CORES}" -lt 4 ] || [ "${SERVER_DISK_GB}" -lt 30 ]; then
    php_recommend_option=14
    php_recommend_name="PHP-8.4"
    db_recommend_option=1
    db_recommend_name="MySQL-8.0"
    web_recommend_option=1
    web_recommend_name="Nginx"
    server_profile_level="balanced"
    server_profile_note="Medium-resource server detected, prefer stable versions to improve installation success."
  else
    php_recommend_option=15
    php_recommend_name="PHP-8.5"
    db_recommend_option=1
    db_recommend_name="MySQL-8.0"
    web_recommend_option=1
    web_recommend_name="Nginx"
    server_profile_level="high"
    server_profile_note="High-resource server detected, latest stable stack is recommended."
    if [ "${SERVER_MEM_MB}" -ge 8192 ] && [ "${SERVER_CPU_CORES}" -ge 4 ] && [ "${SERVER_DISK_GB}" -ge 50 ] && [ "${mysql90_binary_supported}" == 'y' ]; then
      db_recommend_option=15
      db_recommend_name="MySQL-9.0"
      server_profile_note="High-resource server detected, MySQL-9.0 is recommended."
    fi
  fi

  if [ "${mysql_binary_supported}" != 'y' ] && { [ "${SERVER_MEM_MB}" -lt 6144 ] || [ "${SERVER_CPU_CORES}" -lt 4 ]; }; then
    db_recommend_option=5
    db_recommend_name="MariaDB-10.11"
    server_profile_note="${server_profile_note} Current architecture requires source DB builds, MariaDB-10.11 is preferred for better installation success."
  fi

  if [ "${db_recommend_option}" == '15' ] && [ "${mysql90_binary_supported}" != 'y' ]; then
    db_recommend_option=1
    db_recommend_name="MySQL-8.0"
    server_profile_note="${server_profile_note} MySQL-9.0 binary requires x86_64 and glibc>=2.28."
  fi
}

Normalize_Selections_For_Modern_OS() {
  [ "${MODERN_MAINSTREAM_OS}" != 'y' ] && return 0
  [ "${QILNMP_ALLOW_LEGACY}" == '1' ] && return 0

  if [ -n "${php_option}" ] && [[ ! "${php_option}" =~ ^1[2-5]$ ]]; then
    echo "${CWARNING}Modern OS profile detected, php_option=${php_option} auto-adjusted to 14 (PHP-8.4). Set QILNMP_ALLOW_LEGACY=1 to keep older PHP choices.${CEND}"
    php_option=14
  fi

  if [ -n "${mphp_ver}" ] && [[ ! "${mphp_ver}" =~ ^8[2-5]$ ]]; then
    echo "${CWARNING}Modern OS profile detected, mphp_ver=${mphp_ver} auto-adjusted to 84 (PHP-8.4). Set QILNMP_ALLOW_LEGACY=1 to keep older multi-PHP choices.${CEND}"
    mphp_ver=84
  fi

  case "${db_option}" in
    2|3|4|9|10|11|12)
      echo "${CWARNING}Modern OS profile detected, db_option=${db_option} auto-adjusted to 1 (MySQL-8.0). Set QILNMP_ALLOW_LEGACY=1 to keep older DB choices.${CEND}"
      db_option=1
      ;;
    8)
      echo "${CWARNING}Modern OS profile detected, db_option=${db_option} auto-adjusted to 5 (MariaDB-10.11). Set QILNMP_ALLOW_LEGACY=1 to keep older DB choices.${CEND}"
      db_option=5
      ;;
  esac
}

Show_Install_Recommendations() {
  echo
  echo "${CMSG}Server profile detected:${CEND}"
  echo -e "\tCPU Cores: ${CMSG}${SERVER_CPU_CORES}${CEND}"
  echo -e "\tMemory:    ${CMSG}${SERVER_MEM_MB} MB${CEND}"
  echo -e "\tSwap:      ${CMSG}${SERVER_SWAP_MB} MB${CEND}"
  echo -e "\tDisk Free: ${CMSG}${SERVER_DISK_GB} GB${CEND}"
  echo -e "\tglibc:     ${CMSG}${SERVER_GLIBC_VER}${CEND}"
  echo -e "\tProfile:   ${CMSG}${server_profile_level}${CEND}"
  echo -e "\tNote:      ${CMSG}${server_profile_note}${CEND}"
  echo
  echo "${CMSG}Recommended install versions:${CEND}"
  echo -e "\tWeb:       ${CMSG}${web_recommend_name}${CEND} (option ${web_recommend_option})"
  echo -e "\tPHP:       ${CMSG}${php_recommend_name}${CEND} (option ${php_recommend_option})"
  echo -e "\tDatabase:  ${CMSG}${db_recommend_name}${CEND} (option ${db_recommend_option})"
  echo -e "\tDB Method: ${CMSG}${dbinstallmethod_recommend_name}${CEND} (option ${dbinstallmethod_recommend})"
  echo -e "\tPHP Cache: ${CMSG}${phpcache_recommend_name}${CEND} (option ${phpcache_recommend_option})"
  [ "${MODERN_MAINSTREAM_OS}" == 'y' ] && echo "${CMSG}Modern OS mode is active (Rocky 9+/Debian 12+/Ubuntu 24+): PHP 8.2+ and current DB branches are kept, older legacy choices will be auto-normalized unless QILNMP_ALLOW_LEGACY=1.${CEND}"
  if [ "${mysql90_binary_supported}" != 'y' ]; then
    echo "${CWARNING}MySQL-9.0 binary package is not compatible with current architecture/glibc, source build is required.${CEND}"
  fi
  echo "${CWARNING}You can still manually choose other versions in the next steps.${CEND}"
}

Warn_If_Selection_Risky() {
  if [ "${php_option}" == '15' ] && { [ "${SERVER_MEM_MB}" -lt 6144 ] || [ "${SERVER_CPU_CORES}" -lt 4 ]; }; then
    echo "${CWARNING}Warning: PHP-8.5 may fail to build on servers below 4C/6GB. PHP-8.4 is recommended.${CEND}"
  fi

  if [ "${db_option}" == '1' ] && { [ "${SERVER_MEM_MB}" -lt 3072 ] || [ "${SERVER_CPU_CORES}" -lt 2 ]; }; then
    echo "${CWARNING}Warning: MySQL-8.0 may be heavy for current server resources. Prefer binary install or choose MariaDB-10.11 for lower resource pressure.${CEND}"
  fi

  if [ "${db_option}" == '15' ]; then
    if [ "${dbinstallmethod}" == '1' ] && [ "${mysql90_binary_supported}" != 'y' ]; then
      echo "${CWARNING}Warning: MySQL-9.0 binary package requires x86_64 with glibc>=2.28, please choose source install (option 2).${CEND}"
    fi
    if [ "${SERVER_MEM_MB}" -lt 4096 ] || [ "${SERVER_CPU_CORES}" -lt 4 ] || [ "${SERVER_DISK_GB}" -lt 30 ]; then
      echo "${CWARNING}Warning: MySQL-9.0 is resource-intensive for current server profile, MySQL-8.0 is recommended.${CEND}"
    fi
  fi

  if [[ "${db_option}" =~ ^[1-9]$|^1[0-2]$|^1[5-6]$ ]] && [ "${dbinstallmethod}" == '2' ] && [ "${SERVER_MEM_MB}" -lt 4096 ]; then
    echo "${CWARNING}Warning: Database source compilation may fail on low memory servers (<4GB), binary package is preferred when available.${CEND}"
  fi

  if [ "${nginx_option}" == '3' ] && [ "${SERVER_MEM_MB}" -lt 3072 ]; then
    echo "${CWARNING}Warning: OpenResty usually needs more memory than Nginx/Caddy on low-resource servers.${CEND}"
  fi
}
