---
name: fpf-latest
description: Maintain and use the current First Principles Framework (FPF) context from ansea09/fpf-spec-mirror and Codex skills/protocols from ansea09/codex-skills-and-protocols. Run the FPF context refresh gate before substantive reasoning, coding, review, research, planning, document drafting, agent work, or source-backed answers; the gate refreshes only on session start, forced refresh, missing cache, or TTL expiry. Use when the user asks to answer with FPF or FPF Latest, when a task needs FPF patterns or FPF-backed protocols, or when working in this user's Codex environment where current FPF-backed reasoning is required.
compatibility:
  primary_runtime: "Codex on macOS"
  secondary_runtime: "Claude Code or other agents when this skill directory is installed and invoked explicitly"
  supported_shells:
    - "macOS Bash"
    - "WSL Bash"
    - "Git Bash best effort"
  unsupported_shells:
    - "native Windows PowerShell/CMD until a separate PowerShell implementation exists"
  required_commands:
    - "bash"
    - "git for fresh GitHub refresh"
    - "standard Unix utilities: awk, date, dirname, mkdir, mv, rmdir, stat, uname"
  network_requirement: "GitHub network access is required only when a refresh is due, forced, or no valid cache exists."
  cache_fallback: "Supported when FPF and protocol caches already exist; disclose cached/fresh status."
---

# FPF Latest

## Compatibility Contract

This skill is Codex/macOS-first. It is designed to run in a Unix-like shell with Bash, Git, and standard command line utilities.

Supported runtime contract:

- Codex on macOS: primary supported runtime.
- Claude Code or another agent: supported only when the whole `fpf-latest` directory is installed and the refresh gate is invoked from that installed directory.
- Windows: WSL Bash is supported; Git Bash is best effort; native PowerShell/CMD is not supported until a separate PowerShell implementation exists.
- Fresh refresh requires Git and network access to GitHub. If GitHub is unavailable but a valid cache exists, use the current cached copy and disclose that status.

## Required First Move

Before any substantive answer, code edit, review, plan, or delegated agent task, run the FPF context refresh gate:

Codex installed copy:

```bash
FPF_LATEST_SKILL_DIR="${FPF_LATEST_SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills/fpf-latest}"
bash "$FPF_LATEST_SKILL_DIR/scripts/update_fpf_context.sh"
```

Modern Codex user-scoped copy:

```bash
FPF_LATEST_SKILL_DIR="${FPF_LATEST_SKILL_DIR:-$HOME/.agents/skills/fpf-latest}"
bash "$FPF_LATEST_SKILL_DIR/scripts/update_fpf_context.sh"
```

Claude Code, WSL, Git Bash, or a non-Codex installation:

```bash
FPF_LATEST_SKILL_DIR="/absolute/path/to/fpf-latest"
bash "$FPF_LATEST_SKILL_DIR/scripts/update_fpf_context.sh"
```

If running from a non-installed copy of this skill, run the script from that skill folder instead.

If the workspace path is a symlink and diagnostics should show the human-facing path rather than the physical target, set `FPF_UPDATE_STATE_DIR` explicitly before running the gate:

```bash
FPF_UPDATE_STATE_DIR="/visible/workspace/path/.fpf-update" bash "$FPF_LATEST_SKILL_DIR/scripts/update_fpf_context.sh"
```

For installation validation, troubleshooting, or a portable-install check, run:

```bash
FPF_LATEST_SKILL_DIR="${FPF_LATEST_SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills/fpf-latest}"
bash "$FPF_LATEST_SKILL_DIR/scripts/fpf-latest-doctor" --write-state
```

Equivalent direct check:

```bash
FPF_LATEST_SKILL_DIR="${FPF_LATEST_SKILL_DIR:-${CODEX_HOME:-$HOME/.codex}/skills/fpf-latest}"
bash "$FPF_LATEST_SKILL_DIR/scripts/check_fpf_environment.sh" --portable-install --write-state
```

The environment check does not contact GitHub. The refresh gate runs a silent fingerprint probe when local environment state and cache exist, and prints environment diagnostics only when the fingerprint changed, the environment is degraded or blocked, or the check is forced with `FPF_ENV_CHECK_FORCE=1`. It runs the full write-state check when local environment state is missing, the FPF/protocol cache is incomplete, the check is forced, the fingerprint changed, or a refresh attempt ends in a blocked state. By default the environment state is stored beside the refresh state, usually in the current workspace `.fpf-update` directory unless a launcher passes `FPF_UPDATE_STATE_DIR`, `FPF_REFRESH_STATE_DIR`, or `FPF_ENV_STATE_DIR`. In symlinked workspaces, prefer an explicit `FPF_UPDATE_STATE_DIR` so reports do not alternate between the visible path and the resolved physical path.

The gate is the only component that decides whether to refresh from GitHub or use cache-only validation:

- refresh immediately when `FPF_REFRESH_FORCE=1`, for example from the external session-start hook or launcher.
- refresh when no valid cache exists.
- refresh when the last refresh attempt is older than `FPF_REFRESH_TTL_SECONDS`.
- otherwise do not contact GitHub; validate and use the current cached copy.

Read the script output:

- `FPF_REFRESH_DECISION`: `attempted`, `skipped_recent`, or `blocked`
- `FPF_REFRESH_REASON`: `session-start`, `ttl-expired`, `recent-cache`, `missing-cache`, `missing-state`, `forced`, `active-refresh`, or `state-dir-unavailable`
- `FPF_REFRESH_TTL_SECONDS`: refresh TTL, normally `21600`
- `FPF_REFRESH_LOCK_STALE_SECONDS`: lock age after which an abandoned refresh lock may be recovered, normally `900`
- `FPF_ENV_CHECK_POLICY`: `fingerprint` by default; set `on-demand` or `disabled` to skip the silent per-run fingerprint probe
- `FPF_REFRESH_LAST_ATTEMPT_AT`: timestamp of the last refresh attempt, or `none`
- `FPF_REFRESH_NEXT_ELIGIBLE_AT`: next timestamp when TTL-based refresh may run, or `none`
- `FPF_REFRESH_STATE_PATH`: state file used by the refresh gate; by default this is the current workspace `.fpf-update/latest.env` unless a launcher or hook passes `FPF_UPDATE_STATE_DIR`
- `FPF_REFRESH_DETAIL`: diagnostic detail for the refresh gate, when present
- `FPF_ENV_CHECK_STATUS`: `ok`, `degraded`, or `blocked`, present only when the environment check ran
- `FPF_ENV_CHECK_REASON`: machine-readable reason for the environment check status
- `FPF_ENV_CHECK_STATE_STATUS`: `missing`, `changed`, `same`, or `recorded`
- `FPF_ENV_CHECK_STATE_PATH`: local path to the environment state file
- `FPF_ENV_CHECK_STATE_DETAIL`: short explanation of the environment state result
- `FPF_ENV_CHECK_SKILL_DIR`: resolved local skill directory
- `FPF_ENV_CHECK_CACHE_HOME`: cache root used by default when specific cache paths are not passed
- `FPF_ENV_CHECK_CODEX_APP_PATH`, `FPF_ENV_CHECK_CODEX_APP_FINGERPRINT`: optional macOS Codex app bundle path and filesystem fingerprint used to detect local app replacement when available
- `FPF_ENV_CHECK_OS_NAME`, `FPF_ENV_CHECK_OS_ARCH`: detected platform values
- `FPF_ENV_CHECK_BASH_PATH`, `FPF_ENV_CHECK_BASH_VERSION`: Bash used by the skill scripts
- `FPF_ENV_CHECK_GIT_STATUS`: `available` or `missing`
- `FPF_ENV_CHECK_CACHE_STATUS`: `ready`, `partial`, or `missing`
- `FPF_ENV_CHECK_SUMMARY`: short human-readable environment result
- `FPF_ENV_CHECK_ACTION`: what the user or environment owner should do, when action is needed
- `FPF_ENV_CHECK_CONSEQUENCE`: practical consequence for FPF-backed work
- `FPF_PORTABLE_CHECK_STATUS`: `ok`, `degraded`, or `blocked`, present only when `--portable-install` or `scripts/fpf-latest-doctor` ran
- `FPF_PORTABLE_CHECK_REASON`: machine-readable portable-install reason
- `FPF_PORTABLE_CHECK_PLATFORM`: `macOS`, `WSL`, `Windows Unix shell`, `Linux`, or another detected platform label
- `FPF_PORTABLE_CHECK_WINDOWS_MODE`: `not-windows`, `wsl`, or `git-bash`
- `FPF_PORTABLE_CHECK_AGENT_MODE`: `codex-default`, `custom-codex-home`, or portable agent mode inferred by the check
- `FPF_SPEC_PATH`: local path to the current or cached `FPF-Spec.md`
- `FPF_SPEC_COMMIT`: Git commit used for the answer
- `FPF_SPEC_STATUS`: `fresh`, `cached`, or `missing`
- `FPF_SPEC_WARNING`: warning to disclose if GitHub was unavailable and cached content was used
- `FPF_SPEC_DETAIL`: blocking or diagnostic detail for the full specification
- `FPF_CHUNKS_LAYOUT_MANIFEST_PATH`: local path to the optional root-level `fpf-chunks-layout.env` layout contract
- `FPF_CHUNKS_LAYOUT_STATUS`: `legacy`, `ready`, or `invalid`
- `FPF_CHUNKS_LAYOUT_SOURCE`: `legacy-defaults` or `manifest`
- `FPF_CHUNKS_LAYOUT_VERSION`: declared layout version, or `legacy-1` when no layout manifest exists
- `FPF_CHUNKS_LAYOUT_DETAIL`: diagnostic detail when the layout manifest is invalid
- `FPF_CHUNKS_PATH`: local path to the canonical chunks root selected by layout manifest or legacy defaults
- `FPF_CHUNKS_INDEX_PATH`: local path to the canonical chunk index selected by layout manifest or legacy defaults
- `FPF_CHUNKS_METADATA_PATH`: local path to optional chunk lookup metadata selected by layout manifest or legacy defaults
- `FPF_CHUNKS_BY_PATTERN_DIR`: local path to pattern chunks
- `FPF_CHUNKS_BY_SECTION_DIR`: local path to section or cluster chunks
- `FPF_CHUNKS_NON_PATTERNS_DIR`: local path to chunks without pattern bodies
- `FPF_CHUNKS_STATUS`: `ready`, `degraded`, or `missing`
- `FPF_CHUNKS_MODE`: `chunk-first`, `full-spec-fallback`, or `blocked`
- `FPF_CHUNKS_WARNING`: warning to disclose when chunk lookup is degraded
- `FPF_CHUNKS_DETAIL`: concrete missing or degraded chunk entrypoint
- `FPF_PROTOCOLS_PATH`: local path to the current or cached protocol repository
- `FPF_PROTOCOLS_REGISTRY_PATH`: local path to `registry.yaml`
- `FPF_PROTOCOLS_COMMIT`: protocol repository commit used for the answer
- `FPF_PROTOCOLS_STATUS`: `fresh`, `cached`, or `missing`
- `FPF_PROTOCOLS_WARNING`: warning to disclose if GitHub was unavailable and cached content was used

If `FPF_SPEC_STATUS=missing`, explain that no local FPF cache exists and ask the user to allow a GitHub fetch or provide the file.

Never describe FPF or protocols as latest when `FPF_SPEC_STATUS=cached` or `FPF_PROTOCOLS_STATUS=cached`; say `current cached copy` instead.

If `FPF_REFRESH_DECISION=skipped_recent`, do not say that an update was attempted. Say that the gate used cache-only validation because the TTL has not expired.

If `FPF_REFRESH_DECISION=blocked`, explain why FPF-backed work is blocked and ask the user only for the action needed to restore a valid cache or allow a fetch.

If `FPF_REFRESH_REASON=state-dir-unavailable`, explain that the refresh gate could not create or write the local state directory. If cache-only validation succeeded, continue with the current cached copy and say refresh state was not durable. If cache-only validation failed, ask the user to fix write permissions or set `FPF_UPDATE_STATE_DIR` to a writable directory.

If `FPF_ENV_CHECK_STATUS=blocked`, explain `FPF_ENV_CHECK_SUMMARY`, `FPF_ENV_CHECK_ACTION`, and `FPF_ENV_CHECK_CONSEQUENCE` before any other FPF diagnostic.

If `FPF_ENV_CHECK_STATUS=degraded`, continue only when the cache status and downstream script statuses allow it. Disclose the degraded environment status when it affects freshness, trust, or a user decision.

If `FPF_CHUNKS_MODE=blocked`, explain that neither chunk-first lookup nor full-spec fallback is safe enough for an FPF-backed answer. Ask the user to allow a GitHub fetch or provide a valid local mirror.

If `FPF_CHUNKS_MODE=full-spec-fallback`, continue only with `FPF_SPEC_PATH` and disclose that chunks are unavailable or structurally incomplete.

If `FPF_PROTOCOLS_STATUS=missing`, explain that no local FPF Codex protocol cache exists and ask the user to allow a GitHub fetch or provide the repository files.

Backward compatibility: `scripts/update_fpf_spec.sh` refreshes or validates only the FPF specification depending on `FPF_REFRESH_MODE`. Use `scripts/update_fpf_context.sh` for normal work.

Cache safety: `update_fpf_spec.sh` and `update_fpf_protocols.sh` may run `git reset --hard` only in the default dedicated cache path, in a cache directory that contains `.fpf-cache-repo`, or when `FPF_ALLOW_NONSTANDARD_CACHE_RESET=1` is explicitly set. If a custom cache path looks like an ordinary working repository, use the cached copy or block rather than resetting it.

Portable cache root: set `FPF_CACHE_HOME` to move both FPF caches outside `${CODEX_HOME:-$HOME/.codex}/cache`, for example when running from Claude Code, WSL, or another agent runtime. More specific `FPF_SPEC_CACHE_DIR` and `FPF_PROTOCOLS_CACHE_DIR` still take precedence.

## How To Use The Protocols

Read `FPF_PROTOCOLS_REGISTRY_PATH` first. Then load only the files required by the registry for the current task:

1. Read `protocols/00-definitions.md` when message/request/question/task distinctions matter.
2. Read `protocols/01-classification.md` for every substantive task.
3. Read `protocols/02-routing-table.md` before selecting a protocol.
4. Select exactly one baseline protocol: `simple-medium` or `complex`.
5. Execute every selected checklist item without silent skips.
6. Mark each item as `done`, `not_applicable: reason`, or `blocked: reason`.

Use `simple-medium` for bounded low-risk tasks. Use `complex` for high-stakes, source-sensitive, multi-view, external-action, architecture, automation, large-code-change, or ambiguous ontology tasks.

Do not print the full checklist unless the user asks for an audit trace. For ordinary final answers, summarize the selected protocol and completion status in the engineering basis.

## How To Use FPF Chunks

Use a chunk-first method. Do not load the full specification into context unless chunks are unavailable, incomplete, or a targeted chunk lookup fails.

Interpret chunk mode this way:

- `FPF_CHUNKS_STATUS=ready` and `FPF_CHUNKS_MODE=chunk-first`: use chunks as the primary source for FPF pattern reads.
- `FPF_CHUNKS_STATUS=degraded` and `FPF_CHUNKS_MODE=chunk-first`: required chunk entrypoints exist, but optional metadata is missing. Use index and direct paths.
- `FPF_CHUNKS_MODE=full-spec-fallback`: do not rely on chunk layout. Use targeted `rg` and `sed` reads against `FPF_SPEC_PATH`.
- `FPF_CHUNKS_MODE=blocked`: do not claim FPF-backed reasoning until the user provides a valid source or allows a fetch.

Treat the root-level `fpf-chunks-layout.env` file as the optional layout contract manifest. If it exists, it is the source of truth for the chunk layout version and canonical entrypoints. If it does not exist, use the legacy layout contract: `fpf_chunks/000-index.md`, `fpf_chunks/by_pattern`, `fpf_chunks/by_section`, and `fpf_chunks/non_patterns`.

The layout manifest format is intentionally shell-independent key/value text, but do not source it. The refresh script parses these keys:

```text
FPF_CHUNKS_LAYOUT_VERSION=1
FPF_CHUNKS_ROOT=fpf_chunks
FPF_CHUNKS_INDEX=000-index.md
FPF_CHUNKS_METADATA=metadata.jsonl
FPF_CHUNKS_BY_PATTERN=by_pattern
FPF_CHUNKS_BY_SECTION=by_section
FPF_CHUNKS_NON_PATTERNS=non_patterns
```

When the layout manifest changes folder or file names, use the paths emitted by the refresh gate: `FPF_CHUNKS_PATH`, `FPF_CHUNKS_INDEX_PATH`, `FPF_CHUNKS_BY_PATTERN_DIR`, `FPF_CHUNKS_BY_SECTION_DIR`, and `FPF_CHUNKS_NON_PATTERNS_DIR`. Do not hard-code legacy folder names after the gate has emitted canonical paths.

Manifest paths must be non-empty relative paths, must not start with `/`, and must not contain `..`. If the layout manifest is missing required keys or contains unsafe paths, ignore chunk-first reads and use full-spec fallback when possible.

Treat `metadata.jsonl` as optional lookup metadata for fallback and diagnostics, not as the layout source of truth. Never let metadata override an existing direct chunk path, a validated index entry, or the layout contract manifest. If metadata conflicts with direct paths or points outside `FPF_CHUNKS_PATH`, ignore metadata and use direct chunks or full-spec fallback.

When selecting relevant patterns yourself:

1. Read `FPF_CHUNKS_INDEX_PATH` first.
2. Select the minimal relevant pattern IDs or cluster IDs for the task.
3. Read only the matching chunk files.
4. If the index is missing and `FPF_CHUNKS_MODE=full-spec-fallback`, search `FPF_SPEC_PATH` directly.

When a specific pattern ID is known:

1. Prefer the direct file: `FPF_CHUNKS_BY_PATTERN_DIR/<pattern-id>.md`.
2. If absent, search `FPF_CHUNKS_INDEX_PATH`.
3. Use `FPF_CHUNKS_METADATA_PATH` only as a fallback hint or diagnostic aid when direct path and index lookup do not resolve the pattern.
4. Only follow lookup paths that are relative, do not start with `/`, do not contain `..`, and resolve under `FPF_CHUNKS_PATH`.
5. If a matching file exists only in `FPF_CHUNKS_NON_PATTERNS_DIR`, say that the pattern title exists but the body is unavailable.
6. If chunk lookup fails, use `FPF_SPEC_PATH` fallback and disclose the fallback when the answer depends on FPF.

When a cluster or section is requested:

1. Prefer sorted files under `FPF_CHUNKS_BY_SECTION_DIR/<cluster-id>/`.
2. If that directory is absent, try `FPF_CHUNKS_BY_PATTERN_DIR/<cluster-id>.md`.
3. If both fail, use targeted full-spec fallback.

Safe full-spec fallback search pattern:

```bash
rg -n "A\\.1\\.1|A\\.1 |A\\.2|A\\.2\\.1|A\\.2\\.2|A\\.2\\.4|A\\.2\\.6|A\\.3\\.1|A\\.3\\.3|A\\.4|A\\.6\\.P|A\\.7|A\\.10|A\\.11|A\\.15|C\\.7|C\\.27|C\\.28|E\\.17" "$FPF_SPEC_PATH"
```

For every substantive response, apply these baseline distinctions:

- Bound the answer context before reasoning.
- Identify the active systems, their roles, methods, and actual work.
- Separate object, description, carrier, role, method, work plan, and performed work.
- State scope and time window for claims that can change.
- Tie factual or external-domain claims to evidence.
- Prefer the smallest sufficient ontology; do not invent new categories when ordinary domain terms are enough.
- If several viewpoints matter, handle them separately and then reconcile.

## User-Facing Diagnostics

Show a diagnostic only when it affects what the user can trust or decide.

Use this shape:

```text
What happened: ...
What it means: ...
What you can do: ...
Consequences: ...
```

Diagnostic triggers:

- A refresh attempt was made and GitHub was unavailable but cache exists: say the answer uses the current cached FPF copy; consequence is possible staleness.
- The refresh gate skipped GitHub because TTL has not expired: mention this only in the engineering basis, not as a user-facing warning.
- No local cache exists: say FPF-backed work is blocked until fetch or local files are provided.
- Chunks are missing or structurally incomplete but `FPF-Spec.md` exists: say chunk-first lookup is unavailable and full-spec fallback is being used; consequence is slower and less focused reads.
- The layout manifest is invalid: say the chunk layout contract is invalid and full-spec fallback is being used when possible.
- The canonical chunk index is missing: say automatic pattern discovery is less reliable; use direct known pattern paths or full-spec fallback.
- A requested pattern chunk is missing: try `non_patterns`, related section chunks, then full-spec fallback before asking the user.
- A metadata or index path is unsafe: ignore that path, use direct safe paths or full-spec fallback, and mention the ignored unsafe entry if it affected the answer.
- Protocols are missing: say answer protocol selection is blocked until protocols are fetched or provided.

## Response Discipline

Write the main answer in the user's domain language, not in FPF terminology, unless the user explicitly asks for FPF terms.

If the user asks in Russian, answer in Russian. If the user asks in another domain language, use that language.

Do not lie or fill gaps with invented facts. If a claim is unknown, say so. If a hypothesis is useful, label it as a hypothesis invented by the assistant and explain why it may be workable.

End substantive answers with a concise engineering basis:

- FPF refresh gate: decision, reason, TTL, and next eligible refresh time.
- FPF spec source: local path, commit, and whether it was fresh or cached.
- FPF chunks source: local path, status, mode, and whether chunk-first or full-spec fallback was used.
- FPF protocol source: local path, commit, and whether it was fresh or cached.
- selected protocol and completion status.
- FPF patterns used and why.
- External sources used, selection reason, and channels searched.
- Relevant sources or channels not used.
- Consistency check and temporal adequacy limits.

If `FPF_SPEC_WARNING`, `FPF_CHUNKS_WARNING`, or `FPF_PROTOCOLS_WARNING` is present, include it in the engineering basis or a short diagnostic when relevant.

## External Sources

When external sources are needed, use expert sources from the relevant domain rather than AI-generated or SEO-like summaries. Read `references/source-selection.md` when doing source-backed research.

## Coding And Agent Work

When writing code, reviewing code, or delegating to agents:

- Run the FPF context refresh gate first, then record the gate decision and both commits.
- Use FPF chunks for pattern lookup whenever `FPF_CHUNKS_MODE=chunk-first`.
- Pass the same FPF requirement to agents in their prompt when delegation is explicitly authorized.
- Use FPF to structure reasoning and verification, but keep code changes idiomatic to the repository.
- Do not add FPF jargon to user-facing code, UI copy, or documentation unless the user requests it.
