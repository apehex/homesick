#!/usr/bin/env bash
set -Eeuo pipefail

USER_NAME="${1:-default}"
BASE_DIR="${HOME}/.cache/bugger/chromium"
USER_DIR="${BASE_DIR}/${USER_NAME}"

mkdir -p "$USER_DIR"

exec chromium \
  --proxy-server="http://127.0.0.1:8080" \
  --remote-debugging-address="127.0.0.1" \
  --remote-debugging-port="9222" \
  --user-data-dir="$USER_DIR"
