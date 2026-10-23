#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
# Notes: QILNMP for Rocky/Alma/RHEL 8+ Debian 11+ and Ubuntu 20+ (64-bit)
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

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

oneinstack_dir=$(dirname "`readlink -f $0`")
pushd ${oneinstack_dir}/tools > /dev/null
[ -d "${oneinstack_dir}/tools" ] && chmod +x ${oneinstack_dir}/*.sh ${oneinstack_dir}/tools/*.sh ${oneinstack_dir}/tools/*.exp > /dev/null 2>&1
. ../options.conf
. ../include/color.sh
[ ! -e "${backup_dir}" ] && mkdir -p ${backup_dir}

DB_Local_BK() {
  for D in `echo ${db_name} | tr ',' ' '`
  do
    bash ./db_bk.sh ${D}
  done
}

DB_Remote_BK() {
  for D in `echo ${db_name} | tr ',' ' '`
  do
    bash ./db_bk.sh ${D}
    DB_GREP="DB_${D}_`date +%Y%m%d`"
    DB_FILE=`ls -lrt ${backup_dir} 2>/dev/null | grep ${DB_GREP} | tail -1 | awk '{print $NF}'`
    if [ -n "${DB_FILE}" ] && [ -f "${backup_dir}/${DB_FILE}" ]; then
      echo "file:::${backup_dir}/${DB_FILE} ${backup_dir} push" >> config_backup.txt
      echo "com:::[ -e "${backup_dir}/${DB_FILE}" ] && rm -rf ${backup_dir}/DB_${D}_$(date +%Y%m%d --date="${expired_days} days ago")_*.tgz" >> config_backup.txt
    else
      echo "${CWARNING}Warning: Database ${D} backup file not found in ${backup_dir}, skip remote push.${CEND}"
    fi
  done
}

DB_OSS_BK() {
  for D in `echo ${db_name} | tr ',' ' '`
  do
    bash ./db_bk.sh ${D}
    DB_GREP="DB_${D}_`date +%Y%m%d`"
    DB_FILE=`ls -lrt ${backup_dir} 2>/dev/null | grep ${DB_GREP} | tail -1 | awk '{print $NF}'`
    if [ -n "${DB_FILE}" ] && [ -f "${backup_dir}/${DB_FILE}" ]; then
      ossutil cp -f ${backup_dir}/${DB_FILE} oss://${oss_bucket}/`date +%F`/${DB_FILE}
      if [ $? -eq 0 ]; then
        ossutil rm -rf oss://${oss_bucket}/`date +%F --date="${expired_days} days ago"`/
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${backup_dir}/${DB_FILE}
      fi
    else
      echo "${CWARNING}Warning: Database ${D} backup file not found in ${backup_dir}, skip OSS upload.${CEND}"
    fi
  done
}

DB_COS_BK() {
  for D in `echo ${db_name} | tr ',' ' '`
  do
    bash ./db_bk.sh ${D}
    DB_GREP="DB_${D}_`date +%Y%m%d`"
    DB_FILE=`ls -lrt ${backup_dir} 2>/dev/null | grep ${DB_GREP} | tail -1 | awk '{print $NF}'`
    if [ -n "${DB_FILE}" ] && [ -f "${backup_dir}/${DB_FILE}" ]; then
      coscli sync ${backup_dir}/${DB_FILE} cos://${cos_bucket}/`date +%F`/${DB_FILE}
      if [ $? -eq 0 ]; then
        coscli rm -rf cos://${cos_bucket}/`date +%F --date="${expired_days} days ago"` > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${backup_dir}/${DB_FILE}
      fi
    else
      echo "${CWARNING}Warning: Database ${D} backup file not found in ${backup_dir}, skip COS upload.${CEND}"
    fi
  done
}

DB_UPYUN_BK() {
  for D in `echo ${db_name} | tr ',' ' '`
  do
    bash ./db_bk.sh ${D}
    DB_GREP="DB_${D}_`date +%Y%m%d`"
    DB_FILE=`ls -lrt ${backup_dir} 2>/dev/null | grep ${DB_GREP} | tail -1 | awk '{print $NF}'`
    if [ -n "${DB_FILE}" ] && [ -f "${backup_dir}/${DB_FILE}" ]; then
      upx put ${backup_dir}/${DB_FILE} /`date +%F`/${DB_FILE}
      if [ $? -eq 0 ]; then
        upx rm -a `date +%F --date="${expired_days} days ago"` > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${backup_dir}/${DB_FILE}
      fi
    else
      echo "${CWARNING}Warning: Database ${D} backup file not found in ${backup_dir}, skip UPYUN upload.${CEND}"
    fi
  done
}

DB_QINIU_BK() {
  for D in `echo ${db_name} | tr ',' ' '`
  do
    bash ./db_bk.sh ${D}
    DB_GREP="DB_${D}_`date +%Y%m%d`"
    DB_FILE=`ls -lrt ${backup_dir} 2>/dev/null | grep ${DB_GREP} | tail -1 | awk '{print $NF}'`
    if [ -n "${DB_FILE}" ] && [ -f "${backup_dir}/${DB_FILE}" ]; then
      qshell rput ${qiniu_bucket} /`date +%F`/${DB_FILE} ${backup_dir}/${DB_FILE}
      if [ $? -eq 0 ]; then
        qshell listbucket ${qiniu_bucket} /`date +%F --date="${expired_days} days ago"` /tmp/qiniu.txt > /dev/null 2>&1
        qshell batchdelete -force ${qiniu_bucket} /tmp/qiniu.txt > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${backup_dir}/${DB_FILE}
        rm -f /tmp/qiniu.txt
      fi
    else
      echo "${CWARNING}Warning: Database ${D} backup file not found in ${backup_dir}, skip QINIU upload.${CEND}"
    fi
  done
}

DB_S3_BK() {
  for D in `echo ${db_name} | tr ',' ' '`
  do
    bash ./db_bk.sh ${D}
    DB_GREP="DB_${D}_`date +%Y%m%d`"
    DB_FILE=`ls -lrt ${backup_dir} 2>/dev/null | grep ${DB_GREP} | tail -1 | awk '{print $NF}'`
    if [ -n "${DB_FILE}" ] && [ -f "${backup_dir}/${DB_FILE}" ]; then
      aws s3 sync ${backup_dir}/${DB_FILE} s3://${s3_bucket}/`date +%F`/${DB_FILE}
      if [ $? -eq 0 ]; then
        aws s3 rm -r s3://${s3_bucket}/`date +%F --date="${expired_days} days ago"` > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${backup_dir}/${DB_FILE}
      fi
    else
      echo "${CWARNING}Warning: Database ${D} backup file not found in ${backup_dir}, skip S3 upload.${CEND}"
    fi
  done
}

DB_DROPBOX_BK() {
  for D in `echo ${db_name} | tr ',' ' '`
  do
    bash ./db_bk.sh ${D}
    DB_GREP="DB_${D}_`date +%Y%m%d`"
    DB_FILE=`ls -lrt ${backup_dir} 2>/dev/null | grep ${DB_GREP} | tail -1 | awk '{print $NF}'`
    if [ -n "${DB_FILE}" ] && [ -f "${backup_dir}/${DB_FILE}" ]; then
      dbxcli put ${backup_dir}/${DB_FILE} `date +%F`/${DB_FILE}
      if [ $? -eq 0 ]; then
        dbxcli rm -f `date +%F --date="${expired_days} days ago"` > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${backup_dir}/${DB_FILE}
      fi
    else
      echo "${CWARNING}Warning: Database ${D} backup file not found in ${backup_dir}, skip Dropbox upload.${CEND}"
    fi
  done
}

WEB_LOCAL_BK() {
  for W in `echo ${website_name} | tr ',' ' '`
  do
    bash ./website_bk.sh $W
  done
}

WEB_Remote_BK() {
  for W in `echo ${website_name} | tr ',' ' '`
  do
    [ ! -e "${wwwroot_dir}/$W" ] && { echo "[${wwwroot_dir}/$W] not exist"; continue; }
    if [ `du -sm "${wwwroot_dir}/$W" | awk '{print $1}'` -lt 2048 ]; then
      bash ./website_bk.sh $W
      Web_GREP="Web_${W}_`date +%Y%m%d`"
      Web_FILE=`ls -lrt ${backup_dir} 2>/dev/null | grep ${Web_GREP} | tail -1 | awk '{print $NF}'`
      if [ -n "${Web_FILE}" ] && [ -f "${backup_dir}/${Web_FILE}" ]; then
        echo "file:::${backup_dir}/${Web_FILE} ${backup_dir} push" >> config_backup.txt
        echo "com:::[ -e "${backup_dir}/${Web_FILE}" ] && rm -rf ${backup_dir}/Web_${W}_$(date +%Y%m%d --date="${expired_days} days ago")_*.tgz" >> config_backup.txt
      else
        echo "${CWARNING}Warning: Website $W backup file not found in ${backup_dir}, skip remote push.${CEND}"
      fi
    else
      echo "file:::${wwwroot_dir}/$W ${backup_dir} push" >> config_backup.txt
    fi
  done
}

WEB_OSS_BK() {
  for W in `echo ${website_name} | tr ',' ' '`
  do
    [ ! -e "${wwwroot_dir}/$W" ] && { echo "[${wwwroot_dir}/$W] not exist"; continue; }
    PUSH_FILE="${backup_dir}/Web_${W}_$(date +%Y%m%d_%H).tgz"
    if [ ! -e "${PUSH_FILE}" ]; then
      pushd ${wwwroot_dir} > /dev/null
      tar czf ${PUSH_FILE} ./$W
      popd > /dev/null
    fi
    if [ -f "${PUSH_FILE}" ]; then
      ossutil cp -f ${PUSH_FILE} oss://${oss_bucket}/`date +%F`/${PUSH_FILE##*/}
      if [ $? -eq 0 ]; then
        ossutil rm -rf oss://${oss_bucket}/`date +%F --date="${expired_days} days ago"`/
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${PUSH_FILE}
      fi
    else
      echo "${CWARNING}Warning: Website $W archive ${PUSH_FILE} not created, skip OSS upload.${CEND}"
    fi
  done
}

WEB_COS_BK() {
  for W in `echo ${website_name} | tr ',' ' '`
  do
    [ ! -e "${wwwroot_dir}/$W" ] && { echo "[${wwwroot_dir}/$W] not exist"; continue; }
    PUSH_FILE="${backup_dir}/Web_${W}_$(date +%Y%m%d_%H).tgz"
    if [ ! -e "${PUSH_FILE}" ]; then
      pushd ${wwwroot_dir} > /dev/null
      tar czf ${PUSH_FILE} ./$W
      popd > /dev/null
    fi
    if [ -f "${PUSH_FILE}" ]; then
      coscli sync ${PUSH_FILE} cos://${cos_bucket}/`date +%F`/${PUSH_FILE##*/}
      if [ $? -eq 0 ]; then
        coscli rm -rf cos://${cos_bucket}/`date +%F --date="${expired_days} days ago"` > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${PUSH_FILE}
      fi
    else
      echo "${CWARNING}Warning: Website $W archive ${PUSH_FILE} not created, skip COS upload.${CEND}"
    fi
  done
}

WEB_UPYUN_BK() {
  for W in `echo ${website_name} | tr ',' ' '`
  do
    [ ! -e "${wwwroot_dir}/$W" ] && { echo "[${wwwroot_dir}/$W] not exist"; continue; }
    [ ! -e "${backup_dir}" ] && mkdir -p ${backup_dir}
    PUSH_FILE="${backup_dir}/Web_${W}_$(date +%Y%m%d_%H).tgz"
    if [ ! -e "${PUSH_FILE}" ]; then
      pushd ${wwwroot_dir} > /dev/null
      tar czf ${PUSH_FILE} ./$W
      popd > /dev/null
    fi
    if [ -f "${PUSH_FILE}" ]; then
      upx put ${PUSH_FILE} /`date +%F`/${PUSH_FILE##*/}
      if [ $? -eq 0 ]; then
        upx rm -a `date +%F --date="${expired_days} days ago"` > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${PUSH_FILE}
      fi
    else
      echo "${CWARNING}Warning: Website $W archive ${PUSH_FILE} not created, skip UPYUN upload.${CEND}"
    fi
  done
}

WEB_QINIU_BK() {
  for W in `echo ${website_name} | tr ',' ' '`
  do
    [ ! -e "${wwwroot_dir}/$W" ] && { echo "[${wwwroot_dir}/$W] not exist"; continue; }
    [ ! -e "${backup_dir}" ] && mkdir -p ${backup_dir}
    PUSH_FILE="${backup_dir}/Web_${W}_$(date +%Y%m%d_%H).tgz"
    if [ ! -e "${PUSH_FILE}" ]; then
      pushd ${wwwroot_dir} > /dev/null
      tar czf ${PUSH_FILE} ./$W
      popd > /dev/null
    fi
    if [ -f "${PUSH_FILE}" ]; then
      qshell rput ${qiniu_bucket} /`date +%F`/${PUSH_FILE##*/} ${PUSH_FILE}
      if [ $? -eq 0 ]; then
        qshell listbucket ${qiniu_bucket} /`date +%F --date="${expired_days} days ago"` /tmp/qiniu.txt > /dev/null 2>&1
        qshell batchdelete -force ${qiniu_bucket} /tmp/qiniu.txt > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${PUSH_FILE}
        rm -f /tmp/qiniu.txt
      fi
    else
      echo "${CWARNING}Warning: Website $W archive ${PUSH_FILE} not created, skip QINIU upload.${CEND}"
    fi
  done
}

WEB_S3_BK() {
  for W in `echo ${website_name} | tr ',' ' '`
  do
    [ ! -e "${wwwroot_dir}/$W" ] && { echo "[${wwwroot_dir}/$W] not exist"; continue; }
    [ ! -e "${backup_dir}" ] && mkdir -p ${backup_dir}
    PUSH_FILE="${backup_dir}/Web_${W}_$(date +%Y%m%d_%H).tgz"
    if [ ! -e "${PUSH_FILE}" ]; then
      pushd ${wwwroot_dir} > /dev/null
      tar czf ${PUSH_FILE} ./$W
      popd > /dev/null
    fi
    if [ -f "${PUSH_FILE}" ]; then
      aws s3 sync ${PUSH_FILE} s3://${s3_bucket}/`date +%F`/${PUSH_FILE##*/}
      if [ $? -eq 0 ]; then
        aws s3 rm -r s3://${s3_bucket}/`date +%F --date="${expired_days} days ago"` > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${PUSH_FILE}
      fi
    else
      echo "${CWARNING}Warning: Website $W archive ${PUSH_FILE} not created, skip S3 upload.${CEND}"
    fi
  done
}

WEB_DROPBOX_BK() {
  for W in `echo ${website_name} | tr ',' ' '`
  do
    [ ! -e "${wwwroot_dir}/$W" ] && { echo "[${wwwroot_dir}/$W] not exist"; continue; }
    [ ! -e "${backup_dir}" ] && mkdir -p ${backup_dir}
    PUSH_FILE="${backup_dir}/Web_${W}_$(date +%Y%m%d_%H).tgz"
    if [ ! -e "${PUSH_FILE}" ]; then
      pushd ${wwwroot_dir} > /dev/null
      tar czf ${PUSH_FILE} ./$W
      popd > /dev/null
    fi
    if [ -f "${PUSH_FILE}" ]; then
      dbxcli put ${PUSH_FILE} `date +%F`/${PUSH_FILE##*/}
      if [ $? -eq 0 ]; then
        dbxcli rm -f `date +%F --date="${expired_days} days ago"` > /dev/null 2>&1
        [ -z "`echo ${backup_destination} | grep -ow 'local'`" ] && rm -f ${PUSH_FILE}
      fi
    else
      echo "${CWARNING}Warning: Website $W archive ${PUSH_FILE} not created, skip Dropbox upload.${CEND}"
    fi
  done
}

for DEST in `echo ${backup_destination} | tr ',' ' '`
do
  if [ "${DEST}" == 'local' ]; then
    [ -n "`echo ${backup_content} | grep -ow db`" ] && DB_Local_BK
    [ -n "`echo ${backup_content} | grep -ow web`" ] && WEB_LOCAL_BK
  fi
  if [ "${DEST}" == 'remote' ]; then
    echo "com:::[ ! -e "${backup_dir}" ] && mkdir -p ${backup_dir}" > config_backup.txt
    [ -n "`echo ${backup_content} | grep -ow db`" ] && DB_Remote_BK
    [ -n "`echo ${backup_content} | grep -ow web`" ] && WEB_Remote_BK
    bash ./mabs.sh -c config_backup.txt -T -1 | tee -a mabs.log
  fi
  if [ "${DEST}" == 'oss' ]; then
    [ -n "`echo ${backup_content} | grep -ow db`" ] && DB_OSS_BK
    [ -n "`echo ${backup_content} | grep -ow web`" ] && WEB_OSS_BK
  fi
  if [ "${DEST}" == 'cos' ]; then
    [ -n "`echo ${backup_content} | grep -ow db`" ] && DB_COS_BK
    [ -n "`echo ${backup_content} | grep -ow web`" ] && WEB_COS_BK
  fi
  if [ "${DEST}" == 'upyun' ]; then
    [ -n "`echo ${backup_content} | grep -ow db`" ] && DB_UPYUN_BK
    [ -n "`echo ${backup_content} | grep -ow web`" ] && WEB_UPYUN_BK
  fi
  if [ "${DEST}" == 'qiniu' ]; then
    [ -n "`echo ${backup_content} | grep -ow db`" ] && DB_QINIU_BK
    [ -n "`echo ${backup_content} | grep -ow web`" ] && WEB_QINIU_BK
  fi
  if [ "${DEST}" == 's3' ]; then
    [ -n "`echo ${backup_content} | grep -ow db`" ] && DB_S3_BK
    [ -n "`echo ${backup_content} | grep -ow web`" ] && WEB_S3_BK
  fi
  if [ "${DEST}" == 'dropbox' ]; then
    [ -n "`echo ${backup_content} | grep -ow db`" ] && DB_DROPBOX_BK
    [ -n "`echo ${backup_content} | grep -ow web`" ] && WEB_DROPBOX_BK
  fi
done
