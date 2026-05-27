# fpf-latest Behavior Model

## Purpose

This document defines when an agent should invoke the public `fpf-latest`
refresh gate, what counts as a substantive task, and what "task start" means
for the public skill contract.

It is a behavior model for the public skill. It is not a private launcher,
LaunchAgent, or session-start hook specification.

## Context And Scope

In scope:

- the public `fpf-latest` skill behavior;
- agent-side task admission;
- refresh gate invocation before FPF-backed work;
- event and state vocabulary for documentation, review, and implementation;
- examples that separate substantive tasks from non-substantive interactions.

Out of scope:

- personal launchers;
- macOS LaunchAgents;
- session-index watchers;
- private workspace paths;
- private cache/state migration notes;
- a broker, event sourcing, outbox, durable event log, or async consumer design.

This model describes feature behavior. It does not imply Event-Driven
Architecture.

## Core Definitions

| Term | Meaning | Notes |
| --- | --- | --- |
| User message | The raw message delivered to the agent. | It can contain several requests or no work request at all. |
| Candidate request | A possible work demand extracted from a user message. | It is not yet accepted as work. |
| Normalized task | The unit of work the agent decides it can perform after reading the message, constraints, files, tools, and context. | Protocol routing is based on this, not on raw wording alone. |
| Substantive task | A normalized task where the answer or action depends on reasoning, code/files, sources, FPF patterns, protocols, architecture, review, planning, or other checkable work. | The agent runs `update_fpf_context.sh` before performing it. |
| Non-substantive interaction | A turn that only acknowledges, pauses, cancels, thanks, or asks for a trivial response that does not depend on FPF, files, tools, sources, or reasoning state. | The agent does not run the refresh gate solely for this interaction. |
| Task admission | The agent-side decision that a candidate request will be handled as a task. | This is the operational start of a task. |
| Substantive task start | The moment after minimal intake when the agent admits the normalized task as substantive work. | It is not identical to message receipt or application session start. |
| Codex session start | An application/runtime lifecycle event. | The public skill does not detect this event. Personal automation may react to it outside the public skill. |

## Active Systems And Work Artifacts

| Participant | Kind | Role in this behavior |
| --- | --- | --- |
| User | Human actor | Sends messages, supplies files, approves or fixes environment issues when needed. |
| Agent runtime | Active system | Parses the user message, admits or rejects tasks, invokes the refresh gate, and uses the resulting FPF context. |
| Local shell environment | Active system boundary | Provides Bash, Git, filesystem, Unix utilities, and optional network access. |
| GitHub | External system | Provides upstream FPF mirror and protocol repository when refresh is due or forced. |
| Local filesystem | Active system/resource boundary | Stores installed skill files, cache, state files, and diagnostics. |
| `update_fpf_context.sh` | Work artifact / script | The refresh gate script executed by the agent runtime. It is not the acting system. |
| `fpf-latest-doctor` | Work artifact / script | Installation and portability diagnostic entrypoint. It is not the acting system. |

## Commands

| Command | Initiator | Target | Preconditions | Success event | Failure or rejection result |
| --- | --- | --- | --- | --- | --- |
| `AdmitTask` | Agent runtime | Candidate request | User message contains a request that can be handled. | `TaskAdmitted` | `InteractionTreatedAsNonSubstantive` |
| `RunFpfRefreshGate` | Agent runtime | FPF context cache and refresh state | Task is admitted as substantive. | `FpfGateCompleted` | `FpfGateBlocked` |
| `RefreshFpfContext` | Refresh gate under agent runtime | FPF and protocol caches | Refresh is forced, TTL expired, state missing, or cache missing. | `FpfContextRefreshed` | `CachedContextUsed` or `FpfBackedWorkBlocked` |
| `UseFpfContext` | Agent runtime | Current answer or work | Gate output allows safe use. | `FpfBackedWorkStarted` | `FpfBackedWorkBlocked` |
| `RunPortableDoctor` | User or agent runtime | Local environment state | User is installing or troubleshooting. | `EnvironmentChecked` | `EnvironmentCheckBlocked` |

## Domain Events

| Event | Meaning | Caused by | State change |
| --- | --- | --- | --- |
| `UserMessageReceived` | The agent received a raw user message. | User action. | No task state change by itself. |
| `CandidateRequestIdentified` | The agent extracted a possible request. | Minimal intake. | `none -> candidate` |
| `InteractionTreatedAsNonSubstantive` | The turn does not require FPF-backed work. | `AdmitTask` rejected substantive handling. | `candidate -> no-work` |
| `TaskAdmitted` | The agent accepted a normalized task. | `AdmitTask`. | `candidate -> admitted` |
| `SubstantiveTaskAdmitted` | The admitted task requires FPF-backed substantive work. | Task classification. | `admitted -> substantive` |
| `FpfGateRequested` | The agent invokes the refresh gate. | `SubstantiveTaskAdmitted`. | `substantive -> gate-running` |
| `FpfGateCompleted` | The gate returned a usable fresh or cached context. | `RunFpfRefreshGate`. | `gate-running -> context-usable` |
| `FpfGateBlocked` | The gate cannot provide a safe FPF context. | `RunFpfRefreshGate`. | `gate-running -> blocked` |
| `FpfBackedWorkStarted` | The agent starts the substantive answer or work using the allowed context. | `UseFpfContext`. | `context-usable -> work-running` |

These are behavior-model events, not broker messages.

## Lifecycle

```text
UserMessageReceived
  -> CandidateRequestIdentified
  -> InteractionTreatedAsNonSubstantive

UserMessageReceived
  -> CandidateRequestIdentified
  -> TaskAdmitted
  -> SubstantiveTaskAdmitted
  -> FpfGateRequested
  -> FpfGateCompleted
  -> FpfBackedWorkStarted

UserMessageReceived
  -> CandidateRequestIdentified
  -> TaskAdmitted
  -> SubstantiveTaskAdmitted
  -> FpfGateRequested
  -> FpfGateBlocked
```

## Substantive Task Decision Table

| User turn shape | Substantive? | Gate? | Reason |
| --- | --- | --- | --- |
| "ok", "thanks" | no | no | Social acknowledgement only. |
| "stop", "wait", "pause" | no | no | Control turn; it cancels or suspends work. |
| "What is the current FPF cache status?" | yes | yes | Requires local state inspection and freshness disclosure. |
| "Use FPF to review this architecture" | yes | yes | Explicit FPF-backed reasoning. |
| "Fix this script" | yes | yes | Code/file work with verification. |
| "Explain how the public fpf-latest skill works" | yes | yes | Architecture/behavior explanation tied to the skill contract. |
| "Run fpf-latest-doctor" | yes | yes or doctor first | Troubleshooting/install validation depends on local environment state. |
| "Launch Codex app" | not by public skill | no public-skill automatic trigger | Public `fpf-latest` does not observe app lifecycle. Personal automation may force refresh before Codex work begins. |

If one user message contains several requests and any request is substantive,
the agent should run the refresh gate once before the first substantive work.

## Start Event Semantics

For the public skill, "start" means task admission, not raw message arrival.

The sequence is:

1. User message is delivered.
2. Agent performs minimal intake.
3. Agent identifies candidate request(s).
4. Agent decides whether a normalized task exists.
5. Agent decides whether the normalized task is substantive.
6. If substantive, the task starts for `fpf-latest` purposes and the agent runs the refresh gate before substantive work.

The public skill does not define or detect:

- application launch;
- new Codex UI session;
- laptop sleep or wake;
- user closing or reopening the Codex app;
- changes in `~/.codex/session_index.jsonl`.

Those are runtime or personal-automation concerns. A launcher or hook may map
one of those lifecycle events to `FPF_REFRESH_FORCE=1`, but that mapping is
outside the public skill contract.

## Refresh Policies

When a substantive task is admitted:

- run `scripts/update_fpf_context.sh` before reasoning, file reads, edits, review, planning, or final answer;
- if the gate returns `skipped_recent`, use cache-only validation and do not claim that an update was attempted;
- if the gate returns `attempted`, disclose fresh/cached status when it affects trust;
- if the gate returns `blocked`, do not claim FPF-backed work until the user fixes the source/cache/environment problem or allows a fetch;
- if `FPF_SPEC_STATUS=cached` or `FPF_PROTOCOLS_STATUS=cached`, say "current cached copy", not "latest".

## Queries And Read Models

| Read model | Used by | Data shown |
| --- | --- | --- |
| Refresh gate output | Agent runtime and user diagnostics | `FPF_REFRESH_DECISION`, reason, TTL, state path, cache status, chunk mode, commits. |
| Protocol registry | Agent runtime | Protocol routing files and checklist locations. |
| Chunk index and chunk directories | Agent runtime | FPF pattern and cluster lookup paths. |
| Doctor output | User or maintainer | Bash/Git/platform/cache/install readiness. |

## Side Effects

Possible side effects of the public skill scripts:

- local cache clone/fetch;
- cache marker write;
- refresh state write;
- environment state write;
- diagnostic output;
- no-op cache-only validation.

The public skill does not install LaunchAgents, write personal launcher files,
or watch Codex application session state.

## Acceptance Questions

- Does the user turn contain a normalized task, or only a control/social interaction?
- If there is a task, does correctness depend on FPF, files, tools, sources, architecture, code, or reasoning?
- If yes, did the agent run the refresh gate before substantive work?
- Did the agent avoid claiming "latest" when the gate reported cached sources?
- Did the answer disclose blocked/degraded status when it affects user trust or decisions?
- If session-start refresh is discussed, is it clearly marked as external personal automation rather than public skill behavior?
