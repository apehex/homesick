#!/usr/bin/env python3
"""Asynchronously monitor a Codex scope that may outlive its shell tool call."""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections.abc import Callable
from typing import Any

from oom_callback import scope_identity, terminal_output
from oom_config import CONFIG_PATH, ConfigurationError, load_config
from oom_lib import read_json_stream
from oom_report import (
    OBSERVATION_ERRORS,
    emit_hook_output,
    format_diagnostic_message,
    hook_output,
    safe_detail,
)
from oom_systemd import inspect_scope, scope_is_active, scope_is_present

# CONSTANTS ####################################################################


DEFAULT_CONFIG = "default"
DEFAULT_GRACE_SECONDS = 2.0
DEFAULT_POLL_SECONDS = 5.0
DEFAULT_MAX_SECONDS = 21_600.0
MONITOR_ERRORS = (ConfigurationError, json.JSONDecodeError, *OBSERVATION_ERRORS)


# INPUTS #######################################################################


def parse_inputs() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    parser.add_argument("--grace-seconds", type=float, default=DEFAULT_GRACE_SECONDS)
    parser.add_argument("--poll-seconds", type=float, default=DEFAULT_POLL_SECONDS)
    parser.add_argument("--max-seconds", type=float, default=DEFAULT_MAX_SECONDS)
    return parser.parse_args()


# MONITORING ###################################################################


def process_packet(
    packet: dict[str, Any],
    config_name: str,
    *,
    grace_seconds: float,
    poll_seconds: float,
    max_seconds: float,
    sleep: Callable[[float], None] = time.sleep,
    monotonic: Callable[[], float] = time.monotonic,
) -> dict[str, Any] | None:
    unit = scope_identity(packet)
    if grace_seconds < 0:
        raise ValueError("grace seconds must not be negative")
    if poll_seconds <= 0 or max_seconds <= 0:
        raise ValueError("poll and maximum seconds must be positive")

    config = load_config(config_name, CONFIG_PATH)
    deadline = monotonic() + max_seconds
    if grace_seconds:
        sleep(min(grace_seconds, max_seconds))

    while True:
        observation = inspect_scope(unit)
        if not scope_is_present(observation):
            return None
        if not scope_is_active(observation):
            return terminal_output(observation, config.slice.name, delayed=True)

        remaining = deadline - monotonic()
        if remaining <= 0:
            return None
        sleep(min(poll_seconds, remaining))


# MAIN #########################################################################


def main() -> int:
    args = parse_inputs()
    unit = "unknown scope"
    try:
        packet = read_json_stream(sys.stdin.buffer)
        unit = scope_identity(packet)
        output = process_packet(
            packet,
            args.config,
            grace_seconds=args.grace_seconds,
            poll_seconds=args.poll_seconds,
            max_seconds=args.max_seconds,
        )
    except MONITOR_ERRORS as error:
        output = hook_output(
            system_message=format_diagnostic_message(
                unit,
                [f"asynchronous monitor failed: {safe_detail(error)}"],
            )
        )
    emit_hook_output(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
