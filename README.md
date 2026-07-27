# dns-doh

Minimal private DoH deployment with AdGuard Home + Nginx UUID path protection.

## Features

- AdGuard Home as DNS backend
- Nginx reverse proxy for DoH
- UUID path guard: only `/dns-query/<uuid>` is allowed
- Non-UUID `/dns-query` path is blocked with `403`

## Requirements

- Linux server with root access
- A domain name pointing to this server (example: `doh.example.com`)
- Valid TLS certificate already configured in Nginx
- Nginx installed (BT panel Nginx path supported)

## Quick Install

```bash
cd /www/wwwroot/ceshi.1com
chmod +x scripts/install_bt_uuid_doh.sh
./scripts/install_bt_uuid_doh.sh --domain doh.mnhhnbb.com --site-conf /www/server/panel/vhost/nginx/ceshi.1com.conf
```

The script prints a generated UUID and final DoH URL.

## Client Example (Mihomo/Clash)

```yaml
nameserver-policy:
  "+.quandao.com":
    - "https://doh.mnhhnbb.com/dns-query/<your-uuid>"
  "+.jiandaoyun.com":
    - "https://doh.mnhhnbb.com/dns-query/<your-uuid>"
```

## Verify DoH

```bash
chmod +x scripts/test_doh_rfc8484.sh
./scripts/test_doh_rfc8484.sh "https://doh.mnhhnbb.com/dns-query/<your-uuid>" baidu.com
```

If you get a non-zero DNS response size and A records, it works.

## Files

- `scripts/install_bt_uuid_doh.sh`: install + configure script
- `scripts/test_doh_rfc8484.sh`: RFC8484 DoH test script
- `nginx/doh_uuid.conf.template`: location block template

## Sync To GitHub

If this folder is not yet a git repo:

```bash
cd /www/wwwroot/ceshi.1com
git init
git add .
git commit -m "feat: add AdGuard+Nginx UUID DoH deploy scripts"
git branch -M main
git remote add origin https://github.com/vulmallpro-sketch/dns-doh.git
git push -u origin main
```

If remote already exists:

```bash
git remote set-url origin https://github.com/vulmallpro-sketch/dns-doh.git
git add .
git commit -m "docs: add install tutorial and scripts"
git push
```
