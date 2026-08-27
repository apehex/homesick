---
name: oom-control
description: Inspect and tune Codex OOM guards.
---

# OOM Control

Use direct systemd and journal queries. The hooks keep no custom daemon, socket, event database, or acknowledgement state.

## Inspect

Check the aggregate slice and its limits:

```bash
systemctl --user show codex-jobs.slice \
  --property=LoadState,ActiveState,MemoryCurrent,MemoryPeak,MemoryHigh,MemoryMax,ManagedOOMMemoryPressure,ManagedOOMMemoryPressureLimit,ManagedOOMMemoryPressureDurationUSec
```

List current and failed command scopes:

```bash
systemctl --user list-units 'codex-job-*.scope' --all
```

Inspect a specific unit reported by the PostToolUse hook:

```bash
systemctl --user show UNIT \
  --property=LoadState,ActiveState,Result,ControlGroup,MemoryPeak,MemorySwapPeak
```

Check recent pressure kills recorded by systemd-oomd:

```bash
journalctl --unit=systemd-oomd.service --since=-1day --no-pager
```

Correlate the exact unit and timestamp with the affected tool call.

Successful transient scopes may already have been collected.

## Tune

Per-command `MemoryMax`, `MemorySwapMax`, and `TasksMax` values are arguments to `oom_guard.py` in `~/.codex/hooks.json`.

Aggregate slice limits and memory-pressure policy are arguments to `oom_setup.py` in the same file.

After changing aggregate settings, apply them without restarting Codex:

```bash
python3 ~/.codex/hooks/oom_setup.py
```

A command killed at `MemoryMax` may need a larger hard limit.

A `systemd-oomd` pressure kill may instead justify changing concurrency, the pressure threshold or duration, or the aggregate slice limits.

Reset a retained failed scope only after recording the evidence you need:

```bash
systemctl --user reset-failed UNIT
```
