#!/usr/bin/env python3
"""Run one Codex shell command with a named, bounded systemd config."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

from oom_config import CONFIG_PATH, Configuration, ConfigurationError, load_config

# CONSTANTS ####################################################################


SYSTEMD_RUN = Path("/usr/bin/systemd-run")
BASH_PATH = Path("/usr/bin/bash")

SCOPE_UNIT_PATTERN = re.compile(
    r"codex-job-[0-9a-f]{8}-[0-9a-f]{10}\.scope"
)


# EXECUTION ####################################################################


def systemd_command(config: Configuration, unit: str, command: str) -> list[str]:
    accounting = "yes" if config.job.memory_accounting else "no"
    return [
        str(SYSTEMD_RUN),
        "--user",
        "--scope",
        "--quiet",
        "--same-dir",
        f"--unit={unit}",
        f"--slice={config.slice.name}",
        f"--property=MemoryAccounting={accounting}",
        f"--property=MemoryMax={config.job.memory_max}",
        f"--property=MemorySwapMax={config.job.memory_swap_max}",
        f"--property=TasksMax={config.job.tasks_max}",
        f"--property=OOMPolicy={config.job.oom_policy}",
        "--",
        str(BASH_PATH),
        "-lc",
        command,
    ]


def executable_error(path: Path) -> str | None:
    if not path.is_file():
        return f"required executable is unavailable: {path}"
    if not os.access(path, os.X_OK):
        return f"required executable is not executable: {path}"
    return None


def parse_invocation(argv: list[str]) -> tuple[str, str, str]:
    if len(argv) != 4:
        raise ConfigurationError(
            f"usage: {Path(argv[0]).name} CONFIG UNIT COMMAND"
        )
    config_name, unit, command = argv[1:]
    if SCOPE_UNIT_PATTERN.fullmatch(unit) is None:
        raise ConfigurationError(f"invalid Codex job scope: {unit!r}")
    if not command.strip():
        raise ConfigurationError("command must not be empty")
    return config_name, unit, command


def report_error(message: str, status: int = 2) -> int:
    print(f"oom_exec: {message}", file=sys.stderr)
    return status


# MAIN #########################################################################


def main(argv: list[str] | None = None) -> int:
    invocation = sys.argv if argv is None else argv
    try:
        config_name, unit, command = parse_invocation(invocation)
        config = load_config(config_name, CONFIG_PATH)
    except (ConfigurationError, OSError) as error:
        return report_error(str(error))

    for executable in (SYSTEMD_RUN, BASH_PATH):
        error = executable_error(executable)
        if error is not None:
            return report_error(error, status=127)

    try:
        os.execv(str(SYSTEMD_RUN), systemd_command(config, unit, command))
    except OSError as error:
        return report_error(f"could not execute {SYSTEMD_RUN}: {error}", status=126)


if __name__ == "__main__":
    raise SystemExit(main())
