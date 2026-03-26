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

Install_ZendOPcache() {
  if [ -e "${php_install_dir}/bin/phpize" ]; then
    pushd ${oneinstack_dir}/src > /dev/null
    phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
    PHP_detail_ver=$(${php_install_dir}/bin/php-config --version)
    PHP_main_ver=${PHP_detail_ver%.*}
    php_builtin_opcache='n'
    ${php_install_dir}/bin/php -v 2>/dev/null | grep -qi 'Zend OPcache' && php_builtin_opcache='y'
    write_opcache_ini() {
      local opcache_so=$1
      cat > ${php_install_dir}/etc/php.d/02-opcache.ini << EOF
[opcache]
EOF
      if [ -n "${opcache_so}" ]; then
        cat >> ${php_install_dir}/etc/php.d/02-opcache.ini << EOF
zend_extension=${opcache_so}
EOF
      fi
      cat >> ${php_install_dir}/etc/php.d/02-opcache.ini << EOF
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=${Memory_limit}
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=100000
opcache.max_wasted_percentage=5
opcache.use_cwd=1
opcache.validate_timestamps=1
opcache.revalidate_freq=60
;opcache.save_comments=0
opcache.consistency_checks=0
;opcache.optimization_level=0
EOF
    }

    # PHP 8.4/8.5 may already have OPcache statically linked.
    # In this case there is no opcache.so and rebuilding ext/opcache is unnecessary.
    if [[ "${PHP_main_ver}" =~ ^8\.[45]$ ]] && [ "${php_builtin_opcache}" == 'y' ] && [ ! -f "${phpExtensionDir}/opcache.so" ]; then
      write_opcache_ini ""
      echo "${CSUCCESS}Zend OPcache is built-in (${PHP_detail_ver}), skip extra module build.${CEND}"
      popd > /dev/null
      return 0
    fi
    if [[ "${PHP_main_ver}" =~ ^5.[3-4]$ ]]; then
      tar xzf zendopcache-${zendopcache_ver}.tgz
      pushd zendopcache-${zendopcache_ver} > /dev/null
    else
      src_url=${mirror_link}/src/php-${PHP_detail_ver}.tar.gz
      src_url_backup=https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz
      Download_src; unset src_url_backup
      tar xzf php-${PHP_detail_ver}.tar.gz
      pushd php-${PHP_detail_ver}/ext/opcache > /dev/null
    fi

    ${php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_install_dir}/bin/php-config
    make -j ${THREAD} && make install
    popd > /dev/null
    if [ -f "${phpExtensionDir}/opcache.so" ]; then
      # write opcache configs
      if [[ "${PHP_main_ver}" =~ ^5.[3-4]$ ]]; then
        # For php 5.3 5.4
        cat > ${php_install_dir}/etc/php.d/02-opcache.ini << EOF
[opcache]
zend_extension=${phpExtensionDir}/opcache.so
opcache.enable=1
opcache.memory_consumption=${Memory_limit}
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
;opcache.save_comments=0
opcache.fast_shutdown=1
opcache.enable_cli=1
;opcache.optimization_level=0
EOF
        rm -rf zendopcache-${zendopcache_ver}
      else
        # For php 5.5+
        write_opcache_ini "${phpExtensionDir}/opcache.so"
      fi

      echo "${CSUCCESS}PHP opcache module installed successfully! ${CEND}"
      rm -rf php-${PHP_detail_ver}
    elif [ "${php_builtin_opcache}" == 'y' ]; then
      # Build step may not produce opcache.so when OPcache is static.
      write_opcache_ini ""
      echo "${CSUCCESS}Zend OPcache is available as built-in extension, no opcache.so required.${CEND}"
    else
      echo "${CFAILURE}PHP opcache module install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    fi
    popd > /dev/null
  fi
}

Uninstall_ZendOPcache() {
  if [ -e "${php_install_dir}/etc/php.d/02-opcache.ini" ]; then
    rm -f ${php_install_dir}/etc/php.d/02-opcache.ini
    echo; echo "${CMSG}PHP opcache module uninstall completed${CEND}"
  else
    echo; echo "${CWARNING}PHP opcache module does not exist! ${CEND}"
  fi
}
