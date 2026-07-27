#!/usr/bin/env bash
set -Eeuo pipefail

USE_PROXY=0
[[ "${1:-}" == "-p" ]] && { USE_PROXY=1; shift; }

USER_NAME="${1:-default}"
BASE_DIR="${HOME}/.cache/bugger/chromium"
USER_DIR="${BASE_DIR}/${USER_NAME}"

CHROMIUM_ARGS=(
  --remote-debugging-address="127.0.0.1"
  --remote-debugging-port="9222"
  --user-data-dir="$USER_DIR"
)

mkdir -p "$USER_DIR"

[[ "$USE_PROXY" -eq 1 ]] && { CHROMIUM_ARGS+=( --proxy-server="http://127.0.0.1:8080" ); }

exec chromium "${CHROMIUM_ARGS[@]}"
