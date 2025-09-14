#!/usr/bin/env bash
# setup_srv_dirs.sh
# Usage: sudo scripts/setup/setup_srv_dirs.sh

set -euo pipefail

# must be root (use sudo)
if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo: sudo $0"; exit 1
fi

ME="${SUDO_USER:-$USER}"
GROUP="$(id -gn "$ME")"

# Create dirs
install -d -o "$ME"   -g "$GROUP" -m 0750 /srv/data
install -d -o root    -g root      -m 0700 /srv/secrets
install -d -o "$ME"   -g "$GROUP"  -m 0750 /srv/backup
install -d -o "$ME"   -g "$GROUP"  -m 0750 /srv/backup/tmp
install -d -o "$ME"   -g "$GROUP"  -m 0750 /srv/backup/dumps

echo "Created:"
printf '  %s (mode %s, owner %s:%s)\n' \
  "/srv/data"   "$(stat -c %a /srv/data)"   "$(stat -c %U /srv/data)"   "$(stat -c %G /srv/data)" \
  "/srv/secrets" "$(stat -c %a /srv/secrets)" "$(stat -c %U /srv/secrets)" "$(stat -c %G /srv/secrets)" \
  "/srv/backup"  "$(stat -c %a /srv/backup)"  "$(stat -c %U /srv/backup)"  "$(stat -c %G /srv/backup)" \
  "/srv/backup/tmp"   "$(stat -c %a /srv/backup/tmp)"   "$(stat -c %U /srv/backup/tmp)"   "$(stat -c %G /srv/backup/tmp)" \
  "/srv/backup/dumps" "$(stat -c %a /srv/backup/dumps)" "$(stat -c %U /srv/backup/dumps)" "$(stat -c %G /srv/backup/dumps)"
