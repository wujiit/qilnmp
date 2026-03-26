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

Install_pecl_phalcon() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    if [[ "${PHP_main_ver}" =~ ^7.[2-4]$|^8.[0-5]$ ]]; then
      src_url=${mirror_link}/src/cphalcon-v${phalcon_ver}.tar.gz
      src_url_backup=https://github.com/phalcon/cphalcon/archive/refs/tags/v${phalcon_ver}.tar.gz
      Download_src; unset src_url_backup
      tar xzf cphalcon-v${phalcon_ver}.tar.gz
      PHALCON_SRC_DIR=$(find . -maxdepth 1 -type d \( -name "cphalcon-${phalcon_ver}" -o -name "cphalcon-v${phalcon_ver}" -o -name "cphalcon-*${phalcon_ver}*" \) | head -n1)
      [ -z "${PHALCON_SRC_DIR}" ] && PHALCON_SRC_DIR=./cphalcon-${phalcon_ver}
      pushd ${PHALCON_SRC_DIR} > /dev/null
      echo "${CMSG}It may take a few minutes... ${CEND}"
      if [ -x "./build/install" ]; then
        ./build/install --phpize ${php_install_dir}/bin/phpize --php-config ${php_install_dir}/bin/php-config --arch 64bits
      else
        ${php_install_dir}/bin/phpize
        ./configure --with-php-config=${php_install_dir}/bin/php-config
        make -j ${THREAD} && make install
      fi
      popd > /dev/null
    elif [[ "${PHP_main_ver}" =~ ^5.[5-6]$|^7.[0-1]$ ]]; then
      src_url=${mirror_link}/src/cphalcon-${phalcon_oldver}.tar.gz && Download_src
      tar xzf cphalcon-${phalcon_oldver}.tar.gz
      pushd cphalcon-${phalcon_oldver}/build > /dev/null
      echo "${CMSG}It may take a few minutes... ${CEND}"
      ./install --phpize ${php_install_dir}/bin/phpize --php-config ${php_install_dir}/bin/php-config --arch 64bits
      popd > /dev/null
    else
      echo "${CWARNING}Your php ${PHP_detail_ver} does not support phalcon! ${CEND}"
    fi
    if [ -f "${phpExtensionDir}/phalcon.so" ]; then
      echo 'extension=phalcon.so' > ${php_install_dir}/etc/php.d/04-phalcon.ini
      echo "${CSUCCESS}PHP phalcon module installed successfully! ${CEND}"
      rm -rf cphalcon-${phalcon_oldver} cphalcon-${phalcon_ver} cphalcon-v${phalcon_ver} phalcon-${phalcon_ver}
    else
      echo "${CFAILURE}PHP phalcon module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_pecl_phalcon() {
  if [ -e "${php_install_dir}/etc/php.d/04-phalcon.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/04-phalcon.ini
    echo; echo "${CMSG}PHP phalcon module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP phalcon module does not exist! ${CEND}"
  fi
}
