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

. ../options.conf
. ../include/check_dir.sh

DBname=$1
LogFile=${backup_dir}/db.log
DumpFile=${backup_dir}/DB_${DBname}_$(date +%Y%m%d_%H%M%S).sql
NewFile=${backup_dir}/DB_${DBname}_$(date +%Y%m%d_%H%M%S).tgz
OldFile=${backup_dir}/DB_${DBname}_$(date +%Y%m%d --date="${expired_days} days ago")*.tgz

[ ! -e "${backup_dir}" ] && mkdir -p ${backup_dir}

MYSQL_BIN="${db_install_dir}/bin/mysql"
[ -x "${db_install_dir}/bin/mariadb" ] && MYSQL_BIN="${db_install_dir}/bin/mariadb"

DUMP_BIN="${db_install_dir}/bin/mysqldump"
[ -x "${db_install_dir}/bin/mariadb-dump" ] && DUMP_BIN="${db_install_dir}/bin/mariadb-dump"

DB_tmp=`${MYSQL_BIN} -uroot -p${dbrootpwd} -e "show databases\G" 2>/dev/null | grep ${DBname}`
[ -z "${DB_tmp}" ] && { echo "Database [${DBname}] does not exist!" | tee -a ${LogFile} >&2 ; exit 1 ; }

if [ -n "`ls ${OldFile} 2>/dev/null`" ]; then
  rm -f ${OldFile}
  echo "[${OldFile}] Delete Old File Success" >> ${LogFile}
else
  echo "[${OldFile}] Delete Old Backup File" >> ${LogFile}
fi

if [ -e "${NewFile}" ]; then
  echo "[${NewFile}] The Backup File is exists, Can't Backup" >> ${LogFile}
else
  ${DUMP_BIN} -uroot -p${dbrootpwd} --databases ${DBname} > ${DumpFile}
  pushd ${backup_dir} > /dev/null
  tar czf ${NewFile} ${DumpFile##*/} >> ${LogFile} 2>&1
  echo "[${NewFile}] Backup success ">> ${LogFile}
  rm -f ${DumpFile}
  popd > /dev/null
fi
