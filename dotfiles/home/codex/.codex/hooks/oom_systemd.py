#!/usr/bin/env python3
"""Systemd and cgroup operations used by the Codex OOM hooks."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from oom_config import SliceConfiguration
from oom_lib import parse_records, run_subprocess, unsigned_integer

# CONSTANTS ####################################################################


CGROUP_ROOT = Path("/sys/fs/cgroup")

SYSTEMD_RUN = "/usr/bin/systemd-run"
SYSTEMCTL = "/usr/bin/systemctl"
JOURNALCTL = "/usr/bin/journalctl"
TRUE_PATH = "/usr/bin/true"

SYSTEMD_COMMAND_TIMEOUT_SECONDS = 5.0
UNIT_COMMAND_TIMEOUT_SECONDS = 1.0
JOURNAL_COMMAND_TIMEOUT_SECONDS = 1.0
JOURNAL_LOOKBACK = "-5min"

PROPERTY_SEPARATOR = "="
CGROUP_RECORD_SEPARATOR = " "
SCOPE_PROPERTIES = (
    "LoadState",
    "ActiveState",
    "SubState",
    "Result",
    "ControlGroup",
    "MemoryCurrent",
    "MemoryPeak",
    "MemorySwapCurrent",
    "MemorySwapPeak",
    "MemoryMax",
    "MemorySwapMax",
    "EffectiveMemoryMax",
    "TasksCurrent",
    "TasksMax",
    "ManagedOOMPreference",
    "OOMPolicy",
)
SLICE_PROPERTIES = (
    "LoadState",
    "ActiveState",
    "SubState",
    "ControlGroup",
    "MemoryCurrent",
    "MemoryPeak",
    "MemorySwapCurrent",
    "MemorySwapPeak",
    "MemoryHigh",
    "MemoryMax",
    "EffectiveMemoryMax",
    "MemoryAvailable",
    "TasksCurrent",
    "ManagedOOMMemoryPressure",
    "ManagedOOMMemoryPressureLimit",
    "ManagedOOMMemoryPressureDurationUSec",
)
TEXT_PROPERTIES = (
    ("LoadState", "load_state"),
    ("ActiveState", "active_state"),
    ("SubState", "sub_state"),
    ("Result", "result"),
    ("ControlGroup", "control_group"),
    ("ManagedOOMPreference", "managed_oom_preference"),
    ("OOMPolicy", "oom_policy"),
    ("ManagedOOMMemoryPressure", "managed_oom_memory_pressure"),
    (
        "ManagedOOMMemoryPressureLimit",
        "managed_oom_memory_pressure_limit",
    ),
    (
        "ManagedOOMMemoryPressureDurationUSec",
        "managed_oom_memory_pressure_duration",
    ),
)
MEASUREMENT_PROPERTIES = (
    ("MemoryCurrent", "memory_current_bytes"),
    ("MemoryPeak", "memory_peak_bytes"),
    ("MemorySwapCurrent", "memory_swap_current_bytes"),
    ("MemorySwapPeak", "memory_swap_peak_bytes"),
    ("MemoryHigh", "memory_high_bytes"),
    ("MemoryMax", "memory_max_bytes"),
    ("MemorySwapMax", "memory_swap_max_bytes"),
    ("EffectiveMemoryMax", "effective_memory_max_bytes"),
    ("MemoryAvailable", "memory_available_bytes"),
    ("TasksCurrent", "tasks_current"),
    ("TasksMax", "tasks_max"),
)
CGROUP_MEASUREMENT_FILES = (
    ("memory.current", "memory_current_bytes"),
    ("memory.peak", "memory_peak_bytes"),
    ("memory.swap.current", "memory_swap_current_bytes"),
    ("memory.swap.peak", "memory_swap_peak_bytes"),
    ("memory.max", "memory_max_bytes"),
    ("memory.swap.max", "memory_swap_max_bytes"),
    ("pids.current", "tasks_current"),
    ("pids.max", "tasks_max"),
)

OOMD_MARKED_PREFIX = "Marked "
OOMD_MARKED_INFIX = " for killing "
UNIT_TOKEN_CHARACTERS = r"A-Za-z0-9_.:@-"
MANAGED_OOM_PREFERENCES = frozenset({"none", "avoid", "omit"})


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


def compose_slice_configuration_command(config: SliceConfiguration) -> list[str]:
    accounting = "yes" if config.memory_accounting else "no"
    return [
        SYSTEMCTL,
        "--user",
        "set-property",
        "--runtime",
        config.name,
        f"MemoryAccounting={accounting}",
        f"MemoryHigh={config.memory_high}",
        f"MemoryMax={config.memory_max}",
        f"ManagedOOMMemoryPressure={config.managed_oom_memory_pressure}",
        (
            "ManagedOOMMemoryPressureLimit="
            f"{config.managed_oom_memory_pressure_limit}"
        ),
        (
            "ManagedOOMMemoryPressureDurationSec="
            f"{config.managed_oom_memory_pressure_duration}"
        ),
    ]


def checked_command(
    command: list[str],
    failure: str,
    *,
    timeout: float = SYSTEMD_COMMAND_TIMEOUT_SECONDS,
) -> None:
    result = run_subprocess(command, timeout=timeout)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or failure)


def configure_slice(config: SliceConfiguration) -> None:
    checked_command(
        compose_slice_probe_command(config.name),
        "could not load job slice",
    )
    checked_command(
        compose_slice_configuration_command(config),
        "could not configure job slice",
    )


# UNIT OBSERVATION #############################################################


def show_unit(unit: str, properties: tuple[str, ...]) -> dict[str, Any]:
    result = run_subprocess(
        [
            SYSTEMCTL,
            "--user",
            "show",
            unit,
            f"--property={','.join(properties)}",
        ],
        timeout=UNIT_COMMAND_TIMEOUT_SECONDS,
    )
    if result.returncode != 0 and not result.stdout.strip():
        raise RuntimeError(result.stderr.strip() or f"could not inspect {unit}")
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


def read_cgroup_events(path: Path, filename: str) -> dict[str, int]:
    return parse_records(
        read_text(path / filename),
        CGROUP_RECORD_SEPARATOR,
        unsigned_integer,
    )


def measurement(value: Any) -> int | str | None:
    numeric = unsigned_integer(value)
    if numeric is not None:
        return numeric
    if isinstance(value, str) and value and value != "[not set]":
        return value
    return None


def populate_observation(
    unit: str,
    properties: dict[str, Any],
) -> dict[str, Any]:
    observation: dict[str, Any] = {"unit": unit, "properties": properties}
    for source, destination in TEXT_PROPERTIES:
        value = properties.get(source)
        if isinstance(value, str):
            observation[destination] = value
    for source, destination in MEASUREMENT_PROPERTIES:
        value = measurement(properties.get(source))
        if value is not None:
            observation[destination] = value

    path = cgroup_path(properties)
    if path is None:
        return observation
    observation["cgroup_path"] = str(path)
    for filename, destination in CGROUP_MEASUREMENT_FILES:
        value = measurement(read_text(path / filename).strip())
        if value is None:
            continue
        existing = observation.get(destination)
        if destination.endswith("_peak_bytes"):
            if isinstance(existing, int) and isinstance(value, int):
                observation[destination] = max(existing, value)
            elif existing is None:
                observation[destination] = value
        elif not isinstance(existing, int):
            observation[destination] = value
    observation["memory_events_local"] = read_cgroup_events(
        path, "memory.events.local"
    )
    observation["memory_events"] = read_cgroup_events(path, "memory.events")
    return observation


def inspect_scope(unit: str) -> dict[str, Any]:
    return populate_observation(unit, show_unit(unit, SCOPE_PROPERTIES))


def inspect_slice(unit: str) -> dict[str, Any]:
    return populate_observation(unit, show_unit(unit, SLICE_PROPERTIES))


def scope_is_present(observation: dict[str, Any]) -> bool:
    return observation.get("load_state") not in {None, "", "not-found"}


def scope_is_active(observation: dict[str, Any]) -> bool:
    if not scope_is_present(observation):
        return False
    return observation.get("active_state") not in {"inactive", "failed"}


def scope_is_failed(observation: dict[str, Any]) -> bool:
    return scope_is_present(observation) and observation.get("active_state") == "failed"


# OOM CLASSIFICATION ###########################################################


def exact_target_match(line: str, target: str) -> bool:
    pattern = rf"(?<![{UNIT_TOKEN_CHARACTERS}]){re.escape(target)}(?![{UNIT_TOKEN_CHARACTERS}])"
    return re.search(pattern, line) is not None


def find_oomd_journal_evidence(unit: str, control_group: Any) -> str | None:
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
    if result.returncode != 0 and not result.stdout.strip():
        raise RuntimeError(
            result.stderr.strip() or "could not inspect the systemd-oomd journal"
        )
    targets = [unit]
    if isinstance(control_group, str) and control_group.startswith("/"):
        targets.append(control_group)
    for raw_line in result.stdout.splitlines():
        line = " ".join(raw_line.split())
        if not line.startswith(OOMD_MARKED_PREFIX):
            continue
        if OOMD_MARKED_INFIX not in line:
            continue
        if any(exact_target_match(line, target) for target in targets):
            return line
    return None


def event_count(events: Any, key: str) -> int:
    if not isinstance(events, dict):
        return 0
    return unsigned_integer(events.get(key)) or 0


def recorded_oom_kill(events: Any) -> bool:
    return bool(event_count(events, "oom_kill") or event_count(events, "oom_group_kill"))


def classify_oom(
    observation: dict[str, Any],
    oomd_evidence: str | None = None,
) -> str | None:
    if oomd_evidence:
        return "systemd-oomd"
    local_events = observation.get("memory_events_local")
    if recorded_oom_kill(local_events) and event_count(local_events, "max"):
        return "job-memory-max"
    if recorded_oom_kill(local_events):
        return "cgroup-oom"
    if recorded_oom_kill(observation.get("memory_events")):
        return "cgroup-oom"
    if observation.get("result") == "oom-kill":
        return "cgroup-oom"
    return None


# CLEANUP ######################################################################


def set_scope_managed_oom_preference(unit: str, preference: str) -> None:
    if preference not in MANAGED_OOM_PREFERENCES:
        raise ValueError(f"invalid ManagedOOMPreference: {preference!r}")
    checked_command(
        [
            SYSTEMCTL,
            "--user",
            "set-property",
            "--runtime",
            unit,
            f"ManagedOOMPreference={preference}",
        ],
        f"could not set ManagedOOMPreference={preference} on {unit}",
        timeout=UNIT_COMMAND_TIMEOUT_SECONDS,
    )


def reset_failed_scope(unit: str) -> None:
    checked_command(
        [SYSTEMCTL, "--user", "reset-failed", unit],
        f"could not reset failed scope {unit}",
        timeout=UNIT_COMMAND_TIMEOUT_SECONDS,
    )
