# dns-doh

基于 `AdGuard Home + Nginx` 的私有 DoH 部署方案，支持 UUID 路径访问控制。

## 1. 这套方案做什么

- AdGuard Home 负责 DNS 解析。
- Nginx 暴露 HTTPS DoH 接口。
- 仅允许 `/dns-query/<uuid>`，其他 `/dns-query` 一律 `403`。

## 2. 安装前准备

- Linux 服务器（root 权限）
- 域名已解析到服务器（示例：`doh.mnhhnbb.com`）
- Nginx 已安装
- 域名 SSL 证书已配置好（宝塔可直接申请 Let's Encrypt）

建议开放端口：`80`、`443`。不建议对公网开放 `3000`。

## 3. 手动安装步骤（推荐先看这个）

### 第一步：安装 AdGuard Home

```bash
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh
```

安装后访问（任选一种）：

- `http://服务器IP:3000`
- `http://127.0.0.1:3000`（本机）

初始化向导建议：

- 管理地址：`0.0.0.0:3000`（需要公网管理时）
- DNS 监听：`127.0.0.1:5353`

### 第二步：确认 AdGuard DoH 路由开启

编辑 ` /opt/AdGuardHome/AdGuardHome.yaml `，确认：

```yaml
http:
  address: 0.0.0.0:3000
  doh:
    insecure_enabled: true

dns:
  bind_hosts:
    - 127.0.0.1
  port: 5353
```

重启服务：

```bash
sudo /opt/AdGuardHome/AdGuardHome -s restart
```

### 第三步：配置 Nginx UUID 路径

在你的站点 `server {}` 里加入：

```nginx
location = /dns-query/<uuid> {
    proxy_pass http://127.0.0.1:3000/dns-query;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $http_x_forwarded_for;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

location ^~ /dns-query/ {
    return 403;
}

location = /dns-query {
    return 403;
}
```

验证并重载：

```bash
nginx -t && nginx -s reload
```

最终可用地址示例：

`https://doh.mnhhnbb.com/dns-query/e9444f3c-e8e1-46af-be40-24cb76b8fe44`

## 4. 一键脚本安装（宝塔路径）

如果你已经在宝塔建好站点，可直接用脚本：

```bash
cd /www/wwwroot/ceshi.1com
chmod +x scripts/install_bt_uuid_doh.sh
./scripts/install_bt_uuid_doh.sh --domain doh.mnhhnbb.com --site-conf /www/server/panel/vhost/nginx/ceshi.1com.conf
```

脚本会：

- 生成 UUID
- 修改 AdGuard 必需项
- 修改站点 Nginx 的 DoH 路由
- 自动 `nginx -t` 与重载

## 5. 客户端配置示例（Mihomo/Clash）

```yaml
nameserver-policy:
  "+.quandao.com":
    - "https://doh.mnhhnbb.com/dns-query/<your-uuid>"
  "+.jiandaoyun.com":
    - "https://doh.mnhhnbb.com/dns-query/<your-uuid>"
```

## 6. 测试是否安装成功

### 快速连通性测试

```bash
curl -skI "https://doh.mnhhnbb.com/dns-query/<your-uuid>"
```

返回 `400` 代表已到达 DoH 端点（请求体不完整是正常的）。

### RFC8484 测试（推荐）

```bash
chmod +x scripts/test_doh_rfc8484.sh
./scripts/test_doh_rfc8484.sh "https://doh.mnhhnbb.com/dns-query/<your-uuid>" baidu.com
```

成功标准：

- `response_size` 大于 0
- `A_records` 有 IP 返回

## 7. 反向代理配置（宝塔/Nginx 二级反代）

如果用宝塔反向代理本服务，后台看不到真实客户端 IP，需要以下配置：

### Nginx 反向代理配置

在宝塔站点反向代理中配置：

```nginx
location / {
    proxy_pass https://原始DoH服务器域名或IP;
    proxy_http_version 1.1;
    proxy_set_header Host 原始服务器域名;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $server_name;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
}
```

### AdGuard Home 信任反代IP

编辑原始 DoH 服务器上的 `/opt/AdGuardHome/AdGuardHome.yaml`：

```yaml
http:
  address: 0.0.0.0:3000
  doh:
    insecure_enabled: true
  trusted_proxies:
    - 127.0.0.0/8
    - ::1/128
    - 反代服务器IP地址/32    # 填写宝塔或反代机器的公网IP
```

重启 AdGuard：

```bash
sudo /opt/AdGuardHome/AdGuardHome -s restart
```

这样 AdGuard 才会从 `X-Forwarded-For` 头部读取真实客户端 IP。

## 8. 常见问题

- 问：`/dns-query` 返回 `403` 或 `404`。
答：正常。应访问 `/dns-query/<uuid>`，并确认 `insecure_enabled: true`。

- 问：上游 `dns.alidns.com` / `doh.pub` 不可用。
答：是网络连通问题，先改为可达上游（如 `dns.google`、`cloudflare-dns` 或纯 IP DNS）。

- 问：AdGuard 后台打不开。
答：检查 `http.address` 是否绑定 `127.0.0.1`。需要公网管理就改回 `0.0.0.0:3000`。

- 问：反向代理后看不到真实客户端 IP。
答：检查两处配置：(1) 反代 nginx 是否设置了 `X-Forwarded-For` 头部；(2) AdGuard 的 `trusted_proxies` 是否包含反代服务器 IP。

- 问：DNS 重写后，腾讯等 DNS 的线路分流（多 IP）功能失效，总是返回同一个 IP。
答：需要启用 ECS（EDNS Client Subnet）功能，让 AdGuard 把真实客户端 IP 传给上游 DNS。编辑 `/opt/AdGuardHome/AdGuardHome.yaml`，找到 `edns_client_subnet` 部分，改为：
```yaml
edns_client_subnet:
  custom_ip: ""
  enabled: true
  use_custom: false
```
然后重启 AdGuard：`sudo /opt/AdGuardHome/AdGuardHome -s restart`。之后腾讯 DNS 能根据客户端 IP 返回对应线路的 CNAME 和多个 IP。

## 9. 文件说明

- `scripts/install_bt_uuid_doh.sh`：宝塔场景一键配置脚本
- `scripts/test_doh_rfc8484.sh`：DoH 标准测试脚本
- `nginx/doh_uuid.conf.template`：Nginx UUID 路由模板




https://doh.pub/dns-query
https://dns.alidns.com/dns-query
223.5.5.5
119.28.28.28
119.29.29.29