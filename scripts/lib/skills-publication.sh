#!/usr/bin/env sh

manifest_entries() {
  awk '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      return value
    }
    function emit() {
      if (name != "") {
        print name "\t" mode
      }
    }
    /^[[:space:]]*-[[:space:]]name:/ {
      emit()
      name = $0
      sub(/^[[:space:]]*-[[:space:]]name:[[:space:]]*/, "", name)
      name = trim(name)
      mode = "auto"
      next
    }
    /^[[:space:]]*mode:/ && name != "" {
      mode = $0
      sub(/^[[:space:]]*mode:[[:space:]]*/, "", mode)
      mode = trim(mode)
      next
    }
    END { emit() }
  ' "$1"
}

manifest_skills() {
  manifest_entries "$1" | awk '{ print $1 }'
}

manifest_auto_skills() {
  manifest_entries "$1" | awk '$2 == "auto" { print $1 }'
}

manifest_skill_mode() {
  manifest_entries "$1" | awk -v wanted="$2" '$1 == wanted { print $2; found = 1 } END { exit found ? 0 : 1 }'
}

assert_safe_skill_name() {
  case "${1:-}" in
    ""|.*|*/*|*..*|*\\*)
      echo "ERROR: unsafe skill name: ${1:-<empty>}" >&2
      return 1
      ;;
  esac

  case "$1" in
    *[!A-Za-z0-9._-]*)
      echo "ERROR: unsupported characters in skill name: $1" >&2
      return 1
      ;;
  esac
}

remove_generated_artifacts() {
  target="$1"
  find "$target" -name .DS_Store -type f -exec rm -f {} +
  find "$target" -name '*.pyc' -type f -exec rm -f {} +
  find "$target" -name __pycache__ -type d -prune -exec rm -rf {} +
}

copy_sanitized_skill() {
  source_dir="$1"
  output_parent="$2"
  skill_name="$3"

  mkdir -p "$output_parent"
  cp -R "$source_dir" "$output_parent/$skill_name"
  remove_generated_artifacts "$output_parent/$skill_name"
}

scan_private_markers() {
  target="$1"
  pattern='/Users/[A-Za-z0-9._/-]+|BEGIN (RSA|OPENSSH|DSA|EC) PRIVATE KEY|AWS_SECRET_ACCESS_KEY|GITHUB_TOKEN|OPENAI_API_KEY|ANTHROPIC_API_KEY|API_KEY=|TOKEN=|SECRET=|PASSWORD=|ghp_[A-Za-z0-9_]+|sk-[A-Za-z0-9_-]{20,}'

  if command -v rg >/dev/null 2>&1; then
    if rg -n "$pattern" "$target"; then
      return 1
    fi
  else
    if grep -RInE "$pattern" "$target"; then
      return 1
    fi
  fi

  return 0
}
