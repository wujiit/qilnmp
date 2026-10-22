#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: QILNMP for Rocky/Alma/RHEL 8+ Debian 11+ and Ubuntu 20+ (64-bit)
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

if [ -e "/etc/os-release" ]; then
  . /etc/os-release
else
  echo "${CFAILURE}/etc/os-release does not exist! ${CEND}"
  kill -9 $$; exit 1;
fi

# Get OS Version
Platform=${ID,,}
VERSION_MAIN_ID=${VERSION_ID%%.*}
ARCH=$(arch)
if [[ "${Platform}" =~ ^centos$|^rhel$|^almalinux$|^rocky$|^fedora$|^amzn$|^ol$|^alinux$|^anolis$|^tencentos$|^opencloudos$|^euleros$|^openeuler$|^kylin$|^uos$|^kylinsecos$ ]]; then
  PM=yum
  Family=rhel
  RHEL_ver=${VERSION_MAIN_ID}
  if [[ "${Platform}" =~ ^centos$ ]]; then
    if [ "${VERSION_MAIN_ID}" == '6' ]; then
      sed -i "s@centos/\$releasever@centos-vault/6.10@g" /etc/yum.repos.d/CentOS-Base.repo
      sed -i 's@centos/RPM-GPG@centos-vault/RPM-GPG@g' /etc/yum.repos.d/CentOS-Base.repo
      [ -e /etc/yum.repos.d/epel.repo ] && rm -f /etc/yum.repos.d/epel.repo
    fi
  elif [[ "${Platform}" =~ ^fedora$ ]]; then
    Fedora_ver=${VERSION_MAIN_ID}
    [ ${VERSION_MAIN_ID} -ge 19 ] && [ ${VERSION_MAIN_ID} -lt 28 ] && RHEL_ver=7
    [ ${VERSION_MAIN_ID} -ge 28 ] && [ ${VERSION_MAIN_ID} -lt 34 ] && RHEL_ver=8
    [ ${VERSION_MAIN_ID} -ge 34 ] && RHEL_ver=9
  elif [[ "${Platform}" =~ ^amzn$|^alinux$|^tencentos$|^euleros$ ]]; then
    [[ "${VERSION_MAIN_ID}" =~ ^2$ ]] && RHEL_ver=7
    [[ "${VERSION_MAIN_ID}" =~ ^3$ ]] && RHEL_ver=8
  elif [[ "${Platform}" =~ ^openeuler$ ]]; then
    [[ "${RHEL_ver}" =~ ^20$ ]] && RHEL_ver=7
    [[ "${RHEL_ver}" =~ ^2[1,2]$ ]] && RHEL_ver=8
  elif [[ "${Platform}" =~ ^kylin$ ]]; then
    [[ "${RHEL_ver}" =~ ^V10$ ]] && RHEL_ver=7
  elif [[ "${Platform}" =~ ^uos$ ]]; then
    [[ "${RHEL_ver}" =~ ^20$ ]] && RHEL_ver=8
  elif [[ "${Platform}" =~ ^kylinsecos$ ]]; then
    [[ "${VERSION_ID}" =~ ^3.4 ]] && RHEL_ver=7
    [[ "${VERSION_ID}" =~ ^3.5 ]] && RHEL_ver=8
  fi
elif [[ "${Platform}" =~ ^debian$|^deepin$|^kali$ ]]; then
  PM=apt-get
  Family=debian
  Debian_ver=${VERSION_MAIN_ID}
  if [[ "${Platform}" =~ ^deepin$ ]]; then
    [[ "${Debian_ver}" =~ ^20$ ]] && Debian_ver=10
    [[ "${Debian_ver}" =~ ^23$ ]] && Debian_ver=11
  elif [[ "${Platform}" =~ ^kali$ ]]; then
    [[ "${Debian_ver}" =~ ^202 ]] && Debian_ver=10
  fi
elif [[ "${Platform}" =~ ^ubuntu$|^linuxmint$|^elementary$ ]]; then
  PM=apt-get
  Family=ubuntu
  Ubuntu_ver=${VERSION_MAIN_ID}
  if [[ "${Platform}" =~ ^linuxmint$ ]]; then
    [[ "${VERSION_MAIN_ID}" =~ ^18$ ]] && Ubuntu_ver=16
    [[ "${VERSION_MAIN_ID}" =~ ^19$ ]] && Ubuntu_ver=18
    [[ "${VERSION_MAIN_ID}" =~ ^20$ ]] && Ubuntu_ver=20
    [[ "${VERSION_MAIN_ID}" =~ ^21$ ]] && Ubuntu_ver=22
  elif [[ "${Platform}" =~ ^elementary$ ]]; then
    [[ "${VERSION_MAIN_ID}" =~ ^5$ ]] && Ubuntu_ver=18
    [[ "${VERSION_MAIN_ID}" =~ ^6$ ]] && Ubuntu_ver=20
    [[ "${VERSION_MAIN_ID}" =~ ^7$ ]] && Ubuntu_ver=22
  fi
else
  echo "${CFAILURE}Does not support this OS ${CEND}"
  kill -9 $$; exit 1;
fi

# Check OS Version - QILNMP requires modern OS for PHP 8.4/8.5 & MySQL 8.0/8.4 (glibc 2.28+, GCC 8+)
# CentOS 7 (including 7.9), Debian <=10, and Ubuntu <=18 are EOL and lack modern C11/GCC/glibc toolchains
SUPPORTED_OS=true
if [ "${Family}" == 'rhel' ]; then
  if [ -z "${RHEL_ver}" ] || [ "${RHEL_ver}" -lt 8 ]; then
    SUPPORTED_OS=false
  fi
elif [ "${Family}" == 'debian' ]; then
  if [ -z "${Debian_ver}" ] || [ "${Debian_ver}" -lt 11 ]; then
    SUPPORTED_OS=false
  fi
elif [ "${Family}" == 'ubuntu' ]; then
  if [ -z "${Ubuntu_ver}" ] || [ "${Ubuntu_ver}" -lt 20 ]; then
    SUPPORTED_OS=false
  fi
fi

if [ "${SUPPORTED_OS}" == 'false' ]; then
  echo ""
  echo "${CFAILURE}========================================================================${CEND}"
  echo "${CFAILURE}[ERROR] Current OS (${Platform} ${VERSION_ID:-unknown}) is NOT supported by QILNMP!${CEND}"
  echo "${CFAILURE}========================================================================${CEND}"
  echo "${CWARNING}CentOS 7.x (including CentOS 7.9), Debian <=10, and Ubuntu <=18 are End-Of-Life (EOL).${CEND}"
  echo "${CWARNING}Their legacy toolchains (GCC 4.8.x, glibc 2.17, OpenSSL 1.0.2) cannot compile modern${CEND}"
  echo "${CWARNING}PHP (8.4 / 8.5) or run modern MySQL (8.0 / 8.4 GLIBC 2.28+) binaries.${CEND}"
  echo ""
  echo "${CSUCCESS}Supported 64-bit operating systems:${CEND}"
  echo "  - RHEL / Rocky Linux / AlmaLinux / CentOS Stream: 8.x / 9.x"
  echo "  - Debian: 11 (Bullseye) / 12 (Bookworm) / 13"
  echo "  - Ubuntu: 20.04 LTS / 22.04 LTS / 24.04 LTS"
  echo "  - Anolis OS 8+ / OpenCloudOS 8+ / openEuler 22+"
  echo "${CFAILURE}========================================================================${CEND}"
  echo ""
  kill -9 $$; exit 1;
fi

[ "${QILNMP_SKIP_GCC_BOOTSTRAP}" != '1' ] && command -v gcc > /dev/null 2>&1 || true
if [ "${QILNMP_SKIP_GCC_BOOTSTRAP}" != '1' ] && ! command -v gcc > /dev/null 2>&1; then
  $PM -y install gcc
fi
if command -v gcc > /dev/null 2>&1; then
  gcc_ver=$(gcc -dumpversion | awk -F. '{print $1}')
else
  # Keep security/status tooling side-effect free when gcc is irrelevant.
  gcc_ver=5
fi

[ ${gcc_ver} -lt 5 >/dev/null 2>&1 ] && redis_ver=${redis_oldver}

if uname -m | grep -Eqi "arm|aarch64"; then
  armplatform="y"
  if uname -m | grep -Eqi "armv7"; then
    TARGET_ARCH="armv7"
  elif uname -m | grep -Eqi "armv8"; then
    TARGET_ARCH="arm64"
  elif uname -m | grep -Eqi "aarch64"; then
    TARGET_ARCH="aarch64"
  else
    TARGET_ARCH="unknown"
  fi
fi

if [ "$(uname -r | awk -F- '{print $3}' 2>/dev/null)" == "Microsoft" ]; then
  Wsl=true
fi

if [ "$(getconf WORD_BIT)" == "32" ] && [ "$(getconf LONG_BIT)" == "64" ]; then
  if [ "${TARGET_ARCH}" == 'aarch64' ]; then
    SYS_ARCH=arm64
    SYS_ARCH_i=aarch64
  else
    SYS_ARCH=amd64 #openjdk
    SYS_ARCH_i=x86-64 #ioncube
  fi
else
  echo "${CWARNING}32-bit OS are not supported! ${CEND}"
  kill -9 $$; exit 1;
fi

THREAD=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)

# Percona binary: https://docs.percona.com/percona-server/5.7/installation/binary-tarball.html
if [ ${Debian_ver} -lt 9 >/dev/null 2>&1 ]; then
  sslLibVer=ssl100
elif [ "${RHEL_ver}" == '7' ] && [ "${Platform}" != 'fedora' ]; then
  sslLibVer=ssl101
elif [ ${Debian_ver} -ge 9 >/dev/null 2>&1 ] || [ ${Ubuntu_ver} -ge 16 >/dev/null 2>&1 ]; then
  sslLibVer=ssl102
elif [ ${Fedora_ver} -ge 27 >/dev/null 2>&1 ]; then
  sslLibVer=ssl102
elif [ "${RHEL_ver}" == '8' ]; then
  sslLibVer=ssl1:111
else
  sslLibVer=unknown
fi
