#!/bin/bash
# Author:  summer <iticu@qq.com>
# Notes:   QILNMP 网站防篡改与安全加固模块 (Website Anti-Tamper & Security Hardening)
#          包含：上传目录木马隔离、核心关键文件只读锁定、临时维护模式自动回锁

# 基础目录配置
QILNMP_SECURITY_ROOT=${QILNMP_SECURITY_ROOT:-/etc/qilnmp-security}
QILNMP_TAMPER_BACKUP_DIR="${QILNMP_SECURITY_ROOT}/tamper_backups"
QILNMP_SECURITY_LOG="${QILNMP_SECURITY_LOG:-/var/log/qilnmp_security.log}"

# ==============================================================================
# 工具函数：记录安全审计操作日志
# ==============================================================================
QILNMP_security_log_event() {
  local msg="$1"
  touch "${QILNMP_SECURITY_LOG}" 2>/dev/null
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${msg}" >> "${QILNMP_SECURITY_LOG}" 2>/dev/null
}

# ==============================================================================
# 工具函数：获取所有已配置的 Nginx 虚拟主机域名列表
# ==============================================================================
QILNMP_tamper_get_domains() {
  local vhost_dir="${web_install_dir}/conf/vhost"
  if [ -d "${vhost_dir}" ]; then
    ls "${vhost_dir}" 2>/dev/null | grep -E '\.conf$' | sed 's/\.conf$//' | grep -v '^0\.'
  fi
}

# ==============================================================================
# 工具函数：获取防篡改快速概览统计 (用于主菜单看板展示)
# ==============================================================================
QILNMP_tamper_summary() {
  local domains=()
  mapfile -t domains < <(QILNMP_tamper_get_domains)
  local total=${#domains[@]}
  if [ "${total}" -eq 0 ]; then
    echo "未创建任何网站"
    return 0
  fi
  local protected_cnt=0
  for d in "${domains[@]}"; do
    local vhost_conf="${web_install_dir}/conf/vhost/${d}.conf"
    if [ -f "${vhost_conf}" ] && grep -q 'QILNMP_TAMPER_BEGIN' "${vhost_conf}"; then
      protected_cnt=$((protected_cnt + 1))
    fi
  done
  if [ "${protected_cnt}" -eq 0 ]; then
    echo "${total} 个网站 (均未开启)"
  elif [ "${protected_cnt}" -eq "${total}" ]; then
    echo "全部已保护 (${protected_cnt}/${total})"
  else
    echo "${protected_cnt} / ${total} 个网站保护中"
  fi
}

# ==============================================================================
# 工具函数：获取指定域名的网站根目录 (WebRoot)
# ==============================================================================
QILNMP_tamper_get_webroot() {
  local domain="$1"
  local vhost_conf="${web_install_dir}/conf/vhost/${domain}.conf"
  local webroot=""

  if [ -f "${vhost_conf}" ]; then
    webroot=$(grep -E '^[[:space:]]*root[[:space:]]+' "${vhost_conf}" | head -1 | awk '{print $2}' | tr -d ';')
  fi

  # 如果配置文件中未解析到，则回退到 QILNMP 默认网站路径
  if [ -z "${webroot}" ] || [ ! -d "${webroot}" ]; then
    webroot="${wwwroot_dir}/${domain}"
  fi
  echo "${webroot}"
}

# ==============================================================================
# 工具函数：获取指定网站的核心保护文件清单
# ==============================================================================
QILNMP_tamper_get_core_files() {
  local webroot="$1"
  local file_list=()

  # 1. 通用核心文件与入口
  [ -f "${webroot}/index.php" ] && file_list+=("${webroot}/index.php")
  [ -f "${webroot}/.user.ini" ] && file_list+=("${webroot}/.user.ini")
  [ -f "${webroot}/.htaccess" ] && file_list+=("${webroot}/.htaccess")

  # 2. WordPress 专有核心文件
  [ -f "${webroot}/wp-config.php" ] && file_list+=("${webroot}/wp-config.php")
  [ -f "${webroot}/wp-blog-header.php" ] && file_list+=("${webroot}/wp-blog-header.php")
  [ -f "${webroot}/wp-load.php" ] && file_list+=("${webroot}/wp-load.php")
  [ -f "${webroot}/wp-settings.php" ] && file_list+=("${webroot}/wp-settings.php")

  # 3. Typecho 专有核心文件
  [ -f "${webroot}/config.inc.php" ] && file_list+=("${webroot}/config.inc.php")

  # 4. ThinkPHP / Laravel 专有核心文件
  [ -f "${webroot}/.env" ] && file_list+=("${webroot}/.env")
  [ -f "${webroot}/public/index.php" ] && file_list+=("${webroot}/public/index.php")

  # 5. Discuz 专有核心文件
  [ -f "${webroot}/config/config_global.php" ] && file_list+=("${webroot}/config/config_global.php")

  echo "${file_list[@]}"
}

# ==============================================================================
# 功能 1：为指定网站开启防篡改保护 (Lock / Enable)
# ==============================================================================
QILNMP_tamper_enable() {
  local domain="$1"
  [ -z "${domain}" ] && { echo "${CFAILURE}【错误】未指定目标域名！${CEND}"; return 1; }

  local vhost_conf="${web_install_dir}/conf/vhost/${domain}.conf"
  [ ! -f "${vhost_conf}" ] && {
    echo "${CFAILURE}【错误】未找到网站配置文件: ${vhost_conf}${CEND}"
    return 1
  }

  local webroot
  webroot=$(QILNMP_tamper_get_webroot "${domain}")
  [ ! -d "${webroot}" ] && {
    echo "${CFAILURE}【错误】网站根目录不存在: ${webroot}${CEND}"
    return 1
  }

  echo "${CMSG}>>> 正在为站点 [${domain}] 开启防篡改与安全加固...${CEND}"

  # 1. 备份当前 Nginx 虚拟主机配置
  mkdir -p "${QILNMP_TAMPER_BACKUP_DIR}/${domain}"
  cp -a "${vhost_conf}" "${QILNMP_TAMPER_BACKUP_DIR}/${domain}/vhost_$(date +%Y%m%d_%H%M%S).conf"

  # 2. 在 Nginx 配置中注入静态与上传目录脚本执行阻断规则
  if ! grep -q 'QILNMP_TAMPER_BEGIN' "${vhost_conf}"; then
    local tmp_conf
    tmp_conf=$(mktemp /tmp/qilnmp-vhost.XXXXXX)

    awk '
      BEGIN { inserted=0 }
      /^[[:space:]]*root[[:space:]]+.*;/ && inserted==0 {
        print $0
        print "  # QILNMP_TAMPER_BEGIN"
        print "  # [QILNMP 防篡改] 严禁在静态及上传目录执行任何脚本（木马隔离规则）"
        print "  # 说明：正常上传和浏览图片/附件 100% 正常，但任何脚本尝试在此目录执行都会被 403 阻断"
        print "  location ~* ^/(wp-content/uploads|uploads|upload|attachment|attachments|static|data/attachment|runtime)/.*\\.(php|php5|phps|phtml|sh|py|pl)$ {"
        print "    deny all;"
        print "    return 403;"
        print "  }"
        print "  # QILNMP_TAMPER_END"
        inserted=1
        next
      }
      { print }
    ' "${vhost_conf}" > "${tmp_conf}"

    # 如果没有匹配到 root 行（例如特殊的 proxy 配置），尝试在 server { 后面插入
    if ! grep -q 'QILNMP_TAMPER_BEGIN' "${tmp_conf}"; then
      awk '
        BEGIN { inserted=0 }
        /^[[:space:]]*server[[:space:]]*{/ && inserted==0 {
          print $0
          print "  # QILNMP_TAMPER_BEGIN"
          print "  # [QILNMP 防篡改] 严禁在静态及上传目录执行任何脚本（木马隔离规则）"
          print "  # 说明：正常上传和浏览图片/附件 100% 正常，但任何脚本尝试在此目录执行都会被 403 阻断"
          print "  location ~* ^/(wp-content/uploads|uploads|upload|attachment|attachments|static|data/attachment|runtime)/.*\\.(php|php5|phps|phtml|sh|py|pl)$ {"
          print "    deny all;"
          print "    return 403;"
          print "  }"
          print "  # QILNMP_TAMPER_END"
          inserted=1
          next
        }
        { print }
      ' "${vhost_conf}" > "${tmp_conf}"
    fi

    cat "${tmp_conf}" > "${vhost_conf}"
    rm -f "${tmp_conf}"

    # 测试 Nginx 配置语法是否正确
    if "${web_install_dir}/sbin/nginx" -t >/dev/null 2>&1; then
      "${web_install_dir}/sbin/nginx" -s reload >/dev/null 2>&1
      echo "${CSUCCESS}  [✓] Nginx 上传与静态目录木马隔离规则已生效${CEND}"
    else
      echo "${CFAILURE}  [✗] Nginx 语法检查失败，正在自动回滚配置...${CEND}"
      sed -i '/# QILNMP_TAMPER_BEGIN/,/# QILNMP_TAMPER_END/d' "${vhost_conf}"
      "${web_install_dir}/sbin/nginx" -s reload >/dev/null 2>&1
      return 1
    fi
  else
    echo "${CSUCCESS}  [✓] Nginx 上传与静态目录木马隔离规则此前已生效${CEND}"
  fi

  # 3. 规范常用可写目录权限（确保用户上传图片/缓存正常写入）
  local writable_dirs=("wp-content/uploads" "uploads" "upload" "data/attachment" "runtime" "cache" "storage")
  for udir in "${writable_dirs[@]}"; do
    if [ -d "${webroot}/${udir}" ]; then
      chown -R ${run_user}:${run_group} "${webroot}/${udir}" 2>/dev/null
      find "${webroot}/${udir}" -type d -exec chmod 755 {} \; 2>/dev/null
    fi
  done

  # 4. 如果是 WordPress，自动禁用后台高危的在线主题/插件代码编辑器
  if [ -f "${webroot}/wp-config.php" ]; then
    chattr -i "${webroot}/wp-config.php" 2>/dev/null
    if ! grep -q "DISALLOW_FILE_EDIT" "${webroot}/wp-config.php"; then
      if grep -q "stop editing" "${webroot}/wp-config.php"; then
        sed -i "/stop editing/i define('DISALLOW_FILE_EDIT', true); // QILNMP 安全防护: 禁用后台直接修改代码" "${webroot}/wp-config.php"
      else
        sed -i "2i define('DISALLOW_FILE_EDIT', true); // QILNMP 安全防护: 禁用后台直接修改代码" "${webroot}/wp-config.php"
      fi
      echo "${CSUCCESS}  [✓] WordPress 后台在线代码修改漏洞已封堵 (已启用 DISALLOW_FILE_EDIT)${CEND}"
    fi
  fi

  # 5. 核心关键文件加锁 (chattr +i)
  local core_files
  core_files=$(QILNMP_tamper_get_core_files "${webroot}")
  local locked_count=0
  for cfile in ${core_files}; do
    if [ -f "${cfile}" ]; then
      chattr +i "${cfile}" 2>/dev/null
      locked_count=$((locked_count + 1))
    fi
  done
  echo "${CSUCCESS}  [✓] 已将 ${locked_count} 个关键核心文件打上底层只读锁 (防止被挂马与篡改)${CEND}"

  # 6. 清理可能存在的维护模式倒计时锁
  local pid_file="${QILNMP_SECURITY_ROOT}/maintenance_${domain}.pid"
  local info_file="${QILNMP_SECURITY_ROOT}/maintenance_${domain}.info"
  if [ -f "${pid_file}" ]; then
    kill -9 "$(cat "${pid_file}")" >/dev/null 2>&1
    rm -f "${pid_file}" "${info_file}"
  fi

  # 7. 记录状态
  mkdir -p "${QILNMP_SECURITY_ROOT}"
  echo "ENABLED" > "${QILNMP_SECURITY_ROOT}/tamper_${domain}.state"
  QILNMP_security_log_event "站点 [${domain}] 开启防篡改 (锁定 ${locked_count} 个核心文件 + Nginx 静态目录脚本隔离生效)"

  echo
  echo "${CSUCCESS}=======================================================================${CEND}"
  echo "${CSUCCESS} 站点 [${domain}] 防篡改保护已成功开启！${CEND}"
  echo "${CSUCCESS}=======================================================================${CEND}"
  echo "${CMSG}【安全收益】${CEND}"
  echo "  1. 静态及上传目录已被隔离，即便有后门文件被偷传，也绝无法在浏览器中运行。"
  echo "  2. 网站主入口与数据库配置文件被设为底层不可修改，黑客无法篡改首页或窃取凭据。"
  echo "${CYELLOW}【温馨提示】${CEND}"
  echo "  • 访客正常发帖、发表评论、上传图片/头像完全不受影响。"
  echo "  • 若管理员需在后台安装新插件或在线升级程序，请使用【临时维护模式】快速解锁。"
  echo
}

# ==============================================================================
# 功能 2：为指定网站关闭防篡改保护 (Unlock All / Disable)
# ==============================================================================
QILNMP_tamper_disable() {
  local domain="$1"
  [ -z "${domain}" ] && { echo "${CFAILURE}【错误】未指定目标域名！${CEND}"; return 1; }

  local vhost_conf="${web_install_dir}/conf/vhost/${domain}.conf"
  local webroot
  webroot=$(QILNMP_tamper_get_webroot "${domain}")

  echo "${CMSG}>>> 正在关闭站点 [${domain}] 的防篡改保护...${CEND}"

  # 1. 解除所有核心文件的只读锁
  local core_files
  core_files=$(QILNMP_tamper_get_core_files "${webroot}")
  for cfile in ${core_files}; do
    [ -f "${cfile}" ] && chattr -i "${cfile}" 2>/dev/null
  done
  echo "${CSUCCESS}  [✓] 关键文件只读锁定已解除${CEND}"

  # 2. 移除 Nginx 上传与静态目录隔离规则
  if [ -f "${vhost_conf}" ] && grep -q 'QILNMP_TAMPER_BEGIN' "${vhost_conf}"; then
    sed -i '/# QILNMP_TAMPER_BEGIN/,/# QILNMP_TAMPER_END/d' "${vhost_conf}"
    "${web_install_dir}/sbin/nginx" -t >/dev/null 2>&1 && "${web_install_dir}/sbin/nginx" -s reload >/dev/null 2>&1
    echo "${CSUCCESS}  [✓] Nginx 静态目录脚本限制规则已移除${CEND}"
  fi

  # 3. 清理维护模式与状态文件
  rm -f "${QILNMP_SECURITY_ROOT}/maintenance_${domain}.pid"
  rm -f "${QILNMP_SECURITY_ROOT}/maintenance_${domain}.info"
  rm -f "${QILNMP_SECURITY_ROOT}/tamper_${domain}.state"
  QILNMP_security_log_event "站点 [${domain}] 关闭防篡改保护 (恢复默认可写权限)"

  echo "${CSUCCESS}站点 [${domain}] 防篡改防护已彻底关闭，文件已恢复系统默认读写权限。${CEND}"
}

# ==============================================================================
# 功能 3：开启临时维护模式（解锁指定分钟，到期自动重新上锁）
# ==============================================================================
QILNMP_tamper_unlock() {
  local domain="$1"
  local minutes="${2:-15}"

  [ -z "${domain}" ] && { echo "${CFAILURE}【错误】未指定目标域名！${CEND}"; return 1; }

  # 验证输入是否为正整数
  if ! [[ "${minutes}" =~ ^[0-9]+$ ]] || [ "${minutes}" -le 0 ]; then
    minutes=15
  fi

  local webroot
  webroot=$(QILNMP_tamper_get_webroot "${domain}")
  [ ! -d "${webroot}" ] && { echo "${CFAILURE}【错误】网站根目录不存在: ${webroot}${CEND}"; return 1; }

  echo "${CMSG}>>> 正在为站点 [${domain}] 开启临时维护模式（时效: ${minutes} 分钟）...${CEND}"

  # 1. 解除关键核心文件的只读锁
  local core_files
  core_files=$(QILNMP_tamper_get_core_files "${webroot}")
  for cfile in ${core_files}; do
    [ -f "${cfile}" ] && chattr -i "${cfile}" 2>/dev/null
  done

  # 2. 清理可能遗留的旧后台任务
  local pid_file="${QILNMP_SECURITY_ROOT}/maintenance_${domain}.pid"
  local info_file="${QILNMP_SECURITY_ROOT}/maintenance_${domain}.info"
  if [ -f "${pid_file}" ]; then
    kill -9 "$(cat "${pid_file}")" >/dev/null 2>&1
    rm -f "${pid_file}" "${info_file}"
  fi

  # 3. 记录维护模式到期时间
  mkdir -p "${QILNMP_SECURITY_ROOT}"
  local start_ts
  start_ts=$(date +%s)
  local expire_ts=$((start_ts + minutes * 60))
  cat > "${info_file}" << EOF
DOMAIN='${domain}'
MINUTES='${minutes}'
START_TS='${start_ts}'
EXPIRE_TS='${expire_ts}'
EOF

  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  QILNMP_security_log_event "站点 [${domain}] 开启临时维护模式 (时效: ${minutes} 分钟)"

  # 4. 启动后台守护任务：等待指定时间后自动执行重新加锁
  (
    sleep $((minutes * 60))
    "${script_dir}/security.sh" --tamper-lock "${domain}" >/dev/null 2>&1
    QILNMP_security_log_event "站点 [${domain}] 临时维护模式到期，系统已在后台自动重新上锁！"
    rm -f "${pid_file}" "${info_file}"
  ) >/dev/null 2>&1 &
  echo $! > "${pid_file}"

  echo
  echo "${CSUCCESS}=======================================================================${CEND}"
  echo "${CSUCCESS} 站点 [${domain}] 已进入【临时维护模式】！${CEND}"
  echo "${CSUCCESS}=======================================================================${CEND}"
  echo "  • 核心代码只读锁定已解除，您现在可以在 WordPress/程序后台进行："
  echo "    ${CGREEN}✔ 在线安装新插件${CEND}"
  echo "    ${CGREEN}✔ 在线更新主题与系统核心${CEND}"
  echo "    ${CGREEN}✔ 修改系统设置与配置文件${CEND}"
  echo
  echo "${CYELLOW}  • 维护倒计时：[ ${minutes} 分钟 ]${CEND}"
  echo "${CYELLOW}  • 时间到期后，系统将在后台自动重新上锁加固，无需手动操作！${CEND}"
  echo
}

# ==============================================================================
# 功能 4：查看站点防篡改状态
# ==============================================================================
QILNMP_tamper_status() {
  local target_domain="$1"
  local domains=()

  if [ -n "${target_domain}" ]; then
    domains=("${target_domain}")
  else
    mapfile -t domains < <(QILNMP_tamper_get_domains)
  fi

  if [ ${#domains[@]} -eq 0 ]; then
    echo "${CYELLOW}当前服务器未发现任何 Nginx 虚拟主机站点。${CEND}"
    return 0
  fi

  echo "-----------------------------------------------------------------------"
  printf "%-25s %-16s %-16s %-18s\n" "域名 (Domain)" "上传目录隔离" "核心文件只读锁" "维护模式状态"
  echo "-----------------------------------------------------------------------"

  local current_ts
  current_ts=$(date +%s)

  for d in "${domains[@]}"; do
    local vhost_conf="${web_install_dir}/conf/vhost/${d}.conf"
    local webroot
    webroot=$(QILNMP_tamper_get_webroot "${d}")

    # 1. 检查上传隔离规则
    local ngx_rule="未启用"
    if [ -f "${vhost_conf}" ] && grep -q 'QILNMP_TAMPER_BEGIN' "${vhost_conf}"; then
      ngx_rule="${CGREEN}已启用 (403)${CEND}"
    fi

    # 2. 检查核心文件锁定状态
    local lock_status="未锁定"
    if [ -f "${webroot}/index.php" ] && lsattr "${webroot}/index.php" 2>/dev/null | awk '{print $1}' | grep -q 'i'; then
      lock_status="${CGREEN}已锁定 (+i)${CEND}"
    elif [ -f "${webroot}/wp-config.php" ] && lsattr "${webroot}/wp-config.php" 2>/dev/null | awk '{print $1}' | grep -q 'i'; then
      lock_status="${CGREEN}已锁定 (+i)${CEND}"
    fi

    # 3. 检查维护模式倒计时
    local m_status="正常防护中"
    local info_file="${QILNMP_SECURITY_ROOT}/maintenance_${d}.info"
    if [ -f "${info_file}" ]; then
      . "${info_file}"
      if [ -n "${EXPIRE_TS}" ] && [ "${EXPIRE_TS}" -gt "${current_ts}" ]; then
        local remain_sec=$((EXPIRE_TS - current_ts))
        local remain_min=$((remain_sec / 60))
        m_status="${CYELLOW}维护中 (余${remain_min}分)${CEND}"
      fi
    fi

    printf "%-25s %-25b %-25b %-28b\n" "${d}" "${ngx_rule}" "${lock_status}" "${m_status}"
  done
  echo "-----------------------------------------------------------------------"
}

# ==============================================================================
# 功能 5：查看安全综合日志与防御记录看板
# ==============================================================================
QILNMP_show_security_logs() {
  local fail2ban_log="/var/log/fail2ban.log"
  local audit_log="${QILNMP_SECURITY_LOG:-/var/log/qilnmp_security.log}"

  echo
  echo "${CSUCCESS}=======================================================================${CEND}"
  echo "${CSUCCESS}                    QILNMP 安全防御与操作日志看板                      ${CEND}"
  echo "${CSUCCESS}=======================================================================${CEND}"

  # 1. 恶意 IP 自动拉黑记录 (Fail2ban)
  echo "${CMSG}【1. 最近恶意 IP 封禁与解封记录 (Fail2ban)】:${CEND}"
  if [ -f "${fail2ban_log}" ]; then
    local ban_logs
    ban_logs=$(grep -E 'Ban|Unban' "${fail2ban_log}" 2>/dev/null | tail -n 8)
    if [ -n "${ban_logs}" ]; then
      echo "${ban_logs}"
    else
      echo "  (暂无 IP 被封禁记录，当前网络环境安全)"
    fi
  else
    echo "  (Fail2ban 尚未产生日志)"
  fi
  echo

  # 2. 防篡改与加固运维日志
  echo "${CMSG}【2. 网站防篡改操作与自动回锁记录】:${CEND}"
  if [ -f "${audit_log}" ]; then
    local audit_records
    audit_records=$(tail -n 8 "${audit_log}" 2>/dev/null)
    if [ -n "${audit_records}" ]; then
      echo "${audit_records}"
    else
      echo "  (暂无操作日志)"
    fi
  else
    echo "  (暂无操作日志)"
  fi
  echo

  # 3. 上传目录木马隔离拦截 (403 Forbidden)
  echo "${CMSG}【3. 最近木马脚本访问被拦截记录 (Nginx 403 阻断)】:${CEND}"
  local blocked_logs=""
  if [ -d "${wwwlogs_dir}" ]; then
    blocked_logs=$(grep -Rns ' 403 ' "${wwwlogs_dir}"/*nginx.log 2>/dev/null | grep -E '\.(php|phtml|sh|py)' | tail -n 5)
  fi
  if [ -n "${blocked_logs}" ]; then
    echo "${blocked_logs}"
  else
    echo "  (暂无木马访问触发，静态目录隔离运行正常)"
  fi
  echo
  echo "${CYELLOW}【提示】如需实时滚动监控黑客拦截，可在终端执行：tail -f /var/log/fail2ban.log${CEND}"
  echo "${CSUCCESS}=======================================================================${CEND}"
}
