#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/bin/claude-naked"
TEST_TMP=""

cleanup() {
  if [ -n "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  rg -q -- "$pattern" "$file" || fail "$file does not contain $pattern"
}

make_fake_claude() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/claude" <<'SH'
#!/usr/bin/env bash
{
  printf 'HOME=%s\n' "${HOME:-}"
  printf 'CLAUDE_CONFIG_DIR=%s\n' "${CLAUDE_CONFIG_DIR:-}"
  printf 'XDG_CONFIG_HOME=%s\n' "${XDG_CONFIG_HOME:-}"
  printf 'XDG_DATA_HOME=%s\n' "${XDG_DATA_HOME:-}"
  printf 'XDG_STATE_HOME=%s\n' "${XDG_STATE_HOME:-}"
  printf 'XDG_CACHE_HOME=%s\n' "${XDG_CACHE_HOME:-}"
  printf 'ARGS='
  printf '[%s]' "$@"
  printf '\n'
} > "${FAKE_CLAUDE_ENV_OUT:?missing FAKE_CLAUDE_ENV_OUT}"
SH
  chmod +x "$dir/claude"
}

run_with_fixture() {
  local root="$1"
  shift
  local original_home="$root/original-home"
  local real_claude="$root/real-claude"
  local fake_bin="$root/fake-bin"
  mkdir -p "$original_home" "$real_claude"
  printf '{"auth":"real"}' > "$real_claude/.credentials.json"
  make_fake_claude "$fake_bin"
  FAKE_CLAUDE_ENV_OUT="$root/env.out" \
    HOME="$original_home" \
    CLAUDE_HOME_REAL="$real_claude" \
    PATH="$fake_bin:$PATH" \
    "$script" "$@"
}

test_print_env_reports_auth_mode_and_yolo_default() {
  local root="$1"
  local out="$root/print-env.out"
  HOME="$root/home" "$script" \
    --config-dir "$root/config-dir" \
    --user-home "$root/user-home" \
    --auth none \
    --print-env > "$out"
  assert_file_contains "$out" '^AUTH_MODE=none$'
  assert_file_contains "$out" "^NAKED_CONFIG_DIR=$root/config-dir$"
  assert_file_contains "$out" "^NAKED_USER_HOME=$root/user-home$"
  assert_file_contains "$out" '^YOLO=1$'
}

test_default_run_cleans_naked_homes_copies_auth_isolates_home_and_forwards_args() {
  local root="$1"
  mkdir -p "$root/naked-config" "$root/naked-user"
  printf marker > "$root/naked-config/MARKER"
  printf marker > "$root/naked-user/MARKER"

  run_with_fixture "$root" \
    --config-dir "$root/naked-config" \
    --user-home "$root/naked-user" \
    --auth copy \
    -p "say hi"

  [ ! -e "$root/naked-config/MARKER" ] || fail "default run left CLAUDE_CONFIG_DIR marker"
  [ ! -e "$root/naked-user/MARKER" ] || fail "default run left HOME marker"
  [ -f "$root/naked-config/.credentials.json" ] || fail "copy auth did not create .credentials.json"
  [ ! -L "$root/naked-config/.credentials.json" ] || fail "copy auth created a symlink"
  cmp "$root/real-claude/.credentials.json" "$root/naked-config/.credentials.json" \
    || fail "copy auth content mismatch"

  assert_file_contains "$root/env.out" "^HOME=$root/naked-user$"
  assert_file_contains "$root/env.out" "^CLAUDE_CONFIG_DIR=$root/naked-config$"
  assert_file_contains "$root/env.out" "^XDG_CONFIG_HOME=$root/naked-user/.config$"
  assert_file_contains "$root/env.out" '^ARGS=\[--dangerously-skip-permissions\]\[--strict-mcp-config\]\[--setting-sources\]\[project,local\]\[-p\]\[say hi\]$'
}

test_keep_preserves_previous_naked_homes() {
  local root="$1"
  mkdir -p "$root/naked-config" "$root/naked-user"
  printf marker > "$root/naked-config/MARKER"
  printf marker > "$root/naked-user/MARKER"

  run_with_fixture "$root" \
    --config-dir "$root/naked-config" \
    --user-home "$root/naked-user" \
    --keep \
    -p probe

  [ -e "$root/naked-config/MARKER" ] || fail "keep removed CLAUDE_CONFIG_DIR marker"
  [ -e "$root/naked-user/MARKER" ] || fail "keep removed HOME marker"
}

test_symlink_auth_tracks_real_auth() {
  local root="$1"
  run_with_fixture "$root" \
    --config-dir "$root/naked-config" \
    --user-home "$root/naked-user" \
    --auth symlink \
    -p probe

  [ -L "$root/naked-config/.credentials.json" ] || fail "symlink auth did not create a symlink"
  [ "$(readlink "$root/naked-config/.credentials.json")" = "$root/real-claude/.credentials.json" ] \
    || fail "symlink auth target mismatch"
}

test_none_auth_removes_stale_auth_and_skips_real_home_requirement() {
  local root="$1"
  local original_home="$root/original-home"
  local fake_bin="$root/fake-bin"
  mkdir -p "$original_home" "$root/naked-config"
  printf stale > "$root/naked-config/.credentials.json"
  make_fake_claude "$fake_bin"

  FAKE_CLAUDE_ENV_OUT="$root/env.out" \
    HOME="$original_home" \
    CLAUDE_HOME_REAL="$root/missing-real-claude" \
    PATH="$fake_bin:$PATH" \
    "$script" \
      --config-dir "$root/naked-config" \
      --user-home "$root/naked-user" \
      --auth none \
      -p probe

  [ ! -e "$root/naked-config/.credentials.json" ] || fail "none auth left stale .credentials.json"
  assert_file_contains "$root/env.out" "^CLAUDE_CONFIG_DIR=$root/naked-config$"
}

test_keep_home_preserves_original_home_but_still_isolates_config() {
  local root="$1"
  run_with_fixture "$root" \
    --config-dir "$root/naked-config" \
    --user-home "$root/naked-user" \
    --keep-home \
    -p probe

  assert_file_contains "$root/env.out" "^HOME=$root/original-home$"
  assert_file_contains "$root/env.out" "^CLAUDE_CONFIG_DIR=$root/naked-config$"
}

test_yolo_is_on_by_default() {
  local root="$1"
  run_with_fixture "$root" \
    --config-dir "$root/naked-config" \
    --user-home "$root/naked-user" \
    -p "say hi"

  assert_file_contains "$root/env.out" '^ARGS=\[--dangerously-skip-permissions\]\[--strict-mcp-config\]\[--setting-sources\]\[project,local\]\[-p\]\[say hi\]$'
}

test_no_yolo_drops_the_bypass_flag() {
  local root="$1"
  run_with_fixture "$root" \
    --config-dir "$root/naked-config" \
    --user-home "$root/naked-user" \
    --no-yolo \
    -p "say hi"

  assert_file_contains "$root/env.out" '^ARGS=\[--strict-mcp-config\]\[--setting-sources\]\[project,local\]\[-p\]\[say hi\]$'
}

test_account_context_lets_the_login_context_in() {
  local root="$1"
  run_with_fixture "$root" \
    --config-dir "$root/naked-config" \
    --user-home "$root/naked-user" \
    --account-context \
    -p "say hi"

  assert_file_contains "$root/env.out" '^ARGS=\[--dangerously-skip-permissions\]\[-p\]\[say hi\]$'
}

test_invalid_auth_mode_fails() {
  local root="$1"
  local out="$root/invalid.out"
  set +e
  HOME="$root/home" "$script" --auth nope --print-env > "$out" 2>&1
  local status=$?
  set -e
  [ "$status" -ne 0 ] || fail "invalid auth mode unexpectedly passed"
  assert_file_contains "$out" "invalid --auth mode 'nope'"
}

test_refuses_to_clean_real_claude_home() {
  local root="$1"
  local out="$root/refuse.out"
  mkdir -p "$root/original-home/.claude"
  set +e
  HOME="$root/original-home" \
    CLAUDE_HOME_REAL="$root/original-home/.claude" \
    "$script" --config-dir "$root/original-home/.claude" --auth none -p probe > "$out" 2>&1
  local status=$?
  set -e
  [ "$status" -ne 0 ] || fail "cleaning the real Claude home unexpectedly passed"
  assert_file_contains "$out" "refusing to clean real"
}

main() {
  local tmp
  tmp="$(mktemp -d)"
  TEST_TMP="$tmp"
  trap cleanup EXIT

  for test_name in \
    test_print_env_reports_auth_mode_and_yolo_default \
    test_default_run_cleans_naked_homes_copies_auth_isolates_home_and_forwards_args \
    test_keep_preserves_previous_naked_homes \
    test_symlink_auth_tracks_real_auth \
    test_none_auth_removes_stale_auth_and_skips_real_home_requirement \
    test_keep_home_preserves_original_home_but_still_isolates_config \
    test_yolo_is_on_by_default \
    test_no_yolo_drops_the_bypass_flag \
    test_account_context_lets_the_login_context_in \
    test_invalid_auth_mode_fails \
    test_refuses_to_clean_real_claude_home
  do
    local test_root="$tmp/${test_name#test_}"
    mkdir -p "$test_root"
    "$test_name" "$test_root"
  done

  echo "claude-naked tests passed"
  rm -rf "$tmp"
  TEST_TMP=""
  trap - EXIT
}

main "$@"
