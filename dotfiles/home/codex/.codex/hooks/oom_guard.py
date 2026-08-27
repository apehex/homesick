#!/usr/bin/env python3
"""Codex PreToolUse hook: place one Bash tool call in a bounded user cgroup."""

from __future__ import annotations

import argparse
import json
import shlex
import sys
from pathlib import Path
from typing import Any

from oom_lib import encode_json_packet, read_json_stream, scope_unit


# CONSTANTS ####################################################################


DEFAULT_SLICE_NAME = "codex-jobs.slice"
DEFAULT_JOB_MEMORY_MAX = "7G"
DEFAULT_JOB_SWAP_MAX = "256M"
DEFAULT_TASKS_MAX = "512"

SYSTEMD_RUN = "/usr/bin/systemd-run"
BASH_PATH = "/usr/bin/bash"


# INPUTS #######################################################################


def parse_inputs() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--slice-name", default=DEFAULT_SLICE_NAME)
    parser.add_argument("--job-max", default=DEFAULT_JOB_MEMORY_MAX)
    parser.add_argument("--job-swap-max", default=DEFAULT_JOB_SWAP_MAX)
    parser.add_argument("--tasks-max", default=DEFAULT_TASKS_MAX)
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


def compose_guarded_command(
    command: str,
    unit: str,
    args: argparse.Namespace,
) -> str:
    wrapped = [
        SYSTEMD_RUN,
        "--user",
        "--scope",
        "--quiet",
        "--same-dir",
        f"--unit={unit}",
        f"--slice={args.slice_name}",
        "--property=MemoryAccounting=yes",
        f"--property=MemoryMax={args.job_max}",
        f"--property=MemorySwapMax={args.job_swap_max}",
        f"--property=TasksMax={args.tasks_max}",
        "--property=OOMPolicy=kill",
        "--",
        BASH_PATH,
        "-lc",
        command,
    ]
    return shlex.join(wrapped)


# ENTRYPOINT ###################################################################


def main() -> int:
    args = parse_inputs()
    if not Path(SYSTEMD_RUN).is_file():
        emit_hook_output(
            "deny",
            f"{SYSTEMD_RUN} is unavailable; refusing an unguarded Bash tool call",
        )
        return 0
    try:
        tool_input, command, session_id, tool_use_id = read_hook_input()
    except (json.JSONDecodeError, TypeError, ValueError) as error:
        emit_hook_output("deny", f"OOM guard rejected malformed hook input: {error}")
        return 0

    unit = scope_unit(session_id, tool_use_id)
    updated_input = {
        **tool_input,
        "command": compose_guarded_command(command, unit, args),
    }
    emit_hook_output("allow", updated_input=updated_input)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
