#!/usr/bin/env python3
"""Load and validate named Codex OOM configurations."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import tomllib

# CONSTANTS ####################################################################


CONFIG_PATH = Path(__file__).resolve().with_name("oom_config.toml")
CONFIG_VERSION = 1

CONFIG_KEYS = frozenset({"slice", "job"})
SLICE_KEYS = frozenset(
    {
        "name",
        "memory_accounting",
        "memory_high",
        "memory_max",
        "managed_oom_memory_pressure",
        "managed_oom_memory_pressure_limit",
        "managed_oom_memory_pressure_duration",
    }
)
JOB_KEYS = frozenset(
    {
        "memory_accounting",
        "memory_max",
        "memory_swap_max",
        "tasks_max",
        "oom_policy",
    }
)

OOM_POLICIES = frozenset({"continue", "stop", "kill"})
MANAGED_OOM_MODES = frozenset({"auto", "kill"})

CONFIG_NAME_PATTERN = re.compile(r"[a-z][a-z0-9_-]*")
SLICE_UNIT_PATTERN = re.compile(r"[A-Za-z0-9_.:@-]+\.slice")
MEMORY_VALUE_PATTERN = re.compile(
    r"(?:infinity|[0-9]+(?:\.[0-9]+)?[KMGTPE]?)"
)
PRESSURE_LIMIT_PATTERN = re.compile(r"(?:100|[0-9]?[0-9])%")
PRESSURE_DURATION_PATTERN = re.compile(r"[1-9][0-9]*(?:ms|s|min|h)")


# TYPES ########################################################################


class ConfigurationError(ValueError):
    """A config cannot be translated safely into systemd properties."""


@dataclass(frozen=True)
class SliceConfiguration:
    name: str
    memory_accounting: bool
    memory_high: str
    memory_max: str
    managed_oom_memory_pressure: str
    managed_oom_memory_pressure_limit: str
    managed_oom_memory_pressure_duration: str


@dataclass(frozen=True)
class JobConfiguration:
    memory_accounting: bool
    memory_max: str
    memory_swap_max: str
    tasks_max: int
    oom_policy: str


@dataclass(frozen=True)
class Configuration:
    slice: SliceConfiguration
    job: JobConfiguration


# VALIDATION ###################################################################


def require_table(record: Any, subject: str) -> dict[str, Any]:
    if not isinstance(record, dict):
        raise ConfigurationError(f"{subject} must be a table")
    return record


def require_exact_keys(
    record: dict[str, Any], expected: frozenset[str], subject: str
) -> None:
    unexpected = set(record) - expected
    missing = expected - set(record)
    if unexpected:
        raise ConfigurationError(
            f"{subject} has unexpected keys: {', '.join(sorted(unexpected))}"
        )
    if missing:
        raise ConfigurationError(
            f"{subject} is missing keys: {', '.join(sorted(missing))}"
        )


def require_string(record: dict[str, Any], key: str, subject: str) -> str:
    value = record.get(key)
    if not isinstance(value, str) or not value:
        raise ConfigurationError(f"{subject} {key} must be a non-empty string")
    return value


def require_boolean(record: dict[str, Any], key: str, subject: str) -> bool:
    value = record.get(key)
    if not isinstance(value, bool):
        raise ConfigurationError(f"{subject} {key} must be a boolean")
    return value


def require_memory(record: dict[str, Any], key: str, subject: str) -> str:
    value = require_string(record, key, subject)
    if MEMORY_VALUE_PATTERN.fullmatch(value) is None:
        raise ConfigurationError(f"{subject} {key} must be a systemd memory size")
    return value


def parse_slice(record: Any, subject: str) -> SliceConfiguration:
    values = require_table(record, subject)
    require_exact_keys(values, SLICE_KEYS, subject)

    name = require_string(values, "name", subject)
    if SLICE_UNIT_PATTERN.fullmatch(name) is None:
        raise ConfigurationError(f"{subject} name must be a slice unit")

    managed_mode = require_string(
        values, "managed_oom_memory_pressure", subject
    )
    if managed_mode not in MANAGED_OOM_MODES:
        choices = ", ".join(sorted(MANAGED_OOM_MODES))
        raise ConfigurationError(
            f"{subject} managed_oom_memory_pressure must be one of: {choices}"
        )

    pressure_limit = require_string(
        values, "managed_oom_memory_pressure_limit", subject
    )
    if PRESSURE_LIMIT_PATTERN.fullmatch(pressure_limit) is None:
        raise ConfigurationError(
            f"{subject} managed_oom_memory_pressure_limit must be 0% through 100%"
        )

    pressure_duration = require_string(
        values, "managed_oom_memory_pressure_duration", subject
    )
    if PRESSURE_DURATION_PATTERN.fullmatch(pressure_duration) is None:
        raise ConfigurationError(
            f"{subject} managed_oom_memory_pressure_duration must be a positive duration"
        )

    return SliceConfiguration(
        name=name,
        memory_accounting=require_boolean(values, "memory_accounting", subject),
        memory_high=require_memory(values, "memory_high", subject),
        memory_max=require_memory(values, "memory_max", subject),
        managed_oom_memory_pressure=managed_mode,
        managed_oom_memory_pressure_limit=pressure_limit,
        managed_oom_memory_pressure_duration=pressure_duration,
    )


def parse_job(record: Any, subject: str) -> JobConfiguration:
    values = require_table(record, subject)
    require_exact_keys(values, JOB_KEYS, subject)

    tasks_max = values.get("tasks_max")
    if isinstance(tasks_max, bool) or not isinstance(tasks_max, int) or tasks_max <= 0:
        raise ConfigurationError(f"{subject} tasks_max must be a positive integer")

    oom_policy = require_string(values, "oom_policy", subject)
    if oom_policy not in OOM_POLICIES:
        choices = ", ".join(sorted(OOM_POLICIES))
        raise ConfigurationError(f"{subject} oom_policy must be one of: {choices}")

    return JobConfiguration(
        memory_accounting=require_boolean(values, "memory_accounting", subject),
        memory_max=require_memory(values, "memory_max", subject),
        memory_swap_max=require_memory(values, "memory_swap_max", subject),
        tasks_max=tasks_max,
        oom_policy=oom_policy,
    )


def parse_config(name: str, record: Any) -> Configuration:
    subject = f"config {name!r}"
    values = require_table(record, subject)
    require_exact_keys(values, CONFIG_KEYS, subject)
    return Configuration(
        slice=parse_slice(values["slice"], f"{subject} slice"),
        job=parse_job(values["job"], f"{subject} job"),
    )


def load_config(name: str, path: Path = CONFIG_PATH) -> Configuration:
    if CONFIG_NAME_PATTERN.fullmatch(name) is None:
        raise ConfigurationError(f"invalid config name: {name!r}")
    try:
        with path.open("rb") as stream:
            document = tomllib.load(stream)
    except tomllib.TOMLDecodeError as error:
        raise ConfigurationError(f"invalid TOML in {path}: {error}") from error
    if document.get("version") != CONFIG_VERSION:
        raise ConfigurationError(f"{path} must declare version = {CONFIG_VERSION}")
    configs = document.get("configs")
    if not isinstance(configs, dict):
        raise ConfigurationError(f"{path} must contain a configs table")
    if name not in configs:
        raise ConfigurationError(f"unknown OOM config: {name!r}")
    return parse_config(name, configs[name])
