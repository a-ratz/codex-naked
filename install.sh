#!/usr/bin/env sh
set -eu

repo="a-ratz/codex-naked"
ref="${CODEX_NAKED_REF:-main}"
prefix="${CODEX_NAKED_PREFIX:-"$HOME/.local"}"
bindir="${CODEX_NAKED_BINDIR:-"$prefix/bin"}"
tmp="$(mktemp)"

cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT INT TERM

say() {
  printf '%s\n' "$*"
}

die() {
  printf 'codex-naked install: %s\n' "$*" >&2
  exit 1
}

fetch() {
  url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tmp" || die "download failed: $url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp" "$url" || die "download failed: $url"
  else
    die "need curl or wget"
  fi
}

mkdir -p "$bindir"

for name in codex-naked claude-naked; do
  fetch "https://raw.githubusercontent.com/$repo/$ref/bin/$name"
  head -n 1 "$tmp" | grep -q '^#!/usr/bin/env bash' || die "downloaded file does not look like $name"
  install -m 755 "$tmp" "$bindir/$name"
  say "Installed $bindir/$name"
done

case ":$PATH:" in
  *":$bindir:"*) ;;
  *) say "Add $bindir to PATH to run codex-naked and claude-naked from any shell." ;;
esac
