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

export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
Mem=`free -m | awk '/Mem:/{print $2}'`
Swap=`free -m | awk '/Swap:/{print $2}'`
[ -z "${THREAD}" ] && THREAD=1
CPU_THREAD=${THREAD}

if [ $Mem -le 640 ]; then
  Mem_level=512M
  Memory_limit=64
  THREAD=1
elif [ $Mem -gt 640 -a $Mem -le 1280 ]; then
  Mem_level=1G
  Memory_limit=128
elif [ $Mem -gt 1280 -a $Mem -le 2500 ]; then
  Mem_level=2G
  Memory_limit=192
elif [ $Mem -gt 2500 -a $Mem -le 3500 ]; then
  Mem_level=3G
  Memory_limit=256
elif [ $Mem -gt 3500 -a $Mem -le 4500 ]; then
  Mem_level=4G
  Memory_limit=320
elif [ $Mem -gt 4500 -a $Mem -le 8000 ]; then
  Mem_level=6G
  Memory_limit=384
elif [ $Mem -gt 8000 ]; then
  Mem_level=8G
  Memory_limit=448
fi

# add swapfile (also applies on re-run if previous install failed before swap setup)
if [ "${Swap}" == '0' ] && [ ${Mem} -le 4096 ]; then
  SWAPFILE_SIZE_MB=3072
  [ ${Mem} -le 2048 ] && SWAPFILE_SIZE_MB=2048
  echo "${CWARNING}No swap detected on low-memory server (${Mem}MB). Creating ${SWAPFILE_SIZE_MB}MB swapfile...${CEND}"

  if [ ! -f /swapfile ]; then
    if command -v fallocate > /dev/null 2>&1; then
      fallocate -l ${SWAPFILE_SIZE_MB}M /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile count=${SWAPFILE_SIZE_MB} bs=1M
    else
      dd if=/dev/zero of=/swapfile count=${SWAPFILE_SIZE_MB} bs=1M
    fi
  fi

  chmod 600 /swapfile
  mkswap /swapfile >/dev/null 2>&1
  swapon /swapfile >/dev/null 2>&1 || swapon -a >/dev/null 2>&1
  [ -z "`grep -E '^[^#].*[[:space:]]/swapfile[[:space:]]+swap[[:space:]]' /etc/fstab 2>/dev/null`" ] && echo '/swapfile    swap    swap    defaults    0 0' >> /etc/fstab
  Swap=`free -m | awk '/Swap:/{print $2}'`
  [ "${Swap}" == '0' ] && echo "${CWARNING}Swapfile activation failed, compilation may still run out of memory.${CEND}"
fi

# tune compile jobs by CPU + RAM.
# Policy:
# - 2C/4G class machine: force single job for stability
# - 4C class machine: use -j2
# - larger machines: scale conservatively
BuildMem=$((${Mem}+${Swap}))
THREAD=${CPU_THREAD}
if [ ${CPU_THREAD} -le 2 ]; then
  THREAD=1
elif [ ${CPU_THREAD} -le 4 ]; then
  THREAD=2
elif [ ${CPU_THREAD} -le 8 ] || [ ${Mem} -le 16384 ]; then
  THREAD=3
else
  THREAD=4
fi

# hard cap for extremely low memory hosts
[ ${Mem} -le 2048 ] && [ ${THREAD} -gt 1 ] && THREAD=1

# optional overrides
if [[ "${QILNMP_BUILD_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
  THREAD=${QILNMP_BUILD_JOBS}
fi

DB_THREAD=${THREAD}
NGINX_THREAD=${THREAD}
PHP_THREAD=${THREAD}

# DB builds are heavy, cap to 2 by default unless user forces override
[ ${DB_THREAD} -gt 2 ] && DB_THREAD=2

if [[ "${QILNMP_DB_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
  DB_THREAD=${QILNMP_DB_JOBS}
fi
if [[ "${QILNMP_NGINX_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
  NGINX_THREAD=${QILNMP_NGINX_JOBS}
fi
if [[ "${QILNMP_PHP_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
  PHP_THREAD=${QILNMP_PHP_JOBS}
fi

export THREAD DB_THREAD NGINX_THREAD PHP_THREAD
echo "${CMSG}Build jobs tuned by CPU+RAM: mem=${Mem}MB swap=${Swap}MB total=${BuildMem}MB, global=${THREAD}, db=${DB_THREAD}, nginx=${NGINX_THREAD}, php=${PHP_THREAD}${CEND}"
