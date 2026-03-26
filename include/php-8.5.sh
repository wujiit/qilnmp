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

Install_PHP85() {
  pushd ${oneinstack_dir}/src > /dev/null

  version_lt() {
    local current_ver=$1
    local required_ver=$2
    [ -z "${current_ver}" ] && current_ver="0"
    [ "${current_ver}" != "${required_ver}" ] && [ "$(printf "%s\n%s\n" "${current_ver}" "${required_ver}" | sort -V | head -n1)" = "${current_ver}" ]
  }
  php_build_thread=${PHP_THREAD:-${THREAD}}
  [ -z "${php_build_thread}" ] && php_build_thread=1

  Is_valid_archive() {
    local file_name=$1
    if type Check_download_file >/dev/null 2>&1; then
      Check_download_file "${file_name}"
    else
      return 0
    fi
  }

  Ensure_source_archive() {
    local file_name=$1
    local backup_url=$2

    [ -z "${file_name}" ] && return 1
    if [ -s "${file_name}" ] && Is_valid_archive "${file_name}"; then
      return 0
    fi

    [ -e "${file_name}" ] && rm -f "${file_name}"
    if ! type Download_src >/dev/null 2>&1; then
      echo "${CFAILURE}Download_src function not found, cannot fetch ${file_name}.${CEND}"
      kill -9 $$; exit 1;
    fi

    src_url=${mirror_link}/src/${file_name}
    if [ -n "${backup_url}" ]; then
      src_url_backup=${backup_url}
      Download_src
      unset src_url_backup
    else
      Download_src
    fi

    if [ ! -s "${file_name}" ] || ! Is_valid_archive "${file_name}"; then
      echo "${CFAILURE}Required source package missing or corrupted: ${file_name}${CEND}"
      kill -9 $$; exit 1;
    fi
  }

  # Check if system libxml2 version is sufficient (PHP 8.5 requires >= 2.9.4)
  if command -v pkg-config > /dev/null 2>&1; then
    sys_libxml2_ver=$(pkg-config --modversion libxml-2.0 2>/dev/null || echo "0")
  else
    sys_libxml2_ver="0"
  fi
  if version_lt "${sys_libxml2_ver}" "2.9.4"; then
    Ensure_source_archive "libxml2-${libxml2_ver}.tar.xz" "https://download.gnome.org/sources/libxml2/$(echo ${libxml2_ver} | awk -F. '{print $1"."$2}')/libxml2-${libxml2_ver}.tar.xz"
    echo "${CMSG}System libxml2 ${sys_libxml2_ver} is too old, compiling libxml2-${libxml2_ver} from source...${CEND}"
    tar xJf libxml2-${libxml2_ver}.tar.xz
    pushd libxml2-${libxml2_ver} > /dev/null
    ./configure --prefix=/usr/local --without-python
    make -j ${php_build_thread} && make install
    popd > /dev/null
    rm -rf libxml2-${libxml2_ver}
    ldconfig
  fi
  if [ ! -e "/usr/local/lib/libiconv.la" ]; then
    Ensure_source_archive "libiconv-${libiconv_ver}.tar.gz" "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${libiconv_ver}.tar.gz"
    tar xzf libiconv-${libiconv_ver}.tar.gz
    pushd libiconv-${libiconv_ver} > /dev/null
    ./configure
    make -j ${php_build_thread} && make install
    popd > /dev/null
    rm -rf libiconv-${libiconv_ver}
  fi

  if [ ! -e "${curl_install_dir}/lib/libcurl.la" ]; then
    Ensure_source_archive "curl-${curl_ver}.tar.gz" "https://curl.se/download/curl-${curl_ver}.tar.gz"
    tar xzf curl-${curl_ver}.tar.gz
    pushd curl-${curl_ver} > /dev/null
    [ -e "/usr/local/lib/libnghttp2.so" ] && with_nghttp2='--with-nghttp2=/usr/local'
    ./configure --prefix=${curl_install_dir} ${php85_with_ssl} ${with_nghttp2} --without-libpsl || {
      echo "${CFAILURE}curl-${curl_ver} configure failed.${CEND}"
      kill -9 $$; exit 1;
    }
    make -j ${php_build_thread} && make install || {
      echo "${CFAILURE}curl-${curl_ver} build failed.${CEND}"
      kill -9 $$; exit 1;
    }
    popd > /dev/null
    rm -rf curl-${curl_ver}
  fi

  if [ ! -e "${freetype_install_dir}/lib/libfreetype.la" ]; then
    Ensure_source_archive "freetype-${freetype_ver}.tar.gz" "https://downloads.sourceforge.net/project/freetype/freetype2/${freetype_ver}/freetype-${freetype_ver}.tar.gz"
    tar xzf freetype-${freetype_ver}.tar.gz
    pushd freetype-${freetype_ver} > /dev/null
    ./configure --prefix=${freetype_install_dir} --enable-freetype-config
    make -j ${php_build_thread} && make install
    ln -sf ${freetype_install_dir}/include/freetype2/* /usr/include/
    [ -d /usr/lib/pkgconfig ] && /bin/cp ${freetype_install_dir}/lib/pkgconfig/freetype2.pc /usr/lib/pkgconfig/
    popd > /dev/null
    rm -rf freetype-${freetype_ver}
  fi

  if [ ! -e "/usr/local/lib/pkgconfig/libargon2.pc" ]; then
    Ensure_source_archive "argon2-${argon2_ver}.tar.gz" "https://github.com/P-H-C/phc-winner-argon2/archive/refs/tags/${argon2_ver}.tar.gz"
    rm -rf argon2-${argon2_ver} phc-winner-argon2-${argon2_ver}
    tar xzf argon2-${argon2_ver}.tar.gz || {
      echo "${CFAILURE}Extract argon2-${argon2_ver}.tar.gz failed.${CEND}"
      kill -9 $$; exit 1;
    }
    if [ -d "argon2-${argon2_ver}" ]; then
      argon2_src_dir="argon2-${argon2_ver}"
    elif [ -d "phc-winner-argon2-${argon2_ver}" ]; then
      argon2_src_dir="phc-winner-argon2-${argon2_ver}"
    else
      echo "${CFAILURE}Argon2 source directory not found after extract (expect argon2-${argon2_ver} or phc-winner-argon2-${argon2_ver}).${CEND}"
      kill -9 $$; exit 1;
    fi
    pushd "${argon2_src_dir}" > /dev/null
    make -j ${php_build_thread} && make install
    [ ! -d /usr/local/lib/pkgconfig ] && mkdir -p /usr/local/lib/pkgconfig
    /bin/cp libargon2.pc /usr/local/lib/pkgconfig/
    popd > /dev/null
    rm -rf "${argon2_src_dir}"
  fi

  if [ ! -e "/usr/local/lib/libsodium.la" ]; then
    Ensure_source_archive "libsodium-${libsodium_up_ver}.tar.gz" "https://download.libsodium.org/libsodium/releases/libsodium-${libsodium_up_ver}.tar.gz"
    tar xzf libsodium-${libsodium_up_ver}.tar.gz
    pushd libsodium-${libsodium_up_ver} > /dev/null
    ./configure --disable-dependency-tracking --enable-minimal
    make -j ${php_build_thread} && make install
    popd > /dev/null
    rm -rf libsodium-${libsodium_up_ver}
  fi

  if [ ! -e "/usr/local/lib/libzip.so" -a ! -e "/usr/local/lib/libzip.la" ]; then
    Ensure_source_archive "libzip-${libzip_ver}.tar.gz" "https://libzip.org/download/libzip-${libzip_ver}.tar.gz"
    tar xzf libzip-${libzip_ver}.tar.gz || exit 1
    pushd libzip-${libzip_ver} > /dev/null || exit 1
    mkdir -p build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local ..
    make -j ${php_build_thread} && make install
    popd > /dev/null
    rm -rf libzip-${libzip_ver}
  fi

  if [ ! -e "/usr/local/include/mhash.h" -a ! -e "/usr/include/mhash.h" ]; then
    Ensure_source_archive "mhash-${mhash_ver}.tar.gz" "https://downloads.sourceforge.net/project/mhash/mhash/${mhash_ver}/mhash-${mhash_ver}.tar.gz"
    tar xzf mhash-${mhash_ver}.tar.gz
    pushd mhash-${mhash_ver} > /dev/null
    ./configure
    make -j ${php_build_thread} && make install
    popd > /dev/null
    rm -rf mhash-${mhash_ver}
  fi

  # Check if system zlib version is sufficient (PHP 8.4+ requires >= 1.2.11)
  if command -v pkg-config > /dev/null 2>&1; then
    sys_zlib_ver=$(pkg-config --modversion zlib 2>/dev/null || echo "0")
  else
    sys_zlib_ver="0"
  fi
  if version_lt "${sys_zlib_ver}" "1.2.11"; then
    Ensure_source_archive "zlib-${zlib_ver}.tar.gz" "https://zlib.net/zlib-${zlib_ver}.tar.gz"
    echo "${CMSG}System zlib ${sys_zlib_ver} is too old, compiling zlib-${zlib_ver} from source...${CEND}"
    tar xzf zlib-${zlib_ver}.tar.gz
    pushd zlib-${zlib_ver} > /dev/null
    ./configure --prefix=/usr/local/zlib
    make -j ${php_build_thread} && make install
    popd > /dev/null
    rm -rf zlib-${zlib_ver}
    export PKG_CONFIG_PATH=/usr/local/zlib/lib/pkgconfig:$PKG_CONFIG_PATH
    [ -z "`grep /usr/local/zlib/lib /etc/ld.so.conf.d/*.conf 2>/dev/null`" ] && echo '/usr/local/zlib/lib' > /etc/ld.so.conf.d/zlib.conf
    with_zlib="--with-zlib=/usr/local/zlib"
  else
    with_zlib="--with-zlib"
  fi

  [ -z "`grep /usr/local/lib /etc/ld.so.conf.d/*.conf 2>/dev/null`" ] && echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf
  ldconfig

  if [ "${PM}" == 'yum' ]; then
    [ ! -e "/lib64/libpcre.so.1" ] && ln -s /lib64/libpcre.so.0.0.1 /lib64/libpcre.so.1
    [ ! -e "/usr/lib/libc-client.so" ] && ln -s /usr/lib64/libc-client.so /usr/lib/libc-client.so
  fi

  id -g ${run_group} >/dev/null 2>&1
  [ $? -ne 0 ] && groupadd ${run_group}
  id -u ${run_user} >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -g ${run_group} -M -s /sbin/nologin ${run_user}

  Ensure_source_archive "php-${php85_ver}.tar.gz" "https://www.php.net/distributions/php-${php85_ver}.tar.gz"
  rm -rf php-${php85_ver}
  tar xzf php-${php85_ver}.tar.gz || {
    echo "${CFAILURE}Extract php-${php85_ver}.tar.gz failed, source package may be corrupted.${CEND}"
    kill -9 $$; exit 1;
  }
  [ ! -d "php-${php85_ver}" ] && {
    echo "${CFAILURE}PHP source directory php-${php85_ver} not found after extract.${CEND}"
    kill -9 $$; exit 1;
  }
  pushd php-${php85_ver} > /dev/null
  [ -f Makefile ] && make clean
  export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/:$PKG_CONFIG_PATH
  [ "${with_old_openssl_flag}" == 'y' ] && export PKG_CONFIG_PATH=${openssl_install_dir}/lib/pkgconfig/:$PKG_CONFIG_PATH
  [ ! -d "${php_install_dir}" ] && mkdir -p ${php_install_dir}
  [ "${phpcache_option}" == '1' ] && phpcache_arg='--enable-opcache' || phpcache_arg='--disable-opcache'
  if [ "${apache_mode_option}" == '2' ]; then
    ./configure --prefix=${php_install_dir} --with-config-file-path=${php_install_dir}/etc \
    --with-config-file-scan-dir=${php_install_dir}/etc/php.d \
    --with-apxs2=${apache_install_dir}/bin/apxs ${phpcache_arg} --disable-fileinfo \
    --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
    --with-iconv=/usr/local --with-freetype --with-jpeg ${with_zlib} \
    --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-exif \
    --enable-sysvsem ${php85_with_curl} --enable-mbregex \
    --enable-mbstring --with-password-argon2 --with-sodium=/usr/local --enable-gd ${php85_with_openssl} \
    --with-mhash --enable-pcntl --enable-sockets --enable-ftp --enable-intl --with-xsl \
    --with-gettext --with-zip=/usr/local --enable-soap --disable-debug ${php_modules_options}
  else
    ./configure --prefix=${php_install_dir} --with-config-file-path=${php_install_dir}/etc \
    --with-config-file-scan-dir=${php_install_dir}/etc/php.d \
    --with-fpm-user=${run_user} --with-fpm-group=${run_group} --enable-fpm ${phpcache_arg} --disable-fileinfo \
    --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
    --with-iconv=/usr/local --with-freetype --with-jpeg ${with_zlib} \
    --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-exif \
    --enable-sysvsem ${php85_with_curl} --enable-mbregex \
    --enable-mbstring --with-password-argon2 --with-sodium=/usr/local --enable-gd ${php85_with_openssl} \
    --with-mhash --enable-pcntl --enable-sockets --enable-ftp --enable-intl --with-xsl \
    --with-gettext --with-zip=/usr/local --enable-soap --disable-debug ${php_modules_options}
  fi
  make ZEND_EXTRA_LIBS='-liconv' -j ${php_build_thread} || {
    if [ ${php_build_thread} -gt 1 ]; then
      echo "${CWARNING}PHP compile failed with -j${php_build_thread}, retrying with -j1...${CEND}"
      make clean
      make ZEND_EXTRA_LIBS='-liconv' -j 1 || { echo "${CFAILURE}PHP compile failed with -j1.${CEND}"; kill -9 $$; exit 1; }
    else
      echo "${CFAILURE}PHP compile failed.${CEND}"
      kill -9 $$; exit 1;
    fi
  }
  make install

  if [ -e "${php_install_dir}/bin/phpize" ]; then
    [ ! -e "${php_install_dir}/etc/php.d" ] && mkdir -p ${php_install_dir}/etc/php.d
    echo "${CSUCCESS}PHP installed successfully! ${CEND}"
  else
    rm -rf ${php_install_dir}
    echo "${CFAILURE}PHP install failed, Please Contact the author! ${CEND}"
    kill -9 $$; exit 1;
  fi

  [ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=${php_install_dir}/bin:\$PATH" >> /etc/profile
  [ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep ${php_install_dir} /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=${php_install_dir}/bin:\1@" /etc/profile
  . /etc/profile

  # wget -c http://pear.php.net/go-pear.phar
  # ${php_install_dir}/bin/php go-pear.phar

  /bin/cp php.ini-production ${php_install_dir}/etc/php.ini

  sed -i "s@^memory_limit.*@memory_limit = ${Memory_limit}M@" ${php_install_dir}/etc/php.ini
  sed -i 's@^output_buffering =@output_buffering = On\noutput_buffering =@' ${php_install_dir}/etc/php.ini
  #sed -i 's@^;cgi.fix_pathinfo.*@cgi.fix_pathinfo=0@' ${php_install_dir}/etc/php.ini
  sed -i 's@^short_open_tag = Off@short_open_tag = On@' ${php_install_dir}/etc/php.ini
  sed -i 's@^expose_php = On@expose_php = Off@' ${php_install_dir}/etc/php.ini
  sed -i 's@^request_order.*@request_order = "CGP"@' ${php_install_dir}/etc/php.ini
  sed -i "s@^;date.timezone.*@date.timezone = ${timezone}@" ${php_install_dir}/etc/php.ini
  sed -i 's@^post_max_size.*@post_max_size = 100M@' ${php_install_dir}/etc/php.ini
  sed -i 's@^upload_max_filesize.*@upload_max_filesize = 50M@' ${php_install_dir}/etc/php.ini
  sed -i 's@^max_execution_time.*@max_execution_time = 600@' ${php_install_dir}/etc/php.ini
  sed -i 's@^;realpath_cache_size.*@realpath_cache_size = 2M@' ${php_install_dir}/etc/php.ini
  sed -i 's@^disable_functions.*@disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen@' ${php_install_dir}/etc/php.ini
  [ -e /usr/sbin/sendmail ] && sed -i 's@^;sendmail_path.*@sendmail_path = /usr/sbin/sendmail -t -i@' ${php_install_dir}/etc/php.ini
  if [ "${with_old_openssl_flag}" = 'y' ]; then
    sed -i "s@^;curl.cainfo.*@curl.cainfo = \"${openssl_install_dir}/cert.pem\"@" ${php_install_dir}/etc/php.ini
    sed -i "s@^;openssl.cafile.*@openssl.cafile = \"${openssl_install_dir}/cert.pem\"@" ${php_install_dir}/etc/php.ini
    sed -i "s@^;openssl.capath.*@openssl.capath = \"${openssl_install_dir}/cert.pem\"@" ${php_install_dir}/etc/php.ini
  fi

  if [ "${phpcache_option}" == '1' ]; then
    php_ext_dir=`${php_install_dir}/bin/php-config --extension-dir 2>/dev/null`
    if [ -n "${php_ext_dir}" ] && [ -f "${php_ext_dir}/opcache.so" ]; then
      cat > ${php_install_dir}/etc/php.d/02-opcache.ini << EOF
[opcache]
zend_extension=${php_ext_dir}/opcache.so
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
    else
      cat > ${php_install_dir}/etc/php.d/02-opcache.ini << EOF
[opcache]
; opcache.so was not found during install, skip zend_extension to avoid startup warning.
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
    fi
  fi

  if [ "${apache_mode_option}" != '2' ]; then
    # php-fpm Init Script
    /bin/cp ${oneinstack_dir}/init.d/php-fpm.service /lib/systemd/system/
    sed -i "s@/usr/local/php@${php_install_dir}@g" /lib/systemd/system/php-fpm.service
    systemctl enable php-fpm

    cat > ${php_install_dir}/etc/php-fpm.conf <<EOF
;;;;;;;;;;;;;;;;;;;;;
; FPM Configuration ;
;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;
; Global Options ;
;;;;;;;;;;;;;;;;;;

[global]
pid = run/php-fpm.pid
error_log = log/php-fpm.log
log_level = warning

emergency_restart_threshold = 30
emergency_restart_interval = 60s
process_control_timeout = 5s
daemonize = yes

;;;;;;;;;;;;;;;;;;;;
; Pool Definitions ;
;;;;;;;;;;;;;;;;;;;;

[${run_user}]
listen = /dev/shm/php-cgi.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = ${run_user}
listen.group = ${run_group}
listen.mode = 0666
user = ${run_user}
group = ${run_group}

pm = dynamic
pm.max_children = 12
pm.start_servers = 8
pm.min_spare_servers = 6
pm.max_spare_servers = 12
pm.max_requests = 2048
pm.process_idle_timeout = 10s
request_terminate_timeout = 120
request_slowlog_timeout = 0

pm.status_path = /php-fpm_status
slowlog = var/log/slow.log
rlimit_files = 51200
rlimit_core = 0

catch_workers_output = yes
;env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
EOF

    if [ $Mem -le 3000 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = $(($Mem/3/20))@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = $(($Mem/3/30))@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = $(($Mem/3/40))@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = $(($Mem/3/20))@" ${php_install_dir}/etc/php-fpm.conf
    elif [ $Mem -gt 3000 -a $Mem -le 4500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 50@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 30@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 20@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 50@" ${php_install_dir}/etc/php-fpm.conf
    elif [ $Mem -gt 4500 -a $Mem -le 6500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 60@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 40@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 30@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 60@" ${php_install_dir}/etc/php-fpm.conf
    elif [ $Mem -gt 6500 -a $Mem -le 8500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 70@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 50@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 40@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 70@" ${php_install_dir}/etc/php-fpm.conf
    elif [ $Mem -gt 8500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 80@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 60@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 50@" ${php_install_dir}/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 80@" ${php_install_dir}/etc/php-fpm.conf
    fi

    systemctl start php-fpm

  elif [ "${apache_mode_option}" == '2' ]; then
    systemctl restart httpd
  fi
  popd > /dev/null
  [ -e "${php_install_dir}/bin/phpize" ] && rm -rf php-${php85_ver}
  popd > /dev/null
}
