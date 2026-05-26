#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
skills_dir="$repo_root/skills"
manifest="$skills_dir/promote-manifest.yaml"
local_skills_dir="${LOCAL_SKILLS_DIR:-${CODEX_HOME:-$HOME/.codex}/skills}"
selected_skills=""
failed=0

. "$repo_root/scripts/lib/skills-publication.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/check-skills-drift.sh [--skill NAME ...]

Compares sanitized local auto-promotable skills with their staged public copies.
Curated and staged-only skills are reported as skipped.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
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
  selected_skills=$(manifest_skills "$manifest")
fi

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-skill-drift.XXXXXX")
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

for skill_name in $selected_skills; do
  assert_safe_skill_name "$skill_name"

  mode=$(manifest_skill_mode "$manifest" "$skill_name" || true)
  if [ -z "$mode" ]; then
    echo "ERROR: skill is not listed in manifest: $skill_name" >&2
    failed=1
    continue
  fi

  if [ "$mode" != "auto" ]; then
    echo "SKIP: $skill_name mode=$mode"
    continue
  fi

  source_dir="$local_skills_dir/$skill_name"
  staged_dir="$skills_dir/$skill_name"
  work_dir="$tmp_root/$skill_name-work"
  sanitized_dir="$work_dir/$skill_name"

  if [ ! -d "$source_dir" ]; then
    echo "DRIFT: $skill_name local skill missing: $source_dir" >&2
    failed=1
    continue
  fi

  if [ ! -d "$staged_dir" ]; then
    echo "DRIFT: $skill_name staged skill missing: $staged_dir" >&2
    failed=1
    continue
  fi

  copy_sanitized_skill "$source_dir" "$work_dir" "$skill_name"

  if ! scan_private_markers "$sanitized_dir"; then
    echo "DRIFT: $skill_name local copy contains private markers after sanitation" >&2
    failed=1
    continue
  fi

  if diff -qr "$sanitized_dir" "$staged_dir" >/dev/null; then
    echo "OK: $skill_name"
  else
    echo "DRIFT: $skill_name"
    diff -qr "$sanitized_dir" "$staged_dir" || true
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "OK: drift check complete"
