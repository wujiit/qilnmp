# PHP Environment Alignment Checklist

Generated at: 2026-03-24 19:56:53
Mirror metadata: generated from a historical mirror snapshot. Actual runtime mirror selection now follows options.conf (`mirror_link` / `mirror_fallback_links`).

## Summary

- aligned: 34
- mismatch (naming/version mapping needed): 0
- fallback_only (official redirect exists): 0
- mapping_needed (only alt naming in redirects/mirror): 0
- missing (need custom URL or local cache): 4

## Priority Fix List

### missing

- `libxml2` (`libxml2_ver=2.9.14`) -> `libxml2-2.9.14.tar.xz`; action: Add custom URL or local cache file; note: no mirror file and no redirects entry
- `zlib` (`zlib_ver=1.3.1`) -> `zlib-1.3.1.tar.gz`; action: Add custom URL or local cache file; note: no mirror file and no redirects entry
- `GraphicsMagick` (`graphicsmagick_ver=1.3.40`) -> `GraphicsMagick-1.3.40.tar.gz`; action: Add custom URL or local cache file; note: no mirror file and no redirects entry
- `phpMyAdmin` (`phpmyadmin_ver=5.2.3`) -> `phpMyAdmin-5.2.3-all-languages.tar.gz`; action: Add custom URL or local cache file; note: no mirror file and no redirects entry

## Detailed Table

| Category | Component | versions.txt | suggest/latest | Expected file (current script) | Mirror | Redirect | Status | Action |
|---|---|---|---|---|---|---|---|---|
| Web | Nginx | `nginx_ver=1.29.6` | `1.29.6 / 1.29.6` | `nginx-1.29.6.tar.gz` | yes | yes | aligned | No change |
| Web | OpenResty | `openresty_ver=1.27.1.2` | `1.27.1.2 / 1.27.1.2` | `openresty-1.27.1.2.tar.gz` | yes | yes | aligned | No change |
| Web | Tengine | `tengine_ver=3.1.0` | `3.1.0 / 3.1.0` | `tengine-3.1.0.tar.gz` | yes | yes | aligned | No change |
| Web | PCRE | `pcre_ver=8.45` | `8.45 / 8.45` | `pcre-8.45.tar.gz` | yes | yes | aligned | No change |
| Web | jemalloc | `jemalloc_ver=5.3.0` | `5.3.0 / 5.3.0` | `jemalloc-5.3.0.tar.bz2` | yes | yes | aligned | No change |
| Web | nghttp2 | `nghttp2_ver=1.68.1` | `1.68.1 / 1.68.1` | `nghttp2-1.68.1.tar.gz` | yes | yes | aligned | No change |
| DB | MySQL 8.0 (binary) | `mysql80_ver=8.0.44` | `8.0.44 / 8.0.44` | `mysql-8.0.44-linux-glibc2.28-x86_64.tar.xz` | yes | yes | aligned | No change |
| DB | MySQL 9.0 (binary) | `mysql90_ver=9.0.1` | `9.0.1 / 9.0.1` | `mysql-9.0.1-linux-glibc2.28-x86_64.tar.xz` | yes | yes | aligned | No change |
| DB | Boost (MySQL source build) | `boost_ver=1.90.0` | `1.90.0 / 1.90.0` | `boost_1_90_0.tar.gz` | yes | yes | aligned | No change |
| DB | Redis (server) | `redis_ver=8.6.1` | `8.6.1 / 8.6.1` | `redis-8.6.1.tar.gz` | yes | yes | aligned | No change |
| DB | Memcached (server) | `memcached_ver=1.6.9` | `1.6.9 / 1.6.9` | `memcached-1.6.9.tar.gz` | yes | yes | aligned | No change |
| PHP Core | PHP 8.4 | `php84_ver=8.4.18` | `8.4.18 / 8.4.18` | `php-8.4.18.tar.gz` | yes | yes | aligned | No change |
| PHP Core | PHP 8.5 | `php85_ver=8.5.3` | `- / -` | `php-8.5.3.tar.gz` | yes | yes | aligned | No change |
| PHP Deps | argon2 | `argon2_ver=20190702` | `20190702 / 20190702` | `argon2-20190702.tar.gz` | yes | yes | aligned | No change |
| PHP Deps | libsodium | `libsodium_up_ver=1.0.21` | `1.0.21 / 1.0.21` | `libsodium-1.0.21.tar.gz` | yes | yes | aligned | No change |
| PHP Deps | libzip | `libzip_ver=1.11.4` | `1.11.4 / 1.11.4` | `libzip-1.11.4.tar.gz` | yes | yes | aligned | No change |
| PHP Deps | ICU4C | `icu4c_ver=77_1` | `release-78.3 / release-78.3` | `icu4c-77_1-src.tgz` | yes | yes | aligned | No change |
| PHP Deps | libxml2 | `libxml2_ver=2.9.14` | `- / -` | `libxml2-2.9.14.tar.xz` | no | no | missing | Add custom URL or local cache file |
| PHP Deps | zlib | `zlib_ver=1.3.1` | `- / -` | `zlib-1.3.1.tar.gz` | no | no | missing | Add custom URL or local cache file |
| PHP Deps | curl | `curl_ver=8.19.0` | `8.19.0 / 8.19.0` | `curl-8.19.0.tar.gz` | yes | yes | aligned | No change |
| PHP Deps | libiconv | `libiconv_ver=1.7` | `1.7 / 1.7` | `libiconv-1.7.tar.gz` | yes | yes | aligned | No change |
| PHP Deps | freetype | `freetype_ver=2.10.0` | `2.10.0 / 2.10.0` | `freetype-2.10.0.tar.gz` | yes | yes | aligned | No change |
| PHP Image | ImageMagick | `imagemagick_ver=6.9.13-43` | `6.9.13-43 / 6.9.13-43` | `ImageMagick-6.9.13-43.tar.gz` | yes | yes | aligned | No change |
| PHP Image | imagick | `imagick_ver=3.8.1` | `3.8.1 / 3.8.1` | `imagick-3.8.1.tgz` | yes | yes | aligned | No change |
| PHP Image | GraphicsMagick | `graphicsmagick_ver=1.3.40` | `- / -` | `GraphicsMagick-1.3.40.tar.gz` | no | no | missing | Add custom URL or local cache file |
| PHP Image | gmagick | `gmagick_ver=2.0.6RC1` | `2.0.6RC1 / 2.0.6RC1` | `gmagick-2.0.6RC1.tgz` | yes | yes | aligned | No change |
| PHP Ext | APCu | `apcu_ver=5.1.28` | `5.1.28 / 5.1.28` | `apcu-5.1.28.tgz` | yes | yes | aligned | No change |
| PHP Ext | Xdebug | `xdebug_ver=3.5.1` | `3.5.1 / 3.5.1` | `xdebug-3.5.1.tgz` | yes | yes | aligned | No change |
| PHP Ext | Swoole | `swoole_ver=6.2.0` | `6.2.0 / 6.2.0` | `swoole-6.2.0.tgz` | yes | yes | aligned | No change |
| PHP Ext | Yaf | `yaf_ver=3.3.7` | `3.3.7 / 3.3.7` | `yaf-3.3.7.tgz` | yes | yes | aligned | No change |
| PHP Ext | Yar | `yar_ver=2.3.4` | `2.3.4 / 2.3.4` | `yar-2.3.4.tgz` | yes | yes | aligned | No change |
| PHP Ext | redis (pecl) | `pecl_redis_ver=6.3.0` | `6.3.0 / 6.3.0` | `redis-6.3.0.tgz` | yes | yes | aligned | No change |
| PHP Ext | memcached (pecl) | `pecl_memcached_ver=3.4.0` | `3.4.0 / 3.4.0` | `memcached-3.4.0.tgz` | yes | yes | aligned | No change |
| PHP Ext | memcache (pecl) | `pecl_memcache_ver=8.2` | `8.2 / 8.2` | `memcache-8.2.tgz` | yes | yes | aligned | No change |
| PHP Ext | mongodb (pecl) | `pecl_mongodb_ver=2.2.1` | `2.2.1 / 2.2.1` | `mongodb-2.2.1.tgz` | yes | yes | aligned | No change |
| PHP Ext | mongo (legacy pecl) | `pecl_mongo_ver=1.6.16` | `1.6.16 / 1.6.16` | `mongo-1.6.16.tgz` | yes | yes | aligned | No change |
| PHP Ext | Phalcon | `phalcon_ver=5.10.0` | `5.10.0 / 5.10.0` | `cphalcon-v5.10.0.tar.gz` | yes | yes | aligned | No change |
| PHP Tools | phpMyAdmin | `phpmyadmin_ver=5.2.3` | `5.2.3 / 5.2.3` | `phpMyAdmin-5.2.3-all-languages.tar.gz` | no | no | missing | Add custom URL or local cache file |

## Object Storage & Common Web App Stack (Not bundled by oneinstack source downloader)

- S3/MinIO: usually via Composer `aws/aws-sdk-php` (S3 API compatible)
- Aliyun OSS: usually via Composer `aliyuncs/oss-sdk-php`
- Tencent COS: usually via Composer `qcloud/cos-sdk-v5`
- Qiniu Kodo: usually via Composer `qiniu/php-sdk`
- These are app-layer SDK dependencies and are not mirrored as `oneinstack/src/*` install tarballs by default.

## Notes

- `mirror=alt` means current expected filename is not present, but mirror has another naming/version file for same component.
- `redirect=alt` means `_redirects` has alternate naming mapping, not the current expected filename.
- For items marked `missing`, use custom URL rules in `config/custom_src_urls.conf` or upload package into `oneinstack/src/`.
