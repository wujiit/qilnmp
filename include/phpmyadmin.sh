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

Install_phpMyAdmin() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    [ ! -d "${wwwroot_dir}/default" ] && mkdir -p ${wwwroot_dir}/default
    PHP_detail_ver=`${php_install_dir}/bin/php-config --version`
    PHP_main_ver=${PHP_detail_ver%.*}
    if [[ "${PHP_main_ver}" =~ ^5.[3-6]$|^7.[0-1]$ ]]; then
      tar xzf phpMyAdmin-${phpmyadmin_oldver}-all-languages.tar.gz || { echo "${CFAILURE}Extract phpMyAdmin-${phpmyadmin_oldver}-all-languages.tar.gz failed.${CEND}"; kill -9 $$; exit 1; }
      /bin/mv phpMyAdmin-${phpmyadmin_oldver}-all-languages ${wwwroot_dir}/default/phpMyAdmin || { echo "${CFAILURE}Move phpMyAdmin files to ${wwwroot_dir}/default failed.${CEND}"; kill -9 $$; exit 1; }
    else
      tar xzf phpMyAdmin-${phpmyadmin_ver}-all-languages.tar.gz || { echo "${CFAILURE}Extract phpMyAdmin-${phpmyadmin_ver}-all-languages.tar.gz failed.${CEND}"; kill -9 $$; exit 1; }
      /bin/mv phpMyAdmin-${phpmyadmin_ver}-all-languages ${wwwroot_dir}/default/phpMyAdmin || { echo "${CFAILURE}Move phpMyAdmin files to ${wwwroot_dir}/default failed.${CEND}"; kill -9 $$; exit 1; }
    fi
    /bin/cp ${wwwroot_dir}/default/phpMyAdmin/{config.sample.inc.php,config.inc.php} || { echo "${CFAILURE}Initialize phpMyAdmin config failed.${CEND}"; kill -9 $$; exit 1; }
    mkdir -p ${wwwroot_dir}/default/phpMyAdmin/{upload,save}
    sed -i "s@UploadDir.*@UploadDir'\] = 'upload';@" ${wwwroot_dir}/default/phpMyAdmin/config.inc.php
    sed -i "s@SaveDir.*@SaveDir'\] = 'save';@" ${wwwroot_dir}/default/phpMyAdmin/config.inc.php
    sed -i "s@host'\].*@host'\] = '127.0.0.1';@" ${wwwroot_dir}/default/phpMyAdmin/config.inc.php
    sed -i "s@blowfish_secret.*;@blowfish_secret\'\] = \'$(cat /dev/urandom | head -1 | base64 | head -c 32)\';@" ${wwwroot_dir}/default/phpMyAdmin/config.inc.php
    chown -R ${run_user}:${run_group} ${wwwroot_dir}/default/phpMyAdmin
    popd > /dev/null
  fi
}
