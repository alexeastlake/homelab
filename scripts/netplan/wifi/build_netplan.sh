#!/usr/bin/env bash
# Usage: sudo ./build_netplan.sh [wifi.env] [wifi.yaml.tpl]

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$DIR/wifi.env}"
TPL_FILE="${2:-$DIR/wifi.yaml.tpl}"
OUT="$DIR//01-wifi.yaml"

[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

# Load env vars
set -a
source "$ENV_FILE"
set +a

# Render template
sed -e "s|\${WIFI_IFACE}|$WIFI_IFACE|g" \
    -e "s|\${STATIC_IP}|$STATIC_IP|g" \
    -e "s|\${GATEWAY}|$GATEWAY|g" \
    -e "s|\${DNS}|$DNS|g" \
    -e "s|\${WIFI_SSID}|$WIFI_SSID|g" \
    -e "s|\${WIFI_PASSWORD}|$WIFI_PASSWORD|g" \
    "$TPL_FILE" > "$OUT"

chmod 600 "$OUT"
echo "Wrote $OUT"
