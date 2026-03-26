#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

def load_kv_file(path: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


def load_latest_versions(path: Path) -> Dict[str, str]:
    obj = json.loads(path.read_text(encoding="utf-8"))
    return (obj.get("versions") or {}) if isinstance(obj, dict) else {}


def load_resource_index(path: Path) -> Tuple[Dict[str, str], Dict[str, str]]:
    obj = json.loads(path.read_text(encoding="utf-8"))
    file_to_url: Dict[str, str] = {}
    file_to_source: Dict[str, str] = {}
    if not isinstance(obj, dict):
        return file_to_url, file_to_source
    srcs = obj.get("sources") or {}
    if not isinstance(srcs, dict):
        return file_to_url, file_to_source
    for source, items in srcs.items():
        if not isinstance(items, list):
            continue
        for item in items:
            if not isinstance(item, dict):
                continue
            f = item.get("file")
            u = item.get("url")
            if f and f not in file_to_url:
                file_to_url[f] = u or ""
                file_to_source[f] = str(source)
    return file_to_url, file_to_source


def load_redirects(path: Path) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        src_path, dst_url = parts[0], parts[1]
        name = src_path.rsplit("/", 1)[-1]
        out[name] = dst_url
    return out


def pick_first(d: Dict[str, str], keys: List[str]) -> str:
    for k in keys:
        v = d.get(k)
        if v:
            return v
    return ""


def render_template(tpl: str, v: str, sv: str) -> str:
    return tpl.format(v=v, vdot=v.replace("_", "."), vdash=v.replace("_", "-"), vus=v.replace(".", "_"), sv=sv)


def status_of(exact_mirror: bool, alt_mirror: bool, exact_redirect: bool, alt_redirect: bool) -> str:
    if exact_mirror:
        return "aligned"
    if alt_mirror:
        return "mismatch"
    if exact_redirect:
        return "fallback_only"
    if alt_redirect:
        return "mapping_needed"
    return "missing"


def action_of(status: str) -> str:
    return {
        "aligned": "No change",
        "mismatch": "Adjust file name mapping/template",
        "fallback_only": "Keep fallback; consider caching this file",
        "mapping_needed": "Add mapping to mirror naming + fallback",
        "missing": "Add custom URL or local cache file",
    }[status]


def make_items() -> List[Dict[str, object]]:
    return [
        {"cat": "Web", "name": "Nginx", "keys": ["nginx_ver"], "tpl": "nginx-{v}.tar.gz"},
        {"cat": "Web", "name": "OpenResty", "keys": ["openresty_ver"], "tpl": "openresty-{v}.tar.gz"},
        {"cat": "Web", "name": "Tengine", "keys": ["tengine_ver"], "tpl": "tengine-{v}.tar.gz"},
        {"cat": "Web", "name": "PCRE", "keys": ["pcre_ver"], "tpl": "pcre-{v}.tar.gz"},
        {"cat": "Web", "name": "jemalloc", "keys": ["jemalloc_ver"], "tpl": "jemalloc-{v}.tar.bz2"},
        {"cat": "Web", "name": "nghttp2", "keys": ["nghttp2_ver"], "tpl": "nghttp2-{v}.tar.gz"},

        {"cat": "DB", "name": "MySQL 8.0 (binary)", "keys": ["mysql80_ver"], "tpl": "mysql-{v}-linux-glibc2.28-x86_64.tar.xz", "alt_tpls": ["mysql-{v}-linux-glibc2.12-x86_64.tar.xz"]},
        {"cat": "DB", "name": "MySQL 9.0 (binary)", "keys": ["mysql90_ver"], "tpl": "mysql-{v}-linux-glibc2.28-x86_64.tar.xz"},
        {"cat": "DB", "name": "Boost (MySQL source build)", "keys": ["boost_ver"], "tpl": "boost_{vus}.tar.gz"},
        {"cat": "DB", "name": "Redis (server)", "keys": ["redis_ver"], "tpl": "redis-{v}.tar.gz"},
        {"cat": "DB", "name": "Memcached (server)", "keys": ["memcached_ver"], "tpl": "memcached-{v}.tar.gz"},

        {"cat": "PHP Core", "name": "PHP 8.4", "keys": ["php84_ver"], "tpl": "php-{v}.tar.gz"},
        {"cat": "PHP Core", "name": "PHP 8.5", "keys": ["php85_ver"], "tpl": "php-{v}.tar.gz"},

        {"cat": "PHP Deps", "name": "argon2", "keys": ["argon2_ver"], "tpl": "argon2-{v}.tar.gz"},
        {"cat": "PHP Deps", "name": "libsodium", "keys": ["libsodium_up_ver", "libsodium_ver"], "meta_keys": ["libsodium_ver"], "tpl": "libsodium-{v}.tar.gz"},
        {"cat": "PHP Deps", "name": "libzip", "keys": ["libzip_ver"], "tpl": "libzip-{v}.tar.gz"},
        {"cat": "PHP Deps", "name": "ICU4C", "keys": ["icu4c_ver"], "tpl": "icu4c-{v}-src.tgz", "alt_tpls": ["icu4c-{vdot}-sources.tgz"]},
        {"cat": "PHP Deps", "name": "libxml2", "keys": ["libxml2_ver"], "tpl": "libxml2-{v}.tar.xz"},
        {"cat": "PHP Deps", "name": "zlib", "keys": ["zlib_ver"], "tpl": "zlib-{v}.tar.gz"},
        {"cat": "PHP Deps", "name": "curl", "keys": ["curl_ver"], "tpl": "curl-{v}.tar.gz"},
        {"cat": "PHP Deps", "name": "libiconv", "keys": ["libiconv_ver"], "tpl": "libiconv-{v}.tar.gz"},
        {"cat": "PHP Deps", "name": "freetype", "keys": ["freetype_ver"], "tpl": "freetype-{v}.tar.gz"},

        {"cat": "PHP Image", "name": "ImageMagick", "keys": ["imagemagick_ver"], "tpl": "ImageMagick-{v}.tar.gz", "alt_use_suggest": True},
        {"cat": "PHP Image", "name": "imagick", "keys": ["imagick_ver"], "tpl": "imagick-{v}.tgz"},
        {"cat": "PHP Image", "name": "GraphicsMagick", "keys": ["graphicsmagick_ver"], "tpl": "GraphicsMagick-{v}.tar.gz"},
        {"cat": "PHP Image", "name": "gmagick", "keys": ["gmagick_ver"], "tpl": "gmagick-{v}.tgz"},

        {"cat": "PHP Ext", "name": "APCu", "keys": ["apcu_ver"], "tpl": "apcu-{v}.tgz"},
        {"cat": "PHP Ext", "name": "Xdebug", "keys": ["xdebug_ver"], "tpl": "xdebug-{v}.tgz"},
        {"cat": "PHP Ext", "name": "Swoole", "keys": ["swoole_ver"], "tpl": "swoole-{v}.tgz"},
        {"cat": "PHP Ext", "name": "Yaf", "keys": ["yaf_ver"], "tpl": "yaf-{v}.tgz"},
        {"cat": "PHP Ext", "name": "Yar", "keys": ["yar_ver"], "tpl": "yar-{v}.tgz"},
        {"cat": "PHP Ext", "name": "redis (pecl)", "keys": ["pecl_redis_ver"], "tpl": "redis-{v}.tgz"},
        {"cat": "PHP Ext", "name": "memcached (pecl)", "keys": ["pecl_memcached_ver"], "tpl": "memcached-{v}.tgz"},
        {"cat": "PHP Ext", "name": "memcache (pecl)", "keys": ["pecl_memcache_ver"], "tpl": "memcache-{v}.tgz"},
        {"cat": "PHP Ext", "name": "mongodb (pecl)", "keys": ["pecl_mongodb_ver"], "tpl": "mongodb-{v}.tgz"},
        {"cat": "PHP Ext", "name": "mongo (legacy pecl)", "keys": ["pecl_mongo_ver"], "tpl": "mongo-{v}.tgz"},
        {"cat": "PHP Ext", "name": "Phalcon", "keys": ["phalcon_ver"], "tpl": "cphalcon-v{v}.tar.gz", "alt_tpls": ["phalcon-{v}.tgz"]},
        {"cat": "PHP Tools", "name": "phpMyAdmin", "keys": ["phpmyadmin_ver"], "tpl": "phpMyAdmin-{v}-all-languages.tar.gz"},
    ]


def normalize_url(url: str) -> str:
    return url.strip().rstrip("/")


def resolve_mirror_base(oneinstack_dir: Path, explicit_base: str) -> str:
    base = normalize_url(explicit_base)
    if base:
        return base

    options_path = oneinstack_dir / "options.conf"
    if not options_path.exists():
        return ""

    return normalize_url(load_kv_file(options_path).get("mirror_link", ""))


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate PHP env alignment checklist based on mirror metadata")
    ap.add_argument("--oneinstack-dir", default=".")
    ap.add_argument("--mirror-base", default="")
    ap.add_argument("--suggest", default="/tmp/suggest_versions.txt")
    ap.add_argument("--latest", default="/tmp/mirror_latest_meta.json")
    ap.add_argument("--resource", default="/tmp/mirror_resource.json")
    ap.add_argument("--redirects", default="/tmp/mirror_redirects.txt")
    ap.add_argument("--output", default="PHP_ENV_ALIGNMENT_CHECKLIST.md")
    args = ap.parse_args()

    oneinstack_dir = Path(args.oneinstack_dir).resolve()
    mirror_base = resolve_mirror_base(oneinstack_dir, args.mirror_base)
    versions = load_kv_file(oneinstack_dir / "versions.txt")
    suggest = load_kv_file(Path(args.suggest))
    latest = load_latest_versions(Path(args.latest))
    file_to_url, file_to_source = load_resource_index(Path(args.resource))
    redirects = load_redirects(Path(args.redirects))

    items = make_items()
    rows: List[Dict[str, str]] = []
    counts = {"aligned": 0, "mismatch": 0, "fallback_only": 0, "mapping_needed": 0, "missing": 0}

    for it in items:
        keys: List[str] = it["keys"]  # type: ignore[index]
        k = keys[0]
        v = pick_first(versions, keys)
        meta_keys = it.get("meta_keys", keys)  # type: ignore[assignment]
        sv = pick_first(suggest, list(meta_keys))
        lv = pick_first(latest, list(meta_keys))
        tpl = str(it["tpl"])

        expected = render_template(tpl, v, sv)
        exact_mirror = expected in file_to_url
        exact_redirect = expected in redirects

        alt_candidates: List[str] = []
        for alt_tpl in it.get("alt_tpls", []) or []:
            alt_candidates.append(render_template(str(alt_tpl), v, sv))
        if it.get("alt_use_suggest") and sv:
            alt_candidates.append(render_template(tpl, sv, sv))

        alt_mirror_file = ""
        alt_redirect_file = ""
        for af in alt_candidates:
            if not alt_mirror_file and af in file_to_url:
                alt_mirror_file = af
            if not alt_redirect_file and af in redirects:
                alt_redirect_file = af

        st = status_of(exact_mirror, bool(alt_mirror_file), exact_redirect, bool(alt_redirect_file))
        counts[st] += 1

        mirror_url = file_to_url.get(expected, "")
        if not mirror_url and alt_mirror_file:
            mirror_url = file_to_url.get(alt_mirror_file, "")

        redirect_url = redirects.get(expected, "")
        if not redirect_url and alt_redirect_file:
            redirect_url = redirects.get(alt_redirect_file, "")

        note = ""
        if st == "mismatch":
            note = f"mirror has `{alt_mirror_file}`"
        elif st == "mapping_needed":
            note = f"_redirects has `{alt_redirect_file}`"
        elif st == "fallback_only":
            note = "not cached in mirror list, but official redirect exists"
        elif st == "missing":
            note = "no mirror file and no redirects entry"

        rows.append(
            {
                "cat": str(it["cat"]),
                "name": str(it["name"]),
                "key": k,
                "v": v,
                "sv": sv,
                "lv": lv,
                "expected": expected,
                "mirror": "yes" if expected in file_to_url else ("alt" if alt_mirror_file else "no"),
                "redirect": "yes" if expected in redirects else ("alt" if alt_redirect_file else "no"),
                "status": st,
                "action": action_of(st),
                "note": note,
                "mirror_url": mirror_url,
                "redirect_url": redirect_url,
            }
        )

    out_path = Path(args.output)
    if not out_path.is_absolute():
        out_path = oneinstack_dir / out_path

    ts = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    lines: List[str] = []
    lines.append("# PHP Environment Alignment Checklist")
    lines.append("")
    lines.append(f"Generated at: {ts}")
    if mirror_base:
        lines.append(f"Mirror metadata: {mirror_base}/suggest_versions.txt, {mirror_base}/latest_meta.json, {mirror_base}/resource.json, {mirror_base}/_redirects")
    else:
        lines.append("Mirror metadata: (not resolved from options.conf or --mirror-base)")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- aligned: {counts['aligned']}")
    lines.append(f"- mismatch (naming/version mapping needed): {counts['mismatch']}")
    lines.append(f"- fallback_only (official redirect exists): {counts['fallback_only']}")
    lines.append(f"- mapping_needed (only alt naming in redirects/mirror): {counts['mapping_needed']}")
    lines.append(f"- missing (need custom URL or local cache): {counts['missing']}")
    lines.append("")

    lines.append("## Priority Fix List")
    lines.append("")
    for pri in ["missing", "mapping_needed", "mismatch", "fallback_only"]:
        sub = [r for r in rows if r["status"] == pri]
        if not sub:
            continue
        lines.append(f"### {pri}")
        lines.append("")
        for r in sub:
            lines.append(f"- `{r['name']}` (`{r['key']}={r['v']}`) -> `{r['expected']}`; action: {r['action']}; note: {r['note'] or '-'}")
        lines.append("")

    lines.append("## Detailed Table")
    lines.append("")
    lines.append("| Category | Component | versions.txt | suggest/latest | Expected file (current script) | Mirror | Redirect | Status | Action |")
    lines.append("|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        sl = f"{r['sv'] or '-'} / {r['lv'] or '-'}"
        lines.append(
            f"| {r['cat']} | {r['name']} | `{r['key']}={r['v']}` | `{sl}` | `{r['expected']}` | {r['mirror']} | {r['redirect']} | {r['status']} | {r['action']} |"
        )

    lines.append("")
    lines.append("## Object Storage & Common Web App Stack (Not bundled by oneinstack source downloader)")
    lines.append("")
    lines.append("- S3/MinIO: usually via Composer `aws/aws-sdk-php` (S3 API compatible)")
    lines.append("- Aliyun OSS: usually via Composer `aliyuncs/oss-sdk-php`")
    lines.append("- Tencent COS: usually via Composer `qcloud/cos-sdk-v5`")
    lines.append("- Qiniu Kodo: usually via Composer `qiniu/php-sdk`")
    lines.append("- These are app-layer SDK dependencies and are not mirrored as `oneinstack/src/*` install tarballs by default.")
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- `mirror=alt` means current expected filename is not present, but mirror has another naming/version file for same component.")
    lines.append("- `redirect=alt` means `_redirects` has alternate naming mapping, not the current expected filename.")
    lines.append("- For items marked `missing`, use custom URL rules in `config/custom_src_urls.conf` or upload package into `oneinstack/src/`.")

    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(str(out_path))


if __name__ == "__main__":
    main()
