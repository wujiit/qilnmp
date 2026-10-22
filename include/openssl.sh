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

if openssl version | grep -Eqi 'OpenSSL 1.0.2*'; then
  php84_with_openssl="--with-openssl=${openssl_install_dir}"
  php85_with_openssl="--with-openssl=${openssl_install_dir}"

  php84_with_ssl="--with-ssl=${openssl_install_dir}"
  php85_with_ssl="--with-ssl=${openssl_install_dir}"

  php84_with_curl="--with-curl"
  php85_with_curl="--with-curl"
  [[ ${php_option} =~ ^1[4-5]$ ]] || [[ "${mphp_ver}" =~ ^8[4-5]$ ]] && with_old_openssl_flag=y
elif openssl version | grep -Eqi 'OpenSSL 1.1.*'; then
  php84_with_openssl="--with-openssl"
  php85_with_openssl="--with-openssl"

  php84_with_ssl="--with-ssl"
  php85_with_ssl="--with-ssl"

  php84_with_curl="--with-curl"
  php85_with_curl="--with-curl"
elif openssl version | grep -Eqi 'OpenSSL 3.*'; then
  php84_with_openssl="--with-openssl"
  php85_with_openssl="--with-openssl"

  php84_with_ssl="--with-ssl"
  php85_with_ssl="--with-ssl"

  php84_with_curl="--with-curl"
  php85_with_curl="--with-curl"
else
  php84_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"
  php85_with_openssl="--with-openssl=${openssl_install_dir} --with-openssl-dir=${openssl_install_dir}"

  php84_with_ssl="--with-ssl=${openssl_install_dir}"
  php85_with_ssl="--with-ssl=${openssl_install_dir}"

  php84_with_curl="--with-curl=${curl_install_dir}"
  php85_with_curl="--with-curl=${curl_install_dir}"
  with_old_openssl_flag=y
fi

Install_openSSL() {
  if [ "${with_old_openssl_flag}" == 'y' ]; then
    if [ ! -e "${openssl_install_dir}/lib/libssl.a" ]; then
      pushd ${oneinstack_dir}/src > /dev/null
      # PHP 8.4+ requires OpenSSL >= 1.1.1, compile openssl11_ver instead of openssl_ver
      if [[ ${php_option} =~ ^1[4-5]$ ]] || [[ "${mphp_ver}" =~ ^8[4-5]$ ]]; then
        local _openssl_ver=${openssl11_ver}
      else
        local _openssl_ver=${openssl_ver}
      fi
      tar xzf openssl-${_openssl_ver}.tar.gz
      pushd openssl-${_openssl_ver} > /dev/null
      make clean
      ./config -Wl,-rpath=${openssl_install_dir}/lib -fPIC --prefix=${openssl_install_dir} --openssldir=${openssl_install_dir}
      make depend 2>/dev/null
      make -j ${THREAD} && make install
      popd > /dev/null
      if [ -f "${openssl_install_dir}/lib/libcrypto.a" ]; then
        echo "${CSUCCESS}openSSL installed successfully! ${CEND}"
        /bin/cp cacert.pem ${openssl_install_dir}/cert.pem
        rm -rf openssl-${_openssl_ver}
      else
        echo "${CFAILURE}openSSL install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
        kill -9 $$; exit 1;
      fi
      popd > /dev/null
    fi
  fi
}
