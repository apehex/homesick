#!/usr/bin/env python3
"""Small systemd and cgroup operations used by the Codex OOM hooks."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from oom_lib import parse_records, run_subprocess, unsigned_integer


# CONSTANTS ####################################################################


CGROUP_ROOT = Path("/sys/fs/cgroup")

SYSTEMD_RUN = "/usr/bin/systemd-run"
SYSTEMCTL = "/usr/bin/systemctl"
JOURNALCTL = "/usr/bin/journalctl"
TRUE_PATH = "/usr/bin/true"

SYSTEMD_COMMAND_TIMEOUT_SECONDS = 5.0
UNIT_COMMAND_TIMEOUT_SECONDS = 2.0
JOURNAL_COMMAND_TIMEOUT_SECONDS = 2.0
JOURNAL_LOOKBACK = "-5min"

MANAGED_OOM_MODE = "kill"
PROPERTY_SEPARATOR = "="
CGROUP_RECORD_SEPARATOR = " "
SYSTEMD_PROPERTIES = (
    "Result",
    "ControlGroup",
    "MemoryPeak",
    "MemorySwapPeak",
)
PEAK_PROPERTIES = (
    ("MemoryPeak", "memory_peak_bytes"),
    ("MemorySwapPeak", "swap_peak_bytes"),
)
PEAK_FILES = (
    ("memory.peak", "memory_peak_bytes"),
    ("memory.swap.peak", "swap_peak_bytes"),
)


# SLICE CONFIGURATION ##########################################################


def compose_slice_probe_command(slice_name: str) -> list[str]:
    return [
        SYSTEMD_RUN,
        "--user",
        "--scope",
        "--quiet",
        f"--slice={slice_name}",
        "--",
        TRUE_PATH,
    ]


def compose_slice_configuration_command(
    slice_name: str,
    memory_high: str,
    memory_max: str,
    pressure_limit: str,
    pressure_duration: str,
) -> list[str]:
    return [
        SYSTEMCTL,
        "--user",
        "set-property",
        "--runtime",
        slice_name,
        "MemoryAccounting=yes",
        f"MemoryHigh={memory_high}",
        f"MemoryMax={memory_max}",
        f"ManagedOOMMemoryPressure={MANAGED_OOM_MODE}",
        f"ManagedOOMMemoryPressureLimit={pressure_limit}",
        f"ManagedOOMMemoryPressureDurationSec={pressure_duration}",
    ]


def checked_command(command: list[str], failure: str) -> None:
    result = run_subprocess(command, timeout=SYSTEMD_COMMAND_TIMEOUT_SECONDS)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or failure)


def configure_slice(
    slice_name: str,
    memory_high: str,
    memory_max: str,
    pressure_limit: str,
    pressure_duration: str,
) -> None:
    checked_command(
        compose_slice_probe_command(slice_name),
        "could not load job slice",
    )
    checked_command(
        compose_slice_configuration_command(
            slice_name,
            memory_high,
            memory_max,
            pressure_limit,
            pressure_duration,
        ),
        "could not configure job slice",
    )


# UNIT OBSERVATION #############################################################


def show_scope(unit: str) -> dict[str, Any]:
    result = run_subprocess(
        [
            SYSTEMCTL,
            "--user",
            "show",
            unit,
            f"--property={','.join(SYSTEMD_PROPERTIES)}",
        ],
        timeout=UNIT_COMMAND_TIMEOUT_SECONDS,
    )
    return parse_records(result.stdout, PROPERTY_SEPARATOR)


def read_text(path: Path) -> str:
    try:
        return path.read_text()
    except OSError:
        return ""


def cgroup_path(properties: dict[str, Any]) -> Path | None:
    control_group = properties.get("ControlGroup")
    if not isinstance(control_group, str) or not control_group.startswith("/"):
        return None
    return CGROUP_ROOT / control_group.lstrip("/")


def read_cgroup_events(path: Path) -> dict[str, int]:
    text = read_text(path / "memory.events.local")
    if not text:
        text = read_text(path / "memory.events")
    return parse_records(text, CGROUP_RECORD_SEPARATOR, unsigned_integer)


def read_peaks(properties: dict[str, Any], path: Path | None) -> dict[str, int]:
    peaks: dict[str, int] = {}
    for source, destination in PEAK_PROPERTIES:
        value = unsigned_integer(properties.get(source))
        if value is not None:
            peaks[destination] = value
    if path is None:
        return peaks
    for filename, destination in PEAK_FILES:
        value = unsigned_integer(read_text(path / filename).strip())
        if value is not None:
            peaks[destination] = max(peaks.get(destination, 0), value)
    return peaks


def inspect_scope(unit: str) -> dict[str, Any]:
    properties = show_scope(unit)
    path = cgroup_path(properties)
    return {
        "unit": unit,
        "result": properties.get("Result", ""),
        "control_group": properties.get("ControlGroup", ""),
        "memory_events": read_cgroup_events(path) if path else {},
        **read_peaks(properties, path),
    }


# OOM CLASSIFICATION ###########################################################


def exact_oomd_journal_match(unit: str, control_group: Any) -> bool:
    result = run_subprocess(
        [
            JOURNALCTL,
            "--unit=systemd-oomd.service",
            f"--since={JOURNAL_LOOKBACK}",
            "--no-pager",
            "--output=cat",
        ],
        timeout=JOURNAL_COMMAND_TIMEOUT_SECONDS,
    )
    needles = [unit]
    if isinstance(control_group, str) and control_group.startswith("/"):
        needles.append(control_group)
    return any(needle in result.stdout for needle in needles)


def classify_oom(observation: dict[str, Any]) -> str | None:
    if observation.get("result") == "oom-kill":
        return "cgroup-oom"
    events = observation.get("memory_events")
    if isinstance(events, dict) and (unsigned_integer(events.get("oom_kill")) or 0):
        return "cgroup-oom"
    if exact_oomd_journal_match(
        str(observation.get("unit", "")),
        observation.get("control_group"),
    ):
        return "systemd-oomd"
    return None


# CLEANUP ######################################################################


def reset_failed_scope(unit: str) -> None:
    run_subprocess(
        [SYSTEMCTL, "--user", "reset-failed", unit],
        timeout=UNIT_COMMAND_TIMEOUT_SECONDS,
    )
