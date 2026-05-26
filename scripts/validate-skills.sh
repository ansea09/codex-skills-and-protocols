#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
skills_dir="$repo_root/skills"
manifest="$skills_dir/promote-manifest.yaml"
failed=0

. "$repo_root/scripts/lib/skills-publication.sh"

if [ ! -d "$skills_dir" ]; then
  echo "ERROR: skills/ directory is missing" >&2
  exit 1
fi

if find "$repo_root" -name .DS_Store -print | grep -q .; then
  echo "ERROR: .DS_Store files are present" >&2
  find "$repo_root" -name .DS_Store -print >&2
  failed=1
fi

if find "$repo_root" -name '*.pyc' -print | grep -q .; then
  echo "ERROR: .pyc files are present" >&2
  find "$repo_root" -name '*.pyc' -print >&2
  failed=1
fi

if find "$repo_root" -name __pycache__ -type d -print | grep -q .; then
  echo "ERROR: __pycache__ directories are present" >&2
  find "$repo_root" -name __pycache__ -type d -print >&2
  failed=1
fi

if [ ! -f "$manifest" ]; then
  echo "ERROR: missing publication manifest: $manifest" >&2
  failed=1
fi

for skill_dir in "$skills_dir"/*; do
  [ -d "$skill_dir" ] || continue

  dir_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    echo "ERROR: $dir_name is missing SKILL.md" >&2
    failed=1
    continue
  fi

  first_line=$(sed -n '1p' "$skill_md")
  if [ "$first_line" != "---" ]; then
    echo "ERROR: $dir_name/SKILL.md must start with YAML frontmatter" >&2
    failed=1
  fi

  skill_name=$(awk '
    NR == 1 && $0 != "---" { exit 1 }
    NR > 1 && $0 == "---" { exit 0 }
    NR > 1 && $1 == "name:" {
      sub(/^name:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit 0
    }
  ' "$skill_md")

  if [ -z "$skill_name" ]; then
    echo "ERROR: $dir_name/SKILL.md is missing frontmatter name" >&2
    failed=1
  elif [ "$skill_name" != "$dir_name" ]; then
    echo "ERROR: $dir_name/SKILL.md name '$skill_name' does not match directory name" >&2
    failed=1
  fi

  if ! awk '
    NR == 1 && $0 != "---" { exit 1 }
    NR > 1 && $0 == "---" { exit found ? 0 : 1 }
    NR > 1 && $1 == "description:" { found = 1 }
  ' "$skill_md"; then
    echo "ERROR: $dir_name/SKILL.md is missing frontmatter description" >&2
    failed=1
  fi

  if ! grep -q "(skills/$dir_name/)" "$repo_root/skills-index.md"; then
    echo "ERROR: $dir_name is missing from skills-index.md" >&2
    failed=1
  fi
done

if [ -f "$manifest" ]; then
  for skill_name in $(manifest_skills "$manifest"); do
    assert_safe_skill_name "$skill_name" || failed=1
    if [ ! -d "$skills_dir/$skill_name" ]; then
      echo "ERROR: manifest references missing staged skill: $skill_name" >&2
      failed=1
    fi
  done
fi

if ! scan_private_markers "$skills_dir"; then
  echo "ERROR: private markers found under skills/" >&2
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "OK: staged skills passed structural validation"
