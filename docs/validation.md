# Validation

Run this before installing or sharing staged skills or plugins from this repository.

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

The validation checks:

- every directory under `skills/` contains `SKILL.md`;
- each `SKILL.md` starts with YAML frontmatter;
- frontmatter contains `name` and `description`;
- the frontmatter `name` matches the skill directory name;
- no `.DS_Store`, `__pycache__`, or `.pyc` files are present;
- every staged skill is listed in `skills-index.md`;
- every skill listed in `skills/promote-manifest.yaml` exists under `skills/`;
- no high-risk private markers are present under `skills/`.

Plugin validation checks:

- every directory under `plugins/` contains `.codex-plugin/plugin.json`;
- each plugin manifest has `name`, `version`, `description`, `skills`, and `interface`;
- the manifest `name` matches the plugin directory name;
- bundled skills under `plugins/<name>/skills/` contain valid `SKILL.md` files;
- the repo-local marketplace `.agents/plugins/marketplace.json` lists the plugin;
- no high-risk private markers are present under `plugins/`.

Manual review checklist:

- The staged copy is classified using [skill-artifact-model.md](skill-artifact-model.md) before review.
- The skill does not expose secrets, tokens, local private paths, or private data.
- `fpf-latest` installation docs include the one-time portable doctor command.
- Installation docs distinguish modern Codex skill discovery locations such as `.agents/skills` from local legacy/current compatibility paths such as `${CODEX_HOME:-$HOME/.codex}/skills`.
- Installation docs state that plugins are the distribution path for reusable skills shared beyond local authoring or a single repo-scoped workflow.
- `fpf-latest` states its compatibility contract: Codex/macOS-first, Bash and Git required for refresh, cache fallback supported, WSL supported, Git Bash best effort, native PowerShell/CMD unsupported until a separate implementation exists.
- `fpf-latest` does not require hard-coded `$HOME/.codex`, `$HOME/.agents`, or `$PWD/.fpf-update` invocation when installed for Claude Code or another non-Codex agent; the docs show `FPF_LATEST_SKILL_DIR`, `FPF_CACHE_HOME`, and `FPF_UPDATE_STATE_DIR`.
- `fpf-latest` doctor output reports path modes for skill, cache, state, and overall path policy.
- `fpf-latest` protects `git reset --hard` behind a dedicated-cache guard for nonstandard cache paths.
- Personal automation around `fpf-latest` is documented as local infrastructure, not as a public skill overlay or staged skill dependency.
- Symlinked workspaces use explicit `FPF_UPDATE_STATE_DIR` in launchers/hooks when stable human-facing diagnostics matter.
- `fpf-latest` documents that workspace state and launcher/global state can both exist; reviewers inspect `FPF_REFRESH_STATE_PATH` before interpreting refresh decisions.
- `fpf-latest` classifies an unavailable or unwritable state directory as `state-dir-unavailable`, not `active-refresh`.
- Public plugin artifacts do not include personal launchers, LaunchAgents, workspace jobs, `.fpf-update/`, cache, logs, or machine-local env files.
- Private overlays, runtime venvs, caches, local state files, logs, generated outputs, and upstream mirrors are not committed as staged skill content unless explicitly reviewed as public fixtures or examples.
- Public examples do not imply capabilities that are not included in the repository.
- Any optional runtime dependency is disclosed in `skills-index.md` and the skill's `SKILL.md`.
- `fpf-latest` and other FPF-backed skills disclose cached/fresh status rather than claiming "latest" when only cache is available.
- `fpf-latest` treats `fpf-chunks-layout.env` as a parsed key/value layout contract, never as sourced shell code.
- `fpf-latest` has been tested for at least: normal cache-only run, invalid state path fallback, staged/plugin/runtime copy sync, and plugin/skill structural validation.
- The repository README, `skills-index.md`, install instructions, and collaboration scenario still describe the same staged scope.
- Auto-promotable skills are safe to regenerate from local copies; curated skills keep their public-safe edits.
