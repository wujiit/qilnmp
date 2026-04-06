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

declare -F Install_Modern_PHP >/dev/null 2>&1 || . include/php-modern-common.sh

Install_PHP84() {
  Install_Modern_PHP "${php84_ver}" "${php84_with_ssl}" "${php84_with_curl}" "${php84_with_openssl}"
}
