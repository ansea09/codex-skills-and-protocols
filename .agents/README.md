# Agent Configuration

This directory is a machine-readable Codex agent configuration directory.

The marketplace file at [`plugins/marketplace.json`](plugins/marketplace.json)
is used for plugin discovery and installation. It tells Codex which plugins
this repository exposes and where their plugin packages live.

Human-facing plugin documentation lives in the plugin package READMEs:

- [`../plugins/fpf-work-guide/README.md`](../plugins/fpf-work-guide/README.md)
- [`../plugins/doc-to-md/README.md`](../plugins/doc-to-md/README.md)

Do not rename this directory unless the Codex marketplace path is configured
explicitly. Codex/plugin tooling expects repo-local marketplace metadata at:

```text
.agents/plugins/marketplace.json
```
