#!/usr/bin/env bash
set -Eeuo pipefail

# META #########################################################################

AVD_NAME=""
START_AVD=0
LIST_ONLY=0
NO_WINDOW=0
WIPE_DATA=0
SHOW_HELP=0

ADB_HOST="${ADB_HOST:-127.0.0.1}"
ADB_PORT="${ADB_PORT:-5037}"

REMOTE_BURP_PORT="${REMOTE_BURP_PORT:-18080}"
LOCAL_BURP_PORT="${LOCAL_BURP_PORT:-8080}"

# USAGE ########################################################################

print_usage() {
  cat <<EOF
Usage:
  android-bugger.sh [options] [avd-name]

Options:
  -l, --list       List available AVDs and connected devices, then exit
  -s, --start      Start the selected AVD
  -n, --no-window  Start emulator headless
  -w, --wipe-data  Wipe AVD data before boot
  -h, --help       Show this help

Environment:
  ADB_HOST=$ADB_HOST
  ADB_PORT=$ADB_PORT
  LOCAL_BURP_PORT=$LOCAL_BURP_PORT
  REMOTE_BURP_PORT=$REMOTE_BURP_PORT

Examples:
  android-bugger.sh --list
  android-bugger.sh --start Pixel_8_API_35
  android-bugger.sh --start --no-window Pixel_8_API_35

Expected SSH RemoteForward for the agent on the VPS:
  RemoteForward 127.0.0.1:5037 127.0.0.1:5037

Optional Burp RemoteForward:
  RemoteForward 127.0.0.1:${REMOTE_BURP_PORT} 127.0.0.1:${LOCAL_BURP_PORT}
EOF
}

print_handoff() {
  cat <<EOF
Agent handoff
=============

On the VPS, with your SSH RemoteForward active, the agent should use:

  adb -H ${ADB_HOST} -P ${ADB_PORT} devices
  adb -H ${ADB_HOST} -P ${ADB_PORT} shell getprop ro.product.model
  adb -H ${ADB_HOST} -P ${ADB_PORT} shell screencap -p /sdcard/screen.png
  adb -H ${ADB_HOST} -P ${ADB_PORT} pull /sdcard/screen.png ./screen.png
  adb -H ${ADB_HOST} -P ${ADB_PORT} logcat -d -t 200
  adb -H ${ADB_HOST} -P ${ADB_PORT} shell uiautomator dump /sdcard/window.xml
  adb -H ${ADB_HOST} -P ${ADB_PORT} pull /sdcard/window.xml ./window.xml

If Burp is forwarded to the VPS:

  HTTP proxy: http://127.0.0.1:${REMOTE_BURP_PORT}

Remember:
  - Use /tmp only for disposable scratch.
  - Save meaningful screenshots/logs/UI dumps in the persistent workspace.
  - Promote artifacts to notes/<program>/evidence/<session-id>/ only when they support a claim or handoff.
EOF
}

print_info() {
  echo
  echo "Device info:"
  "$ADB" shell getprop ro.product.model 2>/dev/null | sed 's/^/  model: /' || true
  "$ADB" shell getprop ro.build.version.release 2>/dev/null | sed 's/^/  android: /' || true
  "$ADB" shell getprop ro.product.cpu.abi 2>/dev/null | sed 's/^/  abi: /' || true
}

# HELPERS ######################################################################

die() {
  echo "error: $*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

find_tool() {
  local tool="$1"

  if have "$tool"; then
    command -v "$tool"
    return 0
  fi

  for root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/.local/android/sdk" "/opt/android-sdk"; do
    [[ -n "$root" ]] || continue
    for candidate in \
      "$root/platform-tools/$tool" \
      "$root/emulator/$tool" \
      "$root/cmdline-tools/latest/bin/$tool" \
      "$root/tools/bin/$tool"; do
      if [[ -x "$candidate" ]]; then
        echo "$candidate"
        return 0
      fi
    done
  done

  return 1
}

# CLI ##########################################################################

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -l|--list)
        LIST_ONLY=1
        shift
        ;;
      -s|--start)
        START_AVD=1
        shift
        ;;
      -n|--no-window)
        NO_WINDOW=1
        shift
        ;;
      -w|--wipe-data)
        WIPE_DATA=1
        shift
        ;;
      -h|--help)
        SHOW_HELP=1
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        if [[ -z "$AVD_NAME" ]]; then
          AVD_NAME="$1"
          shift
        else
          die "unexpected extra argument: $1"
        fi
        ;;
    esac
  done
}

# DEVICES ######################################################################

list_avds() {
  echo
  echo "Available AVDs:"
  if "$EMULATOR" -list-avds 2>/dev/null | sed 's/^/  - /'; then
    true
  else
    echo "  unable to list AVDs"
  fi
}

start_adb() {
  echo
  echo "Starting/checking ADB server..."
  "$ADB" start-server >/dev/null
}

list_devices() {
  echo
  echo "ADB devices:"
  "$ADB" devices -l || true
}

start_avd() {
  [[ -n "$AVD_NAME" ]] || die "missing AVD name. Use --list to list available AVDs."

  local args=("@$AVD_NAME")

  if [[ "$NO_WINDOW" -eq 1 ]]; then
    args+=("-no-window")
  fi

  if [[ "$WIPE_DATA" -eq 1 ]]; then
    args+=("-wipe-data")
  fi

  echo
  echo "Starting AVD: $AVD_NAME"
  echo "Command: $EMULATOR ${args[*]}"
  nohup "$EMULATOR" "${args[@]}" >/tmp/android-bugger-emulator.log 2>&1 &

  echo "Emulator started in background."
  echo "Log: /tmp/android-bugger-emulator.log"
}

wait_device() {
  echo
  echo "Waiting for device..."
  "$ADB" wait-for-device || true

  local booted=""
  for _ in $(seq 1 60); do
    booted="$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [[ "$booted" == "1" ]]; then
      echo "Device boot completed."
      return 0
    fi
    sleep 2
  done

  echo "warning: timed out waiting for sys.boot_completed=1" >&2
}

# MAIN #########################################################################

parse_args "$@"

[[ "$SHOW_HELP" -eq 1 ]] && { print_usage; exit 0; }

ADB="$(find_tool adb)" || die "adb not found. Install Android platform-tools or set ANDROID_HOME/ANDROID_SDK_ROOT."
EMULATOR="$(find_tool emulator)" || die "emulator not found. Install Android Emulator or set ANDROID_HOME/ANDROID_SDK_ROOT."

echo "Using adb:      $ADB"
echo "Using emulator: $EMULATOR"

start_adb
list_avds
list_devices

[[ "$LIST_ONLY" -eq 1 ]] && { print_handoff; exit 0; }

if [[ "$START_AVD" -eq 1 ]]; then
  start_avd
  wait_device
  list_devices
  print_info
fi

print_handoff
