#!/usr/bin/env python3
"""Capture, format, and emit Codex OOM scope evidence."""

from __future__ import annotations

import subprocess
import sys
from dataclasses import dataclass
from typing import Any

from oom_lib import encode_json_packet
from oom_systemd import (
    classify_oom,
    find_oomd_journal_evidence,
    inspect_slice,
    reset_failed_scope,
    scope_is_failed,
)

# CONSTANTS ####################################################################


BYTE_UNIT = 1024
SIZE_SUFFIXES = ("B", "KiB", "MiB", "GiB", "TiB")
MAX_DIAGNOSTIC_CHARACTERS = 320
MAX_JOURNAL_EVIDENCE_CHARACTERS = 500
PRESSURE_LIMIT_SCALE = (1 << 32) - 1

OBSERVATION_ERRORS = (
    OSError,
    RuntimeError,
    subprocess.TimeoutExpired,
    TypeError,
    ValueError,
)


# TYPES ########################################################################


@dataclass(frozen=True)
class TerminalSnapshot:
    observation: dict[str, Any]
    classification: str | None
    oomd_evidence: str | None
    slice_observation: dict[str, Any] | None
    cleanup_status: str
    diagnostics: tuple[str, ...]


# CAPTURE ######################################################################


def safe_detail(error: BaseException) -> str:
    detail = " ".join(str(error).split()) or type(error).__name__
    return detail[:MAX_DIAGNOSTIC_CHARACTERS]


def capture_terminal_scope(
    observation: dict[str, Any],
    slice_name: str,
) -> TerminalSnapshot:
    """Capture terminal evidence, then reset a failed transient scope."""
    unit = str(observation.get("unit", "unknown scope"))
    diagnostics: list[str] = []
    oomd_evidence: str | None = None
    try:
        oomd_evidence = find_oomd_journal_evidence(
            unit,
            observation.get("control_group"),
        )
    except OBSERVATION_ERRORS as error:
        diagnostics.append(f"systemd-oomd journal inspection failed: {safe_detail(error)}")

    classification = classify_oom(observation, oomd_evidence)
    slice_observation: dict[str, Any] | None = None
    if classification is not None:
        try:
            slice_observation = inspect_slice(slice_name)
        except OBSERVATION_ERRORS as error:
            diagnostics.append(f"aggregate slice inspection failed: {safe_detail(error)}")

    cleanup_status = "not-needed"
    if scope_is_failed(observation):
        try:
            reset_failed_scope(unit)
            cleanup_status = "reset"
        except OBSERVATION_ERRORS as error:
            cleanup_status = "reset-failed"
            diagnostics.append(f"failed-scope cleanup failed: {safe_detail(error)}")

    return TerminalSnapshot(
        observation=observation,
        classification=classification,
        oomd_evidence=oomd_evidence,
        slice_observation=slice_observation,
        cleanup_status=cleanup_status,
        diagnostics=tuple(diagnostics),
    )


# FORMATTING ###################################################################


def format_size(value: Any) -> str:
    if isinstance(value, str):
        return value
    if not isinstance(value, int):
        return "unknown"
    size = float(value)
    for suffix in SIZE_SUFFIXES:
        if size < BYTE_UNIT or suffix == SIZE_SUFFIXES[-1]:
            return f"{size:.1f} {suffix}"
        size /= BYTE_UNIT
    return "unknown"


def format_count(value: Any) -> str:
    if isinstance(value, (int, str)):
        return str(value)
    return "unknown"


def format_events(events: Any) -> str:
    if not isinstance(events, dict) or not events:
        return "unavailable"
    return "{" + ",".join(f"{key}={events[key]}" for key in sorted(events)) + "}"


def format_pressure_limit(value: Any) -> str:
    try:
        numeric = int(value)
    except (TypeError, ValueError):
        return "unknown" if value is None or value == "" else str(value)
    if 0 <= numeric <= PRESSURE_LIMIT_SCALE:
        percentage = numeric * 100 / PRESSURE_LIMIT_SCALE
        return f"{percentage:.1f}%"
    return str(value)


def format_lifecycle(observation: dict[str, Any]) -> str:
    states = (
        observation.get("load_state", "unknown"),
        observation.get("active_state", "unknown"),
        observation.get("sub_state", "unknown"),
    )
    return "/".join(str(state) for state in states)


def format_scope_evidence(observation: dict[str, Any]) -> str:
    return (
        f"unit={observation.get('unit', 'unknown')}; "
        f"lifecycle={format_lifecycle(observation)}; "
        f"result={observation.get('result', 'unknown')}; "
        f"cgroup={observation.get('control_group', 'unknown')}; "
        "memory(current/peak/max/effective)="
        f"{format_size(observation.get('memory_current_bytes'))}/"
        f"{format_size(observation.get('memory_peak_bytes'))}/"
        f"{format_size(observation.get('memory_max_bytes'))}/"
        f"{format_size(observation.get('effective_memory_max_bytes'))}; "
        "swap(current/peak/max)="
        f"{format_size(observation.get('memory_swap_current_bytes'))}/"
        f"{format_size(observation.get('memory_swap_peak_bytes'))}/"
        f"{format_size(observation.get('memory_swap_max_bytes'))}; "
        "tasks(current/max)="
        f"{format_count(observation.get('tasks_current'))}/"
        f"{format_count(observation.get('tasks_max'))}; "
        f"preference={observation.get('managed_oom_preference', 'unknown')}; "
        f"oom_policy={observation.get('oom_policy', 'unknown')}; "
        f"events.local={format_events(observation.get('memory_events_local'))}; "
        f"events={format_events(observation.get('memory_events'))}"
    )


def format_slice_evidence(observation: dict[str, Any] | None) -> str:
    if observation is None:
        return "slice evidence unavailable"
    return (
        f"slice={observation.get('unit', 'unknown')}; "
        f"lifecycle={format_lifecycle(observation)}; "
        "memory(current/peak/high/max/effective/available)="
        f"{format_size(observation.get('memory_current_bytes'))}/"
        f"{format_size(observation.get('memory_peak_bytes'))}/"
        f"{format_size(observation.get('memory_high_bytes'))}/"
        f"{format_size(observation.get('memory_max_bytes'))}/"
        f"{format_size(observation.get('effective_memory_max_bytes'))}/"
        f"{format_size(observation.get('memory_available_bytes'))}; "
        "swap(current/peak)="
        f"{format_size(observation.get('memory_swap_current_bytes'))}/"
        f"{format_size(observation.get('memory_swap_peak_bytes'))}; "
        f"tasks={format_count(observation.get('tasks_current'))}; "
        "pressure="
        f"{observation.get('managed_oom_memory_pressure', 'unknown')}/"
        f"{format_pressure_limit(observation.get('managed_oom_memory_pressure_limit'))}/"
        f"{observation.get('managed_oom_memory_pressure_duration', 'unknown')}; "
        f"events.local={format_events(observation.get('memory_events_local'))}; "
        f"events={format_events(observation.get('memory_events'))}"
    )


def cleanup_description(status: str) -> str:
    if status == "reset":
        return "the failed transient scope was reset after this snapshot"
    if status == "reset-failed":
        return "the failed transient scope could not be reset and may remain loaded"
    return "the scope did not require failed-unit cleanup"


def format_terminal_context(snapshot: TerminalSnapshot, *, delayed: bool) -> str:
    classification = snapshot.classification or "unclassified"
    causes = {
        "systemd-oomd": (
            "was selected and killed by systemd-oomd under aggregate memory pressure"
        ),
        "job-memory-max": (
            "hit its local hard memory boundary and recorded a local cgroup OOM kill"
        ),
        "cgroup-oom": (
            "recorded a cgroup OOM kill, but the evidence does not prove whether "
            "the trigger was its local limit or an ancestor/global constraint"
        ),
    }
    subject = "An earlier shell tool's scope" if delayed else "The preceding shell tool's scope"
    journal = ""
    if snapshot.oomd_evidence:
        evidence = snapshot.oomd_evidence[:MAX_JOURNAL_EVIDENCE_CHARACTERS]
        journal = f'; systemd-oomd journal evidence="{evidence}"'
    return (
        f"{subject} {causes.get(classification, 'had an unclassified OOM outcome')}. "
        f"Classification={classification}. Evidence captured before cleanup: "
        f"{format_scope_evidence(snapshot.observation)}; "
        f"{format_slice_evidence(snapshot.slice_observation)}{journal}. "
        f"Cleanup: {cleanup_description(snapshot.cleanup_status)}. "
        "Treat its command output as potentially incomplete before retrying or tuning "
        "the limits with the oom-control skill."
    )


def format_survivor_context(
    observation: dict[str, Any],
    *,
    demotion: str,
    previous_preference: str,
    monitor_seconds: float,
) -> str:
    if demotion == "demoted":
        current = observation.get("managed_oom_preference", "unknown")
        preference = (
            f"ManagedOOMPreference is now {current} "
            f"(previous snapshot: {previous_preference})"
        )
    else:
        preference = (
            "ManagedOOMPreference could not be changed to none "
            f"(previous snapshot: {previous_preference})"
        )
    hours = monitor_seconds / 3600
    return (
        "The preceding shell tool returned while its scope still had live descendants. "
        f"{preference}; an asynchronous monitor will watch it for up to {hours:g} hours "
        "while this Codex session remains active. Current evidence: "
        f"{format_scope_evidence(observation)}. "
        "Treat those descendants as continuing external effects."
    )


def format_diagnostic_message(unit: str, diagnostics: tuple[str, ...] | list[str]) -> str:
    detail = "; ".join(diagnostics)
    return f"Codex OOM guard had an inspection or cleanup problem for {unit}: {detail}"


# HOOK OUTPUT ##################################################################


def hook_output(
    *,
    additional_context: str | None = None,
    system_message: str | None = None,
) -> dict[str, Any] | None:
    output: dict[str, Any] = {}
    if additional_context:
        output["hookSpecificOutput"] = {
            "hookEventName": "PostToolUse",
            "additionalContext": additional_context,
        }
    if system_message:
        output["systemMessage"] = system_message
    return output or None


def emit_hook_output(output: dict[str, Any] | None) -> None:
    if output is not None:
        sys.stdout.buffer.write(encode_json_packet(output))
