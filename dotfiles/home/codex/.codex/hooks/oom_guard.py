#!/usr/bin/env python3
"""Rewrite one Codex Bash tool call through the named OOM config."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import sys
from pathlib import Path
from typing import Any

from oom_config import CONFIG_PATH, ConfigurationError, load_config
from oom_lib import encode_json_packet, read_json_stream, scope_unit

# CONSTANTS ####################################################################


DEFAULT_CONFIG = "default"
OOM_EXEC = Path(__file__).resolve().with_name("oom_exec.py")


# INPUTS #######################################################################


def parse_inputs() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    return parser.parse_args()


def required_string(packet: dict[str, Any], key: str) -> str:
    value = packet.get(key)
    if not isinstance(value, str) or not value:
        raise ValueError(f"{key} must be a non-empty string")
    return value


def read_hook_input() -> tuple[dict[str, Any], str, str, str]:
    packet = read_json_stream(sys.stdin.buffer)
    session_id = required_string(packet, "session_id")
    tool_use_id = required_string(packet, "tool_use_id")
    tool_input = packet.get("tool_input")
    if not isinstance(tool_input, dict):
        raise TypeError("tool_input must be a JSON object")
    command = tool_input.get("command")
    if not isinstance(command, str) or not command.strip():
        raise ValueError("tool_input.command must be a non-empty string")
    return tool_input, command, session_id, tool_use_id


# HOOK OUTPUT ##################################################################


def emit_hook_output(
    decision: str,
    reason: str | None = None,
    updated_input: dict[str, Any] | None = None,
) -> None:
    specific: dict[str, Any] = {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
    }
    if reason:
        specific["permissionDecisionReason"] = reason
    if updated_input is not None:
        specific["updatedInput"] = updated_input
    sys.stdout.buffer.write(encode_json_packet({"hookSpecificOutput": specific}))


# COMMAND COMPOSITION ##########################################################


def compose_guarded_command(config: str, unit: str, command: str) -> str:
    return shlex.join([str(OOM_EXEC), config, unit, command])


# MAIN #########################################################################


def main() -> int:
    args = parse_inputs()
    if not OOM_EXEC.is_file() or not os.access(OOM_EXEC, os.X_OK):
        emit_hook_output(
            "deny",
            f"{OOM_EXEC} is unavailable; refusing an unguarded Bash tool call",
        )
        return 0
    try:
        load_config(args.config, CONFIG_PATH)
        tool_input, command, session_id, tool_use_id = read_hook_input()
    except (ConfigurationError, json.JSONDecodeError, OSError, TypeError, ValueError) as error:
        emit_hook_output("deny", f"OOM guard rejected the Bash tool call: {error}")
        return 0

    unit = scope_unit(session_id, tool_use_id)
    updated_input = {
        **tool_input,
        "command": compose_guarded_command(args.config, unit, command),
    }
    emit_hook_output("allow", updated_input=updated_input)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
