#!/bin/bash
# Author:  Alpha Eva <kaneawk AT gmail.com>
#
# Notes: QILNMP for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

Ensure_perl_ipc_cmd() {
  local missing_modules=""
  perl -MIPC::Cmd -e1 >/dev/null 2>&1 || missing_modules="${missing_modules} IPC::Cmd"
  perl -MTime::Piece -e1 >/dev/null 2>&1 || missing_modules="${missing_modules} Time::Piece"
  [ -z "${missing_modules}" ] && return 0

  echo "${CWARNING}Perl modules missing (${missing_modules}), trying to install...${CEND}"
  if [ "${PM}" == 'apt-get' ]; then
    apt-get --no-install-recommends -y install libipc-cmd-perl libtime-piece-perl >/dev/null 2>&1 || \
    apt-get --no-install-recommends -y install perl-modules >/dev/null 2>&1 || \
    apt-get --no-install-recommends -y install perl >/dev/null 2>&1
  else
    yum -y install perl-IPC-Cmd perl-Time-Piece >/dev/null 2>&1 || \
    yum -y install 'perl(IPC::Cmd)' 'perl(Time::Piece)' >/dev/null 2>&1 || \
    yum -y install perl >/dev/null 2>&1
  fi

  missing_modules=""
  perl -MIPC::Cmd -e1 >/dev/null 2>&1 || missing_modules="${missing_modules} IPC::Cmd"
  perl -MTime::Piece -e1 >/dev/null 2>&1 || missing_modules="${missing_modules} Time::Piece"
  [ -z "${missing_modules}" ] || {
    echo "${CFAILURE}Required Perl modules for OpenSSL/Nginx build are still missing:${missing_modules}. Please install them manually and retry.${CEND}"
    kill -9 $$; exit 1;
  }
}

Install_apt_pkg_with_fallback() {
  local pkg_spec=$1
  local candidate=""
  local selected=""
  local old_ifs="$IFS"

  IFS='|'
  for candidate in ${pkg_spec}; do
    candidate=$(echo "${candidate}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "${candidate}" ] && continue
    if apt-cache show "${candidate}" >/dev/null 2>&1; then
      selected="${candidate}"
      break
    fi
  done
  IFS="${old_ifs}"

  if [ -z "${selected}" ]; then
    echo "${CWARNING}Skip unavailable apt package candidates: ${pkg_spec}${CEND}"
    return 1
  fi

  apt-get --no-install-recommends -y install "${selected}" >/dev/null 2>&1 || {
    echo "${CWARNING}Install apt package failed: ${selected}${CEND}"
    return 1
  }
  return 0
}

Run_apt_security_upgrade() {
  local security_list=/tmp/security.sources.list
  : > "${security_list}"

  if [ -f /etc/apt/sources.list ] && grep -q "security" /etc/apt/sources.list 2>/dev/null; then
    grep "security" /etc/apt/sources.list > "${security_list}" 2>/dev/null
    if [ -s "${security_list}" ]; then
      apt-get -y upgrade -o Dir::Etc::SourceList="${security_list}"
      return
    fi
  fi

  # Ubuntu 24+ commonly uses deb822 source files (*.sources).
  apt-get -y upgrade
}

installDepsDebian() {
  echo "${CMSG}Removing the conflicting packages...${CEND}"
  if [ "${apache_flag}" == 'y' ]; then
    killall apache2
    pkgList="apache2 apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  if [[ "${db_option}" =~ ^[1-9]$|^1[0-2]$|^15$ ]]; then
    pkgList="mysql-client mysql-server mysql-common mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  apt-get -y update
  apt-get -y autoremove
  apt-get -yf install
  export DEBIAN_FRONTEND=noninteractive

  # critical security updates
  Run_apt_security_upgrade

  # Install needed packages
  local pkgList=""
  case "${Debian_ver}" in
    9|10|11|12)
      pkgList="debian-keyring debian-archive-keyring build-essential pkg-config gcc g++ make cmake autoconf libjpeg-dev|libjpeg62-turbo-dev|libjpeg8-dev libpng-dev libgd-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libc-client2007e-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses6|libncurses5 libncurses-dev|libncurses5-dev libaio1|libaio1t64 libaio-dev|libaio-devt64 numactl libreadline-dev curl libcurl4-openssl-dev|libcurl4-gnutls-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn2-0|libidn11 libidn2-dev|libidn11-dev openssl net-tools libssl-dev libtool libevent-dev bison re2c libsasl2-dev libxslt1-dev libicu-dev libargon2-1|libargon2-0 libargon2-dev libsodium23|libsodium24 libsodium-dev locales patch vim zip unzip tmux htop bc dc expect libexpat1-dev libonig-dev libtirpc-dev rsync git lsof lrzsz rsyslog cron logrotate chrony libsqlite3-dev psmisc wget ca-certificates software-properties-common gnupg ufw python3 xz-utils libperl-dev|perl libipc-cmd-perl|perl-modules|perl"
      ;;
    *)
      echo "${CFAILURE}Your system Debian ${Debian_ver} are not supported!${CEND}"
      kill -9 $$; exit 1;
      ;;
  esac
  for Package in ${pkgList}; do
    Install_apt_pkg_with_fallback "${Package}"
  done
  Ensure_perl_ipc_cmd
}

installDepsRHEL() {
  [ -e '/etc/yum.conf' ] && sed -i 's@^exclude@#exclude@' /etc/yum.conf
  if [ "${RHEL_ver}" == '9' ]; then
    [ -z "`grep -w epel /etc/yum.repos.d/*.repo`" ] && yum -y install epel-release
    if [[ "${Platform}" =~ "rhel" ]]; then
      subscription-manager repos --enable codeready-builder-for-rhel-9-${ARCH}-rpms
      dnf -y install chrony oniguruma-devel rpcgen
    elif [[ "${Platform}" =~ "ol" ]]; then
      dnf config-manager --set-enabled ol9_codeready_builder
      dnf -y install chrony oniguruma-devel rpcgen
    else
      dnf -y --enablerepo=crb install chrony oniguruma-devel rpcgen
    fi
    systemctl enable chronyd
  elif [ "${RHEL_ver}" == '8' ]; then
    if [[ "${Platform}" =~ "rhel" ]]; then
      subscription-manager repos --enable codeready-builder-for-rhel-8-${ARCH}-rpms
      dnf -y install chrony oniguruma-devel rpcgen
    elif [[ "${Platform}" =~ "ol" ]]; then
      dnf config-manager --set-enabled ol8_codeready_builder
      dnf -y install chrony oniguruma-devel rpcgen
    else
      [ -z "`grep -w epel /etc/yum.repos.d/*.repo`" ] && yum -y install epel-release
      if grep -qw "^\[PowerTools\]" /etc/yum.repos.d/*.repo; then
        dnf -y --enablerepo=PowerTools install chrony oniguruma-devel rpcgen
      elif grep -qw "^\[powertools\]" /etc/yum.repos.d/*.repo; then
        dnf -y --enablerepo=powertools install chrony oniguruma-devel rpcgen
      fi
    fi
    systemctl enable chronyd
  elif [ "${RHEL_ver}" == '7' ]; then
    [ -z "`grep -w epel /etc/yum.repos.d/*.repo`" ] && yum -y install epel-release
    yum -y groupremove "Basic Web Server" "MySQL Database server" "MySQL Database client"
  fi

  if [ "${RHEL_ver}" == '9' ]; then
    [ ! -e "/usr/lib64/libtinfo.so.5" ] && ln -s /usr/lib64/libtinfo.so.6 /usr/lib64/libtinfo.so.5
    [ ! -e "/usr/lib64/libncurses.so.5" ] && ln -s /usr/lib64/libncurses.so.6 /usr/lib64/libncurses.so.5
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  # Install needed packages
  pkgList="perl-FindBin perl-IPC-Cmd python3 deltarpm drpm gcc gcc-c++ make cmake autoconf libjpeg libjpeg-devel libjpeg-turbo libjpeg-turbo-devel libpng libpng-devel libxml2 libxml2-devel zlib zlib-devel libzip libzip-devel argon2 argon2-devel libsodium libsodium-devel glibc glibc-devel krb5-devel libc-client libc-client-devel glib2 glib2-devel bzip2 bzip2-devel ncurses ncurses-devel ncurses-compat-libs libaio numactl numactl-libs readline-devel curl curl-devel e2fsprogs e2fsprogs-devel krb5-devel libidn libidn-devel openssl openssl-devel net-tools libxslt-devel libicu-devel libevent-devel libtool libtool-ltdl bison gd-devel vim-enhanced pcre-devel libmcrypt libmcrypt-devel mhash mhash-devel mcrypt zip unzip xz chrony oniguruma-devel rpcgen sqlite-devel sysstat patch bc expect expat-devel perl-devel oniguruma oniguruma-devel libtirpc-devel nss libnsl rsync rsyslog git lsof lrzsz psmisc wget which libatomic tmux chkconfig firewalld"
  for Package in ${pkgList}; do
    yum -y install ${Package}
  done
  [ ${RHEL_ver} -lt 8 >/dev/null 2>&1 ] && yum -y install cmake3

  yum -y update bash openssl glibc
  Ensure_perl_ipc_cmd
}

installDepsUbuntu() {
  # Uninstall the conflicting software
  echo "${CMSG}Removing the conflicting packages...${CEND}"
  if [ "${apache_flag}" == 'y' ]; then
    killall apache2
    pkgList="apache2 apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  if [[ "${db_option}" =~ ^[1-9]$|^1[0-2]$|^15$ ]]; then
    pkgList="mysql-client mysql-server mysql-common mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  apt-get -y update
  apt-get -y autoremove
  apt-get -yf install
  export DEBIAN_FRONTEND=noninteractive
  [[ "${Ubuntu_ver}" =~ ^22$ ]] && apt-get -y --allow-downgrades install libicu70=70.1-2 libglib2.0-0=2.72.1-1 libxml2-dev

  # critical security updates
  Run_apt_security_upgrade

  # Install needed packages
  pkgList="libperl-dev|perl debian-keyring debian-archive-keyring build-essential pkg-config gcc g++ make cmake autoconf libjpeg-dev|libjpeg62-turbo-dev|libjpeg8-dev libpng-dev libgd-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libc-client2007e-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses6|libncurses5 libncurses-dev|libncurses5-dev libaio1|libaio1t64 libaio-dev|libaio-devt64 numactl libreadline-dev curl libcurl4-openssl-dev|libcurl4-gnutls-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn2-0|libidn11 libidn2-dev|libidn11-dev openssl net-tools libssl-dev libtool libevent-dev re2c libsasl2-dev libxslt1-dev libicu-dev libargon2-1|libargon2-0 libargon2-dev libsodium23|libsodium24 libsodium-dev libsqlite3-dev bison patch vim zip unzip tmux htop bc dc expect libexpat1-dev rsyslog libonig-dev libtirpc-dev libnss3 rsync git lsof lrzsz chrony psmisc wget ca-certificates software-properties-common gnupg ufw python3 xz-utils libipc-cmd-perl|perl-modules|perl"
  export DEBIAN_FRONTEND=noninteractive
  for Package in ${pkgList}; do
    Install_apt_pkg_with_fallback "${Package}"
  done
  Ensure_perl_ipc_cmd
}

installDepsBySrc() {
  pushd ${oneinstack_dir}/src > /dev/null
  if ! command -v icu-config > /dev/null 2>&1 || icu-config --version | grep '^3.' || [ "${Ubuntu_ver}" == "20" ]; then
    tar xzf icu4c-${icu4c_ver}-src.tgz
    pushd icu/source > /dev/null
    ./configure --prefix=/usr/local
    make -j ${THREAD} && make install
    popd > /dev/null
    rm -rf icu
  fi

  if command -v lsof >/dev/null 2>&1; then
    echo 'already initialize' > ~/.oneinstack
  else
    echo "${CFAILURE}${PM} config error parsing file failed${CEND}"
    kill -9 $$; exit 1;
  fi

  popd > /dev/null
}
