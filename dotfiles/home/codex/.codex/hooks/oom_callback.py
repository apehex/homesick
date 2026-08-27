#!/usr/bin/env python3
"""Codex PostToolUse hook: report OOM evidence for the exact Bash scope."""

from __future__ import annotations

import json
import subprocess
import sys
from typing import Any

from oom_lib import encode_json_packet, read_json_stream, scope_unit
from oom_systemd import classify_oom, inspect_scope, reset_failed_scope


# CONSTANTS ####################################################################


BYTE_UNIT = 1024
SIZE_SUFFIXES = ("B", "KiB", "MiB", "GiB", "TiB")
CALLBACK_ERRORS = (
    json.JSONDecodeError,
    OSError,
    RuntimeError,
    subprocess.TimeoutExpired,
    TypeError,
    ValueError,
)


# INPUTS #######################################################################


def read_scope_identity() -> str | None:
    packet = read_json_stream(sys.stdin.buffer)
    session_id = packet.get("session_id")
    tool_use_id = packet.get("tool_use_id")
    if not isinstance(session_id, str) or not isinstance(tool_use_id, str):
        return None
    if not session_id or not tool_use_id:
        return None
    return scope_unit(session_id, tool_use_id)


# FORMATTING ###################################################################


def format_size(value: Any) -> str:
    if not isinstance(value, int):
        return "unknown"
    size = float(value)
    for suffix in SIZE_SUFFIXES:
        if size < BYTE_UNIT or suffix == SIZE_SUFFIXES[-1]:
            return f"{size:.1f} {suffix}"
        size /= BYTE_UNIT
    return "unknown"


def format_observation(observation: dict[str, Any], classification: str) -> str:
    return (
        "The preceding shell tool was terminated by a resource guard: "
        f"{classification} in {observation['unit']}; "
        f"peak memory {format_size(observation.get('memory_peak_bytes'))}, "
        f"peak swap {format_size(observation.get('swap_peak_bytes'))}. "
        "Treat incomplete command output as a killed subprocess and use the "
        "oom-control skill to inspect or tune the limits."
    )


def emit_observation(observation: dict[str, Any], classification: str) -> None:
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": format_observation(observation, classification),
        }
    }
    sys.stdout.buffer.write(encode_json_packet(output))


# ENTRYPOINT ###################################################################


def main() -> int:
    try:
        unit = read_scope_identity()
        if unit is None:
            return 0
        observation = inspect_scope(unit)
        classification = classify_oom(observation)
        if classification is None:
            return 0
        emit_observation(observation, classification)
        reset_failed_scope(unit)
    except CALLBACK_ERRORS:
        # Reporting must never turn a completed tool call into a hook failure.
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
