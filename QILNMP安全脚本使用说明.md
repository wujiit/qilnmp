# QILNMP 安全脚本使用说明

这份文档是给服务器使用者看的，不是给开发者看的。

如果你只想知道怎么用，记住这一条就够了：

```bash
cd qilnmp
./security.sh --install
```

执行完以后，再看一下状态：

```bash
./security.sh --status
```

---

## 这是什么

`security.sh` 是 QILNMP 提供的基础安全脚本，适用于：

- `Nginx / Tengine / OpenResty`
- `PHP` 网站
- 普通博客、企业站、CMS 站点

它做的事情很简单：

1. 用 `Nginx` 对访问过快的请求做限速
2. 对持续异常的 IP 返回 `429`
3. 用 `Fail2ban` 读取日志，把反复触发异常的 IP 自动拉黑

它适合做基础防护，比如：

- 简单 `CC`
- 扫描型访问
- 短时间高频刷站

它不是专业 `WAF`，也不是高防，不负责拦截复杂注入攻击或大流量 `DDoS`。

---

## 使用前先看

运行这个脚本前，请先确认：

- 你已经安装好了 `QILNMP`
- 当前服务器用的是 `Nginx`
- 你是 `root` 用户

这个脚本只考虑 `Nginx`，不考虑 `Apache`、`Caddy`。

---

## 一分钟上手

### 第一步：进入脚本目录

```bash
cd qilnmp
```

如果你的 `qilnmp` 不在当前目录，就先进入你实际的安装目录。

### 第二步：执行安装

```bash
./security.sh --install
```

这个命令会自动完成下面这些事：

- 检测当前 `Nginx` 环境
- 检测 `Fail2ban`
- 如果系统里没有 `Fail2ban`，脚本会自动安装
- 写入 `Nginx` 基础防护规则
- 写入 `Fail2ban` 封禁规则
- 检查配置是否正常
- 重载 `Nginx` 和 `Fail2ban`

### 第三步：查看状态

```bash
./security.sh --status
```

你可以把这一步理解成“安装后自检”。

它会告诉你：

- 当前安全功能是不是已经启用
- 监控的是哪类日志
- `Fail2ban` 是否正常
- 哪些站点关闭了 `access_log`

---

## 安装完成后，实际会有什么效果

启用之后，服务器会多一层基础保护：

- 单个 IP 请求太快，会先被 `Nginx` 限制
- 如果同一个 IP 持续触发限制，会被 `Fail2ban` 自动封禁

所以它不是“看到异常马上永久拉黑”，而是两步：

1. 先限流
2. 再对持续异常的 IP 自动拉黑

这也是为什么它比较适合普通网站，而不是高对抗场景。

---

## 多站点服务器怎么生效

如果你的服务器上有多个站点，这个脚本也能一起保护。

它默认会读取：

```bash
/data/wwwlogs/*nginx.log
```

这意味着：

- 默认站点日志会参与检测
- 每个站点自己的 `nginx` 日志也会参与检测
- 同一个异常 IP 连续刷多个站点，也可能一起累计并被封禁

### 但有一个前提

如果某个站点写了：

```nginx
access_log off;
```

那么这个站点虽然还能吃到 `Nginx` 限速，但它的访问不会进入 `Fail2ban` 自动封禁统计。

所以建议你执行一次：

```bash
./security.sh --status
```

看看有没有站点关闭了访问日志。

---

## 最常用的 5 个命令

### 1. 安装并启用

```bash
./security.sh --install
```

适合第一次使用。

### 2. 查看当前状态

```bash
./security.sh --status
```

适合安装后检查、排查问题时使用。

### 3. 临时关闭

```bash
./security.sh --disable
```

适合：

- 怀疑误拦截时先暂停
- 正在排查接口访问问题
- 想先观察业务再决定是否继续开启

执行这个命令后：

- 本模块的限速和自动封禁会停用
- 但脚本生成的结构和记录会保留
- 后面还能重新开启

### 4. 重新开启

```bash
./security.sh --enable
```

适合之前关闭过，现在想重新开启。

### 5. 彻底移除

```bash
./security.sh --uninstall
```

适合：

- 不再使用这套安全脚本
- 想切换成别的方案
- 想回到未安装前状态

---

## 什么时候用 `--disable`，什么时候用 `--uninstall`

很多用户容易把这两个搞混。

### 用 `--disable`

表示“先停掉，但以后还可能再开”。

适合临时排查问题。

### 用 `--uninstall`

表示“我不要这个功能了，直接移除”。

适合你确认以后都不再使用这套方案。

如果你只是怀疑它影响了某个接口，优先用：

```bash
./security.sh --disable
```

不要一上来就卸载。

---

## 进阶：如何查看和管理被封禁的 IP (Fail2ban 操作)

因为脚本是通过源码编译安装的 `Fail2ban`，它的执行文件不在系统 `sudo` 的默认搜寻路径中，所以操作时**必须带上完整的绝对路径**。

### 1. 查看整体运行状态（有哪些监狱在运行）

```bash
sudo /usr/local/bin/fail2ban-client status
```

*这个命令会列出当前启用的所有“监狱 (Jail)”。通常会有防 CC 的 `qilnmp-nginx-cc` 监狱，也可能会有防 SSH 爆破的 `sshd` 监狱。*

### 2. 查看防 CC 监狱拦截了谁（查看具体的黑名单 IP）

```bash
sudo /usr/local/bin/fail2ban-client status qilnmp-nginx-cc
```

*执行后会清晰地展示：当前正在监控哪些日志文件、总共拦截过多少次、**现在被关在小黑屋里的有哪些具体的 IP**。*

如果想看 SSH 暴力破解的拦截情况：

```bash
sudo /usr/local/bin/fail2ban-client status sshd
```

### 3. 手动解封被误杀的 IP

如果自己测试时刷新太快，或者正常的访问 IP 被误封了，你可以用下面这个命令手动把它放出来（以解封 IP `1.2.3.4` 为例）：

```bash
sudo /usr/local/bin/fail2ban-client set qilnmp-nginx-cc unbanip 1.2.3.4
```

### 4. 实时滚动查看拦截日志

如果你想实时看着 Fail2ban 拦截坏人，可以跟踪它的日志文件：

```bash
sudo tail -f /var/log/fail2ban.log
```

---

## 用户最关心的几个问题

### 1. 这个脚本是不是只会自动拉黑 IP

不是。

它实际是两层：

- 第一层：`Nginx` 先限速
- 第二层：`Fail2ban` 再自动拉黑持续异常的 IP

### 2. 多个网站是不是要一个一个单独配置

通常不用。

只要这些站点的访问日志在 `/data/wwwlogs/` 下面，脚本就会一起监控。

### 3. 我以后想关闭，能不能关

可以。

直接执行：

```bash
./security.sh --disable
```

如果以后又想恢复：

```bash
./security.sh --enable
```

### 4. 这个脚本是不是 `WAF`

不是。

它是“基础安全防护”，不是完整 `WAF`。

它能做的是：

- 基础限流
- 自动封禁异常 IP

它不能代替：

- 云 `WAF`
- 专业高防
- 复杂攻击规则系统

---

## 建议这样使用

普通用户按这个顺序就行：

1. 进入 `qilnmp` 目录
2. 执行 `./security.sh --install`
3. 执行 `./security.sh --status`
4. 观察一段时间网站是否正常
5. 如果没有问题，就继续保持启用
6. 如果怀疑误拦截，就先 `./security.sh --disable`

---

## 常见问题

### 1. 执行时报错：必须用 root

这个脚本需要 `root` 权限运行。

请切换到 `root` 后再执行。

### 2. 启用后网站访问异常

先不要急着删配置，先执行：

```bash
./security.sh --disable
```

如果关闭后恢复正常，说明当前规则对你的业务偏严，可以后续再调整。

### 3. 前面挂了 CDN，还能直接用吗

可以用，但前提是你已经正确配置了真实客户端 IP。

如果没有先恢复真实 IP，可能会出现：

- 识别到的是 CDN 回源 IP
- 被封的是 CDN 节点 IP
- 影响正常访问

所以用了 CDN 的服务器，先把真实 IP 配好，再启用这个脚本。

### 4. 这个脚本能防大流量攻击吗

不能。

它只能做基础防护。

如果你的网站面向公网，访问量大、风险高，建议配合：

- CDN
- 云防火墙
- 高防
- 专业 `WAF`

---

## 最后记住这几条就够了

首次启用：

```bash
cd qilnmp
./security.sh --install
./security.sh --status
```

临时关闭：

```bash
./security.sh --disable
```

重新开启：

```bash
./security.sh --enable
```

彻底移除：

```bash
./security.sh --uninstall
```
