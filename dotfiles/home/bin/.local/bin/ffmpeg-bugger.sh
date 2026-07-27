#!/usr/bin/env bash
set -Eeuo pipefail

# META #########################################################################

COMMAND="${1:-record}"
[[ $# -gt 0 ]] && shift

BASE_DIR="${FFMPEG_BUGGER_DIR:-$HOME/Videos/bugger}"
DISPLAY_NAME="${FFMPEG_DISPLAY:-${DISPLAY:-}}"
CAPTURE_SIZE="${FFMPEG_CAPTURE_SIZE:-}"
CAPTURE_OFFSET="${FFMPEG_CAPTURE_OFFSET:-0,0}"
FRAMERATE="${FFMPEG_FRAMERATE:-10}"
RECORD_CRF="${FFMPEG_RECORD_CRF:-18}"
EDIT_CRF="${FFMPEG_EDIT_CRF:-18}"
PRESET="${FFMPEG_PRESET:-veryfast}"
PIXEL_FORMAT="${FFMPEG_PIXEL_FORMAT:-yuv420p}"
KEYFRAME_INTERVAL_SECONDS="${FFMPEG_KEYFRAME_INTERVAL_SECONDS:-2}"
OVERWRITE="${FFMPEG_OVERWRITE:-0}"

FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"

TEMP_PATHS=()
CREATED_TEMP=""
PLAN_STARTS=()
PLAN_ENDS=()
PLAN_SPEEDS=()

# USAGE ########################################################################

print_usage() {
  cat <<EOF_USAGE
Usage:
  ffmpeg-bugger.sh
  ffmpeg-bugger.sh record [output.mp4]
  ffmpeg-bugger.sh info <input-video>
  ffmpeg-bugger.sh clip <input-video> <start> <end> [speed] [output.mp4]
  ffmpeg-bugger.sh speed <input-video> <factor> [output.mp4]
  ffmpeg-bugger.sh render <input-video> <timeline.txt> [output.mp4]
  ffmpeg-bugger.sh concat <output.mp4> <input-1.mp4> <input-2.mp4> [...]
  ffmpeg-bugger.sh frame <input-video> <timestamp> [output.png]
  ffmpeg-bugger.sh help

Default behavior:
  Calling the script without arguments records the full X11 display to a
  timestamped MP4 under:

    $BASE_DIR

Commands:
  record  Record the X11 display until Ctrl-C is pressed.
  info    Show concise video-stream and duration information.
  clip    Render one accurate source interval, optionally at another speed.
  speed   Render the whole source at another speed.
  render  Render selected intervals from a timeline manifest.
  concat  Join compatible video-only MP4 clips without re-encoding.
  frame   Extract one PNG frame at a timestamp.

Timeline format:
  One source segment per line: START END [SPEED]
  Blank lines and lines beginning with # are ignored.
  Omitted source ranges are cut from the final video.

  Example:

    # start     end       speed
    00:00:00    00:00:20  1
    00:00:20    00:05:12  12
    00:05:12    00:08:40  1.5

Environment:
  FFMPEG_BUGGER_DIR=$BASE_DIR
  FFMPEG_DISPLAY=${DISPLAY_NAME:-<unset>}
  FFMPEG_CAPTURE_SIZE=${CAPTURE_SIZE:-<auto-detect>}
  FFMPEG_CAPTURE_OFFSET=$CAPTURE_OFFSET
  FFMPEG_FRAMERATE=$FRAMERATE
  FFMPEG_RECORD_CRF=$RECORD_CRF
  FFMPEG_EDIT_CRF=$EDIT_CRF
  FFMPEG_PRESET=$PRESET
  FFMPEG_PIXEL_FORMAT=$PIXEL_FORMAT
  FFMPEG_KEYFRAME_INTERVAL_SECONDS=$KEYFRAME_INTERVAL_SECONDS
  FFMPEG_OVERWRITE=$OVERWRITE

Examples:
  ffmpeg-bugger.sh record /tmp/poc.mp4
  ffmpeg-bugger.sh info /tmp/poc.mp4
  ffmpeg-bugger.sh clip /tmp/poc.mp4 00:00:00 00:05:12 1.5 /tmp/part-1.mp4
  ffmpeg-bugger.sh speed /tmp/poc.mp4 1.5 /tmp/poc-1.5x.mp4
  ffmpeg-bugger.sh render /tmp/poc.mp4 ./timeline.txt /tmp/poc-edited.mp4
  ffmpeg-bugger.sh concat /tmp/final.mp4 /tmp/part-1.mp4 /tmp/part-2.mp4
  ffmpeg-bugger.sh frame /tmp/poc.mp4 00:05:12 /tmp/proof.png

Notes:
  - Recording and every edited output are video-only.
  - Accurate edits are re-encoded and are not limited to source keyframes.
  - clip, speed, and render share the same segment-plan rendering engine.
EOF_USAGE
}

# MESSAGES #####################################################################

print_info() {
  printf '[ffmpeg-bugger] %s\n' "$*"
}

print_error() {
  printf '[ffmpeg-bugger] ERROR: %s\n' "$*" >&2
}

die() {
  print_error "$*"
  exit 1
}

# TEMPORARY PATHS ##############################################################

register_temp() {
  TEMP_PATHS+=("$1")
}

cleanup_temps() {
  local path

  if (( ${#TEMP_PATHS[@]} == 0 )); then
    return 0
  fi

  for path in "${TEMP_PATHS[@]}"; do
    [[ -n "$path" ]] && rm -rf -- "$path"
  done

  return 0
}

trap cleanup_temps EXIT

make_temp_file() {
  local parent="$1"
  local suffix="$2"

  CREATED_TEMP="$(mktemp --tmpdir="$parent" ".ffmpeg-bugger.XXXXXXXX${suffix}")"
  register_temp "$CREATED_TEMP"
}

make_temp_dir() {
  CREATED_TEMP="$(mktemp -d)"
  register_temp "$CREATED_TEMP"
}

# INPUT CHECKS AND SANITIZATION ################################################

have() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  have "$1" || die "missing required command: $1"
}

reject_control_characters() {
  local value="$1"
  local label="$2"

  [[ "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *$'\t'* ]] || \
    die "$label contains unsupported control characters"
}

normalize_existing_file() {
  local value="$1"
  local label="$2"

  [[ -n "$value" ]] || die "$label is required"
  reject_control_characters "$value" "$label"
  [[ -f "$value" ]] || die "$label not found: $value"
  [[ -r "$value" ]] || die "$label is not readable: $value"
  realpath -- "$value"
}

normalize_output_path() {
  local value="$1"
  local required_extension="$2"
  local label="$3"
  local output

  [[ -n "$value" ]] || die "$label is required"
  reject_control_characters "$value" "$label"
  [[ "$value" == *"$required_extension" ]] || die "$label must end with $required_extension: $value"

  output="$(realpath -m -- "$value")"
  mkdir -p -- "$(dirname -- "$output")"

  if [[ -e "$output" && "$OVERWRITE" != "1" ]]; then
    die "$label already exists: $output (set FFMPEG_OVERWRITE=1 to replace it)"
  fi

  printf '%s\n' "$output"
}

require_video_stream() {
  local input="$1"
  local stream

  stream="$("$FFPROBE" -v error -select_streams v:0 -show_entries stream=index -of csv=p=0 -- "$input")"
  [[ -n "$stream" ]] || die "input contains no video stream: $input"
}

normalize_input_video() {
  local input
  input="$(normalize_existing_file "$1" 'input video')"
  require_video_stream "$input"
  printf '%s\n' "$input"
}

normalize_timeline_file() {
  normalize_existing_file "$1" 'timeline file'
}

normalize_positive_number() {
  local value="$1"
  local label="$2"

  awk -v value="$value" -v label="$label" '
    BEGIN {
      if (value !~ /^[0-9]+([.][0-9]+)?$/ || value <= 0) {
        printf "[ffmpeg-bugger] ERROR: invalid %s: %s\n", label, value > "/dev/stderr"
        exit 1
      }
      printf "%.10g\n", value
    }
  ' || exit 1
}

normalize_speed() {
  local speed
  speed="$(normalize_positive_number "$1" 'speed factor')"

  awk -v speed="$speed" '
    BEGIN {
      if (speed < 0.01 || speed > 1000) {
        printf "[ffmpeg-bugger] ERROR: speed factor must be between 0.01 and 1000: %s\n", speed > "/dev/stderr"
        exit 1
      }
      printf "%.10g\n", speed
    }
  ' || exit 1
}

normalize_timestamp() {
  local value="$1"
  local label="$2"

  awk -F: -v value="$value" -v label="$label" '
    function fail() {
      printf "[ffmpeg-bugger] ERROR: invalid %s: %s\n", label, value > "/dev/stderr"
      exit 1
    }

    BEGIN {
      n = split(value, p, ":")
      if (n < 1 || n > 3) fail()

      for (i = 1; i <= n; i++) {
        if (p[i] !~ /^[0-9]+([.][0-9]+)?$/) fail()
      }

      if (n == 1) {
        seconds = p[1]
      } else if (n == 2) {
        if (p[2] >= 60) fail()
        seconds = p[1] * 60 + p[2]
      } else {
        if (p[2] >= 60 || p[3] >= 60) fail()
        seconds = p[1] * 3600 + p[2] * 60 + p[3]
      }

      if (seconds < 0) fail()
      printf "%.6f\n", seconds
    }
  ' || exit 1
}

normalize_crf() {
  local value="$1"
  local label="$2"

  [[ "$value" =~ ^[0-9]+$ ]] || die "invalid $label: $value"
  (( value >= 0 && value <= 51 )) || die "$label must be between 0 and 51: $value"
  printf '%s\n' "$value"
}

normalize_framerate() {
  normalize_positive_number "$1" 'framerate'
}

normalize_capture_size() {
  local value="$1"
  [[ "$value" =~ ^([1-9][0-9]*)x([1-9][0-9]*)$ ]] || die "invalid capture size: $value"
  printf '%s\n' "$value"
}

normalize_capture_offset() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+,[0-9]+$ ]] || die "invalid capture offset: $value"
  printf '%s\n' "$value"
}

normalize_preset() {
  local value="$1"
  case "$value" in
    ultrafast|superfast|veryfast|faster|fast|medium|slow|slower|veryslow|placebo)
      printf '%s\n' "$value"
      ;;
    *)
      die "invalid x264 preset: $value"
      ;;
  esac
}

normalize_pixel_format() {
  local value="$1"
  [[ "$value" =~ ^[A-Za-z0-9_]+$ ]] || die "invalid pixel format: $value"
  printf '%s\n' "$value"
}

normalize_overwrite() {
  case "$1" in
    0|1) printf '%s\n' "$1" ;;
    *) die "FFMPEG_OVERWRITE must be 0 or 1: $1" ;;
  esac
}

media_duration() {
  local input="$1"
  local duration

  duration="$("$FFPROBE" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -- "$input")"
  normalize_positive_number "$duration" 'video duration'
}

validate_segment_bounds() {
  local start="$1"
  local end="$2"
  local source_duration="$3"

  awk -v start="$start" -v end="$end" -v source="$source_duration" '
    BEGIN {
      tolerance = 0.050001
      if (end <= start) {
        print "[ffmpeg-bugger] ERROR: segment end must be greater than start" > "/dev/stderr"
        exit 1
      }
      if (start >= source) {
        print "[ffmpeg-bugger] ERROR: segment starts at or after the end of the source" > "/dev/stderr"
        exit 1
      }
      if (end > source + tolerance) {
        printf "[ffmpeg-bugger] ERROR: segment end %.6f exceeds source duration %.6f\n", end, source > "/dev/stderr"
        exit 1
      }
    }
  ' || exit 1
}

normalize_segment_end() {
  local end="$1"
  local source_duration="$2"

  awk -v end="$end" -v source="$source_duration" '
    BEGIN {
      if (end > source) end = source
      printf "%.6f\n", end
    }
  '
}

validate_distinct_paths() {
  local input="$1"
  local output="$2"
  [[ "$input" != "$output" ]] || die 'input and output paths must be different'
}

# PATH AND MEDIA HELPERS #######################################################

media_stem() {
  local name
  name="$(basename -- "$1")"
  printf '%s\n' "${name%.*}"
}

media_dir() {
  dirname -- "$1"
}

sanitize_filename_token() {
  printf '%s' "$1" | tr ':,./ ' '------'
}

replace_output() {
  local temporary="$1"
  local output="$2"

  if [[ "$OVERWRITE" == "1" ]]; then
    mv -f -- "$temporary" "$output"
  else
    mv -- "$temporary" "$output"
  fi
}

detect_capture_size() {
  if [[ -n "$CAPTURE_SIZE" ]]; then
    normalize_capture_size "$CAPTURE_SIZE"
    return 0
  fi

  if have xdpyinfo; then
    xdpyinfo -display "$DISPLAY_NAME" 2>/dev/null | awk '/dimensions:/ { print $2; exit }'
    return 0
  fi

  if have xrandr; then
    xrandr --display "$DISPLAY_NAME" --current 2>/dev/null | awk '/\*/ { print $1; exit }'
    return 0
  fi

  return 1
}

video_signature() {
  local input="$1"
  "$FFPROBE" -v error -select_streams v:0 \
    -show_entries stream=codec_name,profile,level,width,height,pix_fmt,time_base \
    -of csv=p=0 -- "$input"
}

# PLAN #########################################################################

plan_clear() {
  PLAN_STARTS=()
  PLAN_ENDS=()
  PLAN_SPEEDS=()
}

plan_add_segment() {
  local raw_start="$1"
  local raw_end="$2"
  local raw_speed="$3"
  local source_duration="$4"
  local start
  local end
  local speed

  start="$(normalize_timestamp "$raw_start" 'segment start')"
  end="$(normalize_timestamp "$raw_end" 'segment end')"
  speed="$(normalize_speed "$raw_speed")"

  validate_segment_bounds "$start" "$end" "$source_duration"
  end="$(normalize_segment_end "$end" "$source_duration")"

  PLAN_STARTS+=("$start")
  PLAN_ENDS+=("$end")
  PLAN_SPEEDS+=("$speed")
}

plan_add_full_video() {
  local source_duration="$1"
  local speed="$2"
  plan_add_segment 0 "$source_duration" "$speed" "$source_duration"
}

plan_load_timeline() {
  local timeline="$1"
  local source_duration="$2"
  local line
  local line_number=0
  local start
  local end
  local speed
  local extra

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    line="${line%%#*}"
    [[ -n "${line//[[:space:]]/}" ]] || continue

    start=''
    end=''
    speed='1'
    extra=''
    read -r start end speed extra <<< "$line"

    [[ -n "$start" && -n "$end" ]] || die "invalid timeline line $line_number: expected START END [SPEED]"
    [[ -z "$extra" ]] || die "invalid timeline line $line_number: too many fields"

    plan_add_segment "$start" "$end" "${speed:-1}" "$source_duration"
  done < "$timeline"

  (( ${#PLAN_STARTS[@]} > 0 )) || die 'timeline contains no segments'
}

# INFO #########################################################################

show_media_info() {
  local input
  input="$(normalize_input_video "$1")"

  "$FFPROBE" -v error \
    -show_entries format=filename,start_time,duration,size,bit_rate \
    -show_entries stream=index,codec_type,codec_name,width,height,pix_fmt,r_frame_rate,avg_frame_rate,start_time,duration \
    -of default=noprint_wrappers=1 -- "$input"
}

# CAPTURE ######################################################################

record_screen() {
  local raw_output="${1:-$BASE_DIR/bugger-$(date +%Y%m%d-%H%M%S).mp4}"
  local output
  local size
  local offset
  local fps
  local record_crf
  local preset
  local pixel_format
  local keyframe_seconds
  local keyframe_interval
  local input_spec
  local overwrite_flag

  [[ -n "$DISPLAY_NAME" ]] || die 'DISPLAY is unset; set DISPLAY or FFMPEG_DISPLAY for X11 capture'

  output="$(normalize_output_path "$raw_output" '.mp4' 'recording output')"
  size="$(detect_capture_size)" || die 'cannot detect display size; set FFMPEG_CAPTURE_SIZE=WIDTHxHEIGHT'
  size="$(normalize_capture_size "$size")"
  offset="$(normalize_capture_offset "$CAPTURE_OFFSET")"
  fps="$(normalize_framerate "$FRAMERATE")"
  record_crf="$(normalize_crf "$RECORD_CRF" 'record CRF')"
  preset="$(normalize_preset "$PRESET")"
  pixel_format="$(normalize_pixel_format "$PIXEL_FORMAT")"
  keyframe_seconds="$(normalize_positive_number "$KEYFRAME_INTERVAL_SECONDS" 'keyframe interval')"
  keyframe_interval="$(awk -v fps="$fps" -v seconds="$keyframe_seconds" 'BEGIN { n = int(fps * seconds + 0.5); if (n < 1) n = 1; print n }')"
  input_spec="${DISPLAY_NAME}+${offset}"
  if [[ "$OVERWRITE" == "1" ]]; then
    overwrite_flag='-y'
  else
    overwrite_flag='-n'
  fi

  print_info "recording X11 display: $input_spec"
  print_info "capture size: $size at ${fps} fps"
  print_info "output: $output"
  print_info 'press Ctrl-C to stop and finalize the recording'

  exec "$FFMPEG" -hide_banner "$overwrite_flag" \
    -thread_queue_size 1024 \
    -framerate "$fps" \
    -video_size "$size" \
    -f x11grab \
    -i "$input_spec" \
    -map 0:v:0 \
    -an \
    -c:v libx264 \
    -preset "$preset" \
    -crf "$record_crf" \
    -pix_fmt "$pixel_format" \
    -g "$keyframe_interval" \
    -keyint_min "$keyframe_interval" \
    -sc_threshold 0 \
    -movflags +faststart \
    "$output"
}

# SHARED SEGMENT RENDERER ######################################################

render_segment_unchecked() {
  local input="$1"
  local start="$2"
  local end="$3"
  local speed="$4"
  local output="$5"
  local duration
  local edit_crf
  local preset
  local pixel_format

  duration="$(awk -v start="$start" -v end="$end" 'BEGIN { printf "%.6f\n", end - start }')"
  edit_crf="$(normalize_crf "$EDIT_CRF" 'edit CRF')"
  preset="$(normalize_preset "$PRESET")"
  pixel_format="$(normalize_pixel_format "$PIXEL_FORMAT")"

  print_info "rendering segment: start=$start end=$end speed=${speed}x"

  "$FFMPEG" -hide_banner -y \
    -ss "$start" \
    -t "$duration" \
    -i "$input" \
    -map 0:v:0 \
    -vf "setpts=(PTS-STARTPTS)/${speed}" \
    -an \
    -c:v libx264 \
    -preset "$preset" \
    -crf "$edit_crf" \
    -pix_fmt "$pixel_format" \
    -fps_mode vfr \
    -video_track_timescale 90000 \
    -movflags +faststart \
    "$output"
}

concat_unchecked() {
  local output="$1"
  shift
  local manifest
  local input
  local absolute
  local escaped

  make_temp_file "$(dirname -- "$output")" '.ffconcat'
  manifest="$CREATED_TEMP"
  printf 'ffconcat version 1.0\n' > "$manifest"

  for input in "$@"; do
    absolute="$(realpath -- "$input")"
    escaped="${absolute//\\/\\\\}"
    escaped="${escaped//\'/\'\\\'\'}"
    printf "file '%s'\n" "$escaped" >> "$manifest"
  done

  "$FFMPEG" -hide_banner -y \
    -f concat \
    -safe 0 \
    -i "$manifest" \
    -map 0:v:0 \
    -an \
    -c:v copy \
    -movflags +faststart \
    "$output"
}

render_plan() {
  local input="$1"
  local output="$2"
  local workdir
  local segment_files=()
  local index
  local segment
  local temporary

  (( ${#PLAN_STARTS[@]} > 0 )) || die 'internal error: render plan is empty'

  make_temp_file "$(dirname -- "$output")" '.mp4'
  temporary="$CREATED_TEMP"

  if (( ${#PLAN_STARTS[@]} == 1 )); then
    render_segment_unchecked \
      "$input" \
      "${PLAN_STARTS[0]}" \
      "${PLAN_ENDS[0]}" \
      "${PLAN_SPEEDS[0]}" \
      "$temporary"
  else
    make_temp_dir
    workdir="$CREATED_TEMP"

    for index in "${!PLAN_STARTS[@]}"; do
      segment="$workdir/$(printf '%04d' "$((index + 1))").mp4"
      render_segment_unchecked \
        "$input" \
        "${PLAN_STARTS[$index]}" \
        "${PLAN_ENDS[$index]}" \
        "${PLAN_SPEEDS[$index]}" \
        "$segment"
      segment_files+=("$segment")
    done

    concat_unchecked "$temporary" "${segment_files[@]}"
  fi

  replace_output "$temporary" "$output"
  print_info "output: $output"
}

# EDIT COMMAND ADAPTERS ########################################################

clip_video() {
  local raw_input="${1:-}"
  local raw_start="${2:-}"
  local raw_end="${3:-}"
  local optional="${4:-}"
  local explicit_output="${5:-}"
  local input
  local source_duration
  local speed='1'
  local raw_output=''
  local output
  local stem
  local directory

  [[ -n "$raw_input" && -n "$raw_start" && -n "$raw_end" ]] || \
    die 'clip requires: <input-video> <start> <end> [speed] [output.mp4]'

  input="$(normalize_input_video "$raw_input")"
  source_duration="$(media_duration "$input")"

  if [[ -n "$optional" ]]; then
    if awk -v value="$optional" 'BEGIN { exit !(value ~ /^[0-9]+([.][0-9]+)?$/ && value > 0) }'; then
      speed="$(normalize_speed "$optional")"
      raw_output="$explicit_output"
    else
      raw_output="$optional"
      [[ -z "$explicit_output" ]] || die 'unexpected extra output argument'
    fi
  fi

  if [[ -z "$raw_output" ]]; then
    stem="$(media_stem "$input")"
    directory="$(media_dir "$input")"
    raw_output="$directory/${stem}-$(sanitize_filename_token "$raw_start")-$(sanitize_filename_token "$raw_end")-${speed}x.mp4"
  fi

  output="$(normalize_output_path "$raw_output" '.mp4' 'clip output')"
  validate_distinct_paths "$input" "$output"

  plan_clear
  plan_add_segment "$raw_start" "$raw_end" "$speed" "$source_duration"
  render_plan "$input" "$output"
}

speed_video() {
  local raw_input="${1:-}"
  local raw_speed="${2:-}"
  local raw_output="${3:-}"
  local input
  local speed
  local source_duration
  local output
  local stem
  local directory

  [[ -n "$raw_input" && -n "$raw_speed" ]] || die 'speed requires: <input-video> <factor> [output.mp4]'

  input="$(normalize_input_video "$raw_input")"
  speed="$(normalize_speed "$raw_speed")"
  source_duration="$(media_duration "$input")"

  if [[ -z "$raw_output" ]]; then
    stem="$(media_stem "$input")"
    directory="$(media_dir "$input")"
    raw_output="$directory/${stem}-${speed}x.mp4"
  fi

  output="$(normalize_output_path "$raw_output" '.mp4' 'speed output')"
  validate_distinct_paths "$input" "$output"

  plan_clear
  plan_add_full_video "$source_duration" "$speed"
  render_plan "$input" "$output"
}

render_timeline() {
  local raw_input="${1:-}"
  local raw_timeline="${2:-}"
  local raw_output="${3:-}"
  local input
  local timeline
  local source_duration
  local output
  local stem
  local directory

  [[ -n "$raw_input" && -n "$raw_timeline" ]] || die 'render requires: <input-video> <timeline.txt> [output.mp4]'

  input="$(normalize_input_video "$raw_input")"
  timeline="$(normalize_timeline_file "$raw_timeline")"
  source_duration="$(media_duration "$input")"

  if [[ -z "$raw_output" ]]; then
    stem="$(media_stem "$input")"
    directory="$(media_dir "$input")"
    raw_output="$directory/${stem}-edited.mp4"
  fi

  output="$(normalize_output_path "$raw_output" '.mp4' 'render output')"
  validate_distinct_paths "$input" "$output"

  plan_clear
  plan_load_timeline "$timeline" "$source_duration"
  render_plan "$input" "$output"
}

# CONCATENATION ################################################################

concat_videos() {
  local raw_output="${1:-}"
  shift || true
  local output
  local inputs=()
  local raw_input
  local input
  local signature=''
  local current_signature
  local temporary

  [[ -n "$raw_output" && $# -ge 2 ]] || die 'concat requires: <output.mp4> <input-1.mp4> <input-2.mp4> [...]'

  output="$(normalize_output_path "$raw_output" '.mp4' 'concat output')"

  for raw_input in "$@"; do
    input="$(normalize_input_video "$raw_input")"
    validate_distinct_paths "$input" "$output"
    current_signature="$(video_signature "$input")"

    if [[ -z "$signature" ]]; then
      signature="$current_signature"
    elif [[ "$current_signature" != "$signature" ]]; then
      die "concat inputs are not stream-copy compatible: $input"
    fi

    inputs+=("$input")
  done

  make_temp_file "$(dirname -- "$output")" '.mp4'
  temporary="$CREATED_TEMP"
  concat_unchecked "$temporary" "${inputs[@]}"
  replace_output "$temporary" "$output"
  print_info "output: $output"
}

# FRAME EXTRACTION #############################################################

extract_frame() {
  local raw_input="${1:-}"
  local raw_timestamp="${2:-}"
  local raw_output="${3:-}"
  local input
  local timestamp
  local source_duration
  local output
  local stem
  local directory
  local temporary

  [[ -n "$raw_input" && -n "$raw_timestamp" ]] || die 'frame requires: <input-video> <timestamp> [output.png]'

  input="$(normalize_input_video "$raw_input")"
  timestamp="$(normalize_timestamp "$raw_timestamp" 'frame timestamp')"
  source_duration="$(media_duration "$input")"

  awk -v time="$timestamp" -v duration="$source_duration" '
    BEGIN {
      if (time >= duration) {
        printf "[ffmpeg-bugger] ERROR: frame timestamp %.6f is outside source duration %.6f\n", time, duration > "/dev/stderr"
        exit 1
      }
    }
  ' || exit 1

  if [[ -z "$raw_output" ]]; then
    stem="$(media_stem "$input")"
    directory="$(media_dir "$input")"
    raw_output="$directory/${stem}-frame-$(sanitize_filename_token "$raw_timestamp").png"
  fi

  output="$(normalize_output_path "$raw_output" '.png' 'frame output')"
  make_temp_file "$(dirname -- "$output")" '.png'
  temporary="$CREATED_TEMP"

  "$FFMPEG" -hide_banner -y \
    -ss "$timestamp" \
    -i "$input" \
    -map 0:v:0 \
    -frames:v 1 \
    -an \
    "$temporary"

  replace_output "$temporary" "$output"
  print_info "output: $output"
}

# MAIN #########################################################################

require_cmd "$FFMPEG"
require_cmd "$FFPROBE"
require_cmd realpath
require_cmd mktemp
require_cmd awk

OVERWRITE="$(normalize_overwrite "$OVERWRITE")"

case "$COMMAND" in
  record)
    [[ $# -le 1 ]] || die 'record accepts at most one output path'
    record_screen "${1:-}"
    ;;
  info|probe)
    [[ $# -eq 1 ]] || die 'info requires one input video'
    show_media_info "$1"
    ;;
  clip|segment)
    clip_video "$@"
    ;;
  speed)
    speed_video "$@"
    ;;
  render|edit)
    render_timeline "$@"
    ;;
  concat|join)
    concat_videos "$@"
    ;;
  frame|screenshot)
    extract_frame "$@"
    ;;
  help|-h|--help)
    print_usage
    ;;
  *)
    print_usage >&2
    die "unknown command: $COMMAND"
    ;;
esac
