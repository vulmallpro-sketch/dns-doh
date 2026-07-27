# dns-doh

基于 `AdGuard Home + Nginx` 的私有 DoH 最小部署方案，使用 UUID 路径做轻鉴权。

## 功能说明

- 使用 AdGuard Home 作为 DNS 后端
- 使用 Nginx 反向代理 DoH 请求
- 仅允许访问 `/dns-query/<uuid>`
- 拒绝无 UUID 的 `/dns-query` 请求（返回 `403`）

## 环境要求

- Linux 服务器（root 权限）
- 域名已解析到当前服务器（例如 `doh.example.com`）
- Nginx 已安装并可正常工作（支持宝塔站点配置路径）
- Nginx 已配置有效 TLS 证书

## 快速安装

```bash
cd /www/wwwroot/ceshi.1com
chmod +x scripts/install_bt_uuid_doh.sh
./scripts/install_bt_uuid_doh.sh --domain doh.mnhhnbb.com --site-conf /www/server/panel/vhost/nginx/ceshi.1com.conf
```

脚本执行完成后会输出：

- 生成的 UUID
- 最终可用的 DoH 地址

## 客户端配置示例（Mihomo/Clash）

```yaml
nameserver-policy:
  "+.quandao.com":
    - "https://doh.mnhhnbb.com/dns-query/<your-uuid>"
  "+.jiandaoyun.com":
    - "https://doh.mnhhnbb.com/dns-query/<your-uuid>"
```

## DoH 可用性测试

```bash
chmod +x scripts/test_doh_rfc8484.sh
./scripts/test_doh_rfc8484.sh "https://doh.mnhhnbb.com/dns-query/<your-uuid>" baidu.com
```

当输出中出现以下结果时，说明可用：

- `response_size` 非 0
- 返回了 `A_records`

## 项目文件说明

- `scripts/install_bt_uuid_doh.sh`：一键安装与配置脚本
- `scripts/test_doh_rfc8484.sh`：RFC8484 标准 DoH 测试脚本
- `nginx/doh_uuid.conf.template`：Nginx UUID 路径配置模板

## 同步到 GitHub

如果当前目录还不是 Git 仓库：

```bash
cd /www/wwwroot/ceshi.1com
git init
git add .
git commit -m "feat: add AdGuard+Nginx UUID DoH deploy scripts"
git branch -M main
git remote add origin https://github.com/vulmallpro-sketch/dns-doh.git
git push -u origin main
```

如果已存在远程仓库地址：

```bash
git remote set-url origin https://github.com/vulmallpro-sketch/dns-doh.git
git add .
git commit -m "docs: update Chinese README"
git push
```
