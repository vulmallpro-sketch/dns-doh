#!/usr/bin/env bash
set -euo pipefail

DOH_URL="${1:-}"
DOMAIN="${2:-baidu.com}"

if [[ -z "$DOH_URL" ]]; then
  echo "Usage: $0 <doh-url> [domain]" >&2
  echo "Example: $0 https://doh.example.com/dns-query/<uuid> baidu.com" >&2
  exit 1
fi

RESP="/tmp/doh_resp_$$.bin"

q=$(python3 - "$DOMAIN" <<'PY'
import sys, base64, struct, secrets
name = sys.argv[1].strip('.')
msg = struct.pack('!HHHHHH', secrets.randbelow(65536), 0x0100, 1, 0, 0, 0)
for part in name.split('.'):
    msg += bytes([len(part)]) + part.encode('ascii')
msg += b'\x00' + struct.pack('!HH', 1, 1)
print(base64.urlsafe_b64encode(msg).decode().rstrip('='))
PY
)

curl -sk "${DOH_URL}?dns=${q}" -H 'accept: application/dns-message' -o "$RESP"

python3 - "$RESP" <<'PY'
import struct, socket, sys
b = open(sys.argv[1], 'rb').read()
print('response_size=', len(b))
if len(b) < 12:
    print('invalid_dns_response')
    sys.exit(2)
ancount = struct.unpack('!H', b[6:8])[0]
print('answer_count=', ancount)
i = 12
while i < len(b) and b[i] != 0:
    i += b[i] + 1
i += 1 + 4
ips = []
for _ in range(ancount):
    if i >= len(b):
        break
    if b[i] & 0xC0 == 0xC0:
        i += 2
    else:
        while i < len(b) and b[i] != 0:
            i += b[i] + 1
        i += 1
    if i + 10 > len(b):
        break
    rtype, _, _, rdlen = struct.unpack('!HHIH', b[i:i+10])
    i += 10
    if i + rdlen > len(b):
        break
    rdata = b[i:i+rdlen]
    i += rdlen
    if rtype == 1 and rdlen == 4:
        ips.append(socket.inet_ntoa(rdata))
if ips:
    print('A_records=')
    for ip in ips:
        print(ip)
else:
    print('A_records=NONE')
PY

rm -f "$RESP"
