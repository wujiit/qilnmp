#!/bin/bash
# Author:  summer <iticu@qq.com>
# Notes:   QILNMP 系统与网站综合安全管理脚本 (Security Center)
#          整合功能：Nginx 限流 + Fail2ban 防 CC / 暴力破解 + 网站防篡改与木马隔离

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

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
. ./include/tamper_security.sh

# ==============================================================================
# 帮助信息输出 (命令行快捷参数)
# ==============================================================================
Show_Help() {
  echo
  echo "Usage: $0 [options]
  
  直接输入 ./security.sh 即可进入【极简中文安全中心菜单】。

【常用命令】:
  -h, --help                  显示帮助信息
  -m, --menu                  打开安全中心交互菜单
  --status                    查看综合安全状态报告
  --logs                      查看安全防御与拦截日志看板

  【网站防篡改】
  --tamper-lock <domain>      开启防篡改 (核心文件只读 + 上传目录隔离木马)
  --tamper-unlock <domain> [m]开启临时维护模式 (默认15分钟，到期自动重新上锁)
  --tamper-disable <domain>   关闭指定站点的防篡改保护
  --tamper-status [domain]    查看站点锁定状态

  【防 CC / 暴力破解】
  --enable,  --cc-enable      开启防 CC 模块 (Nginx限流 + Fail2ban拉黑)
  --disable, --cc-disable     暂停防 CC 模块
  --cc-status                 查看已拉黑的恶意 IP
  "
}

# ==============================================================================
# 智能站点选择与操作辅助函数 (简化交互逻辑)
# ==============================================================================
Select_Domain_And_Execute() {
  local action="$1"
  local domains=()
  mapfile -t domains < <(QILNMP_tamper_get_domains)

  if [ ${#domains[@]} -eq 0 ]; then
    echo "${CWARNING}【提示】当前服务器未发现任何网站，请先使用 ./vhost.sh 建站。${CEND}"
    return 1
  fi

  # 场景 1：如果服务器上只有 1 个网站，直接确认即可，省去选单步骤
  if [ ${#domains[@]} -eq 1 ]; then
    local single_domain="${domains[0]}"
    echo
    echo "${CMSG}检测到当前服务器仅有 1 个网站：[ ${single_domain} ]${CEND}"
    Apply_Tamper_Action "${action}" "${single_domain}"
    return 0
  fi

  # 场景 2：多个网站，展示极简数字列表
  echo
  echo "${CMSG}请选择要操作的网站：${CEND}"
  local idx=1
  for d in "${domains[@]}"; do
    echo "  ${idx}. ${d}"
    idx=$((idx + 1))
  done
  echo "  a. 全部网站 (一键操作全部站点)"
  echo "  q. 返回上一级"
  echo

  while :; do
    read -e -p "请输入序号 [1-${#domains[@]} / a 全部 / q 返回]: " d_choice
    case "${d_choice}" in
      q|Q)
        return 0
        ;;
      a|A)
        for target_d in "${domains[@]}"; do
          echo
          Apply_Tamper_Action "${action}" "${target_d}"
        done
        break
        ;;
      *)
        if [[ "${d_choice}" =~ ^[0-9]+$ ]] && [ "${d_choice}" -ge 1 ] && [ "${d_choice}" -le ${#domains[@]} ]; then
          local selected_domain="${domains[$((d_choice - 1))]}"
          echo
          Apply_Tamper_Action "${action}" "${selected_domain}"
          break
        else
          # 也支持直接敲域名
          local found=0
          for chk_d in "${domains[@]}"; do
            if [ "${chk_d}" == "${d_choice}" ]; then
              found=1
              break
            fi
          done
          if [ "${found}" -eq 1 ]; then
            echo
            Apply_Tamper_Action "${action}" "${d_choice}"
            break
          else
            echo "${CWARNING}输入有误，请输入序号 (如 1) 或 a 全部！${CEND}"
          fi
        fi
        ;;
    esac
  done
}

# ==============================================================================
# 执行具体防篡改动作
# ==============================================================================
Apply_Tamper_Action() {
  local action="$1"
  local domain="$2"

  case "${action}" in
    enable)
      echo "-----------------------------------------------------------------------"
      echo "${CMSG}【操作确认】为 [ ${domain} ] 开启防篡改：${CEND}"
      echo "  • 核心配置文件打上只读锁，防止被篡改挂马；"
      echo "  • 静态及上传目录禁止运行脚本，杜绝 Webshell 图片马；"
      echo "${CGREEN}  ✔ 正常用户发帖、评论上传图片 100% 正常，不受影响！${CEND}"
      echo "-----------------------------------------------------------------------"
      read -e -p "确认立即开启？[Y/n]: " confirm_action
      confirm_action=${confirm_action:-y}
      if [[ "${confirm_action}" =~ ^[yY]$ ]]; then
        QILNMP_tamper_enable "${domain}"
      else
        echo "${CYELLOW}操作已取消。${CEND}"
      fi
      ;;
    disable)
      read -e -p "确认解除 [ ${domain} ] 的防篡改保护？[y/N]: " confirm_action
      confirm_action=${confirm_action:-n}
      if [[ "${confirm_action}" =~ ^[yY]$ ]]; then
        QILNMP_tamper_disable "${domain}"
      else
        echo "${CYELLOW}操作已取消。${CEND}"
      fi
      ;;
    unlock)
      echo "-----------------------------------------------------------------------"
      echo "${CMSG}【临时维护模式说明】${CEND}"
      echo "  • 系统将临时解除锁定，方便您去后台在线安装插件、更换主题或升级系统；"
      echo "  • 倒计时结束后，系统会在后台【自动重新加锁】，无需担心遗忘开启。"
      echo "-----------------------------------------------------------------------"
      read -e -p "请输入维护时长（分钟）[直接回车默认 15 分钟]: " minutes_input
      minutes_input=${minutes_input:-15}
      QILNMP_tamper_unlock "${domain}" "${minutes_input}"
      ;;
  esac
}

# ==============================================================================
# 防 CC / 暴力破解一键智能切换开关
# ==============================================================================
Toggle_CC_Protection() {
  local cc_status
  cc_status=$(QILNMP_security_current_status)

  echo
  if [ "${cc_status}" == "enabled" ]; then
    echo "当前防 CC 模块状态：${CGREEN}【已开启 / 保护中】${CEND}"
    read -e -p "是否暂停防 CC 保护？[y/N]: " confirm_toggle
    confirm_toggle=${confirm_toggle:-n}
    if [[ "${confirm_toggle}" =~ ^[yY]$ ]]; then
      echo "${CMSG}>>> 正在暂停防 CC 模块...${CEND}"
      QILNMP_security_disable
    fi
  else
    echo "当前防 CC 模块状态：${CYELLOW}【未启用 / 暂停中】${CEND}"
    read -e -p "是否立即开启防 CC 与暴力破解保护？[Y/n]: " confirm_toggle
    confirm_toggle=${confirm_toggle:-y}
    if [[ "${confirm_toggle}" =~ ^[yY]$ ]]; then
      echo "${CMSG}>>> 正在开启防 CC 模块...${CEND}"
      QILNMP_security_enable
    fi
  fi
}

# ==============================================================================
# 极简交互式中文主菜单
# ==============================================================================
Interactive_Menu() {
  while :; do
    clear
    # 动态抓取当前实时状态
    local cc_status
    cc_status=$(QILNMP_security_current_status)
    local cc_tag="${CYELLOW}未启用${CEND}"
    local cc_btn="开启"
    if [ "${cc_status}" == "enabled" ]; then
      cc_tag="${CGREEN}● 已开启 (Nginx限速 + 自动拉黑恶毒IP)${CEND}"
      cc_btn="暂停"
    fi

    local tamper_tag
    tamper_tag=$(QILNMP_tamper_summary)

    printf "
${CMSG}#######################################################################${CEND}
${CSUCCESS}#                  QILNMP 安全防护中心 (Security)                     #${CEND}
${CMSG}#         Official Site: https://qiling.jingxialai.com                #${CEND}
${CMSG}#######################################################################${CEND}

  ${CGREEN}【当前系统防护状态】${CEND}
    • 防 CC / 暴力破解 : ${cc_tag}
    • 网站防篡改保护   : ${CGREEN}● ${tamper_tag}${CEND}

-----------------------------------------------------------------------
  ${CMSG}1.${CEND} 开启网站防篡改      ${CGREEN}[推荐]${CEND} 核心文件锁定 + 上传目录木马隔离
  ${CMSG}2.${CEND} 临时维护模式 (15分) 后台装插件/换主题专用，到期自动重新上锁
  ${CMSG}3.${CEND} 关闭网站防篡改      解除只读锁定，恢复正常读写
  ${CMSG}4.${CEND} 防 CC 攻击开关      一键 ${cc_btn} (当前: ${cc_status})
  ${CMSG}5.${CEND} 查看安全日志与状态  查看各站点锁定、被拉黑IP及防御历史
  ${CMSG}q.${CEND} 退出
-----------------------------------------------------------------------
"
    read -e -p "请选择操作 [1-5, 或 q 退出]: " menu_choice
    case "${menu_choice}" in
      1)
        Select_Domain_And_Execute "enable"
        ;;
      2)
        Select_Domain_And_Execute "unlock"
        ;;
      3)
        Select_Domain_And_Execute "disable"
        ;;
      4)
        Toggle_CC_Protection
        ;;
      5)
        echo
        echo "${CSUCCESS}==================== 1. 网站防篡改加固状态 ====================${CEND}"
        QILNMP_tamper_status
        echo
        echo "${CSUCCESS}==================== 2. 防 CC 与暴力破解状态 ====================${CEND}"
        QILNMP_security_status
        # 显示安全防御与操作日志看板
        QILNMP_show_security_logs
        ;;
      q|Q)
        echo "${CMSG}已退出 QILNMP 安全中心。${CEND}"
        break
        ;;
      *)
        echo "${CWARNING}输入无效，请输入数字 1-5 或 q 退出！${CEND}"
        ;;
    esac
    echo
    read -e -p "按回车键 [Enter] 返回主菜单..." dummy
  done
}

# ==============================================================================
# 命令行参数解析 (无需交互时的快捷方式)
# ==============================================================================

# 如果没有任何参数，直接进入极简交互式中文菜单
if [ $# -eq 0 ]; then
  Interactive_Menu
  popd > /dev/null
  exit 0
fi

security_action=""
target_domain=""
custom_minutes=15

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      Show_Help
      popd > /dev/null
      exit 0
      ;;
    -m|--menu)
      Interactive_Menu
      popd > /dev/null
      exit 0
      ;;
    --install|--cc-install)
      security_action="cc_install"
      shift 1
      ;;
    --enable|--cc-enable)
      security_action="cc_enable"
      shift 1
      ;;
    --disable|--cc-disable)
      security_action="cc_disable"
      shift 1
      ;;
    --status)
      security_action="all_status"
      shift 1
      ;;
    --logs)
      security_action="show_logs"
      shift 1
      ;;
    --cc-status)
      security_action="cc_status"
      shift 1
      ;;
    --uninstall|--cc-uninstall)
      security_action="cc_uninstall"
      shift 1
      ;;
    --tamper-lock|--tamper-enable)
      security_action="tamper_lock"
      if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
        echo "${CFAILURE}【错误】--tamper-lock 必须指定目标域名！例如: ./security.sh --tamper-lock domain.com${CEND}"
        popd > /dev/null
        exit 1
      fi
      target_domain="$2"
      shift 2
      ;;
    --tamper-unlock)
      security_action="tamper_unlock"
      if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
        echo "${CFAILURE}【错误】--tamper-unlock 必须指定目标域名！例如: ./security.sh --tamper-unlock domain.com 15${CEND}"
        popd > /dev/null
        exit 1
      fi
      target_domain="$2"
      if [ -n "$3" ] && [[ "$3" =~ ^[0-9]+$ ]]; then
        custom_minutes="$3"
        shift 3
      else
        shift 2
      fi
      ;;
    --tamper-disable)
      security_action="tamper_disable"
      if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
        echo "${CFAILURE}【错误】--tamper-disable 必须指定目标域名！例如: ./security.sh --tamper-disable domain.com${CEND}"
        popd > /dev/null
        exit 1
      fi
      target_domain="$2"
      shift 2
      ;;
    --tamper-status)
      security_action="tamper_status"
      if [ -n "$2" ] && [[ ! "$2" =~ ^- ]]; then
        target_domain="$2"
        shift 2
      else
        shift 1
      fi
      ;;
    *)
      echo "${CWARNING}【错误】未知参数: $1${CEND}"
      Show_Help
      popd > /dev/null
      exit 1
      ;;
  esac
done

case "${security_action}" in
  cc_install|cc_enable)
    QILNMP_security_enable
    ;;
  cc_disable)
    QILNMP_security_disable
    ;;
  cc_status)
    QILNMP_security_status
    ;;
  cc_uninstall)
    QILNMP_security_uninstall
    ;;
  tamper_lock)
    QILNMP_tamper_enable "${target_domain}"
    ;;
  tamper_unlock)
    QILNMP_tamper_unlock "${target_domain}" "${custom_minutes}"
    ;;
  tamper_disable)
    QILNMP_tamper_disable "${target_domain}"
    ;;
  tamper_status)
    QILNMP_tamper_status "${target_domain}"
    ;;
  all_status)
    echo "${CSUCCESS}==================== 1. 网站防篡改加固状态 ====================${CEND}"
    QILNMP_tamper_status
    echo
    echo "${CSUCCESS}==================== 2. 防 CC 与暴力破解状态 ====================${CEND}"
    QILNMP_security_status
    ;;
  show_logs)
    QILNMP_show_security_logs
    ;;
  *)
    Show_Help
    ;;
esac

action_status=$?
popd > /dev/null
exit ${action_status}
