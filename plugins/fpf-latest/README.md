# FPF Latest Plugin

This plugin distributes the public `fpf-latest` Codex skill.

## What Is Included

- `skills/fpf-latest/SKILL.md`
- `skills/fpf-latest/scripts/`
- `skills/fpf-latest/references/source-selection.md`
- `skills/fpf-latest/agents/openai.yaml`

## What Is Not Included

This plugin intentionally does not include personal automation:

- local launchers such as `bin/codex-fpf`;
- macOS LaunchAgents;
- session-start hooks;
- workspace jobs;
- `.fpf-update/`, cache directories, logs, or machine-local env files.

Those are local operational infrastructure around the skill. They must be installed or adapted separately by the user or team that wants automatic session-start refresh behavior.

## Runtime Contract

The bundled skill is Codex/macOS-first and runs in a Unix-like shell. Fresh refresh requires Bash, Git, standard Unix utilities, and GitHub network access. Cache fallback is supported when FPF and protocol caches already exist.

WSL Bash is supported. Git Bash on Windows is best effort. Native PowerShell/CMD is not supported until a separate PowerShell implementation exists.

## Validation

From the repository root:

```bash
scripts/validate-plugins.sh
```

For a portable install check after installation:

```bash
bash "$PLUGIN_ROOT/skills/fpf-latest/scripts/fpf-latest-doctor" --write-state
```
