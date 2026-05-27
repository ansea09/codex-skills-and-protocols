# ADR 0001: FPF Latest Architecture

Status: Accepted

Date: 2026-05-26 19:08:10 +0300

## Context

`fpf-latest` is the skill that lets Codex and compatible agent runtimes use the current cached First Principles Framework (FPF) context and the FPF Codex protocol repository during day-to-day work.

The skill must satisfy two different needs:

- Personal operation: the author's local Codex setup should refresh FPF context automatically, use cache safely, and avoid repeated unnecessary GitHub fetches.
- Public distribution: another user should be able to install or adapt the public skill without receiving personal launchers, machine-local state, cache, logs, or private automation.

The architecture must also keep role, method, work, artifact, process, and runtime boundaries separate. A script or shell process is an execution carrier, not the same thing as an acting system or a published skill artifact.

## Decision

### 1. Keep `fpf-latest` as the public skill boundary

The public `fpf-latest` skill is the portable instruction and script bundle. It defines how an agent refreshes or validates FPF context, selects Codex skills/protocols, reads FPF chunks, and discloses cache/freshness status.

Personal automation around the skill is not part of the public skill. This includes local launchers, session-start hooks, LaunchAgents, workspace jobs, `.fpf-update/`, cache directories, logs, and machine-local environment files.

### 2. Use plugin distribution for sharing the public skill

Reusable sharing beyond one local checkout should use a Codex plugin artifact:

- staged skill source: `skills/fpf-latest/`
- plugin artifact: `plugins/fpf-latest/`
- repo-local marketplace: `.agents/plugins/marketplace.json`

The plugin bundles only the public skill. It must not bundle personal automation, private overlays, cache/state, logs, or local env files.

### 3. Treat artifact layers as distinct

The repository distinguishes:

- public staged skill copy
- plugin distribution artifact
- installed operational copy
- private overlay skill
- runtime dependency layer
- cache and state layer
- personal automation layer
- generated output layer
- upstream source layer

Public staged skills and plugin artifacts may depend on documented runtime prerequisites, but must not depend on private overlays, personal automation, cache/state, generated outputs, or machine-specific paths.

### 4. Make the refresh gate the only refresh decision point

`scripts/update_fpf_context.sh` is the single gate that decides whether to fetch from GitHub or use cache-only validation.

The gate refreshes when:

- `FPF_REFRESH_FORCE=1`
- no valid cache exists
- state is missing
- the TTL has expired

Otherwise it validates and uses the current cached copy without contacting GitHub.

The default TTL is 6 hours (`21600` seconds). A session-start launcher or hook may force refresh on startup, but normal skill invocation must not fetch on every use.

The public task-admission threshold, substantive-task definition, and event vocabulary are defined in [../fpf-latest-behavior-model.md](../fpf-latest-behavior-model.md). In short, a raw user message is not itself the start event for the public skill; the public skill boundary starts at agent-side admission of a normalized task as substantive work.

### 5. Never call cached content "latest"

When `FPF_SPEC_STATUS=cached` or `FPF_PROTOCOLS_STATUS=cached`, answers and diagnostics must say `current cached copy`, not `latest`.

Freshness status is part of the contract. The skill must disclose whether FPF spec, chunks, and protocols were fresh, cached, missing, degraded, or blocked when that affects trust or user decisions.

### 6. Use chunk-first FPF reads with layout contract validation

FPF pattern access is chunk-first.

The optional root-level `fpf-chunks-layout.env` manifest declares the chunk layout version and canonical entrypoints. When present and valid, it is the source of truth for chunk layout.

The manifest is parsed as key/value text, not sourced as shell code. Required keys:

- `FPF_CHUNKS_LAYOUT_VERSION`
- `FPF_CHUNKS_ROOT`
- `FPF_CHUNKS_INDEX`
- `FPF_CHUNKS_METADATA`
- `FPF_CHUNKS_BY_PATTERN`
- `FPF_CHUNKS_BY_SECTION`
- `FPF_CHUNKS_NON_PATTERNS`

When the layout manifest is absent, the legacy layout remains the fallback contract:

- `fpf_chunks/000-index.md`
- `fpf_chunks/by_pattern/`
- `fpf_chunks/by_section/`
- `fpf_chunks/non_patterns/`

`metadata.jsonl` is optional lookup metadata. It is a fallback and diagnostic aid, not the layout source of truth. It must not override the layout manifest, direct chunk paths, index entries, or validated layout.

If chunk layout is unavailable or incomplete, the skill may fall back to targeted reads from `FPF-Spec.md`. If neither chunks nor full spec are safe enough, FPF-backed work is blocked until the user provides a valid source or allows a fetch.

### 7. Keep path lookup safe and simple

Layout manifest and chunk lookup paths may follow only relative paths that:

- do not start with `/`
- do not contain `..`
- resolve under `FPF_CHUNKS_PATH`

Unsafe layout manifest, metadata, or index paths are ignored. If the unsafe path affects the answer, the diagnostic should say what happened and what fallback was used.

### 8. Protect cache repositories from destructive Git operations

`git reset --hard` may run only in a dedicated FPF cache repository:

- the default cache path
- a cache directory containing `.fpf-cache-repo`
- a nonstandard cache path explicitly allowed by `FPF_ALLOW_NONSTANDARD_CACHE_RESET=1`

If a custom cache path looks like an ordinary working repository, the scripts must use the cached copy or block rather than resetting it.

### 9. Use state-based environment checking, not noisy preflight on every run

The environment check is for installation validation, portable checks, and meaningful environment changes. It must not print noisy diagnostics on every skill invocation.

Normal runtime behavior:

- run a silent fingerprint probe when local state and cache exist
- run full write-state checks when state is missing, cache is incomplete, the check is forced, the fingerprint changes, or refresh becomes blocked
- print diagnostics only when the user must decide something or when quality/trust is affected

The doctor command remains available for explicit validation:

```bash
bash "$FPF_LATEST_SKILL_DIR/scripts/fpf-latest-doctor" --write-state
```

### 10. Treat refresh state as an operational dependency

The refresh gate depends on small local state files to decide whether to refresh, skip, or block:

- workspace refresh state, usually `.fpf-update/latest.env`
- workspace environment state, usually `.fpf-update/environment.env`
- optional launcher/global refresh state, for example `~/.local/state/codex-fpf/latest.env`
- optional launcher/global environment state, for example `~/.local/state/codex-fpf/environment.env`

These files are operational evidence and decision state, not skill source. They must not be published as part of the public skill or plugin artifact.

The gate must distinguish an active refresh lock from an unavailable state directory. If the state path cannot be created, is not a directory, or is not writable, the gate reports `FPF_REFRESH_REASON=state-dir-unavailable`.

When state is unavailable but cache-only validation succeeds, the gate may continue with the current cached copy and disclose that durable refresh state was not written. When state is unavailable and cache-only validation fails, FPF-backed work is blocked until the user fixes permissions or sets `FPF_UPDATE_STATE_DIR`, `FPF_REFRESH_STATE_DIR`, or `FPF_ENV_STATE_DIR` to a writable directory.

### 11. Treat path defaults as replaceable defaults

The public skill must not treat `$HOME/.codex`, `$HOME/.agents`, or `$PWD/.fpf-update` as mandatory portable paths.

They are defaults for common local setups:

- `$HOME/.codex` is a Codex compatibility default and may provide the default cache root through `${CODEX_HOME:-$HOME/.codex}/cache`.
- `$HOME/.agents` is a user-scoped skill discovery default for runtimes that load skills there.
- `$PWD/.fpf-update` is a workspace-local state default for refresh and environment state.

Portable invocation should set explicit paths:

```bash
FPF_LATEST_SKILL_DIR="/absolute/path/to/fpf-latest" \
FPF_CACHE_HOME="/absolute/path/to/fpf-cache" \
FPF_UPDATE_STATE_DIR="/absolute/path/to/fpf-state" \
bash "$FPF_LATEST_SKILL_DIR/scripts/update_fpf_context.sh"
```

Specific cache directories may override the shared cache root:

- `FPF_SPEC_CACHE_DIR`
- `FPF_PROTOCOLS_CACHE_DIR`

Specific state directories may override the workspace-local state default:

- `FPF_UPDATE_STATE_DIR`
- `FPF_REFRESH_STATE_DIR`
- `FPF_ENV_STATE_DIR`
- `FPF_ENV_STATE_FILE`

Read-only, symlinked, shared, ephemeral, or non-workspace shells should not rely on `$PWD/.fpf-update`. They should set an explicit state directory.

The environment check reports path modes so agents and maintainers can see which path policy is active:

- `FPF_ENV_CHECK_SKILL_PATH_MODE`
- `FPF_ENV_CHECK_CACHE_PATH_MODE`
- `FPF_ENV_CHECK_STATE_PATH_MODE`
- `FPF_ENV_CHECK_PATH_POLICY_MODE`

### 12. Keep compatibility honest

The primary runtime is Codex on macOS.

Supported or documented modes:

- Codex on macOS: primary
- Claude Code or another agent: supported when the full skill directory is installed and invoked explicitly
- WSL Bash: supported
- Git Bash: best effort
- native Windows PowerShell/CMD: unsupported until a separate PowerShell implementation exists

Fresh refresh requires Bash, Git, standard Unix utilities, and GitHub network access. Cache fallback is supported when valid local caches exist.

### 13. Use explicit state paths for symlinked workspaces

When a workspace path is a symlink, diagnostics may alternate between the human-facing path and the resolved physical path.

Launchers and hooks should pass `FPF_UPDATE_STATE_DIR` explicitly when stable human-facing diagnostics and migration notes matter.

### 14. Separate session-start automation from skill execution

The skill itself does not detect "Codex session start" as an application lifecycle event.

Session-start refresh is implemented by an external launcher or hook that runs before Codex work begins and calls the refresh gate with `FPF_REFRESH_FORCE=1`.

The launcher or hook is personal automation. It may be documented as an example, but it is not required by the public skill or plugin artifact.

### 15. Use human-readable diagnostics only when they change user action or trust

Diagnostics should use this shape:

```text
What happened: ...
What it means: ...
What you can do: ...
Consequences: ...
```

Detailed user-facing diagnostics are required only when:

- no valid cache exists
- refresh is blocked
- refresh state or lock state is unavailable
- environment is blocked or degraded in a way that affects freshness or trust
- chunks are missing or degraded and full-spec fallback is used
- protocols are missing
- unsafe paths or metadata conflicts affected lookup

Routine TTL skips belong in the engineering basis, not as prominent warnings.

### 16. Use a doc-sync gate for method and architecture changes

Architecture-significant changes to `fpf-latest` must not silently drift away from documentation.

The personal workspace provides a local doc-sync gate:

```bash
jobs/fpf-doc-sync/check.sh
```

The gate fingerprints architecture-significant implementation files and documentation files. If implementation files changed but the documentation fingerprint did not change, it blocks and points to the required docs:

- this ADR
- the private personal implementation note at `docs/private/fpf-latest-personal-implementation.md`

The gate is intentionally a verification trigger, not an automatic author. It cannot know whether a change is semantically substantial enough to require a new ADR entry. When it flags a change, the agent or maintainer must either update the relevant documentation or explicitly accept that no documentation update is needed, then record a new baseline. If implementation and documentation both changed, the gate still reports `review-needed` until the updated docs are reviewed and accepted.

The public skill and plugin must not depend on this private doc-sync gate. The gate belongs to personal maintenance automation around the skill.

## Consequences

### Positive consequences

- The public artifact is installable and reviewable without exposing personal infrastructure.
- Daily use avoids unnecessary GitHub fetches while still supporting forced refresh on session start.
- Cached/fresh status is explicit, which avoids false "latest" claims.
- Chunk-first reads keep FPF-backed answers focused and reduce reliance on large full-spec scans.
- State-directory failures are diagnosed as state problems rather than mislabeled as active refreshes.
- Path defaults are explicit and overrideable, which makes portable installs auditable instead of relying on hidden `$HOME` or workspace assumptions.
- Destructive Git operations are constrained to known cache repositories.
- Plugin distribution gives another user a clean installation boundary.

### Costs and tradeoffs

- The skill remains macOS/Codex-first rather than fully cross-platform.
- Native Windows requires a separate implementation before it can be honestly supported.
- Session-start refresh depends on external launcher or hook setup; the public skill does not guarantee application lifecycle automation by itself.
- The plugin artifact must be kept in sync with the staged skill copy.
- Multiple state locations can exist at once, so diagnostics must disclose which state file controlled a refresh decision.
- Additional path-mode fields make doctor output longer, but they make portability decisions inspectable.
- Diagnostics are intentionally selective, so routine cache use is visible in engineering basis rather than always shown as a prominent message.
- Method and architecture changes gain a local documentation drift check, but the check still requires human or agent review of the actual content.

## Alternatives Considered

### Full-spec-first reads

Rejected. Reading the full spec by default is slower, less precise, and more error-prone for pattern-specific work. It remains useful only as fallback.

### Lookup metadata manifest as source of truth

Rejected for `metadata.jsonl` and other lookup metadata. Lookup metadata can drift or contain unsafe paths. The layout contract manifest may define canonical entrypoints, but actual readable chunk files and validated safe paths are still required before chunk-first reads are trusted.

### Refresh on every skill invocation

Rejected. It creates unnecessary network dependency, noise, and user interruption. Forced startup refresh plus 6-hour TTL is sufficient for normal use.

### Bundle personal launchers and hooks in the public skill or plugin

Rejected. Personal automation is machine-specific infrastructure, not the portable public skill contract.

### Claim broad Windows support

Rejected. WSL and Git Bash can be documented, but native PowerShell/CMD support needs a separate implementation.

## Validation Rules

Before publishing or sharing changes related to `fpf-latest`, run:

```bash
scripts/validate-skills.sh
scripts/validate-plugins.sh
```

Manual review must verify:

- staged skill and plugin copies contain no personal automation or private state
- compatibility claims match the scripts that actually exist
- cached/fresh wording is preserved
- layout manifest parsing stays key/value based and never sources the manifest as shell code
- unavailable refresh state is reported as `state-dir-unavailable`, not `active-refresh`
- portable path modes report the active skill/cache/state policy
- plugin artifact and marketplace entry still point to the public skill
- `git reset --hard` remains guarded behind dedicated-cache checks
- symlink-sensitive launchers or hooks pass `FPF_UPDATE_STATE_DIR` explicitly when needed
- architecture-significant `fpf-latest` changes pass the personal doc-sync gate or explicitly record why no documentation update was needed

## Open Follow-Ups

- Add a native PowerShell implementation only if Windows-native support becomes a real distribution target.
- Add `fpf-chunks-layout.env` to `ansea09/fpf-spec-mirror` when the upstream mirror is ready to declare chunk layout explicitly.
- Decide whether public examples should include an optional session-start launcher example without making it part of the public skill contract.
