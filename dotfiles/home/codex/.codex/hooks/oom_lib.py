#!/usr/bin/env python3
"""Shared parsing, identity, and subprocess helpers for Codex OOM hooks."""

from __future__ import annotations

import hashlib
import json
import subprocess
from collections.abc import Callable
from typing import Any, BinaryIO

# CONSTANTS ####################################################################


DEFAULT_HASH_LENGTH = 20
SHA256_HEX_LENGTH = 64
UNSIGNED_INTEGER_LIMIT = 1 << 63

MAX_PACKET_BYTES = 1 << 20
PACKET_TERMINATOR = b"\n"
DEFAULT_SUBPROCESS_TIMEOUT_SECONDS = 3.0

SESSION_UNIT_HASH_LENGTH = 8
TOOL_UNIT_HASH_LENGTH = 10
SCOPE_PREFIX = "codex-job"


# HASHING ######################################################################


def hex_digest(value: str, length: int = DEFAULT_HASH_LENGTH) -> str:
    if not isinstance(length, int):
        raise TypeError("digest length must be an integer")
    if not 1 <= length <= SHA256_HEX_LENGTH:
        raise ValueError(f"digest length must be between 1 and {SHA256_HEX_LENGTH}")
    return hashlib.sha256(value.encode()).hexdigest()[:length]


def scope_unit(session_id: str, tool_use_id: str) -> str:
    session = hex_digest(session_id, SESSION_UNIT_HASH_LENGTH)
    tool = hex_digest(tool_use_id, TOOL_UNIT_HASH_LENGTH)
    return f"{SCOPE_PREFIX}-{session}-{tool}.scope"


# SUBPROCESSES #################################################################


def run_subprocess(
    command: list[str],
    timeout: float = DEFAULT_SUBPROCESS_TIMEOUT_SECONDS,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


# JSON PACKETS #################################################################


def encode_json_packet(payload: dict[str, Any]) -> bytes:
    return json.dumps(payload, separators=(",", ":")).encode() + PACKET_TERMINATOR


def decode_json_packet(packet: bytes) -> dict[str, Any]:
    decoded = json.loads(packet.split(PACKET_TERMINATOR, 1)[0])
    if not isinstance(decoded, dict):
        raise TypeError("JSON packet must contain an object")
    return decoded


def read_json_stream(
    stream: BinaryIO,
    max_bytes: int = MAX_PACKET_BYTES,
) -> dict[str, Any]:
    packet = stream.read(max_bytes + 1)
    if len(packet) > max_bytes:
        raise ValueError(f"JSON packet exceeds {max_bytes} bytes")
    return decode_json_packet(packet)


# RECORD PARSING ###############################################################


def unsigned_integer(value: Any) -> int | None:
    try:
        result = int(value)
    except (TypeError, ValueError):
        return None
    if result < 0 or result >= UNSIGNED_INTEGER_LIMIT:
        return None
    return result


def parse_records(
    text: str,
    separator: str,
    value_parser: Callable[[str], Any] | None = None,
) -> dict[str, Any]:
    if not separator:
        raise ValueError("record separator must not be empty")
    records: dict[str, Any] = {}
    for line in text.splitlines():
        key, marker, raw_value = line.partition(separator)
        if not marker or not key:
            continue
        value = value_parser(raw_value) if value_parser else raw_value
        if value is not None:
            records[key] = value
    return records
