#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/bin/codex-naked"
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

make_fake_codex() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/codex" <<'SH'
#!/usr/bin/env bash
{
  printf 'HOME=%s\n' "${HOME:-}"
  printf 'CODEX_HOME=%s\n' "${CODEX_HOME:-}"
  printf 'XDG_CONFIG_HOME=%s\n' "${XDG_CONFIG_HOME:-}"
  printf 'XDG_DATA_HOME=%s\n' "${XDG_DATA_HOME:-}"
  printf 'XDG_STATE_HOME=%s\n' "${XDG_STATE_HOME:-}"
  printf 'XDG_CACHE_HOME=%s\n' "${XDG_CACHE_HOME:-}"
  printf 'ARGS='
  printf '[%s]' "$@"
  printf '\n'
} > "${FAKE_CODEX_ENV_OUT:?missing FAKE_CODEX_ENV_OUT}"
SH
  chmod +x "$dir/codex"
}

run_with_fixture() {
  local root="$1"
  shift
  local original_home="$root/original-home"
  local real_codex="$root/real-codex"
  local fake_bin="$root/fake-bin"
  mkdir -p "$original_home" "$real_codex"
  printf '{"auth":"real"}' > "$real_codex/auth.json"
  make_fake_codex "$fake_bin"
  FAKE_CODEX_ENV_OUT="$root/env.out" \
    HOME="$original_home" \
    CODEX_HOME_REAL="$real_codex" \
    PATH="$fake_bin:$PATH" \
    "$script" "$@"
}

test_print_env_reports_auth_mode() {
  local root="$1"
  local out="$root/print-env.out"
  HOME="$root/home" "$script" \
    --codex-home "$root/codex-home" \
    --user-home "$root/user-home" \
    --auth none \
    --print-env > "$out"
  assert_file_contains "$out" '^AUTH_MODE=none$'
  assert_file_contains "$out" "^NAKED_CODEX_HOME=$root/codex-home$"
  assert_file_contains "$out" "^NAKED_USER_HOME=$root/user-home$"
}

test_default_run_cleans_naked_homes_copies_auth_isolates_home_and_forwards_args() {
  local root="$1"
  mkdir -p "$root/naked-codex" "$root/naked-user"
  printf marker > "$root/naked-codex/MARKER"
  printf marker > "$root/naked-user/MARKER"

  run_with_fixture "$root" \
    --codex-home "$root/naked-codex" \
    --user-home "$root/naked-user" \
    --auth copy \
    exec --skip-git-repo-check "say hi"

  [ ! -e "$root/naked-codex/MARKER" ] || fail "default run left CODEX_HOME marker"
  [ ! -e "$root/naked-user/MARKER" ] || fail "default run left HOME marker"
  [ -f "$root/naked-codex/auth.json" ] || fail "copy auth did not create auth.json"
  [ ! -L "$root/naked-codex/auth.json" ] || fail "copy auth created a symlink"
  cmp "$root/real-codex/auth.json" "$root/naked-codex/auth.json" || fail "copy auth content mismatch"

  assert_file_contains "$root/env.out" "^HOME=$root/naked-user$"
  assert_file_contains "$root/env.out" "^CODEX_HOME=$root/naked-codex$"
  assert_file_contains "$root/env.out" "^XDG_CONFIG_HOME=$root/naked-user/.config$"
  assert_file_contains "$root/env.out" '^ARGS=\[--disable\]\[remote_plugin\]\[exec\]\[--skip-git-repo-check\]\[say hi\]$'
}

test_keep_preserves_previous_naked_homes() {
  local root="$1"
  mkdir -p "$root/naked-codex" "$root/naked-user"
  printf marker > "$root/naked-codex/MARKER"
  printf marker > "$root/naked-user/MARKER"

  run_with_fixture "$root" \
    --codex-home "$root/naked-codex" \
    --user-home "$root/naked-user" \
    --keep \
    debug prompt-input probe

  [ -e "$root/naked-codex/MARKER" ] || fail "keep removed CODEX_HOME marker"
  [ -e "$root/naked-user/MARKER" ] || fail "keep removed HOME marker"
}

test_symlink_auth_tracks_real_auth() {
  local root="$1"
  run_with_fixture "$root" \
    --codex-home "$root/naked-codex" \
    --user-home "$root/naked-user" \
    --auth symlink \
    debug prompt-input probe

  [ -L "$root/naked-codex/auth.json" ] || fail "symlink auth did not create a symlink"
  [ "$(readlink "$root/naked-codex/auth.json")" = "$root/real-codex/auth.json" ] \
    || fail "symlink auth target mismatch"
}

test_none_auth_removes_stale_auth_and_skips_real_home_requirement() {
  local root="$1"
  local original_home="$root/original-home"
  local fake_bin="$root/fake-bin"
  mkdir -p "$original_home" "$root/naked-codex"
  printf stale > "$root/naked-codex/auth.json"
  make_fake_codex "$fake_bin"

  FAKE_CODEX_ENV_OUT="$root/env.out" \
    HOME="$original_home" \
    CODEX_HOME_REAL="$root/missing-real-codex" \
    PATH="$fake_bin:$PATH" \
    "$script" \
      --codex-home "$root/naked-codex" \
      --user-home "$root/naked-user" \
      --auth none \
      debug prompt-input probe

  [ ! -e "$root/naked-codex/auth.json" ] || fail "none auth left stale auth.json"
  assert_file_contains "$root/env.out" "^CODEX_HOME=$root/naked-codex$"
}

test_keep_home_preserves_original_home() {
  local root="$1"
  run_with_fixture "$root" \
    --codex-home "$root/naked-codex" \
    --user-home "$root/naked-user" \
    --keep-home \
    debug prompt-input probe

  assert_file_contains "$root/env.out" "^HOME=$root/original-home$"
}

test_yolo_adds_codex_bypass_flag() {
  local root="$1"
  run_with_fixture "$root" \
    --codex-home "$root/naked-codex" \
    --user-home "$root/naked-user" \
    --yolo \
    exec "say hi"

  assert_file_contains "$root/env.out" '^ARGS=\[--disable\]\[remote_plugin\]\[--dangerously-bypass-approvals-and-sandbox\]\[exec\]\[say hi\]$'
}

test_subcommand_config_arguments_are_forwarded() {
  local root="$1"
  run_with_fixture "$root" \
    --codex-home "$root/naked-codex" \
    --user-home "$root/naked-user" \
    exec -c features.apps=false "say hi"

  assert_file_contains "$root/env.out" '^ARGS=\[--disable\]\[remote_plugin\]\[exec\]\[-c\]\[features.apps=false\]\[say hi\]$'
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

main() {
  local tmp
  tmp="$(mktemp -d)"
  TEST_TMP="$tmp"
  trap cleanup EXIT

  for test_name in \
    test_print_env_reports_auth_mode \
    test_default_run_cleans_naked_homes_copies_auth_isolates_home_and_forwards_args \
    test_keep_preserves_previous_naked_homes \
    test_symlink_auth_tracks_real_auth \
    test_none_auth_removes_stale_auth_and_skips_real_home_requirement \
    test_keep_home_preserves_original_home \
    test_yolo_adds_codex_bypass_flag \
    test_subcommand_config_arguments_are_forwarded \
    test_invalid_auth_mode_fails
  do
    local test_root="$tmp/${test_name#test_}"
    mkdir -p "$test_root"
    "$test_name" "$test_root"
  done

  echo "codex-naked tests passed"
  rm -rf "$tmp"
  TEST_TMP=""
  trap - EXIT
}

main "$@"
