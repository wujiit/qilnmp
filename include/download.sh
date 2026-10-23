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

Check_download_file() {
  local file_name=$1
  case "${file_name}" in
    *.tar.gz|*.tgz)
      tar tzf "${file_name}" > /dev/null 2>&1
      ;;
    *.tar.bz2|*.tbz2)
      tar tjf "${file_name}" > /dev/null 2>&1
      ;;
    *.tar.xz|*.txz)
      tar tJf "${file_name}" > /dev/null 2>&1
      ;;
    *.zip)
      if command -v unzip > /dev/null 2>&1; then
        unzip -tqq "${file_name}" > /dev/null 2>&1
      else
        return 0
      fi
      ;;
    *)
      return 0
      ;;
  esac
}

Normalize_mirror_base_url() {
  local url=$1

  url=${url#"${url%%[![:space:]]*}"}
  url=${url%"${url##*[![:space:]]}"}
  while [ -n "${url}" ] && [ "${url}" != "${url%/}" ]; do
    url=${url%/}
  done

  [ -n "${url}" ] && echo "${url}"
}

Get_configured_mirror_bases() {
  local base=""
  local item=""
  local seen="|"

  base=$(Normalize_mirror_base_url "${mirror_link}")
  if [ -n "${base}" ]; then
    echo "${base}"
    seen="${seen}${base}|"
  fi

  for item in ${mirror_fallback_links}; do
    base=$(Normalize_mirror_base_url "${item}")
    [ -z "${base}" ] && continue
    [[ "${seen}" == *"|${base}|"* ]] && continue
    echo "${base}"
    seen="${seen}${base}|"
  done
}

Get_current_mirror_base_for_url() {
  local current_url=$1
  local base=""

  while IFS= read -r base; do
    [ -z "${base}" ] && continue
    case "${current_url}" in
      "${base}"|"${base}/"*)
        echo "${base}"
        return 0
        ;;
    esac
  done < <(Get_configured_mirror_bases)

  return 1
}

Get_mirror_fallback_urls() {
  local current_url=$1
  local current_base=""
  local suffix=""
  local base=""

  current_base=$(Get_current_mirror_base_for_url "${current_url}") || return 1
  suffix=${current_url#${current_base}}

  while IFS= read -r base; do
    [ -z "${base}" ] && continue
    [ "${base}" = "${current_base}" ] && continue
    echo "${base}${suffix}"
  done < <(Get_configured_mirror_bases)
}

Fetch_url_to_file() {
  local url=$1
  local out_file=$2

  [ -z "${url}" ] && return 1
  [ -z "${out_file}" ] && return 1

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 5 -m 12 "${url}" -o "${out_file}" >/dev/null 2>&1 || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -q --timeout=12 --tries=1 -O "${out_file}" "${url}" >/dev/null 2>&1 || return 1
  else
    return 1
  fi

  [ -s "${out_file}" ]
}

Get_redirects_fallback_url() {
  local current_url=$1
  local file_name=$2
  local cache_file="/tmp/oneinstack_mirror_redirects.cache"
  local current_base=""
  local candidate_base=""
  local redirects_url=""
  local fallback_url=""

  # Only apply this strategy to /src/* mirror paths.
  if [[ "${current_url}" != */src/* ]]; then
    return 1
  fi
  [ -z "${file_name}" ] && return 1

  current_base=$(Get_current_mirror_base_for_url "${current_url}" 2>/dev/null)
  if [ -n "${current_base}" ]; then
    redirects_url="${current_base}/_redirects"
    Fetch_url_to_file "${redirects_url}" "${cache_file}" || true
  fi

  if [ ! -s "${cache_file}" ]; then
    while IFS= read -r candidate_base; do
      [ -z "${candidate_base}" ] && continue
      [ "${candidate_base}" = "${current_base}" ] && continue
      redirects_url="${candidate_base}/_redirects"
      if Fetch_url_to_file "${redirects_url}" "${cache_file}"; then
        break
      fi
    done < <(Get_configured_mirror_bases)
  fi

  [ ! -s "${cache_file}" ] && return 1

  fallback_url=$(awk -v key="/src/${file_name}" '$1 == key {print $2; exit}' "${cache_file}")
  [ -z "${fallback_url}" ] && return 1
  echo "${fallback_url}"
  return 0
}

Get_custom_src_url() {
  local file_name=$1
  local custom_file=${custom_src_urls_file}
  local custom_url=""
  local line=""
  local key=""
  local value=""

  [ -z "${file_name}" ] && return 1
  [ -z "${custom_file}" ] && custom_file="${oneinstack_dir}/config/custom_src_urls.conf"
  [ ! -s "${custom_file}" ] && return 1

  while IFS= read -r line || [ -n "${line}" ]; do
    case "${line}" in
      ''|\#*) continue ;;
    esac

    if [[ "${line}" == *"="* ]]; then
      key=${line%%=*}
      value=${line#*=}
      key=${key#"${key%%[![:space:]]*}"}
      key=${key%"${key##*[![:space:]]}"}
      value=${value#"${value%%[![:space:]]*}"}
      value=${value%"${value##*[![:space:]]}"}
      [ "${key}" = "${file_name}" ] && [ -n "${value}" ] && {
        custom_url=${value}
        break
      }
    else
      key=$(echo "${line}" | awk '{print $1}')
      value=$(echo "${line}" | awk '{print $2}')
      [ "${key}" = "${file_name}" ] && [ -n "${value}" ] && {
        custom_url=${value}
        break
      }
    fi
  done < "${custom_file}"

  [ -z "${custom_url}" ] && return 1
  echo "${custom_url}"
  return 0
}

Get_builtin_official_url() {
  local file_name=$1
  local ver=""
  local tag=""
  local major_minor=""

  case "${file_name}" in
    icu4c-*-src.tgz)
      ver=${file_name#icu4c-}
      ver=${ver%-src.tgz}
      tag=${ver//_/-}
      echo "https://github.com/unicode-org/icu/releases/download/release-${tag}/${file_name}"
      return 0
      ;;
    jemalloc-*.tar.bz2)
      ver=${file_name#jemalloc-}
      ver=${ver%.tar.bz2}
      echo "https://github.com/jemalloc/jemalloc/releases/download/${ver}/${file_name}"
      return 0
      ;;
    pcre-*.tar.gz)
      ver=${file_name#pcre-}
      ver=${ver%.tar.gz}
      echo "https://downloads.sourceforge.net/project/pcre/pcre/${ver}/${file_name}"
      return 0
      ;;
    nginx-*.tar.gz)
      echo "https://nginx.org/download/${file_name}"
      return 0
      ;;
    tengine-*.tar.gz)
      echo "https://tengine.taobao.org/download/${file_name}"
      return 0
      ;;
    openresty-*.tar.gz)
      echo "https://openresty.org/download/${file_name}"
      return 0
      ;;
    php-*.tar.gz)
      echo "https://www.php.net/distributions/${file_name}"
      return 0
      ;;
    openssl-*.tar.gz)
      ver=${file_name#openssl-}
      ver=${ver%.tar.gz}
      if [[ "${ver}" =~ ^1\. ]]; then
        tag=${ver//./_}
        echo "https://github.com/openssl/openssl/releases/download/OpenSSL_${tag}/${file_name}"
      else
        echo "https://github.com/openssl/openssl/releases/download/openssl-${ver}/${file_name}"
      fi
      return 0
      ;;
    cacert.pem)
      echo "https://curl.se/ca/cacert.pem"
      return 0
      ;;
    curl-*.tar.gz)
      echo "https://curl.se/download/${file_name}"
      return 0
      ;;
    libiconv-*.tar.gz)
      echo "https://ftp.gnu.org/pub/gnu/libiconv/${file_name}"
      return 0
      ;;
    mhash-*.tar.gz)
      ver=${file_name#mhash-}
      ver=${ver%.tar.gz}
      echo "https://downloads.sourceforge.net/project/mhash/mhash/${ver}/${file_name}"
      return 0
      ;;
    freetype-*.tar.gz)
      echo "https://download.savannah.gnu.org/releases/freetype/${file_name}"
      return 0
      ;;
    argon2-*.tar.gz)
      ver=${file_name#argon2-}
      ver=${ver%.tar.gz}
      echo "https://github.com/P-H-C/phc-winner-argon2/archive/refs/tags/${ver}.tar.gz"
      return 0
      ;;
    libsodium-*.tar.gz)
      echo "https://download.libsodium.org/libsodium/releases/${file_name}"
      return 0
      ;;
    libzip-*.tar.gz)
      echo "https://libzip.org/download/${file_name}"
      return 0
      ;;
    libxml2-*.tar.xz)
      ver=${file_name#libxml2-}
      ver=${ver%.tar.xz}
      major_minor=${ver%.*}
      echo "https://download.gnome.org/sources/libxml2/${major_minor}/${file_name}"
      return 0
      ;;
    zlib-*.tar.gz)
      echo "https://zlib.net/fossils/${file_name}"
      return 0
      ;;
    redis-*.tar.gz)
      echo "http://download.redis.io/releases/${file_name}"
      return 0
      ;;
    memcached-*.tar.gz)
      echo "http://www.memcached.org/files/${file_name}"
      return 0
      ;;
    libmemcached-*.tar.gz)
      ver=${file_name#libmemcached-}
      ver=${ver%.tar.gz}
      echo "https://launchpad.net/libmemcached/1.0/${ver}/+download/${file_name}"
      return 0
      ;;
    pure-ftpd-*.tar.gz)
      echo "https://download.pureftpd.org/pub/pure-ftpd/releases/${file_name}"
      return 0
      ;;
    phpMyAdmin-*-all-languages.tar.gz)
      ver=${file_name#phpMyAdmin-}
      ver=${ver%-all-languages.tar.gz}
      echo "https://files.phpmyadmin.net/phpMyAdmin/${ver}/${file_name}"
      return 0
      ;;
    ImageMagick-*.tar.gz)
      echo "https://imagemagick.org/archive/${file_name}"
      return 0
      ;;
    GraphicsMagick-*.tar.gz)
      ver=${file_name#GraphicsMagick-}
      ver=${ver%.tar.gz}
      echo "https://downloads.sourceforge.net/project/graphicsmagick/graphicsmagick/${ver}/${file_name}"
      return 0
      ;;
    boost_*.tar.gz)
      ver=${file_name#boost_}
      ver=${ver%.tar.gz}
      tag=${ver//_/.}
      echo "https://downloads.sourceforge.net/project/boost/boost/${tag}/${file_name}"
      return 0
      ;;
    caddy_*.tar.gz|caddy-*.tar.gz)
      ver=${file_name#caddy-}
      ver=${ver%.tar.gz}
      echo "https://github.com/caddyserver/caddy/releases/download/v${ver}/caddy_${ver}_linux_${ARCH:-amd64}.tar.gz"
      return 0
      ;;
    nghttp2-*.tar.gz)
      ver=${file_name#nghttp2-}
      ver=${ver%.tar.gz}
      echo "https://github.com/nghttp2/nghttp2/releases/download/v${ver}/${file_name}"
      return 0
      ;;
    webgrind-*.zip)
      echo "https://github.com/jokkedk/webgrind/archive/refs/heads/master.zip"
      return 0
      ;;
    acme.sh-*.tar.gz)
      echo "https://github.com/acmesh-official/acme.sh/archive/refs/heads/master.tar.gz"
      return 0
      ;;
    mariadb-*-linux-systemd-x86_64.tar.gz)
      ver=${file_name#mariadb-}
      ver=${ver%-linux-systemd-x86_64.tar.gz}
      echo "https://archive.mariadb.org/mariadb-${ver}/bintar-linux-systemd-x86_64/${file_name}"
      return 0
      ;;
    mariadb-*.tar.gz)
      ver=${file_name#mariadb-}
      ver=${ver%.tar.gz}
      echo "https://archive.mariadb.org/mariadb-${ver}/source/${file_name}"
      return 0
      ;;
    mysql-*-linux-glibc*.tar.xz|mysql-*-linux-glibc*.tar.gz|mysql-*.tar.gz)
      echo "https://downloads.mysql.com/archives/get/p/23/file/${file_name}"
      return 0
      ;;
    wordpress-*.tar.gz)
      echo "https://wordpress.org/${file_name}"
      return 0
      ;;
    httpd-*.tar.gz)
      echo "https://archive.apache.org/dist/httpd/${file_name}"
      return 0
      ;;
    apr-*.tar.gz)
      echo "https://archive.apache.org/dist/apr/${file_name}"
      return 0
      ;;
    apr-util-*.tar.gz)
      echo "https://archive.apache.org/dist/apr/${file_name}"
      return 0
      ;;
    apache-tomcat-*.tar.gz)
      ver=${file_name#apache-tomcat-}
      ver=${ver%.tar.gz}
      local major=${ver%%.*}
      echo "https://archive.apache.org/dist/tomcat/tomcat-${major}/v${ver}/bin/${file_name}"
      return 0
      ;;
    lua-nginx-module-*.tar.gz)
      ver=${file_name#lua-nginx-module-}
      ver=${ver%.tar.gz}
      echo "https://github.com/openresty/lua-nginx-module/archive/refs/tags/v${ver}.tar.gz"
      return 0
      ;;
    luajit2-*.tar.gz)
      ver=${file_name#luajit2-}
      ver=${ver%.tar.gz}
      echo "https://github.com/openresty/luajit2/archive/refs/tags/v${ver}.tar.gz"
      return 0
      ;;
    lua-resty-core-*.tar.gz)
      ver=${file_name#lua-resty-core-}
      ver=${ver%.tar.gz}
      echo "https://github.com/openresty/lua-resty-core/archive/refs/tags/v${ver}.tar.gz"
      return 0
      ;;
    lua-resty-lrucache-*.tar.gz)
      ver=${file_name#lua-resty-lrucache-}
      ver=${ver%.tar.gz}
      echo "https://github.com/openresty/lua-resty-lrucache/archive/refs/tags/v${ver}.tar.gz"
      return 0
      ;;
    *.tgz)
      # PECL extensions
      echo "https://pecl.php.net/get/${file_name}"
      return 0
      ;;
  esac

  return 1
}

Download_src() {
  local file_name=${src_url##*/}
  local try_dl_count=0
  local max_try=3
  local dl_url=""
  local fallback_mirror_url=""
  local redirects_fallback_url=""
  local builtin_official_url=""
  local custom_url=""

  while true; do
    if [ -s "${file_name}" ] && Check_download_file "${file_name}"; then
      echo "[${CMSG}${file_name}${CEND}] found"
      break
    fi

    [ -e "${file_name}" ] && rm -f "${file_name}"
    dl_url="${src_url}"
    wget --limit-rate=100M --tries=6 -c --no-check-certificate -O "${file_name}" "${dl_url}"
    if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
      [ -e "${file_name}" ] && rm -f "${file_name}"
      if [ -e "/usr/local/curl/bin/curl" ]; then
        echo "${CWARNING}wget failed, trying /usr/local/curl...${CEND}"
        /usr/local/curl/bin/curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
      elif command -v curl >/dev/null 2>&1; then
        echo "${CWARNING}wget failed, trying system curl...${CEND}"
        curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
      fi
    fi
    if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
      custom_url=$(Get_custom_src_url "${file_name}")
      if [ -n "${custom_url}" ] && [ "${custom_url}" != "${src_url}" ]; then
        echo "${CWARNING}Primary URL failed, trying custom URL from ${custom_src_urls_file:-${oneinstack_dir}/config/custom_src_urls.conf}: ${custom_url}${CEND}"
        [ -e "${file_name}" ] && rm -f "${file_name}"
        dl_url="${custom_url}"
        wget --limit-rate=100M --tries=6 -c --no-check-certificate -O "${file_name}" "${dl_url}"
        if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
          [ -e "${file_name}" ] && rm -f "${file_name}"
          if [ -e "/usr/local/curl/bin/curl" ]; then
            /usr/local/curl/bin/curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          elif command -v curl >/dev/null 2>&1; then
            curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          fi
        fi
      fi
    fi
    if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
      if [ -n "${src_url_backup}" ]; then
        echo "${CWARNING}Primary URL failed, trying backup url: ${src_url_backup}${CEND}"
        [ -e "${file_name}" ] && rm -f "${file_name}"
        dl_url="${src_url_backup}"
        wget --limit-rate=100M --tries=6 -c --no-check-certificate -O "${file_name}" "${dl_url}"
        if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
          [ -e "${file_name}" ] && rm -f "${file_name}"
          if [ -e "/usr/local/curl/bin/curl" ]; then
            /usr/local/curl/bin/curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          elif command -v curl >/dev/null 2>&1; then
            curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          fi
        fi
      fi
    fi
    if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
      while IFS= read -r fallback_mirror_url; do
        [ -z "${fallback_mirror_url}" ] && continue
        echo "${CWARNING}Primary URL failed, trying configured fallback mirror: ${fallback_mirror_url}${CEND}"
        [ -e "${file_name}" ] && rm -f "${file_name}"
        dl_url="${fallback_mirror_url}"
        wget --limit-rate=100M --tries=6 -c --no-check-certificate -O "${file_name}" "${dl_url}"
        if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
          [ -e "${file_name}" ] && rm -f "${file_name}"
          if [ -e "/usr/local/curl/bin/curl" ]; then
            /usr/local/curl/bin/curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          elif command -v curl >/dev/null 2>&1; then
            curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          fi
        fi
        if [ -s "${file_name}" ] && Check_download_file "${file_name}"; then
          break
        fi
      done < <(Get_mirror_fallback_urls "${src_url}")
    fi
    if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
      redirects_fallback_url=$(Get_redirects_fallback_url "${src_url}" "${file_name}")
      if [ -n "${redirects_fallback_url}" ] \
        && [ "${redirects_fallback_url}" != "${src_url}" ] \
        && [ "${redirects_fallback_url}" != "${src_url_backup}" ]; then
        echo "${CWARNING}Mirror URL failed, trying official URL from _redirects: ${redirects_fallback_url}${CEND}"
        [ -e "${file_name}" ] && rm -f "${file_name}"
        dl_url="${redirects_fallback_url}"
        wget --limit-rate=100M --tries=6 -c --no-check-certificate -O "${file_name}" "${dl_url}"
        if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
          [ -e "${file_name}" ] && rm -f "${file_name}"
          if [ -e "/usr/local/curl/bin/curl" ]; then
            /usr/local/curl/bin/curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          elif command -v curl >/dev/null 2>&1; then
            curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          fi
        fi
      fi
    fi
    if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
      builtin_official_url=$(Get_builtin_official_url "${file_name}")
      if [ -n "${builtin_official_url}" ] \
        && [ "${builtin_official_url}" != "${src_url}" ] \
        && [ "${builtin_official_url}" != "${src_url_backup}" ] \
        && [ "${builtin_official_url}" != "${redirects_fallback_url}" ]; then
        echo "${CWARNING}Mirror URL failed, trying built-in official upstream URL: ${builtin_official_url}${CEND}"
        [ -e "${file_name}" ] && rm -f "${file_name}"
        dl_url="${builtin_official_url}"
        wget --limit-rate=100M --tries=6 -c --no-check-certificate -O "${file_name}" "${dl_url}"
        if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
          [ -e "${file_name}" ] && rm -f "${file_name}"
          if [ -e "/usr/local/curl/bin/curl" ]; then
            /usr/local/curl/bin/curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          elif command -v curl >/dev/null 2>&1; then
            curl -L -C - --insecure --retry 6 -o "${file_name}" "${dl_url}"
          fi
        fi
      fi
    fi
    sleep 1

    if [ -s "${file_name}" ] && Check_download_file "${file_name}"; then
      break
    fi

    let "try_dl_count++"
    [ "${try_dl_count}" -lt "${max_try}" ] && echo "${CWARNING}Download retry ${try_dl_count}/${max_try}: ${file_name}${CEND}"
    [ "${try_dl_count}" -ge "${max_try}" ] && break
  done

  if [ ! -s "${file_name}" ] || ! Check_download_file "${file_name}"; then
    local official_url=$(Get_builtin_official_url "${file_name}" 2>/dev/null)
    echo
    echo "${CFAILURE}#########################################################################${CEND}"
    echo "${CFAILURE}Error: Auto download failed or file is corrupted: ${file_name}${CEND}"
    echo "${CWARNING}Both configured mirror and official fallback sources failed or timed out.${CEND}"
    echo
    echo "${CMSG}You can manually download this package from:${CEND}"
    [ -n "${official_url}" ] && echo "  - Official Upstream : ${CMSG}${official_url}${CEND}"
    [ -n "${src_url_backup}" ] && [ "${src_url_backup}" != "${official_url}" ] && echo "  - Backup Source     : ${CMSG}${src_url_backup}${CEND}"
    echo "  - Configured Mirror : ${CMSG}${src_url}${CEND}"
    echo
    echo "${CMSG}Then upload '${file_name}' into: ${oneinstack_dir}/src/${file_name} and rerun ./install.sh${CEND}"
    echo "${CFAILURE}#########################################################################${CEND}"
    echo
    kill -9 $$; exit 1;
  fi
}
