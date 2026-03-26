# QILNMP

QILNMP 是基于 OneinStack 的社区维护分支，面向 LNMP/LAMP 快速部署与日常运维。  
推荐按需到官方下载文件包本地上传，或者自己搭建软件镜像源网站。  
反馈QQ群：16966111

## Fork / 版权说明

- Upstream Author: yeho `<lj2007331 AT gmail.com>`
- Upstream Project Repo: <https://github.com/oneinstack/oneinstack>
- Fork Maintainer: summer `<iticu@qq.com>`
- Fork Site: <https://qiling.jingxialai.com>
- Fork Repo: <https://github.com/wujiit/qilnmp>
- License: Apache-2.0

## 中文使用文档

### 1. 项目能力

- Shell 交互式安装，支持自动化参数安装
- 源码编译安装，支持本地包、镜像源、自定义源、官方回源
- 支持 Nginx/Tengine/OpenResty/Caddy/Apache
- 支持 MySQL/MariaDB/Percona/PostgreSQL/MongoDB
- 支持 PHP 多版本（含 8.5/8.4）
- 支持 Redis、Memcached、Pure-FTPd、phpMyAdmin、Node.js 等
- 提供虚拟主机、备份、升级、卸载、环境状态检查工具

### 2. 支持系统

当前维护策略：只支持较新系统，低版本系统不再支持。

- RHEL 系（Rocky/AlmaLinux/RHEL 等）：`8/9`
- Debian：`10/11/12`
- Ubuntu：`20.04/22.04/24.04`
- 仅支持 64 位系统

明确不支持示例：

- CentOS 7
- Debian 9 及以下
- Ubuntu 18.04/16.04 及以下

### 3. 快速安装

CentOS/RHEL/Rocky/AlmaLinux：

```bash
yum -y install wget screen || dnf -y install wget screen
git clone https://github.com/wujiit/qilnmp.git
cd qilnmp
# 如需修改安装目录、镜像源、日志目录等，先编辑 options.conf
screen -S qilnmp
# 如果网络中断，可执行 screen -r qilnmp 重新连接安装窗口
chmod +x install.sh
./install.sh
```

Debian/Ubuntu：

```bash
apt-get update && apt-get -y install wget screen
git clone https://github.com/wujiit/qilnmp.git
cd qilnmp
# 如需修改安装目录、镜像源、日志目录等，先编辑 options.conf
screen -S qilnmp
# 如果网络中断，可执行 screen -r qilnmp 重新连接安装窗口
chmod +x install.sh
./install.sh
```

离线压缩包方式：

```bash
tar xzf qilnmp.tar.gz
cd qilnmp
# 如需修改安装目录、镜像源、日志目录等，先编辑 options.conf
screen -S qilnmp
# 如果网络中断，可执行 screen -r qilnmp 重新连接安装窗口
chmod +x install.sh
./install.sh
```

当前发布只保留一个安装包：`qilnmp.tar.gz`。

如果当前文件没有执行权限，也可以改用：

```bash
cd qilnmp
bash install.sh
```

常改项：

- `mirror_link`：镜像源地址
- `mirror_fallback_links`：额外镜像源地址列表（可选，多个地址用空格分隔并用引号包起来）
- `custom_src_urls_file`：自定义包地址映射文件
- `wwwroot_dir`：网站根目录
- `wwwlogs_dir`：日志目录
- `php_install_dir` / `mysql_install_dir` 等安装目录

说明：

- 这个项目本身是 `#!/bin/bash` 的直接执行脚本，常规用法就是 `chmod +x install.sh` 后执行 `./install.sh`
- `bash install.sh` 也能运行，但更适合作为“当前文件没有执行权限时”的备用方式
- 不建议使用 `chmod -R 755 qilnmp` 这类递归改权限命令

### 4. 下载源优先级（重要）

`Download_src` 当前按以下顺序尝试下载：

1. 本地 `src/` 已存在文件
2. `mirror_link` 主镜像地址（例如 `https://mirror.example.com/src/xxx.tar.gz`）
3. `config/custom_src_urls.conf` 里配置的自定义 URL（按文件名匹配）
4. 脚本内置 `src_url_backup` 官方备用地址（按具体组件是否定义而定）
5. `mirror_fallback_links` 里配置的额外镜像地址
6. 当前镜像配置里 `_redirects` 对应的官方回源地址

自定义 URL 示例：

```bash
icu4c-63_1-src.tgz=https://test.12345.com/ty/icu4c-63_1-src.tgz
```

推荐做法（按需选择一种或组合）：

- 按业务需求先从官网下载源码包，再上传到 `src/` 目录（最直接、最可控）
- 搭建自己的镜像源，然后在 `options.conf` 里配置 `mirror_link`
- 如果希望配置多个镜像，只在 `options.conf` 里维护 `mirror_fallback_links`
- 如果安装包 MD5 清单位于单独目录，可在 `options.conf` 里配置 `mirror_md5_url`
- 使用第三方镜像源时，也建议统一写进 `options.conf`，不要在脚本里额外写死

多镜像示例：

```bash
mirror_link=https://mirror-a.example.com
mirror_fallback_links='https://mirror-b.example.com https://mirror-c.example.com'
```

镜像相关域名说明：

- 默认配置下，主镜像域名是 `one.jingxialai.com`，（仅适合中国内地服务器）对应 `options.conf` 里的 `mirror_link`
- `mirror_fallback_links` 默认留空；只有你自己填写后，脚本才会访问这些备用镜像域名
- 例如你可以配置 `mirror_fallback_links='https://mirror.dal.ao'`，这时 `mirror.dal.ao` 才会作为备用镜像参与下载和版本同步
- README 里出现的 `mirror.dal.ao` 现在仅作为示例镜像域名，也是推荐的第三方镜像网站

说明：

- 下载和版本同步现在都只读取 `mirror_link` 与 `mirror_fallback_links`


#### 4.1 当前代码可能访问的外部域名

以下清单按当前代码整理，表示安装、下载、升级、版本同步、可选组件安装，以及备份相关功能中，脚本本身可能访问或读取到的域名。

- 已排除：`xprober.php`、`ocp.php`
- 已排除：`config/custom_src_urls.conf` 中由用户自行配置的自定义地址
- 说明：如果你只走本地 `src/` 离线包，或把相关组件全部改到自建镜像，实际访问域名会少于下面清单

镜像与版本同步：

- `one.jingxialai.com`（默认 `mirror_link`）
- `mirror.dal.ao`（仅当你把它写入 `mirror_fallback_links` 时才会访问）
- `mirror_fallback_links` 中由用户自行配置的额外镜像域名（如有）

Web 服务与基础组件官方源：

- `nginx.org`
- `openresty.org`
- `tengine.taobao.org`
- `archive.apache.org`
- `httpd.apache.org`
- `tomcat.apache.org`
- `curl.se`
- `ftp.gnu.org`
- `download.gnome.org`
- `download.libsodium.org`
- `downloads.sourceforge.net`
- `libzip.org`
- `zlib.net`
- `imagemagick.org`
- `download.pureftpd.org`
- `downloads.ioncube.com`
- `xcache.lighttpd.net`
- `launchpad.net`
- `github.com`

PHP / PECL / Composer / phpMyAdmin：

- `www.php.net`
- `pecl.php.net`
- `www.phpmyadmin.net`
- `files.phpmyadmin.net`
- `getcomposer.org`
- `packagist.phpcomposer.com`
- `mirrors.aliyun.com`

数据库与缓存组件：

- `download.redis.io`
- `www.memcached.org`
- `downloads.mysql.com`
- `cdn.mysql.com`
- `archive.mariadb.org`
- `downloads.percona.com`
- `www.percona.com`
- `ftp.postgresql.org`
- `ftp.heanet.ie`
- `fastdl.mongodb.org`

地区镜像与软件仓库：

- `mirrors.tuna.tsinghua.edu.cn`
- `mirrors.ustc.edu.cn`
- `mirrors.dotsrc.org`
- `cdn.remirepo.net`
- `nodejs.org`

备份与对象存储工具链：

- `gosspublic.alicdn.com`
- `cosbrowser.cloud.tencent.com`
- `devtools.qiniu.com`
- `collection.b0.upaiyun.com`
- `awscli.amazonaws.com`
- `*.aliyuncs.com`
- `*.myqcloud.com`

说明：

- 上面这一组主要在启用阿里云 OSS、腾讯云 COS、七牛云、又拍云、AWS S3 等备份能力时才会访问
- `dbxcli` 由当前 `mirror_link` 下载，但其运行时访问的 Dropbox API 域名未在 shell 脚本中硬编码


常见 LNMP 离线包文件名清单（可直接按表下载到 `src/`）：

- 见 `SRC_PACKAGE_LIST.md`

### 5. MD5 校验说明

安装开始时可选择 `Do you want to check md5sum? [y/n]`。

- 选择 `y` 后，会校验当前安装包 MD5
- 当前安装包固定为 `qilnmp.tar.gz`
- 校验来源优先使用 `mirror_md5_url`，未配置时回退到 `${mirror_link}/md5/md5sum.txt`
- 若不一致会提示重新下载安装包

如果你使用自己的镜像站，建议在镜像站提供 `md5sum.txt`，例如：

```bash
mirror_link=https://mirror.123.com
mirror_fallback_links='https://mirror2.123.com https://mirror3.123.com'
mirror_md5_url=https://mirror.123.com/md5/md5sum.txt
```

### 6. 常用安装与维护命令

#### 6.1 安装额外 PHP 版本

```bash
./install.sh --mphp_ver 85
```

#### 6.2 安装 PHP 扩展

推荐直接用 `install.sh --php_extensions`：

```bash
./install.sh --php_extensions fileinfo
./install.sh --php_extensions redis
./install.sh --php_extensions imagick
./install.sh --php_extensions "fileinfo redis imagick"
```

安装后建议重载 PHP-FPM：

```bash
systemctl restart php-fpm || service php-fpm restart
```

说明：`addons.sh` 主要用于 Composer/fail2ban/ngx_lua_waf，不是主要的 PHP 扩展安装入口。

#### 6.3 安装 Redis 服务端

```bash
./install.sh --redis
systemctl enable --now redis-server || systemctl enable --now redis
```

说明：仅安装 `php redis` 扩展，不等于安装 Redis 服务端。

#### 6.4 安装状态检查

```bash
bash tools/stack_status.sh
```

输出会包含：

- Web 服务与版本
- 数据库服务与版本
- Redis/Memcached/Pure-FTPd 状态
- PHP 版本、关键扩展、扩展列表

#### 6.5 站点与备份

```bash
./vhost.sh
./vhost.sh --del
./pureftpd_vhost.sh
./backup_setup.sh
./backup.sh
./upgrade.sh
./uninstall.sh
```

#### 6.6 install.sh 参数化安装示例

查看参数帮助：

```bash
./install.sh --help
```

示例：一条命令完成 LNMP + PHP 扩展 + 常用组件（按参数自动安装）：

```bash
./install.sh \
  --nginx_option 1 \
  --php_option 11 \
  --phpcache_option 1 \
  --php_extensions "fileinfo redis imagick" \
  --db_option 1 \
  --dbinstallmethod 1 \
  --dbrootpwd 'StrongPass_123' \
  --phpmyadmin \
  --redis \
  --memcached \
  --md5sum
```

说明：

- `--nginx_option`、`--php_option`、`--db_option` 的编号以脚本菜单为准。
- 如果只传部分参数，脚本会按已给参数执行，不一定进入完整交互流程。

#### 6.7 addons.sh（附加组件）

```bash
./addons.sh --install --composer
./addons.sh --install --fail2ban
./addons.sh --install --ngx_lua_waf

./addons.sh --uninstall --composer
./addons.sh --uninstall --fail2ban
./addons.sh --uninstall --ngx_lua_waf
```

#### 6.8 vhost.sh（虚拟主机）常用参数

```bash
./vhost.sh --list
./vhost.sh --add --letsencrypt
./vhost.sh --add --selfsigned
./vhost.sh --add --httponly
./vhost.sh --add --proxy
./vhost.sh --add --mphp_ver 85
./vhost.sh --del
```

#### 6.9 pureftpd_vhost.sh（FTP 用户）常用参数

```bash
./pureftpd_vhost.sh --add -u ftpuser -p 'Pass_123456' -d /data/wwwroot/example.com
./pureftpd_vhost.sh --usermod -u ftpuser -d /data/wwwroot/newpath
./pureftpd_vhost.sh --passwd -u ftpuser -p 'NewPass_123456'
./pureftpd_vhost.sh --showuser -u ftpuser
./pureftpd_vhost.sh --list
./pureftpd_vhost.sh --delete -u ftpuser
```

#### 6.10 升级命令（upgrade.sh）

```bash
./upgrade.sh --help
./upgrade.sh --php <version>
./upgrade.sh --nginx <version>
./upgrade.sh --db <version>
./upgrade.sh --redis <version>
./upgrade.sh --phpmyadmin <version>
./upgrade.sh --oneinstack
./upgrade.sh --acme.sh
```

#### 6.11 卸载命令（uninstall.sh）

```bash
./uninstall.sh --help
./uninstall.sh --php_extensions redis
./uninstall.sh --redis
./uninstall.sh --memcached
./uninstall.sh --phpmyadmin
./uninstall.sh --mphp_ver 84
./uninstall.sh --allphp
./uninstall.sh --web
./uninstall.sh --all
```

#### 6.12 重置数据库 root 密码

```bash
./reset_db_root_password.sh --password 'NewStrongPass_123'
./reset_db_root_password.sh --force --password 'NewStrongPass_123'
```

#### 6.13 备份计划任务示例

```bash
./backup_setup.sh
./backup.sh
crontab -e
# 每天 01:00 执行
0 1 * * * cd /path/to/qilnmp && ./backup.sh > /dev/null 2>&1
```

#### 6.14 tools/ 实用脚本

```bash
# 环境状态报告
bash tools/stack_status.sh

# 单库备份（需在 tools 目录执行）
(cd tools && bash db_bk.sh your_database_name)

# 单站点备份（需在 tools 目录执行）
(cd tools && bash website_bk.sh your_site_dir_name)

# 多机批量执行（高级功能）
(cd tools && bash mabs.sh -h)
```

#### 6.15 单项安装命令（按需执行）

```bash
# 仅安装 Nginx
./install.sh --nginx_option 1

# 仅安装数据库（示例：MySQL 8.0，二进制方式）
./install.sh --db_option 1 --dbinstallmethod 1 --dbrootpwd 'StrongPass_123'

# 仅安装 PHP（示例：PHP 8.5 + OPcache）
./install.sh --php_option 11 --phpcache_option 1

# 仅安装附加服务
./install.sh --phpmyadmin
./install.sh --pureftpd
./install.sh --redis
./install.sh --memcached
./install.sh --nodejs
```

#### 6.16 PHP 版本编号速查（install.sh）

```text
1=PHP7.0  2=PHP7.1  3=PHP7.2  4=PHP7.3  5=PHP7.4
6=PHP8.0  7=PHP8.1  8=PHP8.2  9=PHP8.3  10=PHP8.4  11=PHP8.5
```

说明：当前安装流程已移除 PHP 5.x 支持。

#### 6.17 多 PHP 维护命令

```bash
# 安装第二个 PHP 版本（示例：PHP 8.4）
./install.sh --mphp_ver 84

# 仅给第二个 PHP 安装扩展（示例）
./install.sh --mphp_ver 84 --mphp_addons --php_extensions "redis imagick fileinfo"

# 重启对应 FPM
systemctl restart php84-fpm || service php84-fpm restart
```

#### 6.18 配置检测与重载

```bash
# Nginx
/usr/local/nginx/sbin/nginx -t
systemctl reload nginx || service nginx reload

# PHP-FPM
/usr/local/php/sbin/php-fpm -t
systemctl restart php-fpm || service php-fpm restart

# MySQL
systemctl status mysqld

# Redis
/usr/local/redis/bin/redis-cli ping
systemctl restart redis-server || systemctl restart redis
```

#### 6.19 证书与默认页相关命令

```bash
# 新增站点并申请 Let's Encrypt
./vhost.sh --add --letsencrypt

# 查看 acme.sh 证书列表
~/.acme.sh/acme.sh --list

# 手动触发一次证书续签任务
~/.acme.sh/acme.sh --cron -f

# 重新生成默认演示页（会更新 default/index.html）
oneinstack_dir=$(pwd)
. ./versions.txt
. ./options.conf
. ./include/check_dir.sh
. ./include/download.sh
. ./include/demo.sh
DEMO
```

#### 6.20 日志与排障命令

```bash
# 安装日志
tail -n 200 install.log
tail -f install.log

# Web 日志
tail -f /data/wwwlogs/*.log

# 服务日志
journalctl -u nginx -n 100 --no-pager
journalctl -u php-fpm -n 100 --no-pager
journalctl -u mysqld -n 100 --no-pager
journalctl -u redis-server -n 100 --no-pager

# 端口监听检查
ss -lntp | grep -E ':80|:443|:3306|:6379|:9000'
```

### 7. 常用服务管理命令

```bash
systemctl {start|stop|status|restart|reload} nginx
systemctl {start|stop|status|restart|reload} php-fpm
systemctl {start|stop|status|restart|reload} mysqld
systemctl {start|stop|status|restart|reload} redis-server
systemctl {start|stop|status|restart|reload} memcached

# 开机自启（常用）
systemctl enable nginx php-fpm mysqld
systemctl enable redis-server || systemctl enable redis
systemctl enable memcached
```

兼容环境（无 systemd）可用：

```bash
service nginx restart
service php-fpm restart
service mysqld restart
```

### 8. 安装后验证

```bash
nginx -v
/usr/local/php/bin/php -v
/usr/local/mysql/bin/mysql --version
/usr/local/php/bin/php -m | sort
/usr/local/php/bin/php --ri fileinfo
/usr/local/php/bin/php --ri redis
```

默认站点目录通常为：

```bash
/data/wwwroot/default
```

安装成功后默认页会生成 `index.html`，并提供 `xprober.php`、`phpinfo.php`、`ocp.php` 等快捷入口（按组件安装情况显示）。

### 9. 常见问题

#### 9.1 PHP 8.5 的 OPcache 是否生效？

- PHP 8.5 本身可内置 OPcache 能力
- 即使没有独立 `opcache.so` 文件，`php -v`/OPcache 面板显示启用时通常仍可正常工作

#### 9.2 缺少 Perl 模块导致 OpenSSL 编译失败

若出现 `Can't locate Time/Piece.pm`，先安装 Perl 组件后重试：

```bash
yum -y install perl perl-Time-Piece || dnf -y install perl perl-Time-Piece
# Debian/Ubuntu:
apt-get -y install perl
```

#### 9.3 Redis 缓存为什么不生效？

需要同时满足：

- PHP `redis` 扩展已安装
- Redis 服务端已安装并运行
- 网站端已正确配置对象缓存插件

#### 和oneinstack关系

- oneinstack由于众所周知的原因，这里就不说了，因为我习惯了oneinstack之前的操作方式，所以就根据自己的需求进行单独维护。
- 各种命令和oneinstack是一样，这就是一个分支，只是在原来的代码上进行优化

#### 自己搭建镜像网站项目推荐

- https://github.com/dalao-org/MirrorOne
- 如果你的服务器不是中国内地的服务器，直接用他这个镜像网站就行的。
  
  
## English Summary

QILNMP is a community-maintained fork of OneinStack focused on practical LNMP/LAMP deployment and maintenance.

- Interactive shell installer with source-based builds
- Mirror/custom URL/offline package fallback for source downloads
- Supports major web/database stacks and multiple PHP versions
- Includes vhost, backup, upgrade, uninstall, and status-check scripts

## Community

- QQ 群: `16966111`
- Project site: <https://qiling.jingxialai.com>
- Project repo: <https://github.com/wujiit/qilnmp>
- Upstream OneinStack Repo: <https://github.com/oneinstack/oneinstack>
