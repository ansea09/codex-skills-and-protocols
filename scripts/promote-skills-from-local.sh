#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
skills_dir="$repo_root/skills"
manifest="$skills_dir/promote-manifest.yaml"
local_skills_dir="${LOCAL_SKILLS_DIR:-${CODEX_HOME:-$HOME/.codex}/skills}"
dry_run=0
selected_skills=""

. "$repo_root/scripts/lib/skills-publication.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/promote-skills-from-local.sh [--dry-run] [--skill NAME ...]

Copies auto-promotable local skills from ${CODEX_HOME:-$HOME/.codex}/skills
into this repository's skills/ directory, then runs validation.

Curated and staged-only skills are intentionally skipped by this script.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    --skill)
      [ "$#" -ge 2 ] || { echo "ERROR: --skill requires a value" >&2; exit 2; }
      assert_safe_skill_name "$2"
      selected_skills="${selected_skills}${selected_skills:+
}$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -f "$manifest" ] || { echo "ERROR: missing manifest: $manifest" >&2; exit 1; }
[ -d "$local_skills_dir" ] || { echo "ERROR: local skills directory is missing: $local_skills_dir" >&2; exit 1; }

if [ -z "$selected_skills" ]; then
  selected_skills=$(manifest_auto_skills "$manifest")
fi

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-skill-promote.XXXXXX")
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

for skill_name in $selected_skills; do
  assert_safe_skill_name "$skill_name"

  mode=$(manifest_skill_mode "$manifest" "$skill_name" || true)
  if [ -z "$mode" ]; then
    echo "ERROR: skill is not listed in manifest: $skill_name" >&2
    exit 1
  fi

  if [ "$mode" != "auto" ]; then
    echo "ERROR: $skill_name is mode=$mode; only mode=auto can be promoted automatically" >&2
    exit 1
  fi

  source_dir="$local_skills_dir/$skill_name"
  staged_dir="$skills_dir/$skill_name"
  work_dir="$tmp_root/$skill_name-work"

  [ -d "$source_dir" ] || { echo "ERROR: local skill missing: $source_dir" >&2; exit 1; }
  [ -f "$source_dir/SKILL.md" ] || { echo "ERROR: local skill missing SKILL.md: $source_dir" >&2; exit 1; }

  copy_sanitized_skill "$source_dir" "$work_dir" "$skill_name"

  if ! scan_private_markers "$work_dir/$skill_name"; then
    echo "ERROR: private markers found while preparing $skill_name; staged copy was not changed" >&2
    exit 1
  fi

  if [ "$dry_run" -eq 1 ]; then
    echo "DRY-RUN: would promote $skill_name"
    continue
  fi

  case "$staged_dir" in
    "$skills_dir"/*) ;;
    *)
      echo "ERROR: unsafe staged destination: $staged_dir" >&2
      exit 1
      ;;
  esac

  rm -rf "$staged_dir"
  mv "$work_dir/$skill_name" "$staged_dir"
  echo "PROMOTED: $skill_name"
done

"$repo_root/scripts/validate-skills.sh"

if [ "$dry_run" -eq 1 ]; then
  echo "DRY-RUN: no files changed"
else
  echo "OK: promotion complete; review git diff before committing"
fi
