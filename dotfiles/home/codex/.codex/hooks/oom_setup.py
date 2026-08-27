#!/usr/bin/env python3
"""Configure the aggregate systemd slice used by guarded Codex commands."""

from __future__ import annotations

import argparse
import subprocess
import sys

from oom_lib import encode_json_packet
from oom_systemd import configure_slice


# CONSTANTS ####################################################################


DEFAULT_SLICE_NAME = "codex-jobs.slice"
DEFAULT_SLICE_MEMORY_HIGH = "8G"
DEFAULT_SLICE_MEMORY_MAX = "10G"
DEFAULT_PRESSURE_LIMIT = "40%"
DEFAULT_PRESSURE_DURATION = "15s"


# INPUTS #######################################################################


def parse_inputs() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hook", action="store_true")
    parser.add_argument("--slice-name", default=DEFAULT_SLICE_NAME)
    parser.add_argument("--slice-high", default=DEFAULT_SLICE_MEMORY_HIGH)
    parser.add_argument("--slice-max", default=DEFAULT_SLICE_MEMORY_MAX)
    parser.add_argument("--pressure-limit", default=DEFAULT_PRESSURE_LIMIT)
    parser.add_argument("--pressure-duration", default=DEFAULT_PRESSURE_DURATION)
    return parser.parse_args()


# REPORTING ####################################################################


def report_failure(message: str, hook_mode: bool) -> int:
    warning = f"Codex aggregate OOM protection could not be configured: {message}"
    if hook_mode:
        sys.stdout.buffer.write(encode_json_packet({"systemMessage": warning}))
        return 0
    print(warning, file=sys.stderr)
    return 1


# ENTRYPOINT ###################################################################


def main() -> int:
    args = parse_inputs()
    try:
        configure_slice(
            args.slice_name,
            args.slice_high,
            args.slice_max,
            args.pressure_limit,
            args.pressure_duration,
        )
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        return report_failure(str(error), args.hook)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
