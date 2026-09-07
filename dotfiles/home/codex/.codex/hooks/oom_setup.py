#!/usr/bin/env python3
"""Configure the aggregate systemd slice for one named OOM config."""

from __future__ import annotations

import argparse
import subprocess
import sys

from oom_config import CONFIG_PATH, ConfigurationError, load_config
from oom_lib import encode_json_packet
from oom_systemd import configure_slice

# CONSTANTS ####################################################################


DEFAULT_CONFIG = "default"


# INPUTS #######################################################################


def parse_inputs() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hook", action="store_true")
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    return parser.parse_args()


# REPORTING ####################################################################


def report_failure(message: str, hook_mode: bool) -> int:
    warning = f"Codex aggregate OOM protection could not be configured: {message}"
    if hook_mode:
        sys.stdout.buffer.write(encode_json_packet({"systemMessage": warning}))
        return 0
    print(warning, file=sys.stderr)
    return 1


# MAIN #########################################################################


def main() -> int:
    args = parse_inputs()
    try:
        config = load_config(args.config, CONFIG_PATH)
        configure_slice(config.slice)
    except (
        ConfigurationError,
        OSError,
        RuntimeError,
        subprocess.TimeoutExpired,
    ) as error:
        return report_failure(str(error), args.hook)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
