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

Is_php_related_version_key() {
  case "$1" in
    nginx_ver|caddy_ver|tengine_ver|openresty_ver|\
    apache_ver|pcre_ver|apr_ver|apr_util_ver|nghttp2_ver|\
    mysql55_ver|mysql56_ver|mysql57_ver|mysql80_ver|mysql82_ver|mysql84_ver|mysql90_ver|mysql91_ver|\
    mariadb55_ver|mariadb1011_ver|mariadb105_ver|mariadb104_ver|mariadb106_ver|mariadb114_ver|mariadb118_ver|\
    redis_ver|memcached_ver|jemalloc_ver|pureftpd_ver|\
    php72_ver|php73_ver|php74_ver|php80_ver|php81_ver|php82_ver|php83_ver|php84_ver|php85_ver|\
    openssl_ver|openssl11_ver|openssl3_ver|\
    libiconv_ver|curl_ver|libmcrypt_ver|mcrypt_ver|mhash_ver|freetype_ver|\
    argon2_ver|libsodium_ver|libsodium_up_ver|zlib_ver|libzip_ver|libxml2_ver|icu4c_ver|\
    imagemagick_ver|graphicsmagick_ver|imagick_ver|imagick_oldver|gmagick_ver|gmagick_oldver|\
    phalcon_ver|phalcon_oldver|yaf_ver|yar_ver|swoole_ver|swoole_oldver|xdebug_ver|xdebug_oldver|\
    pecl_redis_ver|pecl_memcached_ver|pecl_memcached_oldver|pecl_memcache_ver|pecl_memcache_oldver|\
    pecl_mongodb_ver|pecl_mongodb_oldver|pecl_mongo_ver|\
    phpmyadmin_ver|phpmyadmin_oldver|\
    boost_ver|boost_mysql90_ver|boost_percona_ver|boost_oldver|\
    lua_nginx_module_ver|luajit2_ver|lua_resty_core_ver|lua_resty_lrucache_ver|lua_cjson_ver|\
    fail2ban_ver)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if ! declare -F Get_configured_mirror_bases >/dev/null 2>&1; then
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
fi

Fetch_version_suggestions() {
  local out_file=$1
  local suggest_url=$2

  : > "${out_file}"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 3 -m 8 "${suggest_url}" -o "${out_file}" >/dev/null 2>&1 || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 8 -O "${out_file}" "${suggest_url}" >/dev/null 2>&1 || return 1
  else
    return 1
  fi

  [ -s "${out_file}" ] && grep -qE '^[a-zA-Z0-9_]+=.+$' "${out_file}"
}

Fetch_latest_meta_versions() {
  local out_file=$1
  local meta_url=$2
  local json_file

  : > "${out_file}"
  json_file=$(mktemp /tmp/oneinstack_latest_meta.XXXXXX)
  [ ! -f "${json_file}" ] && return 1

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 3 -m 10 "${meta_url}" -o "${json_file}" >/dev/null 2>&1 || {
      rm -f "${json_file}"
      return 1
    }
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 10 -O "${json_file}" "${meta_url}" >/dev/null 2>&1 || {
      rm -f "${json_file}"
      return 1
    }
  else
    rm -f "${json_file}"
    return 1
  fi

  python3 - "${json_file}" > "${out_file}" <<'PY'
import json, sys
f = sys.argv[1]
try:
    data = json.load(open(f, 'r', encoding='utf-8'))
except Exception:
    sys.exit(1)
versions = data.get("versions", {}) if isinstance(data, dict) else {}
if not isinstance(versions, dict):
    sys.exit(1)
for k in sorted(versions.keys()):
    v = versions[k]
    if isinstance(v, str):
        print(f"{k}={v}")
PY

  rm -f "${json_file}"
  [ -s "${out_file}" ] && grep -qE '^[a-zA-Z0-9_]+=.+$' "${out_file}"
}

Fetch_resource_file_index() {
  local out_file=$1
  local resource_url=$2
  local json_file

  : > "${out_file}"
  json_file=$(mktemp /tmp/oneinstack_resource_json.XXXXXX)
  [ ! -f "${json_file}" ] && return 1

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 3 -m 12 "${resource_url}" -o "${json_file}" >/dev/null 2>&1 || {
      rm -f "${json_file}"
      return 1
    }
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 12 -O "${json_file}" "${resource_url}" >/dev/null 2>&1 || {
      rm -f "${json_file}"
      return 1
    }
  else
    rm -f "${json_file}"
    return 1
  fi

  python3 - "${json_file}" > "${out_file}" <<'PY'
import json, sys
f = sys.argv[1]
try:
    data = json.load(open(f, 'r', encoding='utf-8'))
except Exception:
    sys.exit(1)
sources = data.get("sources", {}) if isinstance(data, dict) else {}
if not isinstance(sources, dict):
    sys.exit(1)
seen = set()
for _, items in sources.items():
    if not isinstance(items, list):
        continue
    for item in items:
        if not isinstance(item, dict):
            continue
        name = item.get("file")
        if isinstance(name, str) and name and name not in seen:
            seen.add(name)
            print(name)
PY

  rm -f "${json_file}"
  [ -s "${out_file}" ]
}

Ensure_mirror_compatible_core_versions() {
  local resource_file=$1
  local adjusted_count=0
  local latest_ver=""
  local old_ver=""

  [ ! -s "${resource_file}" ] && return 0

  if ! grep -Fxq "nginx-${nginx_ver}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^nginx-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^nginx-([0-9]+\.[0-9]+\.[0-9]+)\.tar\.gz$/\1/' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${nginx_ver}
      nginx_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide nginx-${old_ver}.tar.gz, auto-adjust nginx_ver=${nginx_ver}${CEND}"
    fi
  fi

  if ! grep -Fxq "memcached-${memcached_ver}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^memcached-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^memcached-([0-9]+\.[0-9]+\.[0-9]+)\.tar\.gz$/\1/' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${memcached_ver}
      memcached_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide memcached-${old_ver}.tar.gz, auto-adjust memcached_ver=${memcached_ver}${CEND}"
    fi
  fi

  if ! grep -Fxq "boost_${boost_ver//./_}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^boost_[0-9]+_[0-9]+_[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^boost_([0-9]+_[0-9]+_[0-9]+)\.tar\.gz$/\1/' | tr '_' '.' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${boost_ver}
      boost_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide boost_${old_ver//./_}.tar.gz, auto-adjust boost_ver=${boost_ver}${CEND}"
    fi
  fi

  if ! grep -Fxq "boost_${boost_mysql90_ver//./_}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^boost_[0-9]+_[0-9]+_[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^boost_([0-9]+_[0-9]+_[0-9]+)\.tar\.gz$/\1/' | tr '_' '.' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${boost_mysql90_ver}
      boost_mysql90_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide boost_${old_ver//./_}.tar.gz, auto-adjust boost_mysql90_ver=${boost_mysql90_ver}${CEND}"
    fi
  fi

  if ! grep -Fxq "boost_${boost_percona_ver//./_}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^boost_[0-9]+_[0-9]+_[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^boost_([0-9]+_[0-9]+_[0-9]+)\.tar\.gz$/\1/' | tr '_' '.' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${boost_percona_ver}
      boost_percona_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide boost_${old_ver//./_}.tar.gz, auto-adjust boost_percona_ver=${boost_percona_ver}${CEND}"
    fi
  fi

  if ! grep -Fxq "php-${php82_ver}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^php-8\.2\.[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^php-(8\.2\.[0-9]+)\.tar\.gz$/\1/' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${php82_ver}
      php82_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide php-${old_ver}.tar.gz, auto-adjust php82_ver=${php82_ver}${CEND}"
    fi
  fi

  if ! grep -Fxq "php-${php83_ver}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^php-8\.3\.[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^php-(8\.3\.[0-9]+)\.tar\.gz$/\1/' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${php83_ver}
      php83_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide php-${old_ver}.tar.gz, auto-adjust php83_ver=${php83_ver}${CEND}"
    fi
  fi

  if ! grep -Fxq "php-${php84_ver}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^php-8\.4\.[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^php-(8\.4\.[0-9]+)\.tar\.gz$/\1/' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${php84_ver}
      php84_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide php-${old_ver}.tar.gz, auto-adjust php84_ver=${php84_ver}${CEND}"
    fi
  fi

  if ! grep -Fxq "php-${php85_ver}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^php-8\.5\.[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^php-(8\.5\.[0-9]+)\.tar\.gz$/\1/' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${php85_ver}
      php85_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide php-${old_ver}.tar.gz, auto-adjust php85_ver=${php85_ver}${CEND}"
    fi
  fi

  if [ -n "${mariadb114_ver}" ] && ! grep -Fxq "mariadb-${mariadb114_ver}.tar.gz" "${resource_file}"; then
    latest_ver=$(grep -E '^mariadb-11\.4\.[0-9]+\.tar\.gz$' "${resource_file}" | sed -E 's/^mariadb-(11\.4\.[0-9]+)\.tar\.gz$/\1/' | sort -V | tail -1)
    if [ -n "${latest_ver}" ]; then
      old_ver=${mariadb114_ver}
      mariadb114_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide mariadb-${old_ver}.tar.gz, auto-adjust mariadb114_ver=${mariadb114_ver}${CEND}"
    fi
  fi

  if ! grep -Fxq "icu4c-${icu4c_ver}-src.tgz" "${resource_file}"; then
    latest_ver=$(grep -E '^icu4c-[0-9_]+-src\.tgz$' "${resource_file}" | sed -E 's/^icu4c-([0-9_]+)-src\.tgz$/\1/' | awk -F_ '{printf "%06d.%06d %s\n", $1, $2, $0}' | sort | tail -1 | awk '{print $2}')
    if [ -n "${latest_ver}" ]; then
      old_ver=${icu4c_ver}
      icu4c_ver=${latest_ver}
      let "adjusted_count++"
      echo "${CWARNING}Mirror does not provide icu4c-${old_ver}-src.tgz, auto-adjust icu4c_ver=${icu4c_ver}${CEND}"
    fi
  fi

  if [ "${adjusted_count}" -gt 0 ]; then
    echo "${CMSG}Adjusted ${adjusted_count} critical version variables using mirror resource index.${CEND}"
  fi
}

Sync_versions_from_mirror() {
  local suggest_file
  local meta_file
  local resource_file
  local sync_count=0
  local key=""
  local value=""
  local raw_line=""
  local -a suggest_urls=()
  local -a checked_urls=()
  local suggest_url=""
  local meta_url=""
  local resource_url=""
  local already_checked=""
  local effective_suggest_url=""
  local effective_meta_url=""
  local effective_resource_url=""
  local seen_keys="|"
  local got_suggest=n
  local got_meta=n
  local got_resource=n

  suggest_file=$(mktemp /tmp/oneinstack_suggest_versions.XXXXXX)
  meta_file=$(mktemp /tmp/oneinstack_latest_meta_versions.XXXXXX)
  resource_file=$(mktemp /tmp/oneinstack_resource_files.XXXXXX)
  [ ! -f "${suggest_file}" ] && return 0
  [ ! -f "${meta_file}" ] && {
    rm -f "${suggest_file}"
    return 0
  }
  [ ! -f "${resource_file}" ] && {
    rm -f "${suggest_file}" "${meta_file}"
    return 0
  }

  while IFS= read -r suggest_url; do
    [ -z "${suggest_url}" ] && continue
    suggest_urls+=("${suggest_url}")
  done < <(Get_configured_mirror_bases)

  for suggest_url in "${suggest_urls[@]}"; do
    already_checked=n
    for effective_url in "${checked_urls[@]}"; do
      [ "${effective_url}" = "${suggest_url}" ] && already_checked=y && break
    done
    [ "${already_checked}" = 'y' ] && continue
    checked_urls+=("${suggest_url}")

    if [ "${got_suggest}" = 'n' ]; then
      if Fetch_version_suggestions "${suggest_file}" "${suggest_url}/suggest_versions.txt"; then
        got_suggest=y
        effective_suggest_url="${suggest_url}/suggest_versions.txt"
      fi
    fi

    if [ "${got_meta}" = 'n' ]; then
      if Fetch_latest_meta_versions "${meta_file}" "${suggest_url}/latest_meta.json"; then
        got_meta=y
        effective_meta_url="${suggest_url}/latest_meta.json"
      fi
    fi

    if [ "${got_resource}" = 'n' ]; then
      if Fetch_resource_file_index "${resource_file}" "${suggest_url}/resource.json"; then
        got_resource=y
        effective_resource_url="${suggest_url}/resource.json"
      fi
    fi

    if [ "${got_suggest}" = 'y' ] && [ "${got_meta}" = 'y' ] && [ "${got_resource}" = 'y' ]; then
      break
    fi
  done

  if [ "${got_suggest}" = 'n' ] && [ "${got_meta}" = 'n' ]; then
    rm -f "${suggest_file}" "${meta_file}" "${resource_file}"
    echo "${CWARNING}No version suggestions available from mirror source, continue with local versions.txt.${CEND}"
    return 0
  fi

  for effective_url in "${suggest_file}" "${meta_file}"; do
    [ ! -s "${effective_url}" ] && continue
    while IFS= read -r raw_line || [ -n "${raw_line}" ]; do
      [ -z "${raw_line}" ] && continue
      [[ "${raw_line}" =~ ^[[:space:]]*# ]] && continue
      key=${raw_line%%=*}
      value=${raw_line#*=}
      key=${key//[[:space:]]/}
      value=$(echo "${value}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [[ ! "${key}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && continue
      [[ ! "${value}" =~ ^[0-9A-Za-z._+-]+$ ]] && continue
      Is_php_related_version_key "${key}" || continue
      [[ "${seen_keys}" == *"|${key}|"* ]] && continue
      if [ "${key}" = 'icu4c_ver' ] && [[ "${value}" == release-* ]]; then
        value=${value#release-}
        value=${value//./_}
      fi
      eval "${key}='${value}'"
      seen_keys="${seen_keys}${key}|"
      let "sync_count++"
    done < "${effective_url}"
  done

  if [ -n "${libsodium_ver}" ] && [ -z "${libsodium_up_ver}" ]; then
    libsodium_up_ver=${libsodium_ver}
  fi

  Ensure_mirror_compatible_core_versions "${resource_file}"

  rm -f "${suggest_file}" "${meta_file}" "${resource_file}"

  [ "${sync_count}" -gt 0 ] && echo "${CMSG}Synced ${sync_count} stack version variables from mirror source: ${effective_suggest_url:-${effective_meta_url}}${CEND}"
  [ "${got_meta}" = 'y' ] && echo "${CMSG}Loaded version metadata from: ${effective_meta_url}${CEND}"
  [ "${got_resource}" = 'y' ] && echo "${CMSG}Loaded resource index from: ${effective_resource_url}${CEND}"
}
