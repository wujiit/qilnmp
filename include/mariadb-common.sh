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

MariaDB_escape_sql() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\'/\'\'}
  printf '%s' "${value}"
}

MariaDB_detect_client_bin() {
  if [ -x "${mariadb_install_dir}/bin/mariadb" ]; then
    echo "${mariadb_install_dir}/bin/mariadb"
  elif [ -x "${mariadb_install_dir}/bin/mysql" ]; then
    echo "${mariadb_install_dir}/bin/mysql"
  else
    return 1
  fi
}

MariaDB_detect_server_bin() {
  if [ -x "${mariadb_install_dir}/bin/mariadbd" ]; then
    echo "${mariadb_install_dir}/bin/mariadbd"
  elif [ -x "${mariadb_install_dir}/bin/mysqld" ]; then
    echo "${mariadb_install_dir}/bin/mysqld"
  else
    return 1
  fi
}

MariaDB_detect_install_db_bin() {
  local bin_path=""
  for bin_path in \
    "${mariadb_install_dir}/scripts/mariadb-install-db" \
    "${mariadb_install_dir}/scripts/mysql_install_db" \
    "${mariadb_install_dir}/bin/mariadb-install-db" \
    "${mariadb_install_dir}/bin/mysql_install_db"
  do
    [ -x "${bin_path}" ] && {
      echo "${bin_path}"
      return 0
    }
  done
  return 1
}

MariaDB_write_my_cnf() {
  local enable_query_cache=$1
  local query_cache_block=""

  if [ "${enable_query_cache}" == 'y' ]; then
    query_cache_block="query_cache_type = 1
query_cache_size = 8M
query_cache_limit = 2M
"
  fi

  cat > /etc/my.cnf << EOF
[client]
port = 3306
socket = /tmp/mysql.sock
default-character-set = utf8mb4

[mysql]
prompt="MySQL [\\d]> "
no-auto-rehash

[mysqld]
port = 3306
socket = /tmp/mysql.sock

basedir = ${mariadb_install_dir}
datadir = ${mariadb_data_dir}
pid-file = ${mariadb_data_dir}/mysql.pid
user = mysql
bind-address = 0.0.0.0
server-id = 1

init-connect = 'SET NAMES utf8mb4'
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci

skip-name-resolve
#skip-networking
back_log = 300

max_connections = 1000
max_connect_errors = 6000
open_files_limit = 65535
table_open_cache = 128
max_allowed_packet = 500M
binlog_cache_size = 1M
max_heap_table_size = 8M
tmp_table_size = 16M

read_buffer_size = 2M
read_rnd_buffer_size = 8M
sort_buffer_size = 8M
join_buffer_size = 8M
key_buffer_size = 4M

thread_cache_size = 8

${query_cache_block}ft_min_word_len = 4

log_bin = mysql-bin
binlog_format = mixed
expire_logs_days = 7

log_error = ${mariadb_data_dir}/mysql-error.log
slow_query_log = 1
long_query_time = 1
slow_query_log_file = ${mariadb_data_dir}/mysql-slow.log

performance_schema = 0

#lower_case_table_names = 1

skip-external-locking

default_storage_engine = InnoDB
innodb_file_per_table = 1
innodb_open_files = 500
innodb_buffer_pool_size = 64M
innodb_write_io_threads = 4
innodb_read_io_threads = 4
innodb_purge_threads = 1
innodb_flush_log_at_trx_commit = 2
innodb_log_buffer_size = 2M
innodb_log_file_size = 32M
innodb_max_dirty_pages_pct = 90
innodb_lock_wait_timeout = 120

bulk_insert_buffer_size = 8M
myisam_sort_buffer_size = 8M
myisam_max_sort_file_size = 10G

interactive_timeout = 28800
wait_timeout = 28800

[mysqldump]
quick
max_allowed_packet = 500M

[myisamchk]
key_buffer_size = 8M
sort_buffer_size = 8M
read_buffer = 4M
write_buffer = 4M
EOF

  sed -i "s@max_connections.*@max_connections = $((${Mem}/3))@" /etc/my.cnf
  if [ ${Mem} -gt 1500 -a ${Mem} -le 2500 ]; then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 16@' /etc/my.cnf
    [ "${enable_query_cache}" == 'y' ] && sed -i 's@^query_cache_size.*@query_cache_size = 16M@' /etc/my.cnf
    sed -i 's@^myisam_sort_buffer_size.*@myisam_sort_buffer_size = 16M@' /etc/my.cnf
    sed -i 's@^key_buffer_size.*@key_buffer_size = 16M@' /etc/my.cnf
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 128M@' /etc/my.cnf
    sed -i 's@^tmp_table_size.*@tmp_table_size = 32M@' /etc/my.cnf
    sed -i 's@^table_open_cache.*@table_open_cache = 256@' /etc/my.cnf
  elif [ ${Mem} -gt 2500 -a ${Mem} -le 3500 ]; then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 32@' /etc/my.cnf
    [ "${enable_query_cache}" == 'y' ] && sed -i 's@^query_cache_size.*@query_cache_size = 32M@' /etc/my.cnf
    sed -i 's@^myisam_sort_buffer_size.*@myisam_sort_buffer_size = 32M@' /etc/my.cnf
    sed -i 's@^key_buffer_size.*@key_buffer_size = 64M@' /etc/my.cnf
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 512M@' /etc/my.cnf
    sed -i 's@^tmp_table_size.*@tmp_table_size = 64M@' /etc/my.cnf
    sed -i 's@^table_open_cache.*@table_open_cache = 512@' /etc/my.cnf
  elif [ ${Mem} -gt 3500 ]; then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 64@' /etc/my.cnf
    [ "${enable_query_cache}" == 'y' ] && sed -i 's@^query_cache_size.*@query_cache_size = 64M@' /etc/my.cnf
    sed -i 's@^myisam_sort_buffer_size.*@myisam_sort_buffer_size = 64M@' /etc/my.cnf
    sed -i 's@^key_buffer_size.*@key_buffer_size = 256M@' /etc/my.cnf
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 1024M@' /etc/my.cnf
    sed -i 's@^tmp_table_size.*@tmp_table_size = 128M@' /etc/my.cnf
    sed -i 's@^table_open_cache.*@table_open_cache = 1024@' /etc/my.cnf
  fi
}

MariaDB_initialize_datadir() {
  local install_db_bin=""
  local server_bin=""

  install_db_bin=$(MariaDB_detect_install_db_bin 2>/dev/null || true)
  if [ -n "${install_db_bin}" ]; then
    "${install_db_bin}" --user=mysql --basedir=${mariadb_install_dir} --datadir=${mariadb_data_dir} >/dev/null 2>&1 && return 0
    echo "${CWARNING}MariaDB install-db helper failed, trying initialize-insecure fallback...${CEND}"
  fi

  server_bin=$(MariaDB_detect_server_bin 2>/dev/null || true)
  [ -z "${server_bin}" ] && return 1

  "${server_bin}" --initialize-insecure --user=mysql --basedir=${mariadb_install_dir} --datadir=${mariadb_data_dir} >/dev/null 2>&1
}

MariaDB_secure_installation() {
  local mariadb_client_bin=""
  local sql_root_pwd=""

  mariadb_client_bin=$(MariaDB_detect_client_bin) || {
    echo "${CFAILURE}MariaDB client binary not found after install.${CEND}"
    kill -9 $$; exit 1;
  }
  sql_root_pwd=$(MariaDB_escape_sql "${dbrootpwd}")

  "${mariadb_client_bin}" --protocol=socket --socket=/tmp/mysql.sock -uroot <<EOF
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '${sql_root_pwd}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${sql_root_pwd}';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE User='' OR Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
RESET MASTER;
EOF
}

Install_MariaDB_Generic() {
  local mariadb_version=$1
  local enable_query_cache=$2
  local boostVersion2=""
  local mariadb_build_thread=""
  local archive_root=""

  [ -z "${mariadb_version}" ] && {
    echo "${CFAILURE}MariaDB version is required for Install_MariaDB_Generic.${CEND}"
    kill -9 $$; exit 1;
  }

  pushd ${oneinstack_dir}/src > /dev/null
  id -u mysql >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -M -s /sbin/nologin mysql

  [ ! -d "${mariadb_install_dir}" ] && mkdir -p ${mariadb_install_dir}
  mkdir -p ${mariadb_data_dir}; chown mysql:mysql -R ${mariadb_data_dir}

  if [ "${dbinstallmethod}" == "1" ]; then
    archive_root=$(tar tzf mariadb-${mariadb_version}-linux-systemd-x86_64.tar.gz 2>/dev/null | head -1 | cut -d/ -f1)
    [ -z "${archive_root}" ] && archive_root="mariadb-${mariadb_version}-linux-systemd-x86_64"
    tar zxf mariadb-${mariadb_version}-linux-systemd-x86_64.tar.gz
    [ -d "${archive_root}" ] || archive_root=$(find . -maxdepth 1 -type d -name "mariadb-${mariadb_version}*" | head -1)
    [ -z "${archive_root}" ] && {
      echo "${CFAILURE}Extract MariaDB binary package failed, archive root not found.${CEND}"
      kill -9 $$; exit 1;
    }
    mv ${archive_root}/* ${mariadb_install_dir}
    [ -f "${mariadb_install_dir}/bin/mysqld_safe" ] && {
      sed -i 's@executing mysqld_safe@executing mysqld_safe\nexport LD_PRELOAD=/usr/local/lib/libjemalloc.so@' ${mariadb_install_dir}/bin/mysqld_safe
      sed -i "s@/usr/local/mysql@${mariadb_install_dir}@g" ${mariadb_install_dir}/bin/mysqld_safe
    }
  elif [ "${dbinstallmethod}" == "2" ]; then
    boostVersion2=$(echo ${boost_oldver} | awk -F. '{print $1"_"$2"_"$3}')
    tar xzf boost_${boostVersion2}.tar.gz
    tar xzf mariadb-${mariadb_version}.tar.gz
    pushd mariadb-${mariadb_version} > /dev/null
    mariadb_build_thread=${DB_THREAD:-${THREAD}}
    [ -z "${mariadb_build_thread}" ] && mariadb_build_thread=1
    cmake . -DCMAKE_INSTALL_PREFIX=${mariadb_install_dir} \
    -DMYSQL_DATADIR=${mariadb_data_dir} \
    -DDOWNLOAD_BOOST=1 \
    -DWITH_BOOST=../boost_${boostVersion2} \
    -DSYSCONFDIR=/etc \
    -DWITH_INNOBASE_STORAGE_ENGINE=1 \
    -DWITH_PARTITION_STORAGE_ENGINE=1 \
    -DWITH_FEDERATED_STORAGE_ENGINE=1 \
    -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
    -DWITH_MYISAM_STORAGE_ENGINE=1 \
    -DENABLE_DTRACE=0 \
    -DENABLED_LOCAL_INFILE=1 \
    -DDEFAULT_CHARSET=utf8mb4 \
    -DDEFAULT_COLLATION=utf8mb4_general_ci \
    -DEXTRA_CHARSETS=all \
    -DCMAKE_EXE_LINKER_FLAGS='-ljemalloc'
    make -j ${mariadb_build_thread} || {
      if [ ${mariadb_build_thread} -gt 1 ]; then
        echo "${CWARNING}MariaDB compile failed with -j${mariadb_build_thread}, retrying with -j1...${CEND}"
        make -j 1 || {
          echo "${CFAILURE}MariaDB compile failed with -j1.${CEND}"
          kill -9 $$; exit 1;
        }
      else
        echo "${CFAILURE}MariaDB compile failed.${CEND}"
        kill -9 $$; exit 1;
      fi
    }
    make install
    popd > /dev/null
  fi

  if [ -d "${mariadb_install_dir}/support-files" ]; then
    sed -i "s+^dbrootpwd.*+dbrootpwd='${dbrootpwd}'+" ../options.conf
    echo "${CSUCCESS}MariaDB installed successfully! ${CEND}"
    if [ "${dbinstallmethod}" == "1" ]; then
      [ -n "${archive_root}" ] && rm -rf "${archive_root}"
    else
      rm -rf mariadb-${mariadb_version} boost_${boostVersion2}
    fi
  else
    rm -rf ${mariadb_install_dir}
    echo "${CFAILURE}MariaDB install failed, Please contact the author! ${CEND}" && grep -Ew 'NAME|ID|ID_LIKE|VERSION_ID|PRETTY_NAME' /etc/os-release
    kill -9 $$; exit 1;
  fi

  [ ! -f "${mariadb_install_dir}/support-files/mysql.server" ] && {
    echo "${CFAILURE}MariaDB init script support-files/mysql.server not found.${CEND}"
    kill -9 $$; exit 1;
  }

  /bin/cp ${mariadb_install_dir}/support-files/mysql.server /etc/init.d/mysqld
  sed -i "s@^basedir=.*@basedir=${mariadb_install_dir}@" /etc/init.d/mysqld
  sed -i "s@^datadir=.*@datadir=${mariadb_data_dir}@" /etc/init.d/mysqld
  chmod +x /etc/init.d/mysqld
  [ "${PM}" == 'yum' ] && { chkconfig --add mysqld; chkconfig mysqld on; }
  [ "${PM}" == 'apt-get' ] && update-rc.d mysqld defaults
  popd > /dev/null

  MariaDB_write_my_cnf "${enable_query_cache}"
  MariaDB_initialize_datadir || {
    echo "${CFAILURE}MariaDB data directory initialization failed.${CEND}"
    kill -9 $$; exit 1;
  }

  [ "${Wsl}" == true ] && chmod 600 /etc/my.cnf
  chown mysql:mysql -R ${mariadb_data_dir}
  [ -d "/etc/mysql" ] && /bin/mv /etc/mysql{,_bk}
  service mysqld start
  [ -z "$(grep ^'export PATH=' /etc/profile)" ] && echo "export PATH=${mariadb_install_dir}/bin:\$PATH" >> /etc/profile
  [ -n "$(grep ^'export PATH=' /etc/profile)" -a -z "$(grep ${mariadb_install_dir} /etc/profile)" ] && sed -i "s@^export PATH=\(.*\)@export PATH=${mariadb_install_dir}/bin:\1@" /etc/profile
  . /etc/profile

  MariaDB_secure_installation
  rm -rf /etc/ld.so.conf.d/{mysql,mariadb,percona}*.conf
  echo "${mariadb_install_dir}/lib" > /etc/ld.so.conf.d/z-mariadb.conf
  ldconfig
  service mysqld stop
}
