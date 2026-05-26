#!/usr/bin/env bash
set -u

REPO_URL="${FPF_SPEC_REPO_URL:-https://github.com/ansea09/fpf-spec-mirror.git}"
BRANCH="${FPF_SPEC_BRANCH:-main}"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
DEFAULT_CACHE_HOME="${FPF_CACHE_HOME:-$CODEX_HOME_DIR/cache}"
DEFAULT_CACHE_DIR="$DEFAULT_CACHE_HOME/fpf-spec-mirror"
CACHE_DIR="${FPF_SPEC_CACHE_DIR:-$DEFAULT_CACHE_DIR}"
CACHE_MARKER="$CACHE_DIR/.fpf-cache-repo"
SPEC_PATH="$CACHE_DIR/FPF-Spec.md"
CHUNKS_LAYOUT_MANIFEST_PATH="${FPF_CHUNKS_LAYOUT_MANIFEST_PATH:-$CACHE_DIR/fpf-chunks-layout.env}"
REFRESH_MODE="${FPF_REFRESH_MODE:-${FPF_UPDATE_MODE:-refresh}}"

status="missing"
warning=""
detail=""
chunks_layout_status="legacy"
chunks_layout_source="legacy-defaults"
chunks_layout_version="legacy-1"
chunks_layout_detail=""
chunks_root_rel="fpf_chunks"
chunks_index_rel="000-index.md"
chunks_metadata_rel="metadata.jsonl"
chunks_by_pattern_rel="by_pattern"
chunks_by_section_rel="by_section"
chunks_non_patterns_rel="non_patterns"
CHUNKS_PATH="$CACHE_DIR/$chunks_root_rel"
CHUNKS_INDEX_PATH="$CHUNKS_PATH/$chunks_index_rel"
CHUNKS_METADATA_PATH="$CHUNKS_PATH/$chunks_metadata_rel"
CHUNKS_BY_PATTERN_DIR="$CHUNKS_PATH/$chunks_by_pattern_rel"
CHUNKS_BY_SECTION_DIR="$CHUNKS_PATH/$chunks_by_section_rel"
CHUNKS_NON_PATTERNS_DIR="$CHUNKS_PATH/$chunks_non_patterns_rel"
chunks_status="missing"
chunks_mode="blocked"
chunks_warning=""
chunks_detail=""

manifest_value() {
  local key="$1"
  awk -F= -v key="$key" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      lhs = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", lhs)
      if (lhs == key) {
        value = substr($0, index($0, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        sub(/\r$/, "", value)
        print value
        found = 1
        exit
      }
    }
    END { exit(found ? 0 : 1) }
  ' "$CHUNKS_LAYOUT_MANIFEST_PATH"
}

is_safe_relative_path() {
  local path="$1"
  [ -n "$path" ] || return 1
  case "$path" in
    /*|..|../*|*/..|*/../*) return 1 ;;
  esac
  return 0
}

set_chunk_paths() {
  CHUNKS_PATH="$CACHE_DIR/$chunks_root_rel"
  CHUNKS_INDEX_PATH="$CHUNKS_PATH/$chunks_index_rel"
  CHUNKS_METADATA_PATH="$CHUNKS_PATH/$chunks_metadata_rel"
  CHUNKS_BY_PATTERN_DIR="$CHUNKS_PATH/$chunks_by_pattern_rel"
  CHUNKS_BY_SECTION_DIR="$CHUNKS_PATH/$chunks_by_section_rel"
  CHUNKS_NON_PATTERNS_DIR="$CHUNKS_PATH/$chunks_non_patterns_rel"
}

layout_manifest_has_required_keys() {
  local key
  for key in \
    FPF_CHUNKS_LAYOUT_VERSION \
    FPF_CHUNKS_ROOT \
    FPF_CHUNKS_INDEX \
    FPF_CHUNKS_METADATA \
    FPF_CHUNKS_BY_PATTERN \
    FPF_CHUNKS_BY_SECTION \
    FPF_CHUNKS_NON_PATTERNS
  do
    manifest_value "$key" >/dev/null 2>&1 || return 1
  done
  return 0
}

load_chunk_layout() {
  chunks_layout_status="legacy"
  chunks_layout_source="legacy-defaults"
  chunks_layout_version="legacy-1"
  chunks_layout_detail=""
  chunks_root_rel="fpf_chunks"
  chunks_index_rel="000-index.md"
  chunks_metadata_rel="metadata.jsonl"
  chunks_by_pattern_rel="by_pattern"
  chunks_by_section_rel="by_section"
  chunks_non_patterns_rel="non_patterns"
  set_chunk_paths

  if [ ! -f "$CHUNKS_LAYOUT_MANIFEST_PATH" ]; then
    return 0
  fi

  chunks_layout_source="manifest"

  if [ ! -r "$CHUNKS_LAYOUT_MANIFEST_PATH" ]; then
    chunks_layout_status="invalid"
    chunks_layout_detail="Chunk layout manifest exists but is not readable: $CHUNKS_LAYOUT_MANIFEST_PATH."
    return 1
  fi

  if ! layout_manifest_has_required_keys; then
    chunks_layout_status="invalid"
    chunks_layout_detail="Chunk layout manifest is missing one or more required keys."
    return 1
  fi

  chunks_layout_version="$(manifest_value FPF_CHUNKS_LAYOUT_VERSION)"
  chunks_root_rel="$(manifest_value FPF_CHUNKS_ROOT)"
  chunks_index_rel="$(manifest_value FPF_CHUNKS_INDEX)"
  chunks_metadata_rel="$(manifest_value FPF_CHUNKS_METADATA)"
  chunks_by_pattern_rel="$(manifest_value FPF_CHUNKS_BY_PATTERN)"
  chunks_by_section_rel="$(manifest_value FPF_CHUNKS_BY_SECTION)"
  chunks_non_patterns_rel="$(manifest_value FPF_CHUNKS_NON_PATTERNS)"

  if ! is_safe_relative_path "$chunks_root_rel" \
    || ! is_safe_relative_path "$chunks_index_rel" \
    || ! is_safe_relative_path "$chunks_metadata_rel" \
    || ! is_safe_relative_path "$chunks_by_pattern_rel" \
    || ! is_safe_relative_path "$chunks_by_section_rel" \
    || ! is_safe_relative_path "$chunks_non_patterns_rel"; then
    chunks_layout_status="invalid"
    chunks_layout_detail="Chunk layout manifest contains an unsafe or empty relative path."
    chunks_root_rel="fpf_chunks"
    chunks_index_rel="000-index.md"
    chunks_metadata_rel="metadata.jsonl"
    chunks_by_pattern_rel="by_pattern"
    chunks_by_section_rel="by_section"
    chunks_non_patterns_rel="non_patterns"
    set_chunk_paths
    return 1
  fi

  chunks_layout_status="ready"
  set_chunk_paths
  return 0
}

append_missing_chunk_entrypoint() {
  local entrypoint="$1"
  if [ -z "$chunks_detail" ]; then
    chunks_detail="$entrypoint"
  else
    chunks_detail="$chunks_detail, $entrypoint"
  fi
}

validate_chunks() {
  chunks_status="missing"
  chunks_mode="blocked"
  chunks_warning=""
  chunks_detail=""

  if ! load_chunk_layout; then
    chunks_status="degraded"
    if [ -f "$SPEC_PATH" ]; then
      chunks_mode="full-spec-fallback"
      chunks_warning="FPF chunks layout manifest is invalid; use FPF-Spec.md fallback for pattern lookup."
      chunks_detail="$chunks_layout_detail"
    else
      chunks_mode="blocked"
      chunks_warning="FPF chunks layout manifest is invalid and FPF-Spec.md is unavailable."
      chunks_detail="$chunks_layout_detail"
    fi
    return
  fi

  if [ ! -d "$CHUNKS_PATH" ]; then
    if [ -f "$SPEC_PATH" ]; then
      chunks_mode="full-spec-fallback"
      chunks_warning="FPF chunks are unavailable; use FPF-Spec.md fallback for pattern lookup."
      chunks_detail="Missing chunk entrypoint: $chunks_root_rel directory."
    else
      chunks_detail="Missing chunk entrypoint: $chunks_root_rel directory; FPF-Spec.md is also unavailable."
    fi
    return
  fi

  if [ ! -r "$CHUNKS_INDEX_PATH" ]; then
    append_missing_chunk_entrypoint "$chunks_index_rel"
  fi
  if [ ! -d "$CHUNKS_BY_PATTERN_DIR" ]; then
    append_missing_chunk_entrypoint "$chunks_by_pattern_rel directory"
  fi
  if [ ! -d "$CHUNKS_BY_SECTION_DIR" ]; then
    append_missing_chunk_entrypoint "$chunks_by_section_rel directory"
  fi
  if [ ! -d "$CHUNKS_NON_PATTERNS_DIR" ]; then
    append_missing_chunk_entrypoint "$chunks_non_patterns_rel directory"
  fi

  if [ -n "$chunks_detail" ]; then
    chunks_status="degraded"
    if [ -f "$SPEC_PATH" ]; then
      chunks_mode="full-spec-fallback"
      chunks_warning="FPF chunks layout is incomplete; use FPF-Spec.md fallback for affected lookups."
      chunks_detail="Missing chunk entrypoints: $chunks_detail."
    else
      chunks_mode="blocked"
      chunks_warning="FPF chunks layout is incomplete and FPF-Spec.md is unavailable."
      chunks_detail="Missing chunk entrypoints: $chunks_detail."
    fi
    return
  fi

  chunks_status="ready"
  chunks_mode="chunk-first"

  if [ ! -r "$CHUNKS_METADATA_PATH" ]; then
    chunks_status="degraded"
    chunks_warning="FPF chunks metadata.jsonl is unavailable; use the index and direct chunk paths."
    chunks_detail="Optional chunk manifest metadata.jsonl was not found."
  fi
}

print_result() {
  local commit="$1"
  validate_chunks
  printf 'FPF_SPEC_PATH=%s\n' "$SPEC_PATH"
  printf 'FPF_SPEC_COMMIT=%s\n' "$commit"
  printf 'FPF_SPEC_STATUS=%s\n' "$status"
  if [ -n "$warning" ]; then
    printf 'FPF_SPEC_WARNING=%s\n' "$warning"
  fi
  if [ -n "$detail" ]; then
    printf 'FPF_SPEC_DETAIL=%s\n' "$detail"
  fi
  printf 'FPF_CHUNKS_LAYOUT_MANIFEST_PATH=%s\n' "$CHUNKS_LAYOUT_MANIFEST_PATH"
  printf 'FPF_CHUNKS_LAYOUT_STATUS=%s\n' "$chunks_layout_status"
  printf 'FPF_CHUNKS_LAYOUT_SOURCE=%s\n' "$chunks_layout_source"
  printf 'FPF_CHUNKS_LAYOUT_VERSION=%s\n' "$chunks_layout_version"
  if [ -n "$chunks_layout_detail" ]; then
    printf 'FPF_CHUNKS_LAYOUT_DETAIL=%s\n' "$chunks_layout_detail"
  fi
  printf 'FPF_CHUNKS_PATH=%s\n' "$CHUNKS_PATH"
  printf 'FPF_CHUNKS_INDEX_PATH=%s\n' "$CHUNKS_INDEX_PATH"
  printf 'FPF_CHUNKS_METADATA_PATH=%s\n' "$CHUNKS_METADATA_PATH"
  printf 'FPF_CHUNKS_BY_PATTERN_DIR=%s\n' "$CHUNKS_BY_PATTERN_DIR"
  printf 'FPF_CHUNKS_BY_SECTION_DIR=%s\n' "$CHUNKS_BY_SECTION_DIR"
  printf 'FPF_CHUNKS_NON_PATTERNS_DIR=%s\n' "$CHUNKS_NON_PATTERNS_DIR"
  printf 'FPF_CHUNKS_STATUS=%s\n' "$chunks_status"
  printf 'FPF_CHUNKS_MODE=%s\n' "$chunks_mode"
  if [ -n "$chunks_warning" ]; then
    printf 'FPF_CHUNKS_WARNING=%s\n' "$chunks_warning"
  fi
  if [ -n "$chunks_detail" ]; then
    printf 'FPF_CHUNKS_DETAIL=%s\n' "$chunks_detail"
  fi
}

cached_commit() {
  local commit
  if command -v git >/dev/null 2>&1 && [ -d "$CACHE_DIR/.git" ]; then
    commit="$(git -C "$CACHE_DIR" rev-parse --verify HEAD 2>/dev/null)" \
      && printf '%s' "$commit" \
      || printf 'unknown'
  else
    printf 'unknown'
  fi
}

cache_allows_hard_reset() {
  [ "$CACHE_DIR" = "$DEFAULT_CACHE_DIR" ] && return 0
  [ -f "$CACHE_MARKER" ] && return 0
  [ "${FPF_ALLOW_NONSTANDARD_CACHE_RESET:-0}" = "1" ] && return 0
  return 1
}

write_cache_marker() {
  {
    printf 'kind=fpf-spec-cache\n'
    printf 'repo=%s\n' "$REPO_URL"
    printf 'branch=%s\n' "$BRANCH"
  } > "$CACHE_MARKER" 2>/dev/null || true
}

if [ "$REFRESH_MODE" = "cache-only" ]; then
  if [ -f "$SPEC_PATH" ]; then
    status="cached"
    print_result "$(cached_commit)"
    exit 0
  fi
  detail="Cache-only mode was requested, but no cached FPF specification exists."
  print_result "none"
  exit 2
fi

if [ "$REFRESH_MODE" != "refresh" ]; then
  detail="Unsupported FPF refresh mode: $REFRESH_MODE."
  print_result "none"
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  if [ -f "$SPEC_PATH" ]; then
    status="cached"
    warning="Git is unavailable; using the last cached FPF specification."
    print_result "$(cached_commit)"
    exit 0
  fi
  detail="Git is unavailable and no cached FPF specification exists."
  print_result "none"
  exit 2
fi

if [ ! -d "$CACHE_DIR/.git" ]; then
  mkdir -p "$(dirname "$CACHE_DIR")"
  if git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$CACHE_DIR" >/dev/null 2>&1; then
    write_cache_marker
    status="fresh"
  else
    if [ -f "$SPEC_PATH" ]; then
      status="cached"
      warning="Could not clone the FPF mirror from GitHub; using the last cached FPF specification."
      commit="$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
      print_result "$commit"
      exit 0
    fi
    detail="Could not clone the FPF mirror from GitHub and no cached FPF specification exists."
    print_result "none"
    exit 2
  fi
else
  if ! cache_allows_hard_reset; then
    if [ -f "$SPEC_PATH" ]; then
      status="cached"
      warning="Refusing to run git reset --hard in a nonstandard FPF cache directory without a cache marker or FPF_ALLOW_NONSTANDARD_CACHE_RESET=1; using the cached FPF specification."
      print_result "$(cached_commit)"
      exit 0
    fi
    detail="Refusing to run git reset --hard in a nonstandard FPF cache directory without a cache marker or FPF_ALLOW_NONSTANDARD_CACHE_RESET=1, and no cached FPF specification exists."
    print_result "none"
    exit 2
  fi
  if git -C "$CACHE_DIR" fetch --depth 1 origin "$BRANCH" >/dev/null 2>&1 \
    && git -C "$CACHE_DIR" checkout -q "$BRANCH" >/dev/null 2>&1 \
    && git -C "$CACHE_DIR" reset --hard "origin/$BRANCH" >/dev/null 2>&1; then
    write_cache_marker
    status="fresh"
  else
    if [ -f "$SPEC_PATH" ]; then
      status="cached"
      warning="Could not update the FPF mirror from GitHub; using the last cached FPF specification."
      commit="$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
      print_result "$commit"
      exit 0
    fi
    detail="Could not update the FPF mirror from GitHub and no cached FPF specification exists."
    print_result "none"
    exit 2
  fi
fi

if [ ! -f "$SPEC_PATH" ]; then
  status="missing"
  detail="The repository was fetched, but FPF-Spec.md was not found at the repository root."
  print_result "$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
  exit 2
fi

print_result "$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
