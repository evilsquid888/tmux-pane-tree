#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/real_tmux_testlib.sh"

case "$REAL_TMUX_SOCKET_PATH" in
  "$TEST_TMP"/*) ;;
  *) fail "expected real tmux socket path [$REAL_TMUX_SOCKET_PATH] to live under [$TEST_TMP]" ;;
esac

real_tmux_start_server

session_name="$(real_tmux display-message -p -t work:editor '#{session_name}')"
assert_eq "$session_name" 'work'

client_log="$TEST_TMP/client.log"
real_tmux_attach_session_client_info work "$client_log"
client_pid="$REAL_TMUX_CLIENT_PID"
client_tty="$REAL_TMUX_CLIENT_TTY"
[ -n "$client_pid" ] || fail 'expected attached client pid'
case "$client_tty" in
  /dev/*) ;;
  *) fail "expected attached client tty, got [$client_tty]" ;;
esac

attached_client_tty="$(real_tmux_wait_for_client_tty)"
assert_eq "$attached_client_tty" "$client_tty"
kill "$client_pid" 2>/dev/null || true
