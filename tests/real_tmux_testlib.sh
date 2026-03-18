#!/usr/bin/env bash
set -euo pipefail

TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/tmux-sidebar-real-tests.XXXXXX")"
REAL_TMUX_SOCKET="tmux-sidebar-real-$$"
REAL_TMUX_STATE_DIR="$TEST_TMP/state"
REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

trap 'tmux -L "$REAL_TMUX_SOCKET" kill-server 2>/dev/null || true; rm -rf "$TEST_TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "expected output to contain [$needle]" ;;
  esac
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  if [ "$actual" != "$expected" ]; then
    fail "expected [$expected], got [$actual]"
  fi
}

real_tmux() {
  tmux -L "$REAL_TMUX_SOCKET" -f /dev/null "$@"
}

real_tmux_start_server() {
  mkdir -p "$REAL_TMUX_STATE_DIR"
  real_tmux new-session -d -s work -n editor
  real_tmux set-environment -g TMUX_SIDEBAR_STATE_DIR "$REAL_TMUX_STATE_DIR"
  real_tmux set-option -g status off
}

real_tmux_source_plugin() {
  real_tmux_source_file "$REPO_ROOT/sidebar.tmux"
}

real_tmux_source_file() {
  local path="$1"
  real_tmux source-file "$path"
}

real_tmux_wait_for_sidebar_pane() {
  local window_id="$1"
  local attempts="${2:-100}"
  local pane_id=""
  local _attempt

  for _attempt in $(seq 1 "$attempts"); do
    pane_id="$(
      real_tmux list-panes -t "$window_id" -F '#{pane_id}|#{pane_title}' \
        | awk -F'|' '$2 == "Sidebar" { print $1; exit }'
    )"
    if [ -n "$pane_id" ]; then
      printf '%s\n' "$pane_id"
      return 0
    fi
    sleep 0.05
  done

  fail "sidebar pane did not appear in window [$window_id]"
}

real_tmux_wait_for_capture() {
  local pane_id="$1"
  local expected="$2"
  local attempts="${3:-100}"
  local capture=""
  local _attempt

  for _attempt in $(seq 1 "$attempts"); do
    capture="$(real_tmux capture-pane -pt "$pane_id" || true)"
    case "$capture" in
      *"$expected"*)
        printf '%s\n' "$capture"
        return 0
        ;;
    esac
    sleep 0.05
  done

  printf '%s\n' "$capture"
  fail "pane [$pane_id] never rendered [$expected]"
}
