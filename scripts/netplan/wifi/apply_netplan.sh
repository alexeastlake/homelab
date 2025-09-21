#!/usr/bin/env bash
# Usage: sudo ./apply_netplan.sh [01-wifi.yaml]
# Copies built file into /etc/netplan/ and applies it

OUT_FILE="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/01-wifi.yaml}"
DEST="/etc/netplan/01-wifi.yaml"

[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

[[ -f "$OUT_FILE" ]] || { echo "Missing built file: $OUT_FILE"; exit 1; }

install -m 600 "$OUT_FILE" "$DEST"
echo "Installed $OUT_FILE to $DEST"

netplan generate
netplan try --timeout 10 && netplan apply
echo "Netplan applied"
