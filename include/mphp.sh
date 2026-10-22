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

Install_MPHP() {
  if [ -e "${php_install_dir}/sbin/php-fpm" ]; then
    if [ -e "${php_install_dir}${mphp_ver}/bin/phpize" ]; then
      echo "${CWARNING}PHP${mphp_ver} already installed! ${CEND}"
    else
      [ -e "/lib/systemd/system/php-fpm.service" ] && /bin/mv /lib/systemd/system/php-fpm.service{,_bk}
      php_install_dir=${php_install_dir}${mphp_ver}
      case "${mphp_ver}" in
        84)
          . include/php-8.4.sh
          Install_PHP84 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        85)
          . include/php-8.5.sh
          Install_PHP85 2>&1 | tee -a ${oneinstack_dir}/install.log
          ;;
        *)
          echo "${CFAILURE}PHP${mphp_ver} is not supported. PHP < 8.4 is discontinued due to critical CVE-2026-109618/109619 vulnerabilities. Available options: 84 or 85.${CEND}"
          [ -e "/lib/systemd/system/php-fpm.service_bk" ] && /bin/mv /lib/systemd/system/php-fpm.service{_bk,}
          return 1
          ;;
      esac
      if [ -e "${php_install_dir}/sbin/php-fpm" ]; then
        systemctl stop php-fpm
        sed -i "s@/dev/shm/php-cgi.sock@/dev/shm/php${mphp_ver}-cgi.sock@" ${php_install_dir}/etc/php-fpm.conf
        [ -e "/lib/systemd/system/php-fpm.service" ] && /bin/mv /lib/systemd/system/php-fpm.service /lib/systemd/system/php${mphp_ver}-fpm.service
        [ -e "/lib/systemd/system/php-fpm.service_bk" ] && /bin/mv /lib/systemd/system/php-fpm.service{_bk,}
        systemctl enable php${mphp_ver}-fpm
        systemctl enable php-fpm
        systemctl start php-fpm
        systemctl start php${mphp_ver}-fpm
        sed -i "s@${php_install_dir}/bin:@@" /etc/profile
      fi
    fi
  else
    echo "${CWARNING}To use the multiple PHP versions, You need to use PHP-FPM! ${CEND}"
  fi
}
