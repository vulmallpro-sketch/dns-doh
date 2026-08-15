#!/usr/bin/env bash
set -euo pipefail

DOMAIN=""
SITE_CONF=""
UUID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --site-conf)
      SITE_CONF="$2"
      shift 2
      ;;
    --uuid)
      UUID="$2"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$DOMAIN" || -z "$SITE_CONF" ]]; then
  echo "Usage: $0 --domain doh.example.com --site-conf /www/server/panel/vhost/nginx/site.conf [--uuid <uuid>]" >&2
  exit 1
fi

if [[ ! -f "$SITE_CONF" ]]; then
  echo "Site conf not found: $SITE_CONF" >&2
  exit 1
fi

if [[ -z "$UUID" ]]; then
  UUID="$(cat /proc/sys/kernel/random/uuid)"
fi

if ! command -v nginx >/dev/null 2>&1; then
  echo "nginx not found. Install Nginx first." >&2
  exit 1
fi

if [[ ! -x /opt/AdGuardHome/AdGuardHome ]]; then
  echo "AdGuardHome not found at /opt/AdGuardHome/AdGuardHome" >&2
  echo "Install first: curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh" >&2
  exit 1
fi

AGH_YAML="/opt/AdGuardHome/AdGuardHome.yaml"
if [[ ! -f "$AGH_YAML" ]]; then
  echo "AdGuardHome.yaml not found at $AGH_YAML" >&2
  exit 1
fi

cp -a "$AGH_YAML" "$AGH_YAML.bak.$(date +%Y%m%d%H%M%S)"

# Enable DoH route on web listener and keep admin reachable by IP:3000.
sed -i 's/insecure_enabled: .*/insecure_enabled: true/' "$AGH_YAML"
sed -i 's/address: .*/address: 0.0.0.0:3000/' "$AGH_YAML"

# Ensure DNS backend is listening on localhost:5353 for local checks (optional).
# If this host already has custom settings, adjust manually as needed.
if grep -q '^  bind_hosts:' "$AGH_YAML"; then
  sed -i '/^  bind_hosts:/,/^  port:/c\  bind_hosts:\n    - 127.0.0.1\n  port: 5353' "$AGH_YAML"
fi

/opt/AdGuardHome/AdGuardHome -s restart

cp -a "$SITE_CONF" "$SITE_CONF.bak.$(date +%Y%m%d%H%M%S)"

python3 - "$SITE_CONF" "$UUID" <<'PY'
import re
import sys

path = sys.argv[1]
uuid = sys.argv[2]

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove previous dns-query blocks added by this script or manual basic setup.
content = re.sub(r'\nlocation\s*=\s*/dns-query\s*\{[^{}]*\}\n', '\n', content, flags=re.S)
content = re.sub(r'\nlocation\s*=\s*/dns-query/[0-9a-fA-F-]{36}\s*\{[^{}]*\}\n', '\n', content, flags=re.S)
content = re.sub(r'\nlocation\s*\^~\s*/dns-query/\s*\{[^{}]*\}\n', '\n', content, flags=re.S)

block = f'''
location = /dns-query/{uuid} {{
    proxy_pass http://127.0.0.1:3000/dns-query;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}}

location ^~ /dns-query/ {{
    return 403;
}}

location = /dns-query {{
    return 403;
}}
'''

# Insert before generic location / { ... } if found, else append near end.
m = re.search(r'\n\s*location\s*/\s*\{', content)
if m:
    idx = m.start()
    content = content[:idx] + "\n" + block + content[idx:]
else:
    content = content.rstrip() + "\n" + block + "\n"

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
PY

nginx -t
nginx -s reload

echo ""
echo "Done."
echo "UUID: $UUID"
echo "DoH URL: https://$DOMAIN/dns-query/$UUID"
echo ""
echo "Quick test:"
echo "  curl -skI https://$DOMAIN/dns-query/$UUID"
