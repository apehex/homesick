#!/usr/bin/env bash
set -Eeuo pipefail

# META #########################################################################

IMAGE_NAME=""
LIST_IMAGES=0
LIST_DEVICES=0
STOP=0
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
  android-bugger.sh [options] [image-name]

Default behavior:
  android-bugger.sh                 Start/check the ADB server
  android-bugger.sh <image-name>    Start/check ADB server and launch the AVD image
  android-bugger.sh --images        List available AVD image names
  android-bugger.sh --devices       List running Android devices/emulators
  android-bugger.sh --stop          Stop all running emulators and the ADB server
  android-bugger.sh --stop <device> Stop one running emulator device, e.g. emulator-5554

Options:
  -i, --images     List available AVD image names, then exit
  -d, --devices    List running Android devices/emulators, then exit
  -s, --stop       Stop one device if provided, otherwise stop all emulators and ADB server
  -n, --no-window  Start emulator headless
  -w, --wipe-data  Wipe AVD data before boot
  -h, --help       Show this help

Environment:
  ADB_HOST=$ADB_HOST
  ADB_PORT=$ADB_PORT
  LOCAL_BURP_PORT=$LOCAL_BURP_PORT
  REMOTE_BURP_PORT=$REMOTE_BURP_PORT

Examples:
  android-bugger.sh
  android-bugger.sh --images
  android-bugger.sh --devices
  android-bugger.sh Pixel_3_API_35_Play
  android-bugger.sh --no-window Pixel_3_API_35_Play
  android-bugger.sh --stop emulator-5554
  android-bugger.sh --stop

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

  for root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/.local/share/android/sdk"; do
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

  if have "$tool"; then
    command -v "$tool"
    return 0
  fi

  return 1
}

# CLI ##########################################################################

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--images)
        LIST_IMAGES=1
        shift
        ;;
      -d|--devices)
        LIST_DEVICES=1
        shift
        ;;
      -s|--stop)
        STOP=1
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
        if [[ -z "$IMAGE_NAME" ]]; then
          IMAGE_NAME="$1"
          shift
        else
          die "unexpected extra argument: $1"
        fi
        ;;
    esac
  done
}

# INFO #########################################################################

list_images() {
  echo
  echo "Available AVD images:"
  "$EMULATOR" -list-avds 2>/dev/null | sed 's/^/  - /' || {
    echo "  unable to list AVD images"
    return 1
  }
}

list_devices() {
  echo
  "$ADB" devices -l || true
}

all_emulators() {
  "$ADB" devices | awk '/^emulator-[0-9]+[[:space:]]+device$/ {print $1}'
}

all_devices() {
  "$ADB" devices | awk 'NR > 1 && $1 != "" {print $1}'
}

# START ########################################################################

start_adb() {
  echo
  echo "Starting/checking ADB server..."
  "$ADB" start-server >/dev/null
}

start_image() {
  [[ -n "$IMAGE_NAME" ]] || die "missing image name. Use --images to list available AVD images."

  local args=("@$IMAGE_NAME")

  if [[ "$NO_WINDOW" -eq 1 ]]; then
    args+=("-no-window")
  fi

  if [[ "$WIPE_DATA" -eq 1 ]]; then
    args+=("-wipe-data")
  fi

  echo
  echo "Starting AVD image: $IMAGE_NAME"
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

# STOP #########################################################################

stop_adb() {
  echo
  echo "Stopping ADB server..."
  "$ADB" kill-server || true
}

stop_device() {
  local device="$1"

  echo "Stopping device: $device"

  if [[ "$device" == emulator-* ]]; then
    "$ADB" -s "$device" emu kill || true
  else
    echo "warning: $device is not an emulator; refusing to stop non-emulator device" >&2
    return 1
  fi
}

stop_all() {
  echo
  echo "Stopping all running emulators..."

  local found=0
  local device

  while read -r device; do
    [[ -n "$device" ]] || continue
    found=1
    stop_device "$device" || true
  done < <(all_emulators)

  if [[ "$found" -eq 0 ]]; then
    echo "No running emulators found."
  fi

  stop_adb
}

# MAIN #########################################################################

parse_args "$@"

if [[ "$SHOW_HELP" -eq 1 ]]; then
  print_usage
  exit 0
fi

ADB="$(find_tool adb)" || die "adb not found. Install Android platform-tools or set ANDROID_HOME/ANDROID_SDK_ROOT."
EMULATOR="$(find_tool emulator)" || die "emulator not found. Install Android Emulator or set ANDROID_HOME/ANDROID_SDK_ROOT."

echo "Using adb:      $ADB"
echo "Using emulator: $EMULATOR"

if [[ "$STOP" -eq 1 ]]; then
  if [[ -n "$IMAGE_NAME" ]]; then
    stop_device "$IMAGE_NAME"
  else
    stop_all
  fi
  exit 0
fi

if [[ "$LIST_IMAGES" -eq 1 ]]; then
  list_images
  exit 0
fi

if [[ "$LIST_DEVICES" -eq 1 ]]; then
  list_devices
  exit 0
fi

if [[ -z "$IMAGE_NAME" ]]; then
  start_adb
  list_devices
  print_handoff
  exit 0
fi

start_adb
start_image
wait_device
list_devices
print_info
print_handoff
