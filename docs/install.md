# Installing Skills

These instructions install selected skills from this repository for local use in Codex or another agent runtime.

## Codex Install Targets

Codex supports several skill discovery scopes. Use the smallest scope that matches the job:

| Target | Path | Use when |
| --- | --- | --- |
| Repo-scoped skill | `$REPO_ROOT/.agents/skills` | The skill should travel with one repository or workspace. |
| User-scoped skill | `$HOME/.agents/skills` | The skill should be available across the user's repositories. |
| Admin-scoped skill | `/etc/codex/skills` | A machine or container owner provides shared defaults. |
| Local legacy/current compatibility | `${CODEX_HOME:-$HOME/.codex}/skills` | A local Codex setup already loads skills from this path. |

This repository keeps staged public copies under `skills/`. That is the source artifact for review and adaptation, not automatically the runtime location.

Recommended user-scoped target:

```bash
export CODEX_SKILLS_TARGET="${CODEX_SKILLS_TARGET:-$HOME/.agents/skills}"
mkdir -p "$CODEX_SKILLS_TARGET"
```

Repo-scoped target:

```bash
export CODEX_SKILLS_TARGET="${CODEX_SKILLS_TARGET:-$PWD/.agents/skills}"
mkdir -p "$CODEX_SKILLS_TARGET"
```

Install one skill:

```bash
cp -R skills/fpf-latest "$CODEX_SKILLS_TARGET/"
```

Install all staged skills:

```bash
find skills -mindepth 1 -maxdepth 1 -type d -exec cp -R {} "$CODEX_SKILLS_TARGET/" \;
```

After installation, restart Codex or start a new Codex session so the skill list is reloaded.

If you install `fpf-latest` in Codex, run its portable doctor once:

```bash
bash "$CODEX_SKILLS_TARGET/fpf-latest/scripts/fpf-latest-doctor" --write-state
```

The doctor does not contact GitHub. It verifies local shell tooling, Git availability, cache state, install completeness, and records a local environment state so normal runtime use does not repeat the check unless the environment changes or the refresh gate is blocked.

If your local Codex installation still loads skills from `${CODEX_HOME:-$HOME/.codex}/skills`, keep using that path as a local compatibility target:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export CODEX_SKILLS_TARGET="$CODEX_HOME/skills"
mkdir -p "$CODEX_SKILLS_TARGET"
```

For Claude Code or another non-Codex agent, install the same `fpf-latest` directory wherever that agent can read it, then run the doctor from that directory:

```bash
export FPF_LATEST_SKILL_DIR="/absolute/path/to/fpf-latest"
export FPF_CACHE_HOME="${FPF_CACHE_HOME:-$HOME/.cache/fpf-latest}"
export FPF_UPDATE_STATE_DIR="${FPF_UPDATE_STATE_DIR:-$HOME/.local/state/fpf-latest}"
bash "$FPF_LATEST_SKILL_DIR/scripts/fpf-latest-doctor" --write-state
```

For WSL, use the same Bash command inside WSL. For Git Bash on Windows, the command is best effort. Native PowerShell/CMD is not supported until this repository includes a separate PowerShell implementation.

Portable installs should treat `$HOME/.codex`, `$HOME/.agents`, and `$PWD/.fpf-update` as defaults only. Use explicit paths when the agent runtime does not own those locations:

```bash
FPF_LATEST_SKILL_DIR="/absolute/path/to/fpf-latest" \
FPF_CACHE_HOME="/absolute/path/to/fpf-cache" \
FPF_UPDATE_STATE_DIR="/absolute/path/to/fpf-state" \
bash "$FPF_LATEST_SKILL_DIR/scripts/update_fpf_context.sh"
```

Use exact cache paths only when the FPF specification and protocol repository must live in separate locations:

```bash
export FPF_SPEC_CACHE_DIR="/absolute/path/to/fpf-spec-mirror"
export FPF_PROTOCOLS_CACHE_DIR="/absolute/path/to/codex-skills-and-protocols"
```

Use exact state paths only when refresh state and environment state need separate lifecycle or permissions:

```bash
export FPF_REFRESH_STATE_DIR="/absolute/path/to/fpf-refresh-state"
export FPF_ENV_STATE_DIR="/absolute/path/to/fpf-env-state"
```

## Distribution Boundary

Direct skill folders are appropriate for local authoring, repo-scoped workflows, and personal setup. For reusable distribution to other developers or teams, package the skill as a Codex plugin or expose it through a plugin marketplace. Plugins are the installable distribution unit when the skill should be shared beyond one local checkout.

This repository includes a repo-local plugin marketplace at:

```text
.agents/plugins/marketplace.json
```

The plugin artifacts live at:

```text
plugins/fpf-latest
```

Each plugin bundles its public skill only. Plugins do not include personal launchers, LaunchAgents, session-start hooks, workspace jobs, cache, logs, local state files, private overlays, or generated outputs.

## Artifact Layers

Read [skill-artifact-model.md](skill-artifact-model.md) before packaging or redistributing skills. The installed operational copy under `$HOME/.agents/skills`, `$REPO_ROOT/.agents/skills`, `${CODEX_HOME:-$HOME/.codex}/skills`, or another agent-specific runtime location is not the same artifact as the public staged copy under `skills/`.

`fpf-latest` is the public skill. Local launchers, session-start hooks, LaunchAgents, workspace jobs, `.fpf-update/`, and `~/.local/state/codex-fpf/` are personal automation around that skill. They are not a public skill overlay and must not be installed or published as part of `skills/fpf-latest`.

Public installation may document that such automation can exist, but the staged skill contract remains the portable `fpf-latest` skill plus its bundled scripts.

If a workspace path is symlinked, read-only, shared by several agents, or ephemeral, pass an explicit `FPF_UPDATE_STATE_DIR` from the launcher or hook instead of relying on `$PWD/.fpf-update`. This keeps diagnostics and migration notes stable even when the shell reports the physical target path.

## Runtime State

`fpf-latest` uses local state files to decide whether the refresh gate should fetch from GitHub, skip because the TTL has not expired, or block because cache validation failed. These files are runtime state, not skill source.

Common state locations:

```text
$PWD/.fpf-update/latest.env
$PWD/.fpf-update/environment.env
~/.local/state/codex-fpf/latest.env
~/.local/state/codex-fpf/environment.env
```

The workspace `.fpf-update/` state is usually used when the skill runs inside a repository or workspace. The `~/.local/state/codex-fpf/` state is commonly used by personal launchers or session-start hooks. Both can exist at the same time; always inspect `FPF_REFRESH_STATE_PATH` and `FPF_ENV_CHECK_STATE_PATH` in the gate output before deciding which state file controlled a run.

The portable doctor also reports path modes:

```text
FPF_ENV_CHECK_SKILL_PATH_MODE
FPF_ENV_CHECK_CACHE_PATH_MODE
FPF_ENV_CHECK_STATE_PATH_MODE
FPF_ENV_CHECK_PATH_POLICY_MODE
```

`FPF_ENV_CHECK_PATH_POLICY_MODE=portable-explicit` means the skill, cache, and state locations are all explicit enough for a non-default portable run. `mixed` is acceptable for local setups, but should be reviewed before publishing portability claims.

If the state path cannot be created, is not a directory, or is not writable, the refresh gate reports:

```text
FPF_REFRESH_REASON=state-dir-unavailable
```

If cache-only validation succeeds, the skill can continue with the current cached copy, but refresh timing is not durable because the state file could not be written. If cache-only validation fails, fix write permissions or set one of these variables to a writable directory:

```bash
export FPF_UPDATE_STATE_DIR="/writable/path/.fpf-update"
export FPF_REFRESH_STATE_DIR="$FPF_UPDATE_STATE_DIR"
export FPF_ENV_STATE_DIR="$FPF_UPDATE_STATE_DIR"
```

## Skill-Specific Notes

`fpf-latest` expects Bash, `git`, and network access when a refresh is required. If network access is unavailable but a valid cache already exists, it can use the current cached copy and disclose that status. Its scripts may run `git reset --hard` only in the default dedicated cache path, in a marked `.fpf-cache-repo` cache directory, or when `FPF_ALLOW_NONSTANDARD_CACHE_RESET=1` is explicitly set.

This public repository currently stages only `fpf-latest`. Other local or private skills should stay outside the public staged `skills/` tree unless they are deliberately promoted later.
