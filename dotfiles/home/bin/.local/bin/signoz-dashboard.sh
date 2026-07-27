#!/usr/bin/env bash
set -Eeuo pipefail

# META #########################################################################

# Local SigNoz dashboard launcher.

SIGNOZ_DIR="${SIGNOZ_DIR:-$HOME/workspace/.lib/signoz/deploy/docker}"
SIGNOZ_CFG="${SIGNOZ_CFG:-$SIGNOZ_DIR/docker-compose.yaml}"
SIGNOZ_URL="${SIGNOZ_URL:-http://localhost:8080}"

# HELP #########################################################################

print_usage() {
  cat <<EOF
Usage:
  signoz-dashboard start
  signoz-dashboard stop
  signoz-dashboard restart
  signoz-dashboard logs
  signoz-dashboard status

Environment overrides:
  SIGNOZ_DIR=$SIGNOZ_DIR
  SIGNOZ_CFG=$SIGNOZ_CFG
  SIGNOZ_URL=$SIGNOZ_URL
EOF
}

# CHECK ########################################################################

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker is not installed or not in PATH" >&2
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "error: cannot connect to Docker daemon" >&2
    echo "hint: start Docker Desktop or docker.service" >&2
    exit 1
  fi
}

check_paths() {
  if [[ ! -f "$SIGNOZ_CFG" ]]; then
    echo "error: compose file not found: $SIGNOZ_CFG" >&2
    exit 1
  fi
}

# OPERATIONS ###################################################################

compose() {
  docker compose -f "$SIGNOZ_CFG" "$@"
}

start_dashboard() {
  echo "Starting SigNoz..."
  echo "Compose file: $SIGNOZ_CFG"

  compose up -d --remove-orphans

  echo "SigNoz should be available at: $SIGNOZ_URL"
}

stop_dashboard() {
  echo "Stopping SigNoz..."
  compose down --remove-orphans
}

# MAIN #########################################################################

case "${1:-}" in
  start|up)
    require_docker
    check_paths
    start_dashboard
    ;;
  stop|shutdown|down)
    require_docker
    check_paths
    stop_dashboard
    ;;
  restart)
    stop_dashboard
    start_dashboard
    ;;
  logs)
    require_docker
    check_paths
    compose logs -f
    ;;
  status|ps)
    require_docker
    check_paths
    compose ps
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
