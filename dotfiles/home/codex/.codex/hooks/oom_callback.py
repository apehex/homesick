#!/usr/bin/env python3
"""Inspect and clean the exact Codex Bash command scope after a tool call."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

from oom_config import CONFIG_PATH, ConfigurationError, load_config
from oom_lib import read_json_stream, scope_unit
from oom_report import (
    OBSERVATION_ERRORS,
    capture_terminal_scope,
    emit_hook_output,
    format_diagnostic_message,
    format_survivor_context,
    format_terminal_context,
    hook_output,
    safe_detail,
)
from oom_systemd import (
    inspect_scope,
    scope_is_active,
    scope_is_present,
    set_scope_managed_oom_preference,
)

# CONSTANTS ####################################################################


DEFAULT_CONFIG = "default"
MONITOR_SECONDS = 21_600.0
CALLBACK_ERRORS = (ConfigurationError, json.JSONDecodeError, *OBSERVATION_ERRORS)


# INPUTS #######################################################################


def parse_inputs() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    parser.add_argument("--monitor-seconds", type=float, default=MONITOR_SECONDS)
    return parser.parse_args()


def scope_identity(packet: dict[str, Any]) -> str:
    session_id = packet.get("session_id")
    tool_use_id = packet.get("tool_use_id")
    if not isinstance(session_id, str) or not isinstance(tool_use_id, str):
        raise TypeError("session_id and tool_use_id must be strings")
    if not session_id or not tool_use_id:
        raise ValueError("session_id and tool_use_id must not be empty")
    return scope_unit(session_id, tool_use_id)


# PROCESSING ###################################################################


def terminal_output(
    observation: dict[str, Any],
    slice_name: str,
    *,
    delayed: bool,
) -> dict[str, Any] | None:
    snapshot = capture_terminal_scope(observation, slice_name)
    context = None
    if snapshot.classification is not None:
        context = format_terminal_context(snapshot, delayed=delayed)
    diagnostic = None
    if snapshot.diagnostics:
        diagnostic = format_diagnostic_message(
            str(observation.get("unit", "unknown scope")),
            snapshot.diagnostics,
        )
    return hook_output(additional_context=context, system_message=diagnostic)


def process_packet(
    packet: dict[str, Any],
    config_name: str,
    monitor_seconds: float,
) -> dict[str, Any] | None:
    unit = scope_identity(packet)
    if monitor_seconds <= 0:
        raise ValueError("monitor seconds must be positive")
    config = load_config(config_name, CONFIG_PATH)
    observation = inspect_scope(unit)
    if not scope_is_present(observation):
        return None
    if not scope_is_active(observation):
        return terminal_output(observation, config.slice.name, delayed=False)

    try:
        set_scope_managed_oom_preference(unit, "none")
    except OBSERVATION_ERRORS as error:
        demotion_error = safe_detail(error)
        refreshed = inspect_scope(unit)
        if not scope_is_present(refreshed):
            return None
        if not scope_is_active(refreshed):
            return terminal_output(refreshed, config.slice.name, delayed=False)
        return hook_output(
            additional_context=format_survivor_context(
                refreshed,
                demotion="failed",
                previous_preference=str(
                    observation.get("managed_oom_preference", "unknown")
                ),
                monitor_seconds=monitor_seconds,
            ),
            system_message=format_diagnostic_message(
                unit,
                [f"surviving-scope preference demotion failed: {demotion_error}"],
            ),
        )

    refreshed = inspect_scope(unit)
    if not scope_is_present(refreshed):
        return None
    if not scope_is_active(refreshed):
        return terminal_output(refreshed, config.slice.name, delayed=False)
    return hook_output(
        additional_context=format_survivor_context(
            refreshed,
            demotion="demoted",
            previous_preference=str(
                observation.get("managed_oom_preference", "unknown")
            ),
            monitor_seconds=monitor_seconds,
        )
    )


# MAIN #########################################################################


def main() -> int:
    args = parse_inputs()
    unit = "unknown scope"
    try:
        packet = read_json_stream(sys.stdin.buffer)
        unit = scope_identity(packet)
        output = process_packet(packet, args.config, args.monitor_seconds)
    except CALLBACK_ERRORS as error:
        output = hook_output(
            system_message=format_diagnostic_message(
                unit,
                [f"callback inspection failed: {safe_detail(error)}"],
            )
        )
    emit_hook_output(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
