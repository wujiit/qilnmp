# QILNMP `src/` 离线源码包清单（LNMP 常用）

这份清单用于指导用户自行从官网下载文件包并上传到 `src/` 目录。

- 上传目录：`qilnmp/src/`
- 命名要求：文件名必须与脚本期望完全一致（区分大小写）
- 版本来源：优先使用当前安装时生效的版本变量（`versions.txt` + 镜像版本同步）
- 下载优先级：本地 `src/` > `mirror_link` > `custom_src_urls.conf` > `src_url_backup` > `mirror_fallback_links` > 官方回源

## 1. LNMP 最常见必备包（Nginx + PHP 8.4/8.5）

| 组件 | 放到 `src/` 的文件名 | 官方下载示例 |
|---|---|---|
| Nginx | `nginx-<nginx_ver>.tar.gz` | `https://nginx.org/download/nginx-<nginx_ver>.tar.gz` |
| PCRE | `pcre-<pcre_ver>.tar.gz` | `https://sourceforge.net/projects/pcre/files/pcre/<pcre_ver>/pcre-<pcre_ver>.tar.gz` |
| jemalloc | `jemalloc-<jemalloc_ver>.tar.bz2` | `https://github.com/jemalloc/jemalloc/releases/download/<ver>/jemalloc-<jemalloc_ver>.tar.bz2` |
| OpenSSL（给 Nginx） | `openssl-<openssl3_ver>.tar.gz` | `https://github.com/openssl/openssl/releases/download/openssl-<openssl3_ver>/openssl-<openssl3_ver>.tar.gz` |
| PHP | `php-<php84_ver>.tar.gz` / `php-<php85_ver>.tar.gz` | `https://www.php.net/distributions/php-<php_ver>.tar.gz` |
| libiconv | `libiconv-<libiconv_ver>.tar.gz` | `https://ftp.gnu.org/pub/gnu/libiconv/libiconv-<libiconv_ver>.tar.gz` |
| curl | `curl-<curl_ver>.tar.gz` | `https://curl.se/download/curl-<curl_ver>.tar.gz` |
| libmcrypt（兼容） | `libmcrypt-<libmcrypt_ver>.tar.gz` | `https://downloads.sourceforge.net/project/mcrypt/Libmcrypt/<libmcrypt_ver>/libmcrypt-<libmcrypt_ver>.tar.gz` |
| mcrypt（兼容） | `mcrypt-<mcrypt_ver>.tar.gz` | `https://downloads.sourceforge.net/project/mcrypt/MCrypt/<mcrypt_ver>/mcrypt-<mcrypt_ver>.tar.gz` |
| freetype | `freetype-<freetype_ver>.tar.gz` | `https://downloads.sourceforge.net/project/freetype/freetype2/<freetype_ver>/freetype-<freetype_ver>.tar.gz` |
| argon2 | `argon2-<argon2_ver>.tar.gz` | `https://github.com/P-H-C/phc-winner-argon2/archive/refs/tags/<argon2_ver>.tar.gz` |
| libsodium | `libsodium-<libsodium_up_ver>.tar.gz` | `https://download.libsodium.org/libsodium/releases/libsodium-<libsodium_up_ver>.tar.gz` |
| libzip | `libzip-<libzip_ver>.tar.gz` | `https://libzip.org/download/libzip-<libzip_ver>.tar.gz` |
| libxml2 | `libxml2-<libxml2_ver>.tar.xz` | `https://download.gnome.org/sources/libxml2/<major.minor>/libxml2-<libxml2_ver>.tar.xz` |
| zlib | `zlib-<zlib_ver>.tar.gz` | `https://zlib.net/zlib-<zlib_ver>.tar.gz` |
| mhash | `mhash-<mhash_ver>.tar.gz` | `https://downloads.sourceforge.net/project/mhash/mhash/<mhash_ver>/mhash-<mhash_ver>.tar.gz` |

示例（你提到的命名）：

- `nginx-1.29.7.tar.gz`
- `php-8.5.3.tar.gz`

## 2. MySQL 常见包（按安装方式）

### 二进制安装（`dbinstallmethod=1`）

- `mysql-<mysql80_ver>-linux-glibc2.28-x86_64.tar.xz`（优先）
- 或 `mysql-<mysql80_ver>-linux-glibc2.12-x86_64.tar.xz`（兼容）

### 源码安装（`dbinstallmethod=2`）

- `mysql-<mysql80_ver>.tar.gz`
- `boost_<x_y_z>.tar.gz`（脚本会按 `boost_ver` 计算出文件名）

## 3. 常见可选组件（按需）

| 组件 | 放到 `src/` 的文件名 | 官方下载示例 |
|---|---|---|
| Redis 服务端 | `redis-<redis_ver>.tar.gz` | `http://download.redis.io/releases/redis-<redis_ver>.tar.gz` |
| PHP Redis 扩展 | `redis-<pecl_redis_ver>.tgz` | `https://pecl.php.net/get/redis-<pecl_redis_ver>.tgz` |
| ImageMagick | `ImageMagick-<imagemagick_ver>.tar.gz` | `https://imagemagick.org/archive/ImageMagick-<imagemagick_ver>.tar.gz` |
| imagick 扩展 | `imagick-<imagick_ver>.tgz` | `https://pecl.php.net/get/imagick-<imagick_ver>.tgz` |
| phpMyAdmin | `phpMyAdmin-<phpmyadmin_ver>-all-languages.tar.gz` | `https://files.phpmyadmin.net/phpMyAdmin/<phpmyadmin_ver>/phpMyAdmin-<phpmyadmin_ver>-all-languages.tar.gz` |
| Pure-FTPd | `pure-ftpd-<pureftpd_ver>.tar.gz` | `https://download.pureftpd.org/pub/pure-ftpd/releases/pure-ftpd-<pureftpd_ver>.tar.gz` |
| Memcached 服务端 | `memcached-<memcached_ver>.tar.gz` | `https://www.memcached.org/files/memcached-<memcached_ver>.tar.gz` |

## 4. 快速自检命令

在 `qilnmp` 目录执行：

```bash
ls -lh src | egrep 'nginx-|php-|openssl-|pcre-|mysql-|libiconv-|curl-|argon2-|libsodium-|libzip-|libxml2-|zlib-|redis-|ImageMagick-|imagick-|phpMyAdmin-'
```

## 5. 实操建议

- 只放你本次要安装的版本，不要在 `src/` 堆很多历史包。
- 文件名不要改名，不要带额外后缀（例如 `(1)`、`_new`）。
- 如果你启用了镜像同步，版本号可能被自动调整，建议安装前先看安装输出确认最终版本。
- `src/` 有包时会直接优先使用本地包，不会强制再去官方下载。

## 6. 镜像 `_redirects` 使用说明

当前运行逻辑不会再内置额外镜像域名；如果你配置了 `mirror_link` 或 `mirror_fallback_links`，脚本会优先从这些镜像的 `_redirects` 读取官方回源地址映射。

如果你想核对自己镜像里有哪些文件支持官方回源，建议直接抓取你当前配置的镜像：

```bash
curl -fsSL https://your-mirror.example.com/_redirects
```

如果某个文件在 `_redirects` 里不存在，建议：

- 直接把文件上传到本地 `src/`
- 或在 `config/custom_src_urls.conf` 里补一条自定义下载地址
