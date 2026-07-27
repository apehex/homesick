#!/usr/bin/env bash
set -Eeuo pipefail

# META #########################################################################

COMMAND="${1:-record}"
[[ $# -gt 0 ]] && shift

BASE_DIR="${FFMPEG_BUGGER_DIR:-$HOME/Videos/bugger}"
DISPLAY_NAME="${FFMPEG_DISPLAY:-${DISPLAY:-}}"
CAPTURE_SIZE="${FFMPEG_CAPTURE_SIZE:-}"
FRAMERATE=10
CRF=18
PRESET=veryfast
PIXEL_FORMAT=yuv420p

TMP_DIR=""

# USAGE ########################################################################

print_usage() {
  cat <<EOF_USAGE
Usage:
  ffmpeg-bugger.sh
  ffmpeg-bugger.sh record [output.mp4]
  ffmpeg-bugger.sh info <input.mp4>
  ffmpeg-bugger.sh clip <input.mp4> <start> <end> <speed> [output.mp4]
  ffmpeg-bugger.sh speed <input.mp4> <speed> [output.mp4]
  ffmpeg-bugger.sh render <input.mp4> <timeline.txt> [output.mp4]
  ffmpeg-bugger.sh concat <output.mp4> <input-1.mp4> <input-2.mp4> [...]
  ffmpeg-bugger.sh frame <input.mp4> <timestamp> [output.png]

Calling the script without arguments records the full X11 display.

Timestamps must use HH:MM:SS or HH:MM:SS.mmm.

Timeline format:
  START END SPEED

Example:
  00:00:00 00:00:20 1
  00:00:20 00:05:12 12
  00:05:12 00:08:40 1.5

Blank lines and comments beginning with # are ignored. Omitted ranges are cut.

Fixed video defaults:
  framerate:   $FRAMERATE fps
  codec:       libx264
  preset:      $PRESET
  CRF:         $CRF
  pixel format: $PIXEL_FORMAT
  audio:       disabled

Environment:
  FFMPEG_BUGGER_DIR=$BASE_DIR
  FFMPEG_DISPLAY=${DISPLAY_NAME:-<unset>}
  FFMPEG_CAPTURE_SIZE=${CAPTURE_SIZE:-<auto>}

Examples:
  ffmpeg-bugger.sh record /tmp/poc.mp4
  ffmpeg-bugger.sh clip /tmp/poc.mp4 00:00:00 00:05:12 1.5 /tmp/part-1.mp4
  ffmpeg-bugger.sh speed /tmp/poc.mp4 1.5 /tmp/poc-1.5x.mp4
  ffmpeg-bugger.sh render /tmp/poc.mp4 timeline.txt /tmp/poc-edited.mp4
EOF_USAGE
}

# MESSAGES #####################################################################

info() { printf '[ffmpeg-bugger] %s\n' "$*"; }
die()  { printf '[ffmpeg-bugger] ERROR: %s\n' "$*" >&2; exit 1; }

# TEMPORARY FILES ##############################################################

cleanup() {
  [[ -z "$TMP_DIR" ]] || rm -rf -- "$TMP_DIR"
}

trap cleanup EXIT

ensure_tmp_dir() {
  [[ -n "$TMP_DIR" ]] || TMP_DIR="$(mktemp -d)"
}

new_temp_file() {
  local suffix="$1"
  ensure_tmp_dir
  mktemp --tmpdir="$TMP_DIR" "file.XXXXXXXX$suffix"
}

# INPUT CHECKS AND NORMALIZATION ###############################################

require_tools() {
  local command
  for command in ffmpeg ffprobe realpath mktemp awk; do
    command -v "$command" >/dev/null 2>&1 || die "missing required command: $command"
  done
}

normalize_input_video() {
  local path="${1:-}"
  local absolute

  [[ -n "$path" ]] || die 'input video is required'
  [[ -f "$path" && -r "$path" ]] || die "input video is not readable: $path"
  absolute="$(realpath -- "$path")"

  ffprobe -v error -select_streams v:0 -show_entries stream=index -of csv=p=0 -- "$absolute" | grep -q . || \
    die "input contains no video stream: $absolute"

  printf '%s\n' "$absolute"
}

normalize_input_file() {
  local path="${1:-}"
  [[ -n "$path" ]] || die 'input file is required'
  [[ -f "$path" && -r "$path" ]] || die "input file is not readable: $path"
  realpath -- "$path"
}

normalize_output() {
  local path="$1"
  local extension="$2"
  local absolute

  [[ -n "$path" ]] || die 'output path is required'
  [[ "$path" == *"$extension" ]] || die "output must end with $extension: $path"
  absolute="$(realpath -m -- "$path")"
  mkdir -p -- "$(dirname -- "$absolute")"
  [[ ! -e "$absolute" ]] || die "output already exists: $absolute"
  printf '%s\n' "$absolute"
}

video_duration() {
  local input="$1"
  local duration

  duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 -- "$input")"
  awk -v value="$duration" 'BEGIN { if (value <= 0) exit 1; printf "%.6f\n", value }' || \
    die "cannot determine video duration: $input"
}

timestamp_seconds() {
  local value="$1"
  local label="$2"
  local hours minutes seconds

  [[ "$value" =~ ^([0-9]+):([0-5][0-9]):([0-5][0-9])([.][0-9]+)?$ ]] || \
    die "invalid $label '$value'; expected HH:MM:SS or HH:MM:SS.mmm"

  hours="${BASH_REMATCH[1]}"
  minutes="${BASH_REMATCH[2]}"
  seconds="${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
  awk -v h="$hours" -v m="$minutes" -v s="$seconds" 'BEGIN { printf "%.6f\n", h * 3600 + m * 60 + s }'
}

normalize_speed() {
  local value="$1"

  [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "invalid speed: $value"
  awk -v value="$value" 'BEGIN { if (value <= 0 || value > 100) exit 1; printf "%.6g\n", value }' || \
    die "speed must be greater than 0 and at most 100: $value"
}

write_segment_seconds() {
  local start="$1"
  local end="$2"
  local speed="$3"
  local source_duration="$4"
  local plan="$5"

  awk -v start="$start" -v end="$end" -v source="$source_duration" -v speed="$speed" '
    BEGIN {
      tolerance = 0.05
      if (start < 0 || start >= source) exit 1
      if (end <= start || end > source + tolerance) exit 2
      if (end > source) end = source
      printf "%.6f\t%.6f\t%s\n", start, end - start, speed
    }
  ' >> "$plan" || die "invalid segment: start=$start end=$end source_duration=$source_duration"
}

write_segment() {
  local raw_start="$1"
  local raw_end="$2"
  local raw_speed="$3"
  local source_duration="$4"
  local plan="$5"
  local start end speed

  start="$(timestamp_seconds "$raw_start" 'segment start')"
  end="$(timestamp_seconds "$raw_end" 'segment end')"
  speed="$(normalize_speed "$raw_speed")"
  write_segment_seconds "$start" "$end" "$speed" "$source_duration" "$plan"
}

normalize_timeline() {
  local timeline="$1"
  local source_duration="$2"
  local plan="$3"
  local line line_number=0 start end speed extra

  : > "$plan"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    line="${line%%#*}"
    [[ -n "${line//[[:space:]]/}" ]] || continue

    read -r start end speed extra <<< "$line"
    [[ -n "${start:-}" && -n "${end:-}" && -n "${speed:-}" && -z "${extra:-}" ]] || \
      die "invalid timeline line $line_number; expected: START END SPEED"

    write_segment "$start" "$end" "$speed" "$source_duration" "$plan"
  done < "$timeline"

  [[ -s "$plan" ]] || die 'timeline contains no segments'
}

# PATH HELPERS #################################################################

media_stem() {
  local name
  name="$(basename -- "$1")"
  printf '%s\n' "${name%.*}"
}

filename_time() {
  printf '%s' "$1" | tr ':.' '--'
}

choose_output() {
  local explicit="$1"
  local input="$2"
  local tag="$3"
  local extension="$4"
  local candidate directory stem

  if [[ -n "$explicit" ]]; then
    normalize_output "$explicit" "$extension"
    return
  fi

  directory="$(dirname -- "$input")"
  stem="$(media_stem "$input")"
  candidate="$directory/${stem}-${tag}${extension}"

  if [[ -e "$candidate" ]]; then
    candidate="$directory/${stem}-${tag}-$(date +%Y%m%d-%H%M%S)${extension}"
  fi

  normalize_output "$candidate" "$extension"
}

# RECORDING ####################################################################

detect_capture_size() {
  if [[ -n "$CAPTURE_SIZE" ]]; then
    [[ "$CAPTURE_SIZE" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] || die "invalid FFMPEG_CAPTURE_SIZE: $CAPTURE_SIZE"
    printf '%s\n' "$CAPTURE_SIZE"
    return
  fi

  if command -v xdpyinfo >/dev/null 2>&1; then
    xdpyinfo -display "$DISPLAY_NAME" 2>/dev/null | awk '/dimensions:/ { print $2; exit }'
    return
  fi

  if command -v xrandr >/dev/null 2>&1; then
    xrandr --display "$DISPLAY_NAME" --current 2>/dev/null | awk '/ current / { gsub(",", "", $8); print $8 "x" $10; exit }'
    return
  fi

  die 'cannot detect display size; install xdpyinfo or set FFMPEG_CAPTURE_SIZE'
}

record_screen() {
  local output="${1:-$BASE_DIR/bugger-$(date +%Y%m%d-%H%M%S).mp4}"
  local size

  [[ -n "$DISPLAY_NAME" ]] || die 'DISPLAY is unset; set DISPLAY or FFMPEG_DISPLAY'
  output="$(normalize_output "$output" '.mp4')"
  size="$(detect_capture_size)"

  info "recording ${DISPLAY_NAME}+0,0 at ${size}, ${FRAMERATE} fps"
  info "output: $output"
  info 'press Ctrl-C to stop and finalize the recording'

  exec ffmpeg -hide_banner -n \
    -framerate "$FRAMERATE" \
    -video_size "$size" \
    -f x11grab \
    -i "${DISPLAY_NAME}+0,0" \
    -an \
    -c:v libx264 \
    -preset "$PRESET" \
    -crf "$CRF" \
    -pix_fmt "$PIXEL_FORMAT" \
    -g "$((FRAMERATE * 2))" \
    -movflags +faststart \
    "$output"
}

# SHARED EDITING ENGINE ########################################################

build_filtergraph() {
  local plan="$1"
  local filter="$2"
  local start duration speed index=0 labels=''

  : > "$filter"

  while IFS=$'\t' read -r start duration speed; do
    printf '[0:v]trim=start=%s:duration=%s,setpts=(PTS-STARTPTS)/%s[v%d];\n' \
      "$start" "$duration" "$speed" "$index" >> "$filter"
    labels+="[v$index]"
    index=$((index + 1))
  done < "$plan"

  if (( index == 1 )); then
    printf '[v0]fps=%s,format=%s[outv]\n' "$FRAMERATE" "$PIXEL_FORMAT" >> "$filter"
  else
    printf '%sconcat=n=%d:v=1:a=0,fps=%s,format=%s[outv]\n' \
      "$labels" "$index" "$FRAMERATE" "$PIXEL_FORMAT" >> "$filter"
  fi
}

render_plan() {
  local input="$1"
  local plan="$2"
  local output="$3"
  local filter temporary

  filter="$(new_temp_file '.filter')"
  temporary="$(new_temp_file '.mp4')"
  build_filtergraph "$plan" "$filter"

  ffmpeg -hide_banner -y \
    -i "$input" \
    -filter_complex_script "$filter" \
    -map '[outv]' \
    -an \
    -c:v libx264 \
    -preset "$PRESET" \
    -crf "$CRF" \
    -pix_fmt "$PIXEL_FORMAT" \
    -movflags +faststart \
    "$temporary"

  mv -- "$temporary" "$output"
  info "output: $output"
}

# EDIT COMMANDS ###############################################################

clip_video() {
  [[ $# -ge 4 && $# -le 5 ]] || die 'clip requires: INPUT START END SPEED [OUTPUT]'

  local input start="$2" end="$3" speed="$4" output="${5:-}"
  local duration plan tag

  input="$(normalize_input_video "$1")"
  duration="$(video_duration "$input")"
  speed="$(normalize_speed "$speed")"
  tag="clip-$(filename_time "$start")-$(filename_time "$end")-${speed}x"
  output="$(choose_output "$output" "$input" "$tag" '.mp4')"

  plan="$(new_temp_file '.plan')"
  : > "$plan"
  write_segment "$start" "$end" "$speed" "$duration" "$plan"
  render_plan "$input" "$plan" "$output"
}

speed_video() {
  [[ $# -ge 2 && $# -le 3 ]] || die 'speed requires: INPUT SPEED [OUTPUT]'

  local input speed output="${3:-}" duration plan

  input="$(normalize_input_video "$1")"
  speed="$(normalize_speed "$2")"
  duration="$(video_duration "$input")"
  output="$(choose_output "$output" "$input" "${speed}x" '.mp4')"

  plan="$(new_temp_file '.plan')"
  : > "$plan"
  write_segment_seconds 0 "$duration" "$speed" "$duration" "$plan"
  render_plan "$input" "$plan" "$output"
}

render_timeline() {
  [[ $# -ge 2 && $# -le 3 ]] || die 'render requires: INPUT TIMELINE [OUTPUT]'

  local input timeline output="${3:-}" duration plan

  input="$(normalize_input_video "$1")"
  timeline="$(normalize_input_file "$2")"
  duration="$(video_duration "$input")"
  output="$(choose_output "$output" "$input" 'edited' '.mp4')"

  plan="$(new_temp_file '.plan')"
  normalize_timeline "$timeline" "$duration" "$plan"
  render_plan "$input" "$plan" "$output"
}

# CONCATENATION ################################################################

concat_videos() {
  [[ $# -ge 3 ]] || die 'concat requires: OUTPUT INPUT-1 INPUT-2 [...]'

  local output input manifest temporary escaped

  output="$(normalize_output "$1" '.mp4')"
  shift
  manifest="$(new_temp_file '.ffconcat')"
  temporary="$(new_temp_file '.mp4')"
  printf 'ffconcat version 1.0\n' > "$manifest"

  for input in "$@"; do
    input="$(normalize_input_video "$input")"
    escaped="${input//\'/\'\\\'\'}"
    printf "file '%s'\n" "$escaped" >> "$manifest"
  done

  ffmpeg -hide_banner -y \
    -f concat -safe 0 -i "$manifest" \
    -an -c:v copy -movflags +faststart \
    "$temporary"

  mv -- "$temporary" "$output"
  info "output: $output"
}

# INFORMATION AND FRAMES #######################################################

show_info() {
  [[ $# -eq 1 ]] || die 'info requires: INPUT'
  local input
  input="$(normalize_input_video "$1")"
  ffprobe -v error \
    -show_entries format=filename,start_time,duration,size,bit_rate \
    -show_entries stream=codec_name,width,height,pix_fmt,avg_frame_rate \
    -of default=noprint_wrappers=1 -- "$input"
}

extract_frame() {
  [[ $# -ge 2 && $# -le 3 ]] || die 'frame requires: INPUT TIMESTAMP [OUTPUT]'

  local input timestamp output="${3:-}" duration tag temporary

  input="$(normalize_input_video "$1")"
  timestamp="$(timestamp_seconds "$2" 'frame timestamp')"
  duration="$(video_duration "$input")"
  awk -v time="$timestamp" -v duration="$duration" 'BEGIN { exit !(time < duration) }' || \
    die "frame timestamp is outside the video duration"

  tag="frame-$(filename_time "$2")"
  output="$(choose_output "$output" "$input" "$tag" '.png')"
  temporary="$(new_temp_file '.png')"

  ffmpeg -hide_banner -y -ss "$timestamp" -i "$input" -frames:v 1 -an "$temporary"
  mv -- "$temporary" "$output"
  info "output: $output"
}

# MAIN #########################################################################

require_tools

case "$COMMAND" in
  record)  [[ $# -le 1 ]] || die 'record accepts at most one output'; record_screen "${1:-}" ;;
  info)    show_info "$@" ;;
  clip)    clip_video "$@" ;;
  speed)   speed_video "$@" ;;
  render)  render_timeline "$@" ;;
  concat)  concat_videos "$@" ;;
  frame)   extract_frame "$@" ;;
  help|-h|--help) print_usage ;;
  *) print_usage >&2; die "unknown command: $COMMAND" ;;
esac
