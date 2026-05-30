#!/usr/bin/env bash
set -Eeuo pipefail

# META #########################################################################

# Agent OpenTelemetry collector launcher.
# Intended to run on the VPS.

COLLECTOR_NAME="${COLLECTOR_NAME:-agent-otelcol}"
COLLECTOR_IMAGE="${COLLECTOR_IMAGE:-otel/opentelemetry-collector-contrib:latest}"

OTEL_CONFIG="${OTEL_CONFIG:-$HOME/.otel/agent-collector.yaml}"
TELEMETRY_DIR="${TELEMETRY_DIR:-$HOME/.telemetry}"

# HELP #########################################################################

print_usage() {
  cat <<EOF
Usage:
  agent-otelcol start
  agent-otelcol stop
  agent-otelcol restart
  agent-otelcol logs
  agent-otelcol status

Environment overrides:
  COLLECTOR_NAME=$COLLECTOR_NAME
  COLLECTOR_IMAGE=$COLLECTOR_IMAGE
  OTEL_CONFIG=$OTEL_CONFIG
  TELEMETRY_DIR=$TELEMETRY_DIR
EOF
}

# CHECKS #######################################################################

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker is not installed or not in PATH" >&2
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "error: cannot connect to Docker daemon" >&2
    echo "hint: start docker.service or check Docker permissions for user $(whoami)" >&2
    exit 1
  fi
}

check_paths() {
  if [[ ! -f "$OTEL_CONFIG" ]]; then
    echo "error: collector config not found: $OTEL_CONFIG" >&2
    exit 1
  fi

  mkdir -p "$TELEMETRY_DIR/codex" "$TELEMETRY_DIR/gemini"
  chmod 700 "$TELEMETRY_DIR" "$TELEMETRY_DIR/codex" "$TELEMETRY_DIR/gemini" || true
}

is_running() {
  docker ps --format '{{.Names}}' | grep -Fxq "$COLLECTOR_NAME"
}

# CLEANUP ######################################################################

cleanup_containers() {
  # Remove stale stopped container with the same name, if present.
  if docker ps -a --format '{{.Names}}' | grep -Fxq "$COLLECTOR_NAME"; then
    docker rm "$COLLECTOR_NAME" >/dev/null
  fi
}

# OPERATIONS ###################################################################

stop_collector() {
  if is_running; then
    echo "Stopping $COLLECTOR_NAME..."
    docker stop "$COLLECTOR_NAME" >/dev/null
  else
    echo "$COLLECTOR_NAME is not running."
  fi
}

start_collector() {
  if is_running; then
    echo "$COLLECTOR_NAME is already running."
    exit 0
  fi

  echo "Starting   $COLLECTOR_NAME..."
  echo "Config:    $OTEL_CONFIG"
  echo "Telemetry: $TELEMETRY_DIR"

  docker run -d \
    --name "$COLLECTOR_NAME" \
    --network host \
    --user "$(id -u):$(id -g)" \
    --restart unless-stopped \
    -v "$OTEL_CONFIG:/etc/otelcol-contrib/config.yaml:ro" \
    -v "$TELEMETRY_DIR:/telemetry" \
    "$COLLECTOR_IMAGE" \
    --config=/etc/otelcol-contrib/config.yaml

  echo "$COLLECTOR_NAME started."
}

print_logs() {
  docker logs -f "$COLLECTOR_NAME"
}

print_status() {
  if is_running; then
    docker ps --filter "name=^/${COLLECTOR_NAME}$"
  else
    echo "$COLLECTOR_NAME is not running."
    docker ps -a --filter "name=^/${COLLECTOR_NAME}$"
  fi
}

# MAIN #########################################################################

case "${1:-}" in
  start)
    require_docker
    check_paths
    cleanup_containers
    start_collector
    ;;
  stop|shutdown)
    require_docker
    stop_collector
    ;;
  restart)
    require_docker
    check_paths
    stop_collector
    cleanup_containers
    start_collector
    ;;
  logs)
    require_docker
    print_logs
    ;;
  status)
    require_docker
    print_status
    ;;
  -h|--help|help|"")
    print_usage
    ;;
  *)
    echo "error: unknown command: $1" >&2
    print_usage >&2
    exit 1
    ;;
esac
