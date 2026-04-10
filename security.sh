#!/bin/bash
# Author:  summer <iticu@qq.com>
# Notes:  QILNMP basic security module for Nginx + Fail2ban

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
clear
printf "
#######################################################################
#       QILNMP Basic Security for Nginx + Fail2ban                 #
#      For more information please visit https://qiling.jingxialai.com #
#######################################################################
"

[ "$(id -u)" != '0' ] && { echo "Error: You must be root to run this script"; exit 1; }

oneinstack_dir=$(dirname "`readlink -f $0`")
pushd ${oneinstack_dir} > /dev/null

. ./versions.txt
. ./options.conf
. ./include/color.sh
QILNMP_SKIP_GCC_BOOTSTRAP=1
. ./include/check_os.sh
unset QILNMP_SKIP_GCC_BOOTSTRAP
. ./include/download.sh
. ./include/check_dir.sh
. ./include/fail2ban.sh
. ./include/nginx_security.sh

Show_Help() {
  echo
  echo "Usage: $0 command ...
  --help, -h          Show this help message
  --install           Install and enable the security module
  --enable            Enable the security module
  --disable           Disable the security module but keep configs
  --status            Show current security status
  --uninstall         Remove the security module
  "
}

ARG_NUM=$#
TEMP=`getopt -o h --long help,install,enable,disable,status,uninstall -- "$@" 2>/dev/null`
[ $? != 0 ] && echo "${CWARNING}ERROR: unknown argument! ${CEND}" && Show_Help && exit 1
eval set -- "${TEMP}"

while :; do
  [ -z "$1" ] && break
  case "$1" in
    -h|--help)
      Show_Help
      exit 0
      ;;
    --install)
      security_action=install
      shift 1
      ;;
    --enable)
      security_action=enable
      shift 1
      ;;
    --disable)
      security_action=disable
      shift 1
      ;;
    --status)
      security_action=status
      shift 1
      ;;
    --uninstall)
      security_action=uninstall
      shift 1
      ;;
    --)
      shift
      ;;
    *)
      echo "${CWARNING}ERROR: unknown argument! ${CEND}"
      Show_Help
      exit 1
      ;;
  esac
done

[ -z "${security_action}" ] && {
  Show_Help
  exit 1
}

case "${security_action}" in
  install)
    QILNMP_security_enable
    ;;
  enable)
    QILNMP_security_enable
    ;;
  disable)
    QILNMP_security_disable
    ;;
  status)
    QILNMP_security_status
    ;;
  uninstall)
    QILNMP_security_uninstall
    ;;
esac

action_status=$?
popd > /dev/null
exit ${action_status}
